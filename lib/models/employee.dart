/// سلفة عامل.
class Advance {
  String id;
  double amount;
  DateTime date;
  String note;
  Advance({required this.id, required this.amount, required this.date, this.note = ''});

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'date': date.toIso8601String(), 'note': note};

  factory Advance.fromJson(Map<String, dynamic> j) => Advance(
      id: j['id'],
      amount: (j['amount'] as num).toDouble(),
      date: DateTime.parse(j['date']),
      note: j['note'] ?? '');
}

/// سجل حضور يوم واحد بوقت دخول/خروج حقيقي (To Accio §5).
/// `day` بالشكل YYYY-MM-DD. `checkIn/checkOut` اختياريان — السجلات القديمة
/// (List<String> attendance فقط) تظهر "الوقت غير متوفر" ولا تُخترع لها أوقات.
class AttendanceEntry {
  String id;
  String day;
  DateTime? checkIn;
  DateTime? checkOut;

  AttendanceEntry({required this.id, required this.day, this.checkIn, this.checkOut});

  bool get hasTime => checkIn != null || checkOut != null;

  Duration? get worked =>
      (checkIn != null && checkOut != null) ? checkOut!.difference(checkIn!) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'checkIn': checkIn?.toIso8601String(),
        'checkOut': checkOut?.toIso8601String(),
      };

  factory AttendanceEntry.fromJson(Map<String, dynamic> j) => AttendanceEntry(
        id: j['id'],
        day: j['day'],
        checkIn: j['checkIn'] == null ? null : DateTime.parse(j['checkIn']),
        checkOut: j['checkOut'] == null ? null : DateTime.parse(j['checkOut']),
      );
}

/// دفعة راتب فعلية اتدفعت للعامل.
class EmployeePayment {
  String id;
  double amount;
  DateTime date;
  String note;
  EmployeePayment({required this.id, required this.amount, required this.date, this.note = ''});

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'date': date.toIso8601String(), 'note': note};

  factory EmployeePayment.fromJson(Map<String, dynamic> j) => EmployeePayment(
      id: j['id'],
      amount: (j['amount'] as num).toDouble(),
      date: DateTime.parse(j['date']),
      note: j['note'] ?? '');
}

/// خصم مالي بسبب مذكور.
class EmployeeDeduction {
  String id;
  double amount;
  String reason;
  DateTime date;
  EmployeeDeduction(
      {required this.id, required this.amount, required this.reason, required this.date});

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'reason': reason,
        'date': date.toIso8601String(),
      };

  factory EmployeeDeduction.fromJson(Map<String, dynamic> j) => EmployeeDeduction(
      id: j['id'],
      amount: (j['amount'] as num).toDouble(),
      reason: j['reason'] ?? '',
      date: DateTime.parse(j['date']));
}

/// مكافأة مالية بسبب مذكور.
class EmployeeBonus {
  String id;
  double amount;
  String reason;
  DateTime date;
  EmployeeBonus({required this.id, required this.amount, required this.reason, required this.date});

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'reason': reason, 'date': date.toIso8601String()};

  factory EmployeeBonus.fromJson(Map<String, dynamic> j) => EmployeeBonus(
      id: j['id'],
      amount: (j['amount'] as num).toDouble(),
      reason: j['reason'] ?? '',
      date: DateTime.parse(j['date']));
}

/// إكرامية: بتتسجّل لوحدها وما بتدخلش في الأجر ولا في صافي المستحق.
class EmployeeTip {
  String id;
  double amount;
  DateTime date;
  String note;
  EmployeeTip({required this.id, required this.amount, required this.date, this.note = ''});

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'date': date.toIso8601String(), 'note': note};

  factory EmployeeTip.fromJson(Map<String, dynamic> j) => EmployeeTip(
      id: j['id'],
      amount: (j['amount'] as num).toDouble(),
      date: DateTime.parse(j['date']),
      note: j['note'] ?? '');
}

