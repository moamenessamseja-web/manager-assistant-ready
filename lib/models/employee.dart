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

/// خصم مالي **مؤكَّد** بقيمة وسبب — ليس مجرد ملاحظة.
class EmployeeDeduction {
  String id;
  double amount;
  String reason;
  DateTime date;
  EmployeeDeduction({required this.id, required this.amount, required this.reason, required this.date});

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'reason': reason, 'date': date.toIso8601String()};

  factory EmployeeDeduction.fromJson(Map<String, dynamic> j) => EmployeeDeduction(
      id: j['id'],
      amount: (j['amount'] as num).toDouble(),
      reason: j['reason'] ?? '',
      date: DateTime.parse(j['date']));
}

/// مكافأة بقيمة وسبب.
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

/// ملاحظة نصية (لا تُطبَّق ماليًا تلقائيًا).
class EmployeeNote {
  String id;
  String text;
  DateTime date;
  EmployeeNote({required this.id, required this.text, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'date': date.toIso8601String()};

  factory EmployeeNote.fromJson(Map<String, dynamic> j) =>
      EmployeeNote(id: j['id'], text: j['text'] ?? '', date: DateTime.parse(j['date']));
}

/// حضور يوم واحد بوقت دخول/خروج حقيقي.
class AttendanceEntry {
  String id;
  String day; // YYYY-MM-DD
  DateTime? checkIn;
  DateTime? checkOut;
  AttendanceEntry({required this.id, required this.day, this.checkIn, this.checkOut});

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

class Employee {
  String id;
  String name;
  String role;
  DateTime startDate;
  double salaryMonthly;
  List<Advance> advances;

  /// أيام الحضور (YYYY-MM-DD) — **يبقى كما هو** لتوافق بقية الشاشات
  /// (today/brief/memory/staff تعتمد عليه).
  List<String> attendance;

  bool archived;

  // ── إضافات ملف العامل (كلها اختيارية، توافق خلفي كامل) ──
  String phone;
  String address;
  String idNumber;
  String photoPath;
  List<AttendanceEntry> attendanceLog;
  List<EmployeePayment> payments;
  List<EmployeeDeduction> deductions;
  List<EmployeeBonus> bonuses;
  List<EmployeeNote> notes;

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
  })  : advances = advances ?? [],
        attendance = attendance ?? [],
        attendanceLog = attendanceLog ?? [],
        payments = payments ?? [],
        deductions = deductions ?? [],
        bonuses = bonuses ?? [],
        notes = notes ?? [];

  // ── حسابات قائمة (بدون تغيير القواعد الموجودة) ──
  int get workingDays {
    final n = DateTime.now();
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    if (n.isBefore(s)) return 0;
    return DateTime(n.year, n.month, n.day).difference(s).inDays + 1;
  }

  double get totalAdvances => advances.fold(0, (s, a) => s + a.amount);
  int get absenceDays => workingDays > attendance.length ? workingDays - attendance.length : 0;

  /// القاعدة الأصلية — لا تتغيّر (مُستخدَمة في اختبارات قائمة).
  double get salaryDue => (salaryMonthly / 30 * attendance.length) - totalAdvances;

  /// القاعدة الأصلية — لا تتغيّر.
  double get remainingSalary => salaryMonthly - totalAdvances;

  // ── حسابات إضافية للكيانات الجديدة ──
  double get totalPayments => payments.fold(0, (s, p) => s + p.amount);
  double get totalDeductions => deductions.fold(0, (s, d) => s + d.amount);
  double get totalBonuses => bonuses.fold(0, (s, b) => s + b.amount);

  /// المستحق حسب الحضور مع المكافآت والخصومات (رقم جديد صريح، منفصل عن القواعد القديمة).
  double get netPayable => salaryDue + totalBonuses - totalDeductions;

  bool get hasHistory =>
      advances.isNotEmpty ||
      attendance.isNotEmpty ||
      payments.isNotEmpty ||
      deductions.isNotEmpty ||
      bonuses.isNotEmpty ||
      notes.isNotEmpty;

  bool get isPresentToday {
    final t = DateTime.now().toIso8601String().substring(0, 10);
    return attendance.contains(t);
  }

  bool get checkedOutToday {
    final t = DateTime.now().toIso8601String().substring(0, 10);
    final entry = attendanceLog.where((a) => a.day == t).toList();
    return entry.isNotEmpty && entry.first.checkOut != null;
  }

  /// يسجّل حضور اليوم (وينشئ سجل حضور بوقت الدخول) — idempotent على مستوى اليوم.
  void markAttendance(DateTime when) {
    final day = when.toIso8601String().substring(0, 10);
    if (!attendance.contains(day)) attendance.add(day);
    final existing = attendanceLog.where((a) => a.day == day).toList();
    if (existing.isEmpty) {
      attendanceLog.add(AttendanceEntry(id: '${id}_$day', day: day, checkIn: when));
    } else if (existing.first.checkIn == null) {
      existing.first.checkIn = when;
    }
  }

  /// يسجّل انصراف اليوم.
  void markCheckout(DateTime when) {
    final day = when.toIso8601String().substring(0, 10);
    if (!attendance.contains(day)) attendance.add(day);
    final existing = attendanceLog.where((a) => a.day == day).toList();
    if (existing.isEmpty) {
      attendanceLog.add(AttendanceEntry(id: '${id}_$day', day: day, checkIn: when, checkOut: when));
    } else {
      existing.first.checkOut = when;
    }
  }

  /// سجل النشاط مرتبًا من الأحدث للأقدم.
  List<EmployeeEvent> get timeline {
    final events = <EmployeeEvent>[
      for (final a in advances) EmployeeEvent('advance', a.date, a.amount, a),
      for (final p in payments) EmployeeEvent('payment', p.date, p.amount, p),
      for (final d in deductions) EmployeeEvent('deduction', d.date, d.amount, d),
      for (final b in bonuses) EmployeeEvent('bonus', b.date, b.amount, b),
      for (final n in notes) EmployeeEvent('note', n.date, 0, n),
      for (final al in attendanceLog) EmployeeEvent('attendance', al.checkIn ?? DateTime.parse(al.day), 0, al),
    ];
    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
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
      };

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'],
        name: j['name'],
        role: j['role'] ?? 'عامل',
        startDate: DateTime.parse(j['startDate']),
        salaryMonthly: (j['salaryMonthly'] as num).toDouble(),
        advances: (j['advances'] as List? ?? [])
            .map((e) => Advance.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        attendance: List<String>.from(j['attendance'] ?? []),
        archived: j['archived'] ?? false,
        phone: j['phone'] ?? '',
        address: j['address'] ?? '',
        idNumber: j['idNumber'] ?? '',
        photoPath: j['photoPath'] ?? '',
        attendanceLog: (j['attendanceLog'] as List? ?? [])
            .map((e) => AttendanceEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        payments: (j['payments'] as List? ?? [])
            .map((e) => EmployeePayment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        deductions: (j['deductions'] as List? ?? [])
            .map((e) => EmployeeDeduction.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        bonuses: (j['bonuses'] as List? ?? [])
            .map((e) => EmployeeBonus.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        notes: (j['notes'] as List? ?? [])
            .map((e) => EmployeeNote.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// حدث في سجل العامل.
class EmployeeEvent {
  final String kind; // advance | payment | deduction | bonus | note | attendance
  final DateTime date;
  final double amount;
  final Object payload;
  const EmployeeEvent(this.kind, this.date, this.amount, this.payload);
}
