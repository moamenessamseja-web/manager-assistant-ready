/// عميل بيشتري بالآجل — «المستحقات» = الفلوس اللي لنا برّه.
/// عكس الموظف وظيفيًا: مفيش حضور ولا سلف؛ فيه مبيعات آجلة ودفعات.
class CreditSale {
  final String id;
  final String item;
  final double? quantity;
  final String unit;
  final double total;
  final DateTime date;
  final String note;

  /// رصيد افتتاحي (عليه فلوس قبل بدء التسجيل) — مش حركة بيع فعلية في فترة.
  /// الشاشة القديمة كانت بتسجّله بالاسم «رصيد سابق»، فبنتعرّف عليه برضه.
  final bool opening;

  const CreditSale({
    required this.id,
    required this.item,
    this.quantity,
    this.unit = '',
    required this.total,
    required this.date,
    this.note = '',
    this.opening = false,
  });

  bool get isOpening => opening || item == 'رصيد سابق';

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'quantity': quantity,
        'unit': unit,
        'total': total,
        'date': date.toIso8601String(),
        'note': note,
        if (opening) 'opening': true,
      };

  factory CreditSale.fromJson(Map<String, dynamic> j) => CreditSale(
        id: j['id'] as String,
        item: (j['item'] ?? '') as String,
        quantity: (j['quantity'] as num?)?.toDouble(),
        unit: (j['unit'] ?? '') as String,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] ?? '') as String,
        opening: (j['opening'] ?? false) as bool,
      );
}

class CustomerPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String note;

  /// رصيد افتتاحي لصالح العميل (له فلوس عندنا) — مش تحصيل فعلي في فترة.
  final bool opening;

  const CustomerPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
    this.opening = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        if (opening) 'opening': true,
      };

  factory CustomerPayment.fromJson(Map<String, dynamic> j) => CustomerPayment(
        id: j['id'] as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] ?? '') as String,
        opening: (j['opening'] ?? false) as bool,
      );
}

class Customer {
  final String id;
  String name;
  String phone;
  String notes;
  bool archived;
  final DateTime createdAt;
  final List<CreditSale> sales;
  final List<CustomerPayment> payments;

  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.notes = '',
    this.archived = false,
    DateTime? createdAt,
    List<CreditSale>? sales,
    List<CustomerPayment>? payments,
  })  : createdAt = createdAt ?? DateTime.now(),
        sales = sales ?? [],
        payments = payments ?? [];

  double get totalSales => sales.fold(0.0, (s, x) => s + x.total);
  double get totalPaid => payments.fold(0.0, (s, x) => s + x.amount);

  /// الموجب = العميل مدين لنا. السالب = دفع زيادة (رصيد لصالحه).
  double get balanceDue => totalSales - totalPaid;
  bool get owes => balanceDue > 0.005;
  bool get hasHistory => sales.isNotEmpty || payments.isNotEmpty;

  /// مبيعات/زيادات آجلة داخل الفترة [from, to) — **من غير** الرصيد الافتتاحي.
  double salesBetween(DateTime from, DateTime to) => sales
      .where((x) => !x.isOpening && !x.date.isBefore(from) && x.date.isBefore(to))
      .fold(0.0, (s, x) => s + x.total);

  /// دفعات محصّلة داخل الفترة [from, to) — **من غير** الرصيد الافتتاحي له.
  double collectedBetween(DateTime from, DateTime to) => payments
      .where((x) => !x.opening && !x.date.isBefore(from) && x.date.isBefore(to))
      .fold(0.0, (s, x) => s + x.amount);

  DateTime? get lastActivity {
    DateTime? last;
    for (final d in [...sales.map((s) => s.date), ...payments.map((p) => p.date)]) {
      if (last == null || d.isAfter(last)) last = d;
    }
    return last;
  }

  /// يضيف بيعًا آجلًا. نفس الـ id مرتين = تجاهل (حماية من الحفظ المزدوج).
  bool addSale(CreditSale s) {
    if (s.total <= 0) return false;
    if (sales.any((x) => x.id == s.id)) return false;
    sales.add(s);
    return true;
  }

  /// يسجّل دفعة. نفس الـ id مرتين أو مبلغ ≤ 0 = تجاهل.
  bool addPayment(CustomerPayment p) {
    if (p.amount <= 0) return false;
    if (payments.any((x) => x.id == p.id)) return false;
    payments.add(p);
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'sales': sales.map((s) => s.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        archived: (j['archived'] ?? false) as bool,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String),
        sales: ((j['sales'] ?? []) as List)
            .map((e) => CreditSale.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        payments: ((j['payments'] ?? []) as List)
            .map((e) =>
                CustomerPayment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// فلتر القائمة: 'active' (الافتراضي، وأي قيمة غير معروفة) / 'archived' / 'all'.
List<Customer> filterCustomers(List<Customer> all, String filter) {
  switch (filter) {
    case 'all':
      return List<Customer>.of(all);
    case 'archived':
      return all.where((c) => c.archived).toList();
    case 'active':
    default:
      return all.where((c) => !c.archived).toList();
  }
}

/// إجمالي «اللي لنا برّه»: مجموع أرصدة العملاء المدينين (بما فيهم المؤرشفين
/// لو لسه عليهم فلوس — الفلوس ما بتختفيش بالأرشفة).
double totalReceivables(List<Customer> all) =>
    all.where((c) => c.owes).fold(0.0, (s, c) => s + c.balanceDue);

/// بداية الأسبوع (السبت أول يوم، حسب اتفاقنا) عند منتصف الليل.
DateTime weekStartSaturday(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final back = (today.weekday - DateTime.saturday + 7) % 7;
  return DateTime(today.year, today.month, today.day - back);
}

/// ملخص حركة العملاء في فترة [from, to) — منفصل تمامًا عن الرصيد الكلي.
class ReceivablesSummary {
  /// إجمالي اللي لنا برّه دلوقتي (رصيد كلي، مش بيتأثر بالفترة).
  final double outstanding;

  /// مبيعات آجلة وزيادات في الفترة (بدون الأرصدة الافتتاحية).
  final double charges;

  /// تحصيلات في الفترة (بدون الأرصدة الافتتاحية).
  final double collected;
  const ReceivablesSummary(this.outstanding, this.charges, this.collected);
}

ReceivablesSummary receivablesSummary(
    List<Customer> all, DateTime from, DateTime to) {
  var charges = 0.0, collected = 0.0;
  for (final c in all) {
    charges += c.salesBetween(from, to);
    collected += c.collectedBetween(from, to);
  }
  return ReceivablesSummary(totalReceivables(all), charges, collected);
}
