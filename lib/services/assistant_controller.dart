import 'package:uuid/uuid.dart';
import '../models/commitment.dart';
import '../models/employee.dart';
import '../models/supplier.dart';
import '../models/rule.dart';
import 'gemini_service.dart';
import 'storage_service.dart';
import 'reminder_service.dart';
import '../design/format.dart';

/// نتيجة البحث عن كيان (موظف/مورد) بالاسم — بتميّز صراحة بين:
/// "لقيت واحد بالظبط" و"لقيت أكتر من واحد (محتاج توضيح)" و"مفيش حد".
/// الهدف: عدم التخمين أبدًا لو فيه أكتر من تطابق (راجع قسم Entity Resolution).
class _Resolved<T> {
  final T? value;
  final String? message; // موجودة لو فشل الحل (مفيش / أكتر من واحد)
  const _Resolved(this.value, this.message);
  bool get ok => value != null;
}

class AssistantController {
  static Future<String> handle(String text) async {
    final key = StorageService.apiKey;
    if (key.isEmpty) return '⚠️ ضع مفتاح Gemini من الإعدادات أولاً.';
    final d = await GeminiService(key).parse(text);
    final intent = d['intent'] ?? 'other';

    // موثوقية المبلغ: بعض النوايا محتاجة رقمًا. لو الموديل سابه فاضي،
    // نعيد التحليل **مرة واحدة** — بدون اختراع أي رقم من عندنا.
    if (_needsAmount.contains(intent) && _missingAmount(intent, d)) {
      final retry = await GeminiService(key).parse(text);
      if (!_missingAmount(intent, retry)) {
        d
          ..clear()
          ..addAll(retry);
      }
    }

    // آخر خط دفاع (آمن تمامًا): لو الجملة فيها **رقم واحد فقط** والمبلغ لسه
    // ناقص، فهو المبلغ بلا لبس. لو فيه أكتر من رقم، منخمّنش ونسأل المستخدم.
    if (_needsAmount.contains(intent) && _missingAmount(intent, d)) {
      final only = _singleNumberInText(text);
      if (only != null) d['amount'] = only;
    }

    // §9 — أمر واحد بعدة أسماء: يُنفَّذ لكل اسم على حدة ثم تُجمَع النتائج،
    // بدل ما يفشل أو ينفّذ على أول اسم بس.
    final people = <String>[
      for (final p in (d['people'] as List? ?? []))
        if (p.toString().trim().isNotEmpty) p.toString().trim(),
    ];
    if (people.length > 1 && _multiPersonIntents.contains(intent)) {
      final results = <String>[];
      for (final name in people) {
        final one = Map<String, dynamic>.from(d);
        one['person'] = name;
        one['employee_name'] = name;
        one['people'] = <String>[];
        results.add(await _dispatch(intent, one, text));
      }
      return '📋 نُفِّذ الأمر على ${people.length} أسماء:\n${results.map((r) => '• $r').join('\n')}';
    }
    return _dispatch(intent, d, text);
  }

  /// النوايا اللي لازم يكون فيها رقم مالي.
  static const Set<String> _needsAmount = {
    'add_supplier_payment',
    'add_advance',
    'add_deduction',
    'add_bonus',
    'create_commitment',
    'record_purchase',
  };