/// ملاحظة حرة — **لا** تُطبَّق ماليًا تلقائيًا.
class EmployeeNote {
  String id;
  String text;
  DateTime date;
  EmployeeNote({required this.id, required this.text, required this.date});

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'date': date.toIso8601String()};

  factory EmployeeNote.fromJson(Map<String, dynamic> j) => EmployeeNote(
      id: j['id'], text: j['text'] ?? '', date: DateTime.parse(j['date']));
}

/// حدث في ملف العامل (للـTimeline).
class EmployeeEvent {
  final String kind; // advance | payment | deduction | bonus | note | attendance
  final DateTime date;
  final double amount;
  final String label;
  final Object payload;
  const EmployeeEvent(this.kind, this.date, this.amount, this.label, this.payload);
}

class Employee {
  String id;
  String name;
  String role;
  DateTime startDate;
  double salaryMonthly;
  List<Advance> advances;
  List<String> attendance; // أيام الحضور (YYYY-MM-DD) — للتوافق مع الشاشات القائمة
  bool archived;

  // ── إضافات ملف العامل الحقيقي (To Accio §3) ──
  String phone;
  String address;
  String idNumber;
  String photoPath;
  List<AttendanceEntry> attendanceLog;
  List<EmployeePayment> payments;
  List<EmployeeDeduction> deductions;
  List<EmployeeBonus> bonuses;
  List<EmployeeNote> notes;

  // ── نظام الأجر والشيفتات (إضافي ومتوافق مع القديم: الافتراضي شهري) ──
  // جدول الشغل (شيفت ٨/١٢ ساعة، ثابت/متناوب) منفصل تمامًا عن طريقة حساب الأجر.
  /// 'monthly' (الافتراضي) | 'daily' | 'shift' | 'hourly'
  String payType;

  /// السعر لغير الشهري: يومية / سعر الشيفت / سعر الساعة (ج).
  double payRate;

  /// طول الشيفت بالساعات (٨ أو ١٢)، 0 = غير محدد.
  int shiftHours;

  /// 'fixed' | 'rotating' — معلومة تنظيمية بس.
  String shiftPattern;

