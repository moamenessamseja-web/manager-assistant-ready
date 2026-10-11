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

  /// طريقة الدفع: كاش / تحويل / شيك (اختياري — البيانات القديمة فاضية).
  String method;

  SupplierPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
    this.method = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'method': method,
      };

  factory SupplierPayment.fromJson(Map<String, dynamic> j) => SupplierPayment(
        id: j['id'],
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date']),
        note: j['note'] ?? '',
        method: j['method'] ?? '',
      );
}

/// سجل توريد/مشتريات **بقيمة** — ده اللي بيقيس "قيمة البضاعة".
/// منفصل تمامًا عن الدفعات: تسجيل صنف بـ2,000 جنيه مش معناه إننا دفعنا 2,000.
class SupplierPurchase {
  String id;
  String item; // الصنف: بن، لبن، حديد…
  double? quantity;
  String unit; // كيلو، كرتونة، لتر…
  double unitPrice; // سعر الوحدة (0 لو غير معروف)
  double total; // الإجمالي — قيمة التوريد المعتمدة
  DateTime date; // تاريخ ووقت التسجيل
  String note;
  bool received;
  String? deliveryId; // لو مرتبط بتوريد متوقع

  SupplierPurchase({
    required this.id,
    required this.item,
    this.quantity,
    this.unit = '',
    this.unitPrice = 0,
    required this.total,
    required this.date,
    this.note = '',
    this.received = true,
    this.deliveryId,
  });

  /// وصف الكمية: "20 كيلو" (فاضي لو مفيش كمية)
  String get quantityLabel {
    if (quantity == null) return '';
    final q = quantity!;
    final qs = q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
    return unit.isEmpty ? qs : '$qs $unit';
  }

  /// وصف سعر الوحدة: "100 ج/كيلو"
  String get unitPriceLabel {
    if (unitPrice <= 0) return '';
    final up = unitPrice == unitPrice.truncateToDouble()
        ? unitPrice.toInt().toString()
        : unitPrice.toString();
    return unit.isEmpty ? '$up ج' : '$up ج/$unit';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'total': total,
        'date': date.toIso8601String(),
        'note': note,
        'received': received,
        'deliveryId': deliveryId,
      };

  factory SupplierPurchase.fromJson(Map<String, dynamic> j) {
    final qty = (j['quantity'] as num?)?.toDouble();
    final up = (j['unitPrice'] as num?)?.toDouble() ?? 0;
    final storedTotal = (j['total'] as num?)?.toDouble();
    return SupplierPurchase(
      id: j['id'],
      item: j['item'] ?? '',
      quantity: qty,
      unit: j['unit'] ?? '',
      unitPrice: up,
      // fallback: لو مفيش total محفوظ، احسبه من الكمية × سعر الوحدة.
      total: storedTotal ?? ((qty ?? 0) * up),
      date: j['date'] == null ? DateTime.now() : DateTime.parse(j['date']),
      note: j['note'] ?? '',
      received: j['received'] ?? true,
      deliveryId: j['deliveryId'],
    );
  }
}

/// نتيجة توزيع الدفعات على توريد واحد: قيمته / المدفوع منه / المتبقي عليه.
/// `purchase == null` تعني سطر "رصيد قديم مختصر" بلا تفاصيل (بيانات قبل الترقية).
class PurchaseBalance {
  final SupplierPurchase? purchase;
  final double total;
  final double paid;
  final DateTime date;
  const PurchaseBalance(this.purchase, this.total, this.paid, this.date);

  double get remaining => total - paid;
  bool get isLegacy => purchase == null;
  bool get isSettled => remaining <= 0.004;
}

/// حدث في سجل المورد (للـTimeline).
class SupplierEvent {
  final String kind; // purchase | payment | delivery
  final DateTime date;
  final double amount;
  final Object payload;
  const SupplierEvent(this.kind, this.date, this.amount, this.payload);
}

