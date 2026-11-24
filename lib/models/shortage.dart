/// طلب نقص/احتياج شراء — قائمة «لازم أشتري» وبس. **مش مخزون**: مفيش رصيد
/// مخزن ولا خصم تلقائي ولا تقييم، ومش بيلمس حسابات الموردين أو الفلوس.
class ShortageEvent {
  final String status;
  final DateTime at;
  final String note;
  const ShortageEvent({required this.status, required this.at, this.note = ''});

  Map<String, dynamic> toJson() =>
      {'status': status, 'at': at.toIso8601String(), 'note': note};

  factory ShortageEvent.fromJson(Map<String, dynamic> j) => ShortageEvent(
        status: j['status'] as String,
        at: DateTime.parse(j['at'] as String),
        note: (j['note'] ?? '') as String,
      );
}

class ShortageItem {
  static const pending = 'pending';
  static const ordered = 'ordered';
  static const purchased = 'purchased';
  static const cancelled = 'cancelled';
  static const statuses = [pending, ordered, purchased, cancelled];

  final String id;
  String item;
  double? quantity;
  String unit;
  String note;

  /// ربط اختياري بمورد موجود (للتذكير بس — مفيش أي أثر مالي).
  String supplierId;
  String supplierName;
  String status;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;
  final List<ShortageEvent> history;

  ShortageItem({
    required this.id,
    required this.item,
    this.quantity,
    this.unit = '',
    this.note = '',
    this.supplierId = '',
    this.supplierName = '',
    this.status = pending,
    required this.createdAt,
    DateTime? updatedAt,
    this.completedAt,
    List<ShortageEvent>? history,
  })  : updatedAt = updatedAt ?? createdAt,
        history = history ?? [ShortageEvent(status: pending, at: createdAt)];

  /// لسه محتاج متابعة (مش اتشترى ولا اتلغى).
  bool get isOutstanding => status == pending || status == ordered;
  bool get isDone => status == purchased;

  String get quantityLabel {
    if (quantity == null) return '';
    final q = quantity!;
    final qs = q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
    return unit.isEmpty ? qs : '$qs $unit';
  }

  /// تغيير الحالة مع حفظ التاريخ. إعادة الفتح (من «تم الشراء» لـ«مطلوب») مسموحة.
  void setStatus(String s, DateTime now, {String note = ''}) {
    if (!statuses.contains(s) || s == status) return;
    status = s;
    updatedAt = now;
    completedAt = (s == purchased) ? now : null;
    history.add(ShortageEvent(status: s, at: now, note: note));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'quantity': quantity,
        'unit': unit,
        'note': note,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory ShortageItem.fromJson(Map<String, dynamic> j) => ShortageItem(
        id: j['id'] as String,
        item: j['item'] as String,
        quantity: (j['quantity'] as num?)?.toDouble(),
        unit: (j['unit'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        supplierId: (j['supplierId'] ?? '') as String,
        supplierName: (j['supplierName'] ?? '') as String,
        status: (j['status'] ?? pending) as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
        completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt'] as String),
        history: j['history'] == null
            ? null
            : (j['history'] as List)
                .map((e) => ShortageEvent.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
      );
}