  /// إكراميات منفصلة عن الأجر.
  List<EmployeeTip> tips;

  Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.startDate,
    required this.salaryMonthly,
    List<Advance>? advances,
    List<String>? attendance,
    this.archived = false,
    this.phone = '',
    this.address = '',
    this.idNumber = '',
    this.photoPath = '',
    List<AttendanceEntry>? attendanceLog,
    List<EmployeePayment>? payments,
    List<EmployeeDeduction>? deductions,
    List<EmployeeBonus>? bonuses,
    List<EmployeeNote>? notes,
    this.payType = 'monthly',
    this.payRate = 0,
    this.shiftHours = 0,
    this.shiftPattern = 'fixed',
    List<EmployeeTip>? tips,
  })  : tips = tips ?? [],
        advances = advances ?? [],
        attendance = attendance ?? [],
        attendanceLog = attendanceLog ?? [],
        payments = payments ?? [],
        deductions = deductions ?? [],
        bonuses = bonuses ?? [],
        notes = notes ?? [];

  // ── حسابات أصلية (لم تُغيَّر قواعدها) ──
  int get workingDays {
    final n = DateTime.now();
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    if (n.isBefore(s)) return 0;
    return DateTime(n.year, n.month, n.day).difference(s).inDays + 1;
  }

  double get totalAdvances => advances.fold(0, (s, a) => s + a.amount);
  int get absenceDays => workingDays > attendance.length ? workingDays - attendance.length : 0;
  bool get isMonthly => payType == 'monthly';
  double get salaryDue =>
      isMonthly ? (salaryMonthly / 30 * attendance.length) - totalAdvances : attendancePay - totalAdvances;
  // الشهري: زي ما كان (المرتب − السلف). غير الشهري: مفيش «مرتب ثابت» — المتبقي
  // = المستحق فعلًا حسب الحضور − السلف.
  double get remainingSalary =>
      isMonthly ? salaryMonthly - totalAdvances : attendancePay - totalAdvances;

  // ── إجماليات جديدة (إضافية، بلا خلط مع قواعد الراتب) ──
  double get totalPayments => payments.fold(0, (s, p) => s + p.amount);
  double get totalDeductions => deductions.fold(0, (s, d) => s + d.amount);
  double get totalBonuses => bonuses.fold(0, (s, b) => s + b.amount);

  /// ساعات الشغل الفعلية لأيام الحضور: من الحضور/الانصراف المسجّلين، ولو يوم
  /// من غير انصراف بنستخدم طول الشيفت المحدد؛ ولو مفيش الاتنين اليوم ده بيتعدّ
  /// في [daysWithoutHours] (مفيش تخمين).
  double get workedHours {
    var h = 0.0;
    for (final day in attendance) {
      AttendanceEntry? en;
      for (final a in attendanceLog) {
        if (a.day == day) en = a;
      }
      if (en?.checkIn != null && en?.checkOut != null) {
        h += en!.checkOut!.difference(en.checkIn!).inMinutes / 60.0;
      } else if (shiftHours > 0) {
        h += shiftHours;
      }
    }
    return h;
  }

  int get daysWithoutHours {
    if (payType != 'hourly') return 0;
    var n = 0;
    for (final day in attendance) {
      AttendanceEntry? en;
      for (final a in attendanceLog) {
        if (a.day == day) en = a;
      }
      final has = (en?.checkIn != null && en?.checkOut != null) || shiftHours > 0;
      if (!has) n++;
    }
    return n;
  }

  /// المستحق حسب أيام الحضور فعلاً (معلومة منفصلة وواضحة). حسب نوع الأجر:
  /// شهري = المرتب ÷ ٣٠ لكل يوم · يومي/شيفت = السعر × أيام الحضور ·
  /// بالساعة = السعر × الساعات الفعلية.
  double get attendancePay {
    switch (payType) {
      case 'daily':
      case 'shift':
        return payRate * attendance.length;
      case 'hourly':
        return payRate * workedHours;
      default:
        return salaryMonthly / 30 * attendance.length;
    }
  }

  double get totalTips => tips.fold(0, (s, t) => s + t.amount);

  String get payTypeLabel {
    switch (payType) {
      case 'daily':
        return 'يومية';
      case 'shift':
        return 'بالشيفت';
      case 'hourly':
        return 'بالساعة';
      default:
        return 'شهري';
    }
  }

  /// صافي المستحق = المستحق حسب الحضور + المكافآت − الخصومات − السلف − المدفوعات.
  double get netPayable =>
      attendancePay + totalBonuses - totalDeductions - totalAdvances - totalPayments;

  String get _today => _dayKey(DateTime.now());
  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get isPresentToday => attendance.contains(_today);

  AttendanceEntry? get todayEntry {
    for (final a in attendanceLog) {
      if (a.day == _today) return a;
    }
    return null;
  }

  bool get hasHistory =>
      advances.isNotEmpty ||
      attendance.isNotEmpty ||
      payments.isNotEmpty ||
      deductions.isNotEmpty ||
      bonuses.isNotEmpty ||
      notes.isNotEmpty;

  /// يسجّل حضور اليوم بوقت حقيقي، ويزامن قائمة `attendance` (بدون تكرار).
  AttendanceEntry markAttendance(DateTime when) {
    final day = _dayKey(when);
    if (!attendance.contains(day)) attendance.add(day);
    var entry = _entryFor(day);
    if (entry == null) {
      entry = AttendanceEntry(id: 'att_${day}_${when.microsecondsSinceEpoch}', day: day, checkIn: when);
      attendanceLog.add(entry);
    } else {
      entry.checkIn ??= when;
    }
    return entry;
  }

  /// يسجّل انصراف اليوم بوقت حقيقي.
  AttendanceEntry markCheckout(DateTime when) {
    final day = _dayKey(when);
    var entry = _entryFor(day);
    if (entry == null) {
      entry = AttendanceEntry(id: 'att_${day}_${when.microsecondsSinceEpoch}', day: day, checkOut: when);
      attendanceLog.add(entry);
    } else {
      entry.checkOut = when;
    }
    return entry;
  }

  AttendanceEntry? _entryFor(String day) {
    for (final a in attendanceLog) {
      if (a.day == day) return a;
    }
    return null;
  }

  /// سجل الأحداث مرتّب من الأحدث للأقدم.
  List<EmployeeEvent> get timeline {
    final ev = <EmployeeEvent>[
      for (final a in advances) EmployeeEvent('advance', a.date, a.amount, 'سلفة', a),
      for (final p in payments) EmployeeEvent('payment', p.date, p.amount, 'دفعة راتب', p),
      for (final d in deductions) EmployeeEvent('deduction', d.date, d.amount, 'خصم', d),
      for (final b in bonuses) EmployeeEvent('bonus', b.date, b.amount, 'مكافأة', b),
      for (final n in notes) EmployeeEvent('note', n.date, 0, 'ملاحظة', n),
      for (final a in attendanceLog)
        EmployeeEvent('attendance', a.checkIn ?? DateTime.parse(a.day), 0, 'حضور', a),
    ];
    ev.sort((a, b) => b.date.compareTo(a.date));
    return ev;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'startDate': startDate.toIso8601String(),
        'salaryMonthly': salaryMonthly,
        'advances': advances.map((a) => a.toJson()).toList(),
        'attendance': attendance,
        'archived': archived,
        'phone': phone,
        'address': address,
        'idNumber': idNumber,
        'photoPath': photoPath,
        'attendanceLog': attendanceLog.map((a) => a.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'deductions': deductions.map((d) => d.toJson()).toList(),
        'bonuses': bonuses.map((b) => b.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        if (payType != 'monthly') 'payType': payType,
        if (payRate != 0) 'payRate': payRate,
        if (shiftHours != 0) 'shiftHours': shiftHours,
        if (shiftPattern != 'fixed') 'shiftPattern': shiftPattern,
        if (tips.isNotEmpty) 'tips': tips.map((t) => t.toJson()).toList(),
      };

  factory Employee.fromJson(Map<String, dynamic> j) {
    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) f) =>
        (j[key] as List? ?? []).map((e) => f(Map<String, dynamic>.from(e))).toList();
    return Employee(
      id: j['id'],
      name: j['name'],
      role: j['role'] ?? 'عامل',
      startDate: DateTime.parse(j['startDate']),
      salaryMonthly: (j['salaryMonthly'] as num).toDouble(),
      advances: listOf('advances', Advance.fromJson),
      attendance: List<String>.from(j['attendance'] ?? []),
      archived: j['archived'] ?? false,
      phone: j['phone'] ?? '',
      address: j['address'] ?? '',
      idNumber: j['idNumber'] ?? '',
      photoPath: j['photoPath'] ?? '',
      attendanceLog: listOf('attendanceLog', AttendanceEntry.fromJson),
      payments: listOf('payments', EmployeePayment.fromJson),
      deductions: listOf('deductions', EmployeeDeduction.fromJson),
      bonuses: listOf('bonuses', EmployeeBonus.fromJson),
      notes: listOf('notes', EmployeeNote.fromJson),
      payType: j['payType'] ?? 'monthly',
      payRate: (j['payRate'] as num?)?.toDouble() ?? 0,
      shiftHours: (j['shiftHours'] as num?)?.toInt() ?? 0,
      shiftPattern: j['shiftPattern'] ?? 'fixed',
      tips: listOf('tips', EmployeeTip.fromJson),
    );
  }
}
