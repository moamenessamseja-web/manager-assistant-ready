class Commitment {
  String id, textOriginal, person, type, status, followUpRule;

  /// ربط اختياري بعميل (وعد بالدفع). فارغ لباقي الالتزامات. الوعد ≠ دفعة:
  /// الالتزام نفسه عمره ما بيغيّر رصيد العميل.
  String customerId;
  double? amount;
  DateTime dueDate, remindAt;
  Commitment({
    required this.id,
    required this.textOriginal,
    required this.person,
    required this.type,
    this.amount,
    required this.dueDate,
    required this.remindAt,
    this.status = 'pending',
    this.followUpRule = '',
    this.customerId = '',
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'textOriginal': textOriginal,
        'person': person,
        'type': type,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'remindAt': remindAt.toIso8601String(),
        'status': status,
        'followUpRule': followUpRule,
        if (customerId.isNotEmpty) 'customerId': customerId,
      };
  factory Commitment.fromJson(Map<String, dynamic> j) => Commitment(
        id: j['id'],
        textOriginal: j['textOriginal'],
        person: j['person'],
        type: j['type'],
        amount: (j['amount'] as num?)?.toDouble(),
        dueDate: DateTime.parse(j['dueDate']),
        remindAt: DateTime.parse(j['remindAt']),
        status: j['status'] ?? 'pending',
        followUpRule: j['followUpRule'] ?? '',
        customerId: j['customerId'] ?? '',
      );
}
