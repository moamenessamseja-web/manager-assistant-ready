/// سجل توريد واحد (متوقع أو تم استلامه)
class Delivery {
  String id;
  String item; // الصنف: بن، لبن، مخبوزات...
  double? quantity;
  String unit; // كيلو، كرتونة، لتر...
  DateTime expectedDate;
  bool received;
  DateTime? receivedDate;
  String note;

  Delivery({
    required this.id,
    required this.item,
    this.quantity,
    this.unit = '',
    required this.expectedDate,
    this.received = false,
    this.receivedDate,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'quantity': quantity,
        'unit': unit,
        'expectedDate': expectedDate.toIso8601String(),
        'received': received,
        'receivedDate': receivedDate?.toIso8601String(),
        'note': note,
      };

  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
        id: j['id'],
        item: j['item'] ?? '',
        quantity: (j['quantity'] as num?)?.toDouble(),
        unit: j['unit'] ?? '',
        expectedDate: DateTime.parse(j['expectedDate']),
        received: j['received'] ?? false,
        receivedDate: j['receivedDate'] == null ? null : DateTime.parse(j['receivedDate']),
        note: j['note'] ?? '',
      );
}

/// دفعة سداد لمورد
class SupplierPayment {
  String id;
  double amount;
  DateTime date;
  String note;

  SupplierPayment({required this.id, required this.amount, required this.date, this.note = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory SupplierPayment.fromJson(Map<String, dynamic> j) => SupplierPayment(
        id: j['id'],
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date']),
        note: j['note'] ?? '',
      );
}

/// المورد نفسه (مورد البن، مورد اللبن، المخبوزات...)
class Supplier {
  String id;
  String name; // اسم المورد أو المحل
  String itemType; // الصنف الأساسي اللي بيوردّه
  String phone;
  double totalOwed; // إجمالي قيمة البضاعة المستلمة (دين عليك)
  List<SupplierPayment> payments; // ما تم سداده
  List<Delivery> deliveries; // توريدات متوقعة ومستلمة
  String note;

  Supplier({
    required this.id,
    required this.name,
    required this.itemType,
    this.phone = '',
    this.totalOwed = 0,
    List<SupplierPayment>? payments,
    List<Delivery>? deliveries,
    this.note = '',
  })  : payments = payments ?? [],
        deliveries = deliveries ?? [];

  double get totalPaid => payments.fold(0, (s, p) => s + p.amount);
  double get balanceDue => totalOwed - totalPaid;

  List<Delivery> get pendingDeliveries => deliveries.where((d) => !d.received).toList()
    ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'itemType': itemType,
        'phone': phone,
        'totalOwed': totalOwed,
        'payments': payments.map((p) => p.toJson()).toList(),
        'deliveries': deliveries.map((d) => d.toJson()).toList(),
        'note': note,
      };

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'],
        name: j['name'],
        itemType: j['itemType'] ?? '',
        phone: j['phone'] ?? '',
        totalOwed: (j['totalOwed'] as num?)?.toDouble() ?? 0,
        payments: (j['payments'] as List? ?? [])
            .map((e) => SupplierPayment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        deliveries: (j['deliveries'] as List? ?? [])
            .map((e) => Delivery.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        note: j['note'] ?? '',
      );
}
