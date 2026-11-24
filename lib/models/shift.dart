/// حركة نقدية يدوية داخل الشيفت: دخل آخر أو مصروف تشغيل.
class CashEntry {
  final String id;

  /// 'income' (دخل نقدي آخر) | 'expense' (مصروف تشغيل نقدي)
  final String kind;
  final double amount;
  final String note;
  final DateTime date;
  const CashEntry({
    required this.id,
    required this.kind,
    required this.amount,
    this.note = '',
    required this.date,
  });

  bool get isIncome => kind == 'income';

  Map<String, dynamic> toJson() =>
      {'id': id, 'kind': kind, 'amount': amount, 'note': note, 'date': date.toIso8601String()};

  factory CashEntry.fromJson(Map<String, dynamic> j) => CashEntry(
        id: j['id'] as String,
        kind: j['kind'] as String,
        amount: (j['amount'] as num).toDouble(),
        note: (j['note'] ?? '') as String,
        date: DateTime.parse(j['date'] as String),
      );
}

/// أرقام فترة (شيفت أو يوم). **حركة الكاش** منفصلة تمامًا عن **الأرصدة**:
///  - مبيعات آجلة للعملاء وتوريدات المورّدين بالأجل = أرصدة (مش كاش).
///  - تحصيل دين قديم = كاش داخل + بينقّص المستحقات.
///  - سداد مورد = كاش خارج + بينقّص المستحق للمورد.
/// ومفيش حاجة هنا اسمها «صافي ربح».
class ShiftTotals {
  // كاش داخل
  final double cashSales;
  final double otherIncome;
  final double collections;
  // كاش خارج
  final double supplierPayments;
  final double advances;
  final double salaries;
  final double expenses;
  // أرصدة (مش كاش)
  final double creditSales;
  final double supplierPurchases;

  const ShiftTotals({
    this.cashSales = 0,
    this.otherIncome = 0,
    this.collections = 0,
    this.supplierPayments = 0,
    this.advances = 0,
    this.salaries = 0,
    this.expenses = 0,
    this.creditSales = 0,
    this.supplierPurchases = 0,
  });

  double get cashIn => cashSales + otherIncome + collections;
  double get cashOut => supplierPayments + advances + salaries + expenses;

  /// حركة الكاش المسجّلة (داخل − خارج). **مش** ربح.
  double get netCashMovement => cashIn - cashOut;

  ShiftTotals operator +(ShiftTotals o) => ShiftTotals(
        cashSales: cashSales + o.cashSales,
        otherIncome: otherIncome + o.otherIncome,
        collections: collections + o.collections,
        supplierPayments: supplierPayments + o.supplierPayments,
        advances: advances + o.advances,
        salaries: salaries + o.salaries,
        expenses: expenses + o.expenses,
        creditSales: creditSales + o.creditSales,
        supplierPurchases: supplierPurchases + o.supplierPurchases,
      );

  bool sameAs(ShiftTotals o, {double eps = 0.005}) =>
      (cashSales - o.cashSales).abs() < eps &&
      (otherIncome - o.otherIncome).abs() < eps &&
      (collections - o.collections).abs() < eps &&
      (supplierPayments - o.supplierPayments).abs() < eps &&
      (advances - o.advances).abs() < eps &&
      (salaries - o.salaries).abs() < eps &&
      (expenses - o.expenses).abs() < eps &&
      (creditSales - o.creditSales).abs() < eps &&
      (supplierPurchases - o.supplierPurchases).abs() < eps;

  Map<String, dynamic> toJson() => {
        'cashSales': cashSales,
        'otherIncome': otherIncome,
        'collections': collections,
        'supplierPayments': supplierPayments,
        'advances': advances,
        'salaries': salaries,
        'expenses': expenses,
        'creditSales': creditSales,
        'supplierPurchases': supplierPurchases,
      };

  factory ShiftTotals.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return ShiftTotals(
      cashSales: d('cashSales'),
      otherIncome: d('otherIncome'),
      collections: d('collections'),
      supplierPayments: d('supplierPayments'),
      advances: d('advances'),
      salaries: d('salaries'),
      expenses: d('expenses'),
      creditSales: d('creditSales'),
      supplierPurchases: d('supplierPurchases'),
    );
  }
}

/// شيفت: بيتفتح برصيد كاش افتتاحي وبيتقفل لوحده. أرقامه المحفوظة وقت الإقفال
/// ([snapshot]) ثابتة — أي تعديل أو إلغاء بعد كده مابيغيّرش الإقفال القديم
/// (والاختلاف بيتعرض كتنبيه بدل ما يتخبّى).
class Shift {
  final String id;