  /// يرجع الرقم المذكور في النص **فقط لو كان رقمًا واحدًا** (أرقام عربية أو
  /// هندية أو إنجليزية). لو فيه أكتر من رقم، يرجع null — لأن الاختيار هيكون تخمين.
  static double? _singleNumberInText(String text) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final buf = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final ai = ar.indexOf(ch);
      final fi = fa.indexOf(ch);
      if (ai >= 0) {
        buf.write(ai);
      } else if (fi >= 0) {
        buf.write(fi);
      } else {
        buf.write(ch);
      }
    }
    final matches = RegExp(r'\d+(?:\.\d+)?').allMatches(buf.toString()).toList();
    if (matches.length != 1) return null;
    final v = double.tryParse(matches.first.group(0)!);
    return (v == null || v <= 0) ? null : v;
  }

  /// هل الرقم المالي ناقص فعلًا في نتيجة التحليل؟
  static bool _missingAmount(String intent, Map<String, dynamic> d) {
    final hasAmount = ((d['amount'] as num?)?.toDouble() ?? 0) > 0;
    if (intent == 'record_purchase') {
      return !hasAmount && resolvePurchaseTotal(d) <= 0;
    }
    return !hasAmount;
  }

  /// الأنواع اللي معناها قد يخص أكتر من شخص واحد (§9).
  static const Set<String> _multiPersonIntents = {
    'mark_attendance',
    'add_advance',
    'add_supplier_payment',
    'record_purchase',
    'add_employee',
    'create_commitment',
  };

  static Future<String> _dispatch(String intent, Map<String, dynamic> d, String text) async {
    switch (intent) {
      case 'add_employee':
        return _addEmployee(d);
      case 'add_advance':
        return _addAdvance(d, text);
      case 'mark_attendance':
        return _markAttendance(d);
      case 'add_supplier':
        return _addSupplier(d);
      case 'record_purchase':
        return _recordPurchaseIntent(d);
      case 'supplier_delivery':
        return _supplierDelivery(d);
      case 'mark_delivery_received':
        return _markDeliveryReceived(d);
      case 'add_supplier_payment':
        return _addSupplierPayment(d);
      case 'add_rule':
        return _addRule(d);
      case 'query_business_data':
        return _queryBusinessData(d);
      case 'create_commitment':
        return _createCommitment(d, text);
      default:
        return 'لم أفهم العملية المطلوبة بوضوح. جرب تصيغها بشكل تاني.';
    }
  }

  // ---------------- Entity resolution (لا تخمين عند التباس) ----------------

  static _Resolved<Employee> _resolveEmployee(String name) {
    if (name.trim().isEmpty) return const _Resolved(null, '❓ محتاج اسم الموظف.');
    final matches = StorageService.employeesMatching(name);
    if (matches.isEmpty) return _Resolved(null, '❓ لم أجد موظف باسم $name.');
    if (matches.length > 1) {
      final opts = matches.map((e) => '${e.name} (${e.role})').join(' / ');
      return _Resolved(null, '🤔 عندي أكتر من موظف بنفس الاسم: $opts. وضّح مين بالظبط؟');
    }
    return _Resolved(matches.first, null);
  }

  static _Resolved<Supplier> _resolveSupplier(String name) {
    if (name.trim().isEmpty) return const _Resolved(null, '❓ محتاج اسم المورد.');
    final matches = StorageService.suppliersMatching(name);
    if (matches.isEmpty) return _Resolved(null, '❓ لم أجد مورد باسم $name.');
    if (matches.length > 1) {
      final opts = matches.map((s) => '${s.name} (${s.itemType})').join(' / ');
      return _Resolved(null, '🤔 عندي أكتر من مورد بنفس الاسم: $opts. وضّح مين بالظبط؟');
    }
    return _Resolved(matches.first, null);
  }

  // ---------------- Employees ----------------

  static Future<String> _addEmployee(Map<String, dynamic> d) async {
    final e = Employee(
      id: const Uuid().v4(),
      name: d['employee_name'] ?? d['person'] ?? 'موظف',
      role: d['employee_role'] ?? 'عامل',
      startDate: DateTime.tryParse(d['start_date'] ?? '') ?? DateTime.now(),
      salaryMonthly: (d['salary'] as num?)?.toDouble() ?? 0,
    );
    await StorageService.saveEmployee(e);
    return '✅ سجلت الموظف ${e.name}، المرتب ${e.salaryMonthly.toStringAsFixed(0)} جنيه.';
  }

  static Future<String> _addAdvance(Map<String, dynamic> d, String text) async {
    final name = d['person'] ?? d['employee_name'] ?? '';
    final resolved = _resolveEmployee(name);
    if (!resolved.ok) return resolved.message!;
    final e = resolved.value!;
    e.advances.add(Advance(
        id: const Uuid().v4(), amount: (d['amount'] as num?)?.toDouble() ?? 0, date: DateTime.now(), note: text));
    await StorageService.saveEmployee(e);
    return '✅ سجلت السلفة لـ ${e.name}. باقي له ${e.remainingSalary.toStringAsFixed(0)} جنيه.';
  }

  static Future<String> _markAttendance(Map<String, dynamic> d) async {
    final resolved = _resolveEmployee(d['person'] ?? '');
    if (!resolved.ok) return resolved.message!;
    final e = resolved.value!;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    if (!e.attendance.contains(day)) e.attendance.add(day);
    await StorageService.saveEmployee(e);
    return '✅ تم تسجيل حضور ${e.name} اليوم.';
  }

  // ---------------- Suppliers ----------------

  static Future<String> _addSupplier(Map<String, dynamic> d) async {
    final name = d['person'] ?? 'مورد';
    if (StorageService.suppliersMatching(name).isNotEmpty) {
      return 'ℹ️ عندي مورد بنفس الاسم مسجل بالفعل.';
    }
    final s = Supplier(
      id: const Uuid().v4(),
      name: name,
      itemType: d['supplier_item'] ?? '',
      phone: d['supplier_phone'] ?? '',
    );
    // لو المستخدم ذكر قيمة بضاعة ابتدائية، تُسجَّل كسجل توريد بقيمة —
    // وليست "دين" مقتضب. لو ذكر مبلغ مدفوع فقط، لا تُسجَّل بضاعة.
    _appendPurchase(s, d);
    await StorageService.saveSupplier(s);
    return '✅ سجلت المورد ${s.name}${s.itemType.isEmpty ? '' : ' (${s.itemType})'}.';
  }

  /// ينشئ سجل توريد بقيمة من بيانات الـAI (item/quantity/unitPrice/total).
  /// القاعدة: الإجمالي الصريح أولاً، ثم الكمية × سعر الوحدة.
  /// يرجع null لو مفيش قيمة ولا كمية وسعر → لا تُسجَّل بضاعة وهمية.
  /// قاعدة استنتاج إجمالي التوريد من بيانات الـAI — مكشوفة للاختبار الحقيقي.
  /// الأولوية: الإجمالي الصريح → المبلغ العام → الكمية × سعر الوحدة.
  /// (الموديل أحيانًا يرجّع سعر الوحدة بدل الإجمالي، فالقاعدة دي بتغطّي الحالتين.)
  static double resolvePurchaseTotal(Map<String, dynamic> d) {
    final qty = (d['purchase_quantity'] as num?)?.toDouble() ??
        (d['delivery_quantity'] as num?)?.toDouble();
    final unitPrice = (d['purchase_unit_price'] as num?)?.toDouble() ?? 0;
    var total = (d['purchase_total'] as num?)?.toDouble() ??
        (d['amount'] as num?)?.toDouble() ??
        0;
    if (total <= 0 && qty != null && unitPrice > 0) total = qty * unitPrice;
    return total;
  }

  static SupplierPurchase? _appendPurchase(Supplier s, Map<String, dynamic> d) {
    final qty = (d['purchase_quantity'] as num?)?.toDouble() ??
        (d['delivery_quantity'] as num?)?.toDouble();
    var unitPrice = (d['purchase_unit_price'] as num?)?.toDouble() ?? 0;
    final total = resolvePurchaseTotal(d);
    if (total <= 0) return null;
    if (unitPrice <= 0 && qty != null && qty > 0) unitPrice = total / qty;
    final p = SupplierPurchase(
      id: const Uuid().v4(),
      item: d['purchase_item'] ?? d['delivery_item'] ?? s.itemType,
      quantity: qty,
      unit: d['purchase_unit'] ?? d['delivery_unit'] ?? '',
      unitPrice: unitPrice,
      total: total,
      date: DateTime.now(),
      note: d['text_original'] ?? '',
    );
    s.purchases.add(p);
    return p;
  }

  /// تسجيل توريد/مشتريات بقيمة (بضاعة مستلمة) — منفصل تمامًا عن الدفعات.
  static Future<String> _recordPurchaseIntent(Map<String, dynamic> d) async {
    final name = d['person'] ?? '';
    if (name.trim().isEmpty) return '❓ محتاج اسم المورد.';
    final resolved = _resolveSupplier(name);
    Supplier s;
    if (!resolved.ok) {
      final matches = StorageService.suppliersMatching(name);
      if (matches.length > 1) return resolved.message!;
      s = Supplier(id: const Uuid().v4(), name: name, itemType: d['supplier_item'] ?? '');
    } else {
      s = resolved.value!;
    }
    final added = _appendPurchase(s, d);
    if (added == null) {
      return '❓ محتاج قيمة التوريد، أو الكمية وسعر الوحدة، عشان أسجّلها صح.';
    }
    await StorageService.saveSupplier(s);
    final qty = added.quantityLabel.isEmpty ? '' : ' (${added.quantityLabel})';
    return '✅ سجلت توريد ${added.item}$qty بقيمة ${added.total.toStringAsFixed(0)} ج '
        'على حساب ${s.name}. إجمالي البضاعة ${s.goodsTotal.toStringAsFixed(0)} ج، '
        'المتبقي ${s.balanceDue.toStringAsFixed(0)} ج.';
  }

  static Future<String> _supplierDelivery(Map<String, dynamic> d) async {
    final name = d['person'] ?? '';
    var resolved = _resolveSupplier(name);
    Supplier s;
    if (!resolved.ok) {
      // لو مفيش مورد بهذا الاسم خالص (مش التباس)، ننشئه تلقائيًا بدل الرفض —
      // لكن لو فيه التباس (أكتر من واحد) نوقف ونطلب توضيح.
      final matches = StorageService.suppliersMatching(name);
      if (matches.length > 1) return resolved.message!;
      s = Supplier(id: const Uuid().v4(), name: name.isEmpty ? 'مورد' : name, itemType: d['supplier_item'] ?? '');
    } else {
      s = resolved.value!;
    }
    final del = Delivery(
      id: const Uuid().v4(),
      item: d['delivery_item'] ?? s.itemType,
      quantity: (d['delivery_quantity'] as num?)?.toDouble(),
      unit: d['delivery_unit'] ?? '',
      expectedDate: DateTime.tryParse(d['due_date'] ?? '') ?? DateTime.now().add(const Duration(days: 1)),
    );
    s.deliveries.add(del);
    await StorageService.saveSupplier(s);
    final rem = DateTime.tryParse((d['remind_at'] ?? '').replaceFirst(' ', 'T')) ??
        del.expectedDate.subtract(const Duration(hours: 2));
    final c = Commitment(
      id: const Uuid().v4(),
      textOriginal: d['text_original'] ?? '',
      person: s.name,
      type: 'supplier',
      dueDate: del.expectedDate,
      remindAt: rem,
    );
    await StorageService.saveCommitment(c);
    final outcome = await ReminderService.createAndSchedule(
      title: 'توريد متوقع: ${s.name}',
      body: c.textOriginal.isEmpty ? 'توريد ${del.item} من ${s.name}' : c.textOriginal,
      dueAt: rem,
      relatedEntityId: c.id,
      relatedEntityType: 'commitment',
    );
    return '✅ متوقع توريد ${del.item.isEmpty ? '' : '${del.item} '}من ${s.name} يوم ${arabicDateTime(del.expectedDate)}.${outcome.warningSuffix}';
  }

  static Future<String> _markDeliveryReceived(Map<String, dynamic> d) async {
    final resolved = _resolveSupplier(d['person'] ?? '');
    if (!resolved.ok) return resolved.message!;
    final s = resolved.value!;
    final pending = s.pendingDeliveries;
    if (pending.isEmpty) return '❓ مفيش توريدات متوقعة من ${s.name} حالياً.';
    final del = pending.first;
    del.received = true;
    del.receivedDate = DateTime.now();
    // لو ذُكرت قيمة (أو كمية × سعر) تُسجَّل كتوريد بقيمة مرتبط بهذا التوريد المتوقع.
    // مبلغ البضاعة لا يُسجَّل كدفعة — الدفعات لها مسارها المستقل.
    final merged = Map<String, dynamic>.from(d);
    merged['purchase_item'] ??= del.item;
    merged['purchase_quantity'] ??= del.quantity;
    merged['purchase_unit'] ??= del.unit;
    final added = _appendPurchase(s, merged);
    if (added != null) added.deliveryId = del.id;
    await StorageService.saveSupplier(s);
    return '✅ تم تأكيد استلام ${del.item} من ${s.name}.'
        '${added != null ? ' أُضيف توريد بقيمة ${added.total.toStringAsFixed(0)} ج (المتبقي الآن ${s.balanceDue.toStringAsFixed(0)} ج).' : ' (من غير قيمة مسجّلة — سجّل القيمة لو عايز تتبّع الحساب.)'}';
  }

  static Future<String> _addSupplierPayment(Map<String, dynamic> d) async {
    final resolved = _resolveSupplier(d['person'] ?? '');
    if (!resolved.ok) return resolved.message!;
    final s = resolved.value!;
    final amt = (d['amount'] as num?)?.toDouble() ?? 0;
    if (amt <= 0) return '❓ محتاج مبلغ الدفعة اللي اتدفعت فعلاً.';
    s.payments.add(SupplierPayment(
      id: const Uuid().v4(),
      amount: amt,
      date: DateTime.now(),
      note: d['text_original'] ?? '',
    ));
    await StorageService.saveSupplier(s);
    return '✅ سجلت دفعة ${amt.toStringAsFixed(0)} ج لـ ${s.name} (نقد مدفوع). '
        'إجمالي البضاعة ${s.goodsTotal.toStringAsFixed(0)} ج، المتبقي ${s.balanceDue.toStringAsFixed(0)} ج.';
  }

  // ---------------- Rules ----------------

  static Future<String> _addRule(Map<String, dynamic> d) async {
    final freq = d['rule_frequency'] ?? 'monthly';
    final anchor = (d['rule_anchor'] as num?)?.toInt() ?? 1;
    final now = DateTime.now();
    DateTime next;
    if (freq == 'weekly') {
      final addDays = (anchor - now.weekday) % 7;
      next = DateTime(now.year, now.month, now.day, 9).add(Duration(days: addDays == 0 ? 7 : addDays));
    } else if (freq == 'daily') {
      next = DateTime(now.year, now.month, now.day, 9).add(const Duration(days: 1));
    } else {
      var y = now.year, m = now.month;
      if (now.day >= anchor) {
        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
      }
      final lastDay = DateTime(y, m + 1, 0).day;
      next = DateTime(y, m, anchor.clamp(1, lastDay), 9);
    }
    final r = FollowUpRule(
      id: const Uuid().v4(),
      text: d['rule_text'] ?? d['text_original'] ?? '',
      frequency: freq,
      anchor: anchor,
      amount: (d['amount'] as num?)?.toDouble(),
      nextDue: next,
    );
    await StorageService.saveRule(r);
    return '✅ قاعدة متابعة جديدة: ${r.text}\nهتتفعل أول مرة يوم ${arabicDateTime(r.nextDue)}.';
  }

  // ---------------- Commitments ----------------

  static Future<String> _createCommitment(Map<String, dynamic> d, String text) async {
    final due = DateTime.tryParse(d['due_date'] ?? '') ?? DateTime.now().add(const Duration(days: 1));
    final rem = DateTime.tryParse((d['remind_at'] ?? '').replaceFirst(' ', 'T')) ?? due.subtract(const Duration(hours: 1));
    final c = Commitment(
      id: const Uuid().v4(),
      textOriginal: d['text_original'] ?? text,
      person: d['person'] ?? 'عام',
      type: d['type'] ?? 'task',
      amount: (d['amount'] as num?)?.toDouble(),
      dueDate: due,
      remindAt: rem,
      followUpRule: d['follow_up_rule'] ?? '',
    );
    await StorageService.saveCommitment(c);
    final outcome = await ReminderService.createAndSchedule(
      title: 'تذكير: ${c.person}',
      body: c.textOriginal,
      dueAt: c.remindAt,
      relatedEntityId: c.id,
      relatedEntityType: 'commitment',
    );
    return 'تمام ✅ سجلت ${c.person}${c.amount == null ? '' : ' - ${c.amount!.toStringAsFixed(0)} جنيه'}، والتذكير ${arabicDateTime(c.remindAt)}.${outcome.warningSuffix}';
  }

  // ---------------- Live business queries (من قاعدة البيانات مباشرة، مش من ذاكرة المحادثة) ----------------

  static Future<String> _queryBusinessData(Map<String, dynamic> d) async {
    final type = d['query_type'] ?? '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (type) {
      case 'debtors':
      case 'who_owes':
        final debts = StorageService.commitments()
            .where((c) => c.status == 'pending' && c.type == 'debt_to_collect' && (c.amount ?? 0) > 0)
            .toList();
        if (debts.isEmpty) return 'مفيش حد عليه فلوس مسجل دلوقتي. 🎉';
        final lines = debts.map((c) => '• ${c.person}: ${c.amount!.toStringAsFixed(0)} ج (${arabicDate(c.dueDate)})');
        return 'اللي عليهم فلوس:\n${lines.join('\n')}';

      case 'absent_today':
        final emps = StorageService.employees().where((e) => !e.archived).toList();
        final todayStr = today.toIso8601String().substring(0, 10);
        final absent = emps.where((e) => !e.attendance.contains(todayStr)).toList();
        if (absent.isEmpty) return 'كل العاملين سجلوا حضورهم النهاردة. ✅';
        return 'لسه ما سجلوش حضور النهاردة:\n${absent.map((e) => '• ${e.name}').join('\n')}';

      case 'supplier_balance':
        final name = d['person'] ?? '';
        final resolved = _resolveSupplier(name);
        if (!resolved.ok) return resolved.message!;
        final s = resolved.value!;
        return 'حساب ${s.name}:\n'
            '• إجمالي البضاعة: ${s.goodsTotal.toStringAsFixed(0)} ج\n'
            '• المدفوع: ${s.totalPaid.toStringAsFixed(0)} ج\n'
            '• المتبقي: ${s.balanceDue.toStringAsFixed(0)} ج';

      case 'advances_this_week':
        final weekAgo = today.subtract(const Duration(days: 7));
        final rows = <String>[];
        for (final e in StorageService.employees()) {
          final recent = e.advances.where((a) => a.date.isAfter(weekAgo));
          for (final a in recent) {
            rows.add('• ${e.name}: ${a.amount.toStringAsFixed(0)} ج (${arabicDateTime(a.date)})');
          }
        }
        if (rows.isEmpty) return 'مفيش سلف اتسجلت في آخر أسبوع.';
        return 'السلف في آخر أسبوع:\n${rows.join('\n')}';

      default:
        return 'تقدر تسأل: "مين عليه فلوس؟" أو "مين ما حضرش النهارده؟" أو "كام للمورد [الاسم]؟" أو "مين أخد سلف الأسبوع ده؟"';
    }
  }
}
