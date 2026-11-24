import '../models/customer.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import '../models/supplier.dart';

class ClosingException implements Exception {
  final String message;
  const ClosingException(this.message);
  @override
  String toString() => message;
}

/// منطق إقفال الشيفت والإقفال اليومي — دوال نقية (من غير تخزين)، فاختبارها
/// مباشر. المبدأ: الشيفت له إقفاله المستقل ولقطته الثابتة؛ الإقفال اليومي
/// تجميع اختياري لـ**لقطات** الشيفتات (مش إعادة عدّ للحركات) فمفيش عدّ مزدوج.
class ClosingService {
  ClosingService._();

  /// الساعة اللي بيبدأ عندها اليوم التشغيلي (الافتراضي ٥ الفجر): حركة الساعة
  /// ٢ بعد نص الليل بتتبع «امبارح» التشغيلي مش النهارده التقويمي.
  static const int defaultDayStartHour = 5;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String businessDateOf(DateTime t, {int startHour = defaultDayStartHour}) {
    final s = t.subtract(Duration(hours: startHour));
    return '${s.year}-${_two(s.month)}-${_two(s.day)}';
  }

  static DateTime dayStart(String businessDate, {int startHour = defaultDayStartHour}) {
    final p = businessDate.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2], startHour);
  }

  /// آخر لحظة في اليوم التشغيلي (قبل بداية اليوم اللي بعده بـ١ ميللي ثانية).
  static DateTime dayEnd(String businessDate, {int startHour = defaultDayStartHour}) {
    final s = dayStart(businessDate, startHour: startHour);
    return DateTime(s.year, s.month, s.day + 1, s.hour).subtract(const Duration(milliseconds: 1));
  }

  // ───────────────────────── حساب الأرقام من السجلات ─────────────────────────

  /// يحسب أرقام أي فترة حسب [include] (مين الوقت اللي داخل الفترة). الأرصدة
  /// الافتتاحية مستبعدة (مش حركة فعلية). الخصومات والمكافآت والإكراميات مش
  /// حركة كاش فمش داخلة.
  static ShiftTotals compute({
    required bool Function(DateTime) include,
    double cashSales = 0,
    List<CashEntry> entries = const [],
    required List<Employee> employees,
    required List<Supplier> suppliers,
    required List<Customer> customers,
  }) {
    var credit = 0.0, collections = 0.0, purchases = 0.0, supPay = 0.0, adv = 0.0, sal = 0.0;
    for (final c in customers) {
      for (final s in c.sales) {
        if (!s.isOpening && include(s.date)) credit += s.total;
      }
      for (final p in c.payments) {
        if (!p.opening && include(p.date)) collections += p.amount;
      }
    }
    for (final s in suppliers) {
      for (final p in s.purchases) {
        if (p.received && include(p.date)) purchases += p.total;
      }
      for (final p in s.payments) {
        if (include(p.date)) supPay += p.amount;
      }
    }
    for (final e in employees) {
      for (final a in e.advances) {
        if (include(a.date)) adv += a.amount;
      }
      for (final p in e.payments) {
        if (include(p.date)) sal += p.amount;
      }
    }
    var income = 0.0, expense = 0.0;
    for (final x in entries) {
      if (x.isIncome) {
        income += x.amount;
      } else {
        expense += x.amount;
      }
    }
    return ShiftTotals(
      cashSales: cashSales,
      otherIncome: income,
      collections: collections,
      supplierPayments: supPay,
      advances: adv,
      salaries: sal,
      expenses: expense,
      creditSales: credit,
      supplierPurchases: purchases,
    );
  }

  /// أرقام الشيفت: من الحركات الواقعة بين فتحه وإقفاله (أو دلوقتي لو لسه مفتوح).
  static ShiftTotals totalsOfShift(
    Shift s, {
    required DateTime now,
    required List<Employee> employees,
    required List<Supplier> suppliers,
    required List<Customer> customers,
    DateTime? closeAt,
  }) {
    final end = closeAt ?? s.closedAt ?? now;
    return compute(
      include: (t) => !t.isBefore(s.openedAt) && !t.isAfter(end),
      cashSales: s.cashSales,
      entries: s.entries,
      employees: employees,
      suppliers: suppliers,
      customers: customers,
    );
  }

  // ───────────────────────────── الشيفت ─────────────────────────────

  static Shift? openShiftOf(List<Shift> all) {
    for (final s in all) {
      if (!s.isClosed) return s;
    }
    return null;
  }

  static List<Shift> closedShifts(List<Shift> all) =>
      all.where((s) => s.isClosed).toList()..sort((a, b) => a.openedAt.compareTo(b.openedAt));

  /// اقتراح الكاش الافتتاحي: الكاش المعدود في آخر شيفت اتقفل، أو المتوقع لو ما اتعدّش.
  static double suggestedOpeningCash(List<Shift> all) {
    final closed = closedShifts(all);
    if (closed.isEmpty) return 0;
    final last = closed.last;
    if (last.countedCash != null) return last.countedCash!;
    final t = last.snapshot;
    return t == null ? 0 : last.expectedCash(t);
  }

  static Shift startShift(
    List<Shift> all, {
    required String id,
    required String name,
    required double openingCash,
    required DateTime now,
    int startHour = defaultDayStartHour,
  }) {
    if (openShiftOf(all) != null) {
      throw const ClosingException('فيه شيفت مفتوح بالفعل. اقفله الأول قبل ما تفتح شيفت جديد.');
    }
    if (openingCash < 0) {
      throw const ClosingException('الكاش الافتتاحي مينفعش يكون بالسالب.');
    }
    var at = now;
    final closed = closedShifts(all);
    if (closed.isNotEmpty) {
      final lastEnd = closed.map((s) => s.closedAt!).reduce((a, b) => a.isAfter(b) ? a : b);
      // الشيفتات ما بتتداخلش أبدًا: الجديد بيبدأ بعد نهاية آخر شيفت.
      if (!at.isAfter(lastEnd)) at = lastEnd.add(const Duration(milliseconds: 1));
    }
    return Shift(
      id: id,
      businessDate: businessDateOf(at, startHour: startHour),
      name: name.trim().isEmpty ? 'شيفت' : name.trim(),
      openedAt: at,
      openingCash: openingCash,
    );
  }

  /// يقفل الشيفت ويحفظ لقطته الثابتة.
  static Shift closeShift(
    Shift s, {
    required DateTime now,
    double? countedCash,
    String note = '',
    required List<Employee> employees,
    required List<Supplier> suppliers,
    required List<Customer> customers,
  }) {
    if (s.isClosed) {
      throw const ClosingException('الشيفت ده مقفول بالفعل.');
    }
    if (countedCash != null && countedCash < 0) {
      throw const ClosingException('الكاش المعدود مينفعش يكون بالسالب.');
    }
    final end = now.isAfter(s.openedAt) ? now : s.openedAt;
    final totals = totalsOfShift(s,
        now: end, closeAt: end, employees: employees, suppliers: suppliers, customers: customers);
    s.closedAt = end;
    s.countedCash = countedCash;
    if (note.trim().isNotEmpty) s.note = note.trim();
    s.snapshot = totals;
    return s;
  }

  /// لو شيفت مقفول واتغيّرت حركاته بعد الإقفال (إلغاء/تسجيل بأثر رجعي): بيرجّع
  /// الأرقام الحالية للمقارنة. null = مفيش اختلاف.
  static ShiftTotals? driftOf(
    Shift s, {
    required DateTime now,
    required List<Employee> employees,
    required List<Supplier> suppliers,
    required List<Customer> customers,
  }) {
    final snap = s.snapshot;
    if (!s.isClosed || snap == null) return null;
    final live = totalsOfShift(s,
        now: now, employees: employees, suppliers: suppliers, customers: customers);
    return live.sameAs(snap) ? null : live;
  }

  // ───────────────────────── الإقفال اليومي ─────────────────────────

  static List<Shift> shiftsOfDay(List<Shift> all, String businessDate) =>
      all.where((s) => s.businessDate == businessDate).toList()
        ..sort((a, b) => a.openedAt.compareTo(b.openedAt));

  /// تجميع شيفتات اليوم التشغيلي المقفولة في تقرير واحد. بيرفض لو فيه شيفت
  /// مفتوح في نفس اليوم أو مفيش شيفت مقفول. [existing] = نسخة سابقة تتحدّث
  /// (مفيش تكرار: اليوم له إقفال يومي واحد).
  static DailyClosing consolidate(
    List<Shift> all,
    String businessDate, {
    DailyClosing? existing,
    required String newId,
    required DateTime now,
    int startHour = defaultDayStartHour,
    String note = '',
    required List<Employee> employees,
    required List<Supplier> suppliers,
    required List<Customer> customers,
  }) {
    final day = shiftsOfDay(all, businessDate);
    if (day.any((s) => !s.isClosed)) {
      throw const ClosingException('فيه شيفت لسه مفتوح في اليوم ده. اقفله الأول.');
    }
    if (day.isEmpty) {
      throw const ClosingException('مفيش شيفتات مقفولة في اليوم ده عشان نجمّعها.');
    }
    var sum = const ShiftTotals();
    for (final s in day) {
      sum = sum + (s.snapshot ?? const ShiftTotals());
    }
    final from = dayStart(businessDate, startHour: startHour);
    final to = dayEnd(businessDate, startHour: startHour);
    final windows = all.map((s) => (s.openedAt, s.closedAt ?? now)).toList();
    final outside = compute(
      include: (t) =>
          !t.isBefore(from) &&
          !t.isAfter(to) &&
          !windows.any((w) => !t.isBefore(w.$1) && !t.isAfter(w.$2)),
      employees: employees,
      suppliers: suppliers,
      customers: customers,
    );
    if (existing != null) {
      existing
        ..shiftIds = day.map((s) => s.id).toList()
        ..totals = sum
        ..outsideShifts = outside
        ..updatedAt = now
        ..note = note.isEmpty ? existing.note : note;
      return existing;
    }
    return DailyClosing(
      id: newId,
      businessDate: businessDate,
      closedAt: now,
      shiftIds: day.map((s) => s.id).toList(),
      totals: sum,
      outsideShifts: outside,
      note: note,
    );
  }

  /// الإقفال اليومي ناقص/قديم: اتضاف شيفت للنهار بعده، أو لقطة شيفت اتغيّرت.
  static bool isDailyStale(DailyClosing d, List<Shift> all) {
    final day = shiftsOfDay(all, d.businessDate).where((s) => s.isClosed).toList();
    if (day.length != d.shiftIds.length) return true;
    for (final s in day) {
      if (!d.shiftIds.contains(s.id)) return true;
    }
    var sum = const ShiftTotals();
    for (final s in day) {
      sum = sum + (s.snapshot ?? const ShiftTotals());
    }
    return !sum.sameAs(d.totals);
  }

  /// تجميع لقطات الشيفتات المقفولة اللي أيامها التشغيلية بين [from] و[to] (شامل)
  /// — للتقرير الأسبوعي.
  static ShiftTotals sumClosedBetween(List<Shift> all, String from, String to) {
    var sum = const ShiftTotals();
    for (final s in all) {
      if (s.isClosed && s.businessDate.compareTo(from) >= 0 && s.businessDate.compareTo(to) <= 0) {
        sum = sum + (s.snapshot ?? const ShiftTotals());
      }
    }
    return sum;
  }
}