  /// اليوم التشغيلي (yyyy-MM-dd) — بيتحدد وقت فتح الشيفت، فالشيفت اللي بيعدّي
  /// نص الليل بيفضل تابع لنفس اليوم التشغيلي.
  final String businessDate;
  String name;
  final DateTime openedAt;
  DateTime? closedAt;
  double openingCash;

  /// مبيعات الكاش اللي المدير بيدخلها (مفيش POS في التطبيق).
  double cashSales;
  final List<CashEntry> entries;

  /// الكاش اللي اتعدّ فعليًا في الدرج وقت الإقفال (اختياري).
  double? countedCash;
  String note;
  ShiftTotals? snapshot;

  Shift({
    required this.id,
    required this.businessDate,
    required this.name,
    required this.openedAt,
    this.closedAt,
    this.openingCash = 0,
    this.cashSales = 0,
    List<CashEntry>? entries,
    this.countedCash,
    this.note = '',
    this.snapshot,
  }) : entries = entries ?? [];

  bool get isClosed => closedAt != null;

  /// الكاش المتوقع في الدرج = الافتتاحي + حركة الكاش المسجّلة.
  double expectedCash(ShiftTotals t) => openingCash + t.netCashMovement;

  /// الفرق (المعدود − المتوقع). null لو ما اتعدّش.
  double? variance(ShiftTotals t) =>
      countedCash == null ? null : countedCash! - expectedCash(t);

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessDate': businessDate,
        'name': name,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'openingCash': openingCash,
        'cashSales': cashSales,
        'entries': entries.map((e) => e.toJson()).toList(),
        'countedCash': countedCash,
        'note': note,
        'snapshot': snapshot?.toJson(),
      };

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['id'] as String,
        businessDate: j['businessDate'] as String,
        name: (j['name'] ?? '') as String,
        openedAt: DateTime.parse(j['openedAt'] as String),
        closedAt: j['closedAt'] == null ? null : DateTime.parse(j['closedAt'] as String),
        openingCash: (j['openingCash'] as num?)?.toDouble() ?? 0,
        cashSales: (j['cashSales'] as num?)?.toDouble() ?? 0,
        entries: ((j['entries'] as List?) ?? const [])
            .map((e) => CashEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        countedCash: (j['countedCash'] as num?)?.toDouble(),
        note: (j['note'] ?? '') as String,
        snapshot: j['snapshot'] == null
            ? null
            : ShiftTotals.fromJson(Map<String, dynamic>.from(j['snapshot'] as Map)),
      );
}

/// إقفال اليوم التشغيلي (اختياري): تجميع شيفتات اليوم المقفولة. الإجماليات
/// مجموع **لقطات** الشيفتات (مش إعادة عدّ للحركات) فمفيش عدّ مزدوج، والشيفتات
/// الأصلية بتفضل زي ما هي.
class DailyClosing {
  final String id;
  final String businessDate;
  DateTime closedAt;
  DateTime? updatedAt;
  List<String> shiftIds;
  ShiftTotals totals;

  /// حركات اليوم اللي وقعت **خارج** أي شيفت (بتتعرض لوحدها، ومش داخلة في الإجمالي).
  ShiftTotals outsideShifts;
  String note;

  DailyClosing({
    required this.id,
    required this.businessDate,
    required this.closedAt,
    this.updatedAt,
    required this.shiftIds,
    required this.totals,
    this.outsideShifts = const ShiftTotals(),
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessDate': businessDate,
        'closedAt': closedAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'shiftIds': shiftIds,
        'totals': totals.toJson(),
        'outsideShifts': outsideShifts.toJson(),
        'note': note,
      };

  factory DailyClosing.fromJson(Map<String, dynamic> j) => DailyClosing(
        id: j['id'] as String,
        businessDate: j['businessDate'] as String,
        closedAt: DateTime.parse(j['closedAt'] as String),
        updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
        shiftIds: ((j['shiftIds'] as List?) ?? const []).map((e) => e as String).toList(),
        totals: ShiftTotals.fromJson(Map<String, dynamic>.from(j['totals'] as Map)),
        outsideShifts: j['outsideShifts'] == null
            ? const ShiftTotals()
            : ShiftTotals.fromJson(Map<String, dynamic>.from(j['outsideShifts'] as Map)),
        note: (j['note'] ?? '') as String,
      );
}
