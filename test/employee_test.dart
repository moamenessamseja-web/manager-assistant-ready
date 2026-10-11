import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/employee.dart';

/// اختبارات ملف العامل (To Accio §3) والأوقات في السجلات (§5)،
/// مع تأكيد أن قواعد الراتب الأصلية لم تتغيّر (توافق خلفي).
void main() {
  Employee emp() => Employee(
        id: 'e1',
        name: 'علي',
        role: 'عامل',
        startDate: DateTime(2026, 10, 1),
        salaryMonthly: 6000,
      );

  test('الحضور والانصراف يسجّلان وقتًا حقيقيًا ويزامنان قائمة الأيام', () {
    final e = emp();
    final when = DateTime(2026, 10, 12, 8, 30);
    e.markAttendance(when);
    expect(e.attendance.length, 1);
    expect(e.attendanceLog.length, 1);
    expect(e.attendanceLog.first.checkIn, when);
    expect(e.attendanceLog.first.checkOut, isNull);
    expect(e.attendanceLog.first.hasTime, isTrue);

    e.markCheckout(DateTime(2026, 10, 12, 17, 0));
    expect(e.attendanceLog.first.checkOut, DateTime(2026, 10, 12, 17, 0));
    expect(e.attendanceLog.first.worked, const Duration(hours: 8, minutes: 30));
  });

  test('تسجيل الحضور مرتين في نفس اليوم لا يكرر اليوم', () {
    final e = emp();
    e.markAttendance(DateTime(2026, 10, 12, 8, 0));
    e.markAttendance(DateTime(2026, 10, 12, 9, 0));
    expect(e.attendance.length, 1);
    expect(e.attendanceLog.length, 1);
    expect(e.attendanceLog.first.checkIn, DateTime(2026, 10, 12, 8, 0)); // أول وقت
  });

  test('التوافق الخلفي: بيانات قديمة (بدون حقول جديدة) تُقرأ وقواعد الراتب كما هي', () {
    final e = Employee.fromJson({
      'id': 'old',
      'name': 'قديم',
      'role': 'عامل',
      'startDate': '2026-10-01T00:00:00.000',
      'salaryMonthly': 3000,
      'advances': [
        {'id': 'a1', 'amount': 500, 'date': '2026-10-05T10:00:00.000', 'note': ''}
      ],
      'attendance': ['2026-10-01'],
      'archived': false,
    });
    expect(e.phone, '');
    expect(e.attendanceLog, isEmpty);
    expect(e.payments, isEmpty);
    expect(e.totalAdvances, 500);
    // القواعد الأصلية لم تتغيّر
    expect(e.salaryDue, closeTo(3000 / 30 * 1 - 500, 0.001));
    expect(e.remainingSalary, 2500);
    expect(e.hasHistory, isTrue);
  });

  test('إجماليات الحركات المالية وصافي المستحق', () {
    final e = emp();
    e.attendance.addAll(['2026-10-01', '2026-10-02', '2026-10-03']); // 3 أيام من 30
    e.advances.add(Advance(id: 'a', amount: 200, date: DateTime(2026, 10, 2)));
    e.payments.add(EmployeePayment(id: 'p', amount: 1000, date: DateTime(2026, 10, 4)));
    e.deductions.add(EmployeeDeduction(
        id: 'd', amount: 150, reason: 'تأخير', date: DateTime(2026, 10, 5)));
    e.bonuses.add(EmployeeBonus(
        id: 'b', amount: 300, reason: 'أداء', date: DateTime(2026, 10, 6)));

    expect(e.totalAdvances, 200);
    expect(e.totalPayments, 1000);
    expect(e.totalDeductions, 150);
    expect(e.totalBonuses, 300);
    expect(e.attendancePay, closeTo(6000 / 30 * 3, 0.001));
    // attendancePay + bonuses − deductions − advances − payments
    expect(e.netPayable, closeTo(600 + 300 - 150 - 200 - 1000, 0.001));
  });

  test('الحفظ/الاسترجاع يحافظ على كل القوائم الجديدة', () {
    final e = emp();
    e.phone = '01000000000';
    e.address = 'القاهرة';
    e.idNumber = '123';
    e.photoPath = '/tmp/x.jpg';
    e.markAttendance(DateTime(2026, 10, 12, 8, 15));
    e.markCheckout(DateTime(2026, 10, 12, 16, 45));
    e.payments.add(EmployeePayment(id: 'p', amount: 500, date: DateTime(2026, 10, 12, 9, 0)));
    e.deductions.add(EmployeeDeduction(
        id: 'd', amount: 50, reason: 'خصم', date: DateTime(2026, 10, 12, 9, 5)));
    e.bonuses.add(EmployeeBonus(
        id: 'b', amount: 100, reason: 'مكافأة', date: DateTime(2026, 10, 12, 9, 10)));
    e.notes.add(EmployeeNote(id: 'n', text: 'ملاحظة', date: DateTime(2026, 10, 12, 9, 15)));

    final e2 = Employee.fromJson(e.toJson());
    expect(e2.phone, '01000000000');
    expect(e2.address, 'القاهرة');
    expect(e2.idNumber, '123');
    expect(e2.photoPath, '/tmp/x.jpg');
    expect(e2.attendanceLog.length, 1);
    expect(e2.attendanceLog.first.checkIn, DateTime(2026, 10, 12, 8, 15));
    expect(e2.attendanceLog.first.checkOut, DateTime(2026, 10, 12, 16, 45));
    expect(e2.payments.length, 1);
    expect(e2.deductions.length, 1);
    expect(e2.bonuses.length, 1);
    expect(e2.notes.length, 1);
    expect(e2.totalPayments, 500);
  });

  test('الخط الزمني مرتّب من الأحدث للأقدم ويشمل كل الأنواع', () {
    final e = emp();
    e.advances.add(Advance(id: 'a', amount: 100, date: DateTime(2026, 10, 1, 9, 0)));
    e.payments.add(EmployeePayment(id: 'p', amount: 200, date: DateTime(2026, 10, 3, 9, 0)));
    e.notes.add(EmployeeNote(id: 'n', text: 'ملاحظة', date: DateTime(2026, 10, 2, 9, 0)));
    final tl = e.timeline;
    expect(tl.map((x) => x.kind).toList(), ['payment', 'note', 'advance']);
    expect(tl.first.date.isAfter(tl.last.date), isTrue);
  });
}
