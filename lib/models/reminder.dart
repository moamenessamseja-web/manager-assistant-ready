/// تذكير مستقل (Reminder) منفصل عن أي Task/Commitment.
/// كل أمر يحتوي على موعد يجب أن ينتج Reminder مستقلة مرتبطة بالكيان الأصلي
/// (التزام، قاعدة متكررة، توريد مورد...) بدل افتراض أن مجرد إنشاء السجل يعني
/// أن التذكير وصل فعليًا للمستخدم.
class Reminder {
  String id;
  String title;
  String body;
  DateTime dueAt;
  String recurrence; // none | daily | weekly | monthly
  String? relatedEntityId;
  String? relatedEntityType; // commitment | rule | supplier_delivery
  // created -> scheduled -> delivered
  // أو: schedule_failed / permission_required / channel_disabled / cancelled
  String status;
  bool enabled;
  DateTime createdAt;
  DateTime updatedAt;

  Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.dueAt,
    this.recurrence = 'none',
    this.relatedEntityId,
    this.relatedEntityType,
    this.status = 'created',
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'dueAt': dueAt.toIso8601String(),
        'recurrence': recurrence,
        'relatedEntityId': relatedEntityId,
        'relatedEntityType': relatedEntityType,
        'status': status,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'],
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        dueAt: DateTime.parse(j['dueAt']),
        recurrence: j['recurrence'] ?? 'none',
        relatedEntityId: j['relatedEntityId'],
        relatedEntityType: j['relatedEntityType'],
        status: j['status'] ?? 'created',
        enabled: j['enabled'] ?? true,
        createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
        updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt']) : DateTime.now(),
      );
}
