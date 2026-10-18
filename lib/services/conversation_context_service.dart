import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// شخص محفوظ في السياق **بمعرّف سجله الثابت** (مش بالاسم الظاهر بس).
/// ده اللي بيمنع تنفيذ عملية على شخص غلط لما الاسم يتكرر أو يتشابه.
class ContextPerson {
  final String id;
  final String name;

  const ContextPerson({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory ContextPerson.fromJson(Map<String, dynamic> j) => ContextPerson(
      id: j['id'] as String? ?? '', name: j['name'] as String? ?? '');
}

/// عملية معلّقة تنتظر توضيحًا أو إكمال حقول (§4).
class PendingOperation {
  /// معرّف ثابت للعملية المعلّقة: أي زر اختيار بيحمله، فزر قديم ما يقدرش يعدّل
  /// عملية أحدث بالغلط.
  final String id;

  /// نية العملية الأصلية (mark_attendance / record_purchase / ...).
  final String intent;

  /// البيانات المجمّعة لحد الآن (بنفس مفاتيح مخطط الأوامر).
  final Map<String, dynamic> fields;

  /// أسماء الحقول المطلوبة اللي لسه ناقصة.
  final List<String> missing;

  /// خيارات الاختيار لو فيه التباس بالاسم (بمعرّفاتها الحقيقية).
  final List<ContextPerson> options;

  final DateTime createdAt;

  PendingOperation({
    String? id,
    required this.intent,
    required this.fields,
    required this.missing,
    this.options = const [],
    required this.createdAt,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  PendingOperation copyWith({
    Map<String, dynamic>? fields,
    List<String>? missing,
    List<ContextPerson>? options,
  }) =>
      PendingOperation(
        id: id,
        intent: intent,
        fields: fields ?? this.fields,
        missing: missing ?? this.missing,
        options: options ?? this.options,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'intent': intent,
        'fields': fields,
        'missing': missing,
        'options': options.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingOperation.fromJson(Map<String, dynamic> j) => PendingOperation(
        // عمليات قديمة اتخزنت قبل ما الـ id يتضاف: نشتق id ثابت من وقت الإنشاء.
        id: j['id'] as String? ?? (j['createdAt'] as String? ?? 'legacy'),
        intent: j['intent'] as String? ?? '',
        fields: Map<String, dynamic>.from(j['fields'] as Map? ?? {}),
        missing: List<String>.from(j['missing'] as List? ?? []),
        options: (j['options'] as List? ?? [])
            .map((e) =>
                ContextPerson.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// سياق المحادثة — يُحفظ محليًا (SharedPreferences) فيبقى بعد إغلاق الشاشة
/// أو إعادة تشغيل التطبيق، وله مهلة صلاحية حتى لا تُستكمل عملية قديمة بالغلط.
class ConversationContextService {
  ConversationContextService._();

  static SharedPreferences? _p;

  /// مهلة العملية المعلّقة: بعدها تُلغى ولا تُستكمل تلقائيًا.
  static const Duration ttl = Duration(minutes: 30);

  static Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
  }

  // ── آخر أشخاص أعادهم استعلام (بمعرّفاتهم) ──
  static const String _kLastPeople = 'ctx_last_people';
  static const String _kPending = 'ctx_pending';

  static List<ContextPerson> lastPeople() {
    final raw = _p?.getString(_kLastPeople);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              ContextPerson.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setLastPeople(List<ContextPerson> people) async {
    await init();
    await _p!.setString(
        _kLastPeople, jsonEncode(people.map((e) => e.toJson()).toList()));
  }

  static Future<void> clearLastPeople() async {
    await init();
    await _p!.remove(_kLastPeople);
  }

  // ── العملية المعلّقة ──
  static PendingOperation? pending() {
    final raw = _p?.getString(_kPending);
    if (raw == null || raw.isEmpty) return null;
    try {
      final op =
          PendingOperation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (DateTime.now().difference(op.createdAt) > ttl) {
        _p!.remove(_kPending); // انتهت الصلاحية → تُلغى
        return null;
      }
      return op;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setPending(PendingOperation op) async {
    await init();
    await _p!.setString(_kPending, jsonEncode(op.toJson()));
  }

  static Future<void> clearPending() async {
    await init();
    await _p!.remove(_kPending);
  }
}
