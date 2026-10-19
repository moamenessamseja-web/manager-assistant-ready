/// نموذج منظم لنتيجة تحليل الأمر — يفصل «فهم الأمر» عن «تنفيذه».
///
/// [fields] بيستخدم **مفاتيح موحّدة** (person/people/amount/...)
/// عشان مسار التنفيذ نفسه (AssistantController._dispatch) يشتغل من غير أي
/// تغيير، سواء الفهم جاء من المحلل المحلي أو من Gemini الاختياري.
enum ParseSource {
  /// المحلل المحلي — يعمل بدون إنترنت وبدون أي مفتاح.
  local,


  /// لم نتمكن من الفهم.
  none,
}

class CommandResult {
  /// النية المكتشفة ('other' لو غير واضحة).
  final String intent;

  /// الحقول المنظمة (person / amount / ... ) بنفس مفاتيح مخطط Gemini.
  final Map<String, dynamic> fields;

  /// مصدر الفهم.
  final ParseSource source;

  /// هل النية واضحة بدرجة كافية للتنفيذ المباشر بدون سؤال؟
  /// لو false لكن [isKnown] true، معناها نية معروفة بس بياناتها ناقصة،
  /// ومسار التنفيذ هيسأل المستخدم عن الناقص بدل ما يخمّن.
  final bool confident;

  /// سؤال توضيحي جاهز (اختياري) لما يكون ناقص بيانات محددة.
  final String? clarification;

  const CommandResult({
    required this.intent,
    this.fields = const <String, dynamic>{},
    this.source = ParseSource.local,
    this.confident = false,
    this.clarification,
  });

  /// نتيجة «لم أفهم».
  static const CommandResult unknown = CommandResult(
    intent: 'other',
    source: ParseSource.none,
    confident: false,
  );

  /// هل النية معروفة (مش other)؟
  bool get isKnown => intent.isNotEmpty && intent != 'other';

  /// النية + الحقول في خريطة واحدة جاهزة لـ _dispatch.
  Map<String, dynamic> toFields() => <String, dynamic>{
        'intent': intent,
        ...fields,
      };

  @override
  String toString() =>
      'CommandResult(intent: $intent, source: $source, confident: $confident, fields: $fields)';
}
