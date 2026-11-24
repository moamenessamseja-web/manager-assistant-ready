/// سجل تصحيح/إلغاء: الحركة الأصلية بتتحفظ كاملة هنا (مش بتتمسح من التاريخ)،
/// ومعاها السبب والوقت. الرصيد بيتحسب من الحركات **الفعالة** بس.
class AuditEntry {
  final String id;
  final DateTime at;

  /// 'void' إلغاء حركة · 'delete_account' حذف حساب كامل (لقطة كاملة)
  final String action;

  /// 'employee' | 'supplier' | 'customer'
  final String ownerType;
  final String ownerId;
  final String ownerName;

  /// 'advance' | 'payment' | 'deduction' | 'delivery' | 'purchase' | 'sale' | 'attendance' | 'account' ...
  final String recordType;
  final String recordId;

  /// وصف مقروء للحركة (مبلغ/تاريخ/ملاحظة).
  final String summary;
  final double? amount;
  final String reason;

  /// الحركة الأصلية كما كانت (JSON).
  final Map<String, dynamic> original;

  const AuditEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.ownerType,
    required this.ownerId,
    required this.ownerName,
    required this.recordType,
    required this.recordId,
    required this.summary,
    this.amount,
    required this.reason,
    required this.original,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'action': action,
        'ownerType': ownerType,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'recordType': recordType,
        'recordId': recordId,
        'summary': summary,
        'amount': amount,
        'reason': reason,
        'original': original,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        action: j['action'] as String,
        ownerType: j['ownerType'] as String,
        ownerId: j['ownerId'] as String,
        ownerName: (j['ownerName'] ?? '') as String,
        recordType: j['recordType'] as String,
        recordId: j['recordId'] as String,
        summary: (j['summary'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble(),
        reason: (j['reason'] ?? '') as String,
        original: Map<String, dynamic>.from(j['original'] as Map),
      );
}