/// المورد نفسه (مورد البن، مورد اللبن، المخبوزات...)
class Supplier {
  String id;
  String name; // اسم المورد أو المحل
  String itemType; // الصنف الأساسي اللي بيوردّه
  String phone;
  /// رصيد قديم **مختصر** (سجل واحد بدون تفاصيل) — بيتحافظ عليه للتوافق مع
  /// البيانات السابقة فقط. أي توريد جديد بيتسجل في `purchases` بسعر ووحدة وتاريخ.
  double totalOwed;
  List<SupplierPayment> payments; // ما تم سداده (نقد فعلي)
  List<Delivery> deliveries; // توريدات متوقعة ومستلمة
  List<SupplierPurchase> purchases; // توريدات بقيمة (قيمة البضاعة)
  String note;
  bool archived;
  DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    required this.itemType,
    this.phone = '',
    this.totalOwed = 0,
    List<SupplierPayment>? payments,
    List<Delivery>? deliveries,
    List<SupplierPurchase>? purchases,
    this.note = '',
    this.archived = false,
    DateTime? createdAt,
  })  : payments = payments ?? [],
        deliveries = deliveries ?? [],
        purchases = purchases ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// مجموع قيمة سجلات التوريد المسجلة.
  double get purchasesTotal => purchases.fold(0, (s, p) => s + p.total);

  /// إجمالي قيمة البضاعة = الرصيد القديم المختصر + كل سجلات التوريد.
  double get goodsTotal => totalOwed + purchasesTotal;

  double get totalPaid => payments.fold(0, (s, p) => s + p.amount);

  /// المتبقي = قيمة البضاعة − المدفوع نقدًا.
  double get balanceDue => goodsTotal - totalPaid;

  /// هل عند المورد أي سجل تاريخي؟ (يمنع الحذف النهائي غير الآمن)
  bool get hasHistory =>
      purchases.isNotEmpty || payments.isNotEmpty || deliveries.isNotEmpty || totalOwed > 0;

  List<Delivery> get pendingDeliveries => deliveries.where((d) => !d.received).toList()
    ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));

  /// سجل الأحداث مرتّب من الأحدث للأقدم (توريدات + دفعات + توريدات متوقعة).
  List<SupplierEvent> get timeline {
    final events = <SupplierEvent>[
      for (final p in purchases) SupplierEvent('purchase', p.date, p.total, p),
      for (final p in payments) SupplierEvent('payment', p.date, p.amount, p),
      for (final d in deliveries)
        SupplierEvent('delivery', d.received ? (d.receivedDate ?? d.expectedDate) : d.expectedDate, 0, d),
    ];
    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  /// يوزّع المدفوعات على التوريدات بالأقدم-أولاً (FIFO) فينتج لكل توريد:
  /// قيمته، ما تم سداده منه، والمتبقي عليه — مع سطر افتتاحي للرصيد القديم.
  List<PurchaseBalance> allocatePayments() {
    final rows = <({DateTime date, SupplierPurchase? p, double total})>[
      if (totalOwed > 0) (date: createdAt, p: null, total: totalOwed),
      for (final p in purchases) (date: p.date, p: p, total: p.total),
    ]..sort((a, b) => a.date.compareTo(b.date));

    var pool = totalPaid;
    final out = <PurchaseBalance>[];
    for (final r in rows) {
      final paid = pool <= 0 ? 0.0 : (pool >= r.total ? r.total : pool);
      pool -= paid;
      out.add(PurchaseBalance(r.p, r.total, paid, r.date));
    }
    return out.reversed.toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'itemType': itemType,
        'phone': phone,
        'totalOwed': totalOwed,
        'payments': payments.map((p) => p.toJson()).toList(),
        'deliveries': deliveries.map((d) => d.toJson()).toList(),
        'purchases': purchases.map((p) => p.toJson()).toList(),
        'note': note,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
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
        purchases: (j['purchases'] as List? ?? [])
            .map((e) => SupplierPurchase.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        note: j['note'] ?? '',
        archived: j['archived'] ?? false,
        createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt']),
      );
}
