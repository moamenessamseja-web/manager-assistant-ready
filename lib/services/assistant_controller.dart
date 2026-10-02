import 'package:uuid/uuid.dart';
import '../models/commitment.dart';
import '../models/employee.dart';
import '../models/supplier.dart';
import '../models/rule.dart';
import 'gemini_service.dart';
import 'storage_service.dart';
import 'reminder_service.dart';

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

    switch (intent) {
      case 'add_employee':
        return _addEmployee(d);
      case 'add_advance':
        return _addAdvance(d, text);
      case 'mark_attendance':
        return _markAttendance(d);
      case 'add_supplier':
        return _addSupplier(d);
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
      totalOwed: (d['amount'] as num?)?.toDouble() ?? 0,
    );
    await StorageService.saveSupplier(s);
    return '✅ سجلت المورد ${s.name}${s.itemType.isEmpty ? '' : ' (${s.itemType})'}.';
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
    return '✅ متوقع توريد ${del.item.isEmpty ? '' : '${del.item} '}من ${s.name} يوم ${del.expectedDate.toString().substring(0, 10)}.${outcome.warningSuffix}';
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
    final amount = (d['amount'] as num?)?.toDouble();
    if (amount != null) s.totalOwed += amount;
    await StorageService.saveSupplier(s);
    return '✅ تم تأكيد استلام التوريد من ${s.name}.${amount != null ? ' أُضيف ${amount.toStringAsFixed(0)} جنيه على حسابه (المستحق الآن ${s.balanceDue.toStringAsFixed(0)} جنيه).' : ''}';
  }

  static Future<String> _addSupplierPayment(Map<String, dynamic> d) async {
    final resolved = _resolveSupplier(d['person'] ?? '');
    if (!resolved.ok) return resolved.message!;
    final s = resolved.value!;
    s.payments.add(SupplierPayment(
        id: const Uuid().v4(), amount: (d['amount'] as num?)?.toDouble() ?? 0, date: DateTime.now()));
    await StorageService.saveSupplier(s);
    return '✅ سجلت دفعة لـ ${s.name}. المتبقي عليك له: ${s.balanceDue.toStringAsFixed(0)} جنيه.';
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
    return '✅ قاعدة متابعة جديدة: ${r.text}\nهتتفعل أول مرة يوم ${r.nextDue.toString().substring(0, 10)}.';
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
    return 'تمام ✅ سجلت ${c.person}${c.amount == null ? '' : ' - ${c.amount!.toStringAsFixed(0)} جنيه'}، والتذكير ${c.remindAt.toString().substring(0, 16)}.${outcome.warningSuffix}';
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
        final lines = debts.map((c) => '• ${c.person}: ${c.amount!.toStringAsFixed(0)} ج (${c.dueDate.toString().substring(0, 10)})');
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
        return 'المستحق عليك لـ ${s.name}: ${s.balanceDue.toStringAsFixed(0)} جنيه.';

      case 'advances_this_week':
        final weekAgo = today.subtract(const Duration(days: 7));
        final rows = <String>[];
        for (final e in StorageService.employees()) {
          final recent = e.advances.where((a) => a.date.isAfter(weekAgo));
          for (final a in recent) {
            rows.add('• ${e.name}: ${a.amount.toStringAsFixed(0)} ج (${a.date.toString().substring(0, 10)})');
          }
        }
        if (rows.isEmpty) return 'مفيش سلف اتسجلت في آخر أسبوع.';
        return 'السلف في آخر أسبوع:\n${rows.join('\n')}';

      default:
        return 'تقدر تسأل: "مين عليه فلوس؟" أو "مين ما حضرش النهارده؟" أو "كام للمورد [الاسم]؟" أو "مين أخد سلف الأسبوع ده؟"';
    }
  }
}
