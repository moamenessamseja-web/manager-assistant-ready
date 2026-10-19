import 'package:uuid/uuid.dart';
import '../models/commitment.dart';
import '../models/employee.dart';
import '../models/supplier.dart';
import '../models/rule.dart';
import 'storage_service.dart';
import 'reminder_service.dart';
import 'local_command_parser.dart';
import 'conversation_context_service.dart';
import 'app_error_service.dart';
import '../design/format.dart';
import 'choice_builder.dart';
import 'idempotency_service.dart';

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
  /// نقطة الدخول الموحّدة. التسلسل (بريف §3 و§4):
  /// 1) استكمال عملية معلّقة من السياق.
  /// 2) المحلل المحلي — بدون إنترنت وبدون أي مفتاح.
  /// 3) رسالة واضحة + أمثلة لو ما فهمناش.
  ///
  /// المحرك محلي بالكامل: مفيش أي خدمة ذكاء اصطناعي خارجية ولا مفتاح API.
  static String? _lastKey;
  static DateTime? _lastAt;
  static String _lastReply = '';

  static Future<String> handle(String text, {String? messageId}) async {
    // (أ) منع تكرار دائم: نفس معرّف الرسالة اتنفّذ قبل كده (حتى لو التطبيق اتقفل
    // واتفتح) → نرجّع الرد المسجّل من غير أي كتابة جديدة.
    await IdempotencyService.init();
    final idemKey = messageId == null ? null : 'msg:$messageId';
    if (idemKey != null) {
      final prev = IdempotencyService.lookup(idemKey);
      if (prev != null) return prev;
    }
    // (ب) حماية من تكرار الإرسال (ضغطتين/إعادة محاولة): نفس النص خلال ٨ ثواني
    // بعد تنفيذ ناجح ما يتنفّذش تاني — عشان ما تتسجلش سلفة/دفعة مرتين.
    final key = LocalCommandParser.normalize(text.trim());
    final last = _lastAt;
    if (key.isNotEmpty &&
        key == _lastKey &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 8) &&
        _lastReply.contains('✅')) {
      return '⚠️ نفس الأمر اتنفّذ من ثواني ومش هكرره عشان ما يتسجلش مرتين. '
          'لو عايزه فعلًا تاني ابعته بعد شوية.';
    }
    final reply = await _handleInner(text);
    if (idemKey != null && reply.contains('✅')) {
      await IdempotencyService.remember(idemKey, reply);
    }
    _lastKey = key;
    _lastAt = DateTime.now();
    _lastReply = reply;
    return reply;
  }

  static Future<String> _handleInner(String text) async {
    final t = text.trim();
    if (t.isEmpty) return 'اكتب أو قولّي عايز تعمل إيه.';

    await ConversationContextService.init();

    // (1) استكمال عملية معلّقة (رد على استيضاح سابق).
    final resumed = await _tryResumePending(t);
    if (resumed != null) return resumed;

    // (2) المحلل المحلي أولاً.
    final local = LocalCommandParser.parse(t);
    if (local.isKnown) {
      final fields = _applyPronounContext(t, local.toFields());
      return _runLocal(fields, t, local.clarification);
    }

    // (3) لم نفهم.
    return 'لم أفهم المطلوب بدقة. تقدر تقول مثلًا: "سجل حضور أحمد"، أو '
        '"خصم 500 من أحمد"، أو "مين محضرش النهارده؟".';
  }

  /// ينفّذ نتيجة المحلل المحلي — ويحفظ العملية المعلّقة لو ناقصها بيانات.
  static Future<String> _runLocal(
    Map<String, dynamic> fields,
    String text,
    String? clarification,
  ) async {
    fields = Map<String, dynamic>.from(fields);
    final intent = fields['intent'] as String;

    // عدة أشخاص (بمعرّفات محفوظة أو بأسماء) — يُنفَّذ على كل سجل ثم تُجمَع النتائج.
    final ids = <String>[
      for (final e in (fields['person_ids'] as List? ?? [])) e.toString(),
    ];
    final people = <String>[
      for (final e in (fields['people'] as List? ?? []))
        if (e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
    if (_multiPersonIntents.contains(intent) &&
        (ids.length > 1 || people.length > 1)) {
      final results = <String>[];
      if (ids.length > 1) {
        for (final id in ids) {
          final one = Map<String, dynamic>.from(fields)..['person_id'] = id;
          results.add(await _safeDispatch(intent, one, text));
        }
      } else {
        for (final name in people) {
          final one = Map<String, dynamic>.from(fields)
            ..['person'] = name
            ..['employee_name'] = name
            ..['people'] = <String>[];
          results.add(await _safeDispatch(intent, one, text));
        }
      }
      await ConversationContextService.clearPending();
      await ConversationContextService.clearLastPeople();
      return '📋 نُفِّذ الأمر على ${results.length} أسماء:\n'
          '${results.map((r) => '• $r').join('\n')}';
    }

    // اسم ملتبس؟ نحسمه قبل التنفيذ بدل تنفيذ العملية على سجل عشوائي.
    final amb = await _ambiguityFor(intent, fields);
    if (amb != null) return amb;

    final missing = _missingFor(intent, fields);
    if (missing.isNotEmpty) {
      final stored = Map<String, dynamic>.from(fields)..remove('intent');
      // موعد فات/ناقص: ما نحتفظش بقيمة قديمة تتسرّب للتنفيذ.
      if (missing.contains('due_date')) stored.remove('due_date');
      if (missing.contains('time')) stored.remove('time');
      await ConversationContextService.setPending(PendingOperation(
        intent: intent,
        fields: stored,
        missing: missing,
        createdAt: DateTime.now(),
      ));
      return clarification ?? _askFor(missing, fields);
    }
    await ConversationContextService.clearPending();
    return _safeDispatch(intent, fields, text);
  }

  // ---------------- إكمال السياق (§4) ----------------

  /// هل النص إشارة جماعية لآخر أشخاص أعادهم استعلام؟
  static final RegExp _themRe = RegExp(
    r'(سجلهم|سجللهم|سجلوا|لهم|كلهم|دول|هما|الغياب|الغايبين|المذكورين|هؤلاء)',
  );

  static Map<String, dynamic> _applyPronounContext(
      String text, Map<String, dynamic> fields) {
    final n = LocalCommandParser.normalize(text);
    final hasPerson = (fields['person'] as String?)?.isNotEmpty == true;
    if (hasPerson || !_themRe.hasMatch(n)) return fields;
    final people = ConversationContextService.lastPeople();
    if (people.isEmpty) return fields;
    return Map<String, dynamic>.from(fields)
      ..['person'] = people.first.name
      ..['people'] = people.map((e) => e.name).toList()
      ..['person_ids'] = people.map((e) => e.id).toList();
  }

  static bool _hasVal(Object? v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is num) return v > 0;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  /// الحقول المطلوبة الناقصة لكل نية — بدون تخمين.
  static List<String> _missingFor(String intent, Map<String, dynamic> f) {
    final hasName = (f['person'] as String?)?.isNotEmpty == true ||
        (f['person_ids'] as List?)?.isNotEmpty == true;
    final hasAmount = ((f['amount'] as num?)?.toDouble() ?? 0) > 0;
    switch (intent) {
      case 'supplier_delivery':
        return [
          if (!hasName) 'person',
          ..._whenMissing(f),
        ];
      case 'create_commitment':
        return _whenMissing(f);
      case 'mark_attendance':
      case 'add_supplier':
      case 'mark_delivery_received':
        return hasName || (f['person_ids'] as List?)?.isNotEmpty == true
            ? const []
            : ['person'];
      case 'add_advance':
      case 'add_deduction':
      case 'add_bonus':
      case 'add_supplier_payment':
        return [
          if (!hasName) 'person',
          if (!hasAmount) 'amount',
        ];
      case 'record_purchase':
        return [
          if (!hasName) 'person',
          if (!hasAmount) 'amount',
        ];
      case 'add_employee':
        return [
          if ((f['employee_name'] as String?)?.isEmpty != false)
            'employee_name',
          if (((f['salary'] as num?)?.toDouble() ?? 0) <= 0) 'salary',
        ];
      default:
        return const [];
    }
  }

  /// يوم + ساعة صريحين ومستقبليين — مفيش افتراض «بكرة» ولا ساعة من عندنا.
  static List<String> _whenMissing(Map<String, dynamic> f) {
    final hasDay = _hasVal(f['due_date']);
    final hasTime = _hasVal(f['time']);
    if (hasDay && hasTime) {
      final due = _dueFrom(f);
      if (due == null ||
          due.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
        return const ['due_date', 'time'];
      }
      return const [];
    }
    return [
      if (!hasDay) 'due_date',
      if (!hasTime) 'time',
    ];
  }

  /// يبني الموعد من due_date (YYYY-MM-DD) + time (HH:mm). null لو ناقص/غلط.
  static DateTime? _dueFrom(Map<String, dynamic> d) {
    final ds = (d['due_date'] ?? '').toString();
    final ts = (d['time'] ?? '').toString();
    final day = DateTime.tryParse(ds.length >= 10 ? ds.substring(0, 10) : ds);
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(ts);
    if (day == null || m == null) return null;
    final hh = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    if (hh > 23 || mm > 59) return null;
    return DateTime(day.year, day.month, day.day, hh, mm);
  }

  static String _askFor(List<String> missing, [Map<String, dynamic>? f]) {
    final parts = <String>[];
    if (missing.contains('due_date')) parts.add('اليوم أو التاريخ');
    if (missing.contains('time')) {
      parts.add(f?['time_hour_raw'] != null
          ? 'الساعة ${f!['time_hour_raw']} صباحًا ولا مساءً'
          : 'الساعة كام');
    }
    if (missing.contains('person')) parts.add('اسم الموظف/المورد');
    if (missing.contains('employee_name')) parts.add('اسم الموظف');
    if (missing.contains('amount')) parts.add('المبلغ');
    if (missing.contains('salary')) parts.add('المرتب الشهري');
    return '❓ محتاج ${parts.join(' و')}.';
  }

  /// استكمال عملية معلّقة من رد المستخدم (مبلغ/اسم ناقص، تأكيد، أو إلغاء).
  /// يرجع null لو الرد مش متعلق بالعملية المعلّقة (أمر جديد مستقل).
  /// يكمّل العملية المعلّقة بعد اختيار شخص (بالكلام أو بزر) — نفس المسار، وكل
  /// الحقول المجمّعة بتتراجع في `_safeDispatch` قبل أي كتابة.
  static Future<String> _resumeWithPick(
      PendingOperation p, ContextPerson pick, String text) async {
    final merged = Map<String, dynamic>.from(p.fields)
      ..['person'] = pick.name
      ..['person_id'] = pick.id;
    final still = p.missing.where((k) => !_hasVal(merged[k])).toList();
    if (still.isEmpty) {
      await ConversationContextService.clearPending();
      return _safeDispatch(p.intent, {'intent': p.intent, ...merged}, text);
    }
    await ConversationContextService.setPending(
        p.copyWith(fields: merged, missing: still, options: const []));
    return _askFor(still, merged);
  }

  /// تأكيد استلام توريد متوقع من كارت «اليوم» (بعد تأكيد المستخدم وقيمة فعلية
  /// اختيارية). نفس مسار `mark_delivery_received`، ومحمي من التكرار بمفتاح ثابت
  /// لكل التزام: ضغطتين/إعادة محاولة ما بيسجّلوش توريد مرتين.
  static Future<String> receiveExpectedDelivery(String commitmentId,
      {double? total}) async {
    await IdempotencyService.init();
    final key = 'receive:$commitmentId';
    final prev = IdempotencyService.lookup(key);
    if (prev != null) return prev;
    final matches =
        StorageService.commitments().where((x) => x.id == commitmentId);
    if (matches.isEmpty) return '⚠️ الالتزام ده مش موجود.';
    final c = matches.first;
    if (c.status != 'pending') return '⚠️ الالتزام ده اتقفل بالفعل.';
    if (c.type != 'supplier') return '⚠️ ده مش توريد متوقع.';
    if (total != null && total <= 0) return '❓ القيمة لازم تكون أكبر من صفر.';
    final d = <String, dynamic>{
      'intent': 'mark_delivery_received',
      'person': c.person,
      'delivery_due': c.dueDate.toIso8601String(),
      'text_original': 'تأكيد استلام من شاشة اليوم',
      if (total != null) 'amount': total,
      if (total != null) 'purchase_total': total,
    };
    final reply = await _safeDispatch(
        'mark_delivery_received', d, 'تأكيد استلام من ${c.person}');
    if (reply.contains('✅')) await IdempotencyService.remember(key, reply);
    return reply;
  }

  static bool _choiceBusy = false;

  /// ضغطة زر اختيار. بتتأكد إنها تخص **نفس** العملية المعلّقة الحالية، وبتمنع
  /// الضغط المزدوج، وبعدين بتمشي في نفس مسار الرد النصي (تحقق ثم تنفيذ).
  static Future<String> handleChoice(String pendingId, ChatChoice c) async {
    if (_choiceBusy) return '⏳ لحظة، الاختيار اللي قبله لسه بيتنفّذ.';
    _choiceBusy = true;
    try {
      final p = ConversationContextService.pending();
      if (p == null || p.id != pendingId) {
        return '⚠️ الاختيار ده بتاع عملية قديمة أو اتنفّذت/اتلغت بالفعل. '
            'ابعت الأمر من جديد لو لسه محتاجه.';
      }
      switch (c.kind) {
        case ChoiceKind.cancel:
          await ConversationContextService.clearPending();
          return 'تمام، ألغيت العملية. 👍';
        case ChoiceKind.person:
          final hit = p.options.where((o) => o.id == c.value).toList();
          if (hit.isEmpty) return '⚠️ الاختيار ده مش من الخيارات الحالية.';
          return await _resumeWithPick(p, hit.first, c.label);
        case ChoiceKind.text:
          return await _handleInner(c.value);
      }
    } finally {
      _choiceBusy = false;
    }
  }

  static Future<String?> _tryResumePending(String text) async {
    final p = ConversationContextService.pending();
    if (p == null) return null;
    final n = LocalCommandParser.normalize(text);

    // إلغاء صريح.
    if (RegExp(r'^(لا|الغي|الغاء|بلاش|سيبها|مش عايز)').hasMatch(n)) {
      await ConversationContextService.clearPending();
      return 'تمام، ألغيت العملية. 👍';
    }
    // اختيار من قائمة ملتبسة: «التاني» / «الثاني» / «الأول» / «رقم ٢».
    if (p.options.isNotEmpty) {
      final pick = _pickOption(n, p.options);
      if (pick != null) return _resumeWithPick(p, pick, text);
    }

    final parsed = LocalCommandParser.parse(text);

    // أمر جديد واضح ومختلف تمامًا → نلغي المعلّق ونسيب المسار العادي يكمّل.
    if (parsed.isKnown && parsed.confident && parsed.intent != p.intent) {
      await ConversationContextService.clearPending();
      return null;
    }

    final merged = Map<String, dynamic>.from(p.fields);
    // رد قصير («٣٠٠» / «بكرة الساعة ٥ العصر» / «مساء») مش أمر كامل، فبنستخرج
    // منه الخانات الناقصة مباشرة.
    final slots = LocalCommandParser.extractSlots(text,
        expect: p.missing.toSet(),
        hourHint: (p.fields['time_hour_raw'] as num?)?.toInt());
    for (final e in slots.entries) {
      if (e.key == 'time_hour_raw' && _hasVal(merged['time'])) continue;
      if (!_hasVal(merged[e.key]) || p.missing.contains(e.key)) {
        merged[e.key] = e.value;
      }
    }
    if (_hasVal(merged['time'])) merged.remove('time_hour_raw');
    for (final e in parsed.fields.entries) {
      if (e.key == 'text_original' || e.key == 'intent') continue;
      if (!_hasVal(merged[e.key]) || p.missing.contains(e.key))
        merged[e.key] = e.value;
    }

    final still = p.missing.where((k) => !_hasVal(merged[k])).toList();
    if (still.isEmpty) {
      await ConversationContextService.clearPending();
      return _safeDispatch(p.intent, {'intent': p.intent, ...merged}, text);
    }
    await ConversationContextService.setPending(
        p.copyWith(fields: merged, missing: still));
    return _askFor(still, merged);
  }

  static ContextPerson? _pickOption(String n, List<ContextPerson> options) {
    const ordinals = {
      'الاول': 1,
      'اول': 1,
      'التاني': 2,
      'الثاني': 2,
      'تاني': 2,
      'التالت': 3,
      'الثالث': 3,
      'تالت': 3,
      'الرابع': 4,
      'رابع': 4,
    };
    for (final e in ordinals.entries) {
      if (RegExp('(^|\\s)${e.key}(\\s|\$)').hasMatch(n)) {
        final i = e.value - 1;
        if (i >= 0 && i < options.length) return options[i];
      }
    }
    // اختيار بالاسم/الوظيفة
    for (final o in options) {
      final first = LocalCommandParser.normalize(o.name).split(' ').first;
      if (first.isNotEmpty && n.contains(first)) return o;
    }
    return null;
  }

  /// النوايا اللي بتخص شخصًا واحدًا — لازم نحسم التباس الاسم قبل التنفيذ (§4).
  static const Set<String> _personIntents = {
    'mark_attendance',
    'add_advance',
    'add_deduction',
    'add_bonus',
    'record_purchase',
    'add_supplier_payment',
    'mark_delivery_received',
    'supplier_delivery',
  };

  static const Set<String> _supplierIntents = {
    'record_purchase',
    'add_supplier_payment',
    'mark_delivery_received',
    'supplier_delivery',
    'add_supplier',
  };

  /// لو الاسم ملتبس (أكتر من سجل)، نحفظ الخيارات بمعرّفاتها ونطلب التحديد
  /// بدل تنفيذ العملية على سجل عشوائي.
  static Future<String?> _ambiguityFor(
      String intent, Map<String, dynamic> f) async {
    if (!_personIntents.contains(intent)) return null;
    if ((f['person_id'] as String?)?.isNotEmpty == true) return null;
    final name = (f['person'] as String? ?? '').trim();
    if (name.isEmpty) return null;
    final isSupplier = _supplierIntents.contains(intent);
    final role = (f['person_role'] as String? ?? '').trim();

    String? ambMsg;
    List<ContextPerson> options = const [];

    if (isSupplier) {
      final matches = StorageService.suppliersMatching(name);
      if (matches.length > 1) {
        options =
            matches.map((s) => ContextPerson(id: s.id, name: s.name)).toList();
        ambMsg = '🤔 عندي أكتر من مورد بالاسم ده: '
            '${matches.map((s) => s.itemType.isEmpty ? s.name : '${s.name} (${s.itemType})').join(' / ')}. '
            'قولّي مين بالظبط؟';
      }
    } else {
      var matches = StorageService.employeesMatching(name);
      if (role.isNotEmpty) {
        final narrowed = matches
            .where(
                (e) => normalizeArabic(e.role).contains(normalizeArabic(role)))
            .toList();
        if (narrowed.isNotEmpty) matches = narrowed;
      }
      if (matches.length > 1) {
        options =
            matches.map((e) => ContextPerson(id: e.id, name: e.name)).toList();
        ambMsg = '🤔 عندي أكتر من موظف بالاسم ده: '
            '${matches.map((e) => '${e.name} (${e.role})').join(' / ')}. '
            'قولّي مين بالظبط؟';
      }
    }

    if (ambMsg == null) return null;
    await ConversationContextService.setPending(PendingOperation(
      intent: intent,
      fields: Map<String, dynamic>.from(f)..remove('intent'),
      missing: const ['person'],
      options: options,
      createdAt: DateTime.now(),
    ));
    return ambMsg;
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

  /// تنفيذ آمن — أي استثناء (زي فشل الحفظ) يتحوّل لرسالة عربية واضحة،
  /// ومفيش نص استثناء خام ولا تفاصيل داخلية بتوصل للمستخدم (§8).
  static Future<String> _safeDispatch(
      String intent, Map<String, dynamic> d, String text) async {
    try {
      return await _dispatch(intent, d, text);
    } catch (e, st) {
      AppErrorService.log('dispatch.$intent', e, st);
      return AppErrorService.userMessage(e);
    }
  }

  static Future<String> _dispatch(
      String intent, Map<String, dynamic> d, String text) async {
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

  /// يحل الموظف بالمعرّف الثابت أولاً (من السياق §4) ثم بالاسم.
  /// المعرّف يتقدّم دائمًا عشان ما ننفّذش عملية على شخص غلط عند تشابه الأسماء.
  static _Resolved<Employee> _resolveEmployee(String name, [String? id]) {
    if (id != null && id.isNotEmpty) {
      final byId = StorageService.employees().where((e) => e.id == id).toList();
      if (byId.length == 1) return _Resolved(byId.first, null);
    }
    if (name.trim().isEmpty)
      return const _Resolved(null, '❓ محتاج اسم الموظف.');
    final matches = StorageService.employeesMatching(name);
    if (matches.isEmpty) return _Resolved(null, '❓ لم أجد موظف باسم $name.');
    if (matches.length > 1) {
      final opts = matches.map((e) => '${e.name} (${e.role})').join(' / ');
      return _Resolved(
          null, '🤔 عندي أكتر من موظف بنفس الاسم: $opts. وضّح مين بالظبط؟');
    }
    return _Resolved(matches.first, null);
  }

  static _Resolved<Supplier> _resolveSupplier(String name, [String? id]) {
    if (id != null && id.isNotEmpty) {
      final byId = StorageService.suppliers().where((s) => s.id == id).toList();
      if (byId.length == 1) return _Resolved(byId.first, null);
    }
    if (name.trim().isEmpty)
      return const _Resolved(null, '❓ محتاج اسم المورد.');
    final matches = StorageService.suppliersMatching(name);
    if (matches.isEmpty) {
      final arch =
          StorageService.suppliersMatching(name, includeArchived: true);
      if (arch.isNotEmpty) {
        return _Resolved(null,
            '🗄️ المورد ${arch.first.name} مؤرشف. ألغِ أرشفته الأول لو عايز تسجّل عليه عملية جديدة.');
      }
      return _Resolved(null, '❓ لم أجد مورد باسم $name.');
    }
    if (matches.length > 1) {
      final opts = matches.map((s) => '${s.name} (${s.itemType})').join(' / ');
      return _Resolved(
          null, '🤔 عندي أكتر من مورد بنفس الاسم: $opts. وضّح مين بالظبط؟');
    }
    return _Resolved(matches.first, null);
  }

  // ---------------- Employees ----------------

  static Future<String> _addEmployee(Map<String, dynamic> d) async {
    final name = (d['employee_name'] ?? d['person'] ?? '').toString().trim();
    if (name.isEmpty) return '❓ محتاج اسم الموظف.';

    // لا نختلق راتبًا — لو مش مذكور نسأل المستخدم (§5).
    final salary = (d['salary'] as num?)?.toDouble() ?? 0;
    if (salary <= 0) return '❓ محتاج المرتب الشهري لـ $name عشان أسجّله صح.';

    // منع تكرار السجل بنفس الاسم (تطابق تام بعد التطبيع، مش تشابه جزئي).
    final norm = normalizeArabic(name);
    final exact = StorageService.employees()
        .where((e) => normalizeArabic(e.name) == norm)
        .toList();
    if (exact.isNotEmpty) {
      return 'ℹ️ فيه موظف مسجل بالفعل باسم ${exact.first.name} (${exact.first.role}). '
          'عدّل بياناته من ملفه بدل إنشاء سجل مكرر.';
    }

    final e = Employee(
      id: const Uuid().v4(),
      name: name,
      role: (d['employee_role'] as String?)?.trim().isNotEmpty == true
          ? d['employee_role']
          : 'عامل',
      startDate: DateTime.tryParse(d['start_date'] ?? '') ?? DateTime.now(),
      salaryMonthly: salary,
    );
    await StorageService.saveEmployee(e);
    return '✅ سجلت الموظف ${e.name}، المرتب ${e.salaryMonthly.toStringAsFixed(0)} جنيه.';
  }

  static Future<String> _addAdvance(Map<String, dynamic> d, String text) async {
    final name = d['person'] ?? d['employee_name'] ?? '';
    final resolved = _resolveEmployee(name, d['person_id'] as String?);
    if (!resolved.ok) return resolved.message!;
    final e = resolved.value!;
    e.advances.add(Advance(
        id: const Uuid().v4(),
        amount: (d['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.now(),
        note: text));
    await StorageService.saveEmployee(e);
    return '✅ سجلت السلفة لـ ${e.name}. باقي له ${e.remainingSalary.toStringAsFixed(0)} جنيه.';
  }

  static Future<String> _markAttendance(Map<String, dynamic> d) async {
    final resolved =
        _resolveEmployee(d['person'] ?? '', d['person_id'] as String?);
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
    final resolved = _resolveSupplier(name, d['person_id'] as String?);
    Supplier s;
    if (!resolved.ok) {
      final matches = StorageService.suppliersMatching(name);
      if (matches.length > 1) return resolved.message!;
      // اسم لمورد مؤرشف: ما ننشئش مورد مكرر بنفس الاسم.
      if (matches.isEmpty &&
          StorageService.suppliersMatching(name, includeArchived: true)
              .isNotEmpty) {
        return resolved.message!;
      }
      s = Supplier(
          id: const Uuid().v4(),
          name: name,
          itemType: d['supplier_item'] ?? '');
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
    var resolved = _resolveSupplier(name, d['person_id'] as String?);
    Supplier s;
    if (!resolved.ok) {
      // لو مفيش مورد بهذا الاسم خالص (مش التباس)، ننشئه تلقائيًا بدل الرفض —
      // لكن لو فيه التباس (أكتر من واحد) نوقف ونطلب توضيح.
      final matches = StorageService.suppliersMatching(name);
      if (matches.length > 1) return resolved.message!;
      // اسم لمورد مؤرشف: ما ننشئش مورد مكرر بنفس الاسم.
      if (matches.isEmpty &&
          StorageService.suppliersMatching(name, includeArchived: true)
              .isNotEmpty) {
        return resolved.message!;
      }
      s = Supplier(
          id: const Uuid().v4(),
          name: name.isEmpty ? 'مورد' : name,
          itemType: d['supplier_item'] ?? '');
    } else {
      s = resolved.value!;
    }
    final due = _dueFrom(d);
    if (due == null) return '❓ محتاج اليوم والساعة بالظبط عشان أسجّل التوريد المتوقع.';
    final del = Delivery(
      id: const Uuid().v4(),
      item: d['delivery_item'] ?? s.itemType,
      quantity: (d['delivery_quantity'] as num?)?.toDouble(),
      unit: d['delivery_unit'] ?? '',
      expectedDate: due,
    );
    s.deliveries.add(del);
    await StorageService.saveSupplier(s);
    // التنبيه في وقت التوريد المتوقع نفسه — لنسأل «اتسلّم؟»؛ مش بنسجّل مشتريات.
    final rem = due;
    final c = Commitment(
      id: const Uuid().v4(),
      textOriginal: d['text_original'] ?? '',
      person: s.name,
      type: 'supplier',
      amount: (d['amount'] as num?)?.toDouble(),
      dueDate: del.expectedDate,
      remindAt: rem,
    );
    await StorageService.saveCommitment(c);
    final outcome = await ReminderService.createAndSchedule(
      category: 'suppliers',
      title: 'توريد متوقع: ${s.name}',
      body: c.textOriginal.isEmpty
          ? 'توريد ${del.item} من ${s.name}'
          : c.textOriginal,
      dueAt: rem,
      relatedEntityId: c.id,
      relatedEntityType: 'commitment',
    );
    return '✅ متوقع توريد ${del.item.isEmpty ? '' : '${del.item} '}من ${s.name} يوم ${arabicDateTime(del.expectedDate)}.${outcome.warningSuffix}';
  }

  static Future<String> _markDeliveryReceived(Map<String, dynamic> d) async {
    final resolved =
        _resolveSupplier(d['person'] ?? '', d['person_id'] as String?);
    if (!resolved.ok) return resolved.message!;
    final s = resolved.value!;
    final pending = s.pendingDeliveries;
    if (pending.isEmpty) return '❓ مفيش توريدات متوقعة من ${s.name} حالياً.';
    var del = pending.first;
    // تأكيد من كارت «اليوم»: نختار التوريد صاحب نفس الموعد مش «أول واحد».
    final dueIso = DateTime.tryParse((d['delivery_due'] ?? '').toString());
    if (dueIso != null) {
      final m = pending.where((x) => x.expectedDate == dueIso);
      if (m.isNotEmpty) del = m.first;
    }
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
    // الالتزام المرتبط بهذا التوريد المتوقع يتقفل (ويتلغي تنبيهه) — مش بيفضل
    // «قائم» بعد ما البضاعة وصلت.
    for (final c in StorageService.commitments()) {
      if (c.status == 'pending' &&
          c.type == 'supplier' &&
          c.person == s.name &&
          c.dueDate == del.expectedDate) {
        c.status = 'done';
        await StorageService.saveCommitment(c);
        for (final r in StorageService.remindersForEntity(c.id)) {
          await ReminderService.cancel(r.id);
        }
      }
    }
    return '✅ تم تأكيد استلام ${del.item} من ${s.name}.'
        '${added != null ? ' أُضيف توريد بقيمة ${added.total.toStringAsFixed(0)} ج (المتبقي الآن ${s.balanceDue.toStringAsFixed(0)} ج).' : ' (من غير قيمة مسجّلة — سجّل القيمة لو عايز تتبّع الحساب.)'}';
  }

  static Future<String> _addSupplierPayment(Map<String, dynamic> d) async {
    final resolved =
        _resolveSupplier(d['person'] ?? '', d['person_id'] as String?);
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
      next = DateTime(now.year, now.month, now.day, 9)
          .add(Duration(days: addDays == 0 ? 7 : addDays));
    } else if (freq == 'daily') {
      next = DateTime(now.year, now.month, now.day, 9)
          .add(const Duration(days: 1));
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

  static Future<String> _createCommitment(
      Map<String, dynamic> d, String text) async {
    final due = _dueFrom(d);
    if (due == null) return '❓ محتاج اليوم والساعة بالظبط عشان أضبط التذكير.';
    final rem = due;
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
      title: c.person == 'عام' ? 'تذكير' : 'تذكير: ${c.person}',
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
            .where((c) =>
                c.status == 'pending' &&
                c.type == 'debt_to_collect' &&
                (c.amount ?? 0) > 0)
            .toList();
        if (debts.isEmpty) return 'مفيش حد عليه فلوس مسجل دلوقتي. 🎉';
        final lines = debts.map((c) =>
            '• ${c.person}: ${c.amount!.toStringAsFixed(0)} ج (${arabicDate(c.dueDate)})');
        return 'اللي عليهم فلوس:\n${lines.join('\n')}';

      case 'absent_today':
        final emps =
            StorageService.employees().where((e) => !e.archived).toList();
        final todayStr = today.toIso8601String().substring(0, 10);
        final absent =
            emps.where((e) => !e.attendance.contains(todayStr)).toList();
        if (absent.isEmpty) {
          await ConversationContextService.clearLastPeople();
          return 'كل العاملين سجلوا حضورهم النهاردة. ✅';
        }
        // §4: نحفظ الأشخاص بمعرّفات سجلاتهم الثابتة عشان «سجلهم حضور» يتنفّذ
        // على السجلات الصحيحة نفسها، مش بالاعتماد على الاسم الظاهر.
        await ConversationContextService.setLastPeople(
          absent.map((e) => ContextPerson(id: e.id, name: e.name)).toList(),
        );
        return 'لسه ما سجلوش حضور النهاردة:\n${absent.map((e) => '• ${e.name}').join('\n')}';

      case 'supplier_balance':
        final name = d['person'] ?? '';
        final resolved = _resolveSupplier(name, d['person_id'] as String?);
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
            rows.add(
                '• ${e.name}: ${a.amount.toStringAsFixed(0)} ج (${arabicDateTime(a.date)})');
          }
        }
        if (rows.isEmpty) return 'مفيش سلف اتسجلت في آخر أسبوع.';
        return 'السلف في آخر أسبوع:\n${rows.join('\n')}';

      default:
        return 'تقدر تسأل: "مين عليه فلوس؟" أو "مين ما حضرش النهارده؟" أو "كام للمورد [الاسم]؟" أو "مين أخد سلف الأسبوع ده؟"';
    }
  }
}
