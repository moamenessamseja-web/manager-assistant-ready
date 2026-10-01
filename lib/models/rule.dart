/// قاعدة متابعة متكررة: "كل أول الشهر فكرني بالإيجار 8000"
/// أو "كل جمعة ابعتلي ملخص الأسبوع"
class FollowUpRule {
  String id;
  String text; // نص القاعدة الأصلي كما قاله المستخدم
  String frequency; // monthly | weekly | daily
  int anchor; // لـ monthly: يوم الشهر (1-31) — لـ weekly: يوم الأسبوع (1=الإثنين..7=الأحد)
  double? amount;
  DateTime nextDue; // المرة الجاية اللي القاعدة هتتفعل فيها
  bool active;

  FollowUpRule({
    required this.id,
    required this.text,
    required this.frequency,
    required this.anchor,
    this.amount,
    required this.nextDue,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'frequency': frequency,
        'anchor': anchor,
        'amount': amount,
        'nextDue': nextDue.toIso8601String(),
        'active': active,
      };

  factory FollowUpRule.fromJson(Map<String, dynamic> j) => FollowUpRule(
        id: j['id'],
        text: j['text'] ?? '',
        frequency: j['frequency'] ?? 'monthly',
        anchor: j['anchor'] ?? 1,
        amount: (j['amount'] as num?)?.toDouble(),
        nextDue: DateTime.parse(j['nextDue']),
        active: j['active'] ?? true,
      );
}
