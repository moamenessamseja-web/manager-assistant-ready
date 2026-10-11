import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/employee.dart';

/// اختبارات ملف العامل: الحضور بالوقت، المدفوعات/الخصومات/المكافآت،
/// والتوافق الخلفي مع البيانات القديمة (بدون تغيير قواعد الحساب الأصلية).
void main() {
  Employee emp() => Employee(
        id: 'e1',
        name: 'علي',
        role: 'عامل',
        startDate: DateTime(2026, 10, 1),
        salaryMonthly: 6000,
      );

  test('حضور وانصراف يسجّلان وقتًا حقيقيًا ويحدّثان سجل الأيام', () {
    final e = emp();
    final t = DateTime(2026, 10, 12, 8, 30);
    e.markAttendance(t);
    expect(e.attendance.length, 1);
    expect(e.attendanceLog.length, 1);
    expect(e.attendanceLog.first.checkIn, t);
    expect(e.attendanceLog.first.checkOut, isNull);

    e.markCheckout(DateTime(2026, 10, 12, 17, 0));
    expect(e.attendanceLog.first.checkOut, DateTime(2026, 10, 12, 17, 0));
    expect(e.attendanceLog.first.worked, const Duration(hours: 8, minutes: 30));
    // idempotent: نفس اليوم لا يُكرَّر
    e.markAttendance(DateTime(2026, 10, 12, 9, 0));
    expect(e.attendanceLog.length, 1);
    expect(e.attendance.length, 1);
  });

  test('إجماليات المدفوعات والخصومات والمكافآت وصافي المستحق', () {
    final e = emp();
    e.attendance.addAll(['2026-10-01', '2026-10-02', '2026-10-03']); // 3 أيام
    e.advances.add(Advance(id: 'a', amount: 500, date: DateTime(2026, 10, 2)));
    e.payments.add(EmployeePayment(id: 'p', amount: 3000, date: DateTime(2026, 10, 5)));
    e.deductions.add(EmployeeDeduction(id: 'd', amount: 200, reason: 'غياب', date: DateTime(2026, 10, 6)));
    e.bonuses.add(EmployeeBonus(id: 'b', amount: 300, reason: 'أداء', date: DateTime(2026, 10, 7)));

    expect(e.totalAdvances, 500);
    expect(e.totalPayments, 3000);
    expect(e.totalDeductions, 200);
    expect(e.totalBonuses, 300);

    // القاعدة الأصلية: (الراتب/30 × أيام الحضور) − السلف
    final expectedSalaryDue = (6000 / 30 * 3) - 500;
    expect(e.salaryDue, expectedSalaryDue);
    // القاعدة الأصلية: الراتب − السلف
    expect(e.remainingSalary, 5500);
    // صافي مستحق صريح جديد
    expect(e.netPayable, expectedSalaryDue + 300 - 200);
  });

  test('التوافق الخلفي: بيانات قديمة بدون الحقول الجديدة تعمل كما هي', () {
    final old = Employee.fromJson({
      'id': 'old',
      'name': 'قديم',
      'role': 'عامل',
      'startDate': '2026-09-01T00:00:00.000',
      'salaryMonthly': 4000,
      'advances': [
        {'id': 'x', 'amount': 500, 'date': '2026-09-10T00:00:00.000', 'note': ''}
      ],
      'attendance': ['2026-09-01'],
      'archived': false,
    });
    expect(old.payments, isEmpty);
    expect(old.deductions, isEmpty);
    expect(old.bonuses, isEmpty);
    expect(old.notes, isEmpty);
    expect(old.attendanceLog, isEmpty);
    expect(old.phone, '');
    expect(old.totalAdvances, 500);
    expect(old.salaryDue, 4000 / 30 * 1 - 500);
    expect(old.remainingSalary, 3500);
    expect(old.hasHistory, isTrue);
  });

  test('الحفظ/الاسترجاع يحافظ على السجلات الجديدة', () {
    final e = emp();
    e.phone = '01000000000';
    e.idNumber = '123456789';
    e.payments.add(EmployeePayment(id: 'p', amount: 1000, date: DateTime(2026, 10, 5), note: 'راتب أكتوبر'));
    e.deductions.add(EmployeeDeduction(id: 'd', amount: 100, reason: 'تأخير', date: DateTime(2026, 10, 6)));
    e.bonuses.add(EmployeeBonus(id: 'b', amount: 250, reason: 'زيادة', date: DateTime(2026, 10, 7)));
    e.notes.add(EmployeeNote(id: 'n', text: 'غاب 3 أيام', date: DateTime(2026, 10, 8)));
    e.markAttendance(DateTime(2026, 10, 9, 8, 0));

    final e2 = Employee.fromJson(e.toJson());
    expect(e2.phone, '01000000000');
    expect(e2.idNumber, '123456789');
    expect(e2.payments.first.note, 'راتب أكتوبر');
    expect(e2.deductions.first.reason, 'تأخير');
    expect(e2.bonuses.first.amount, 250);
    expect(e2.notes.first.text, 'غاب 3 أيام');
    expect(e2.attendanceLog.first.checkIn, DateTime(2026, 10, 9, 8, 0));
    expect(e2.totalPayments, 1000);
  });

  test('السجل الزمني مرتّب من الأحدث للأقدم', () {
    final e = emp();
    e.advances.add(Advance(id: 'a', amount: 100, date: DateTime(2026, 10, 1)));
    e.bonuses.add(EmployeeBonus(id: 'b', amount: 50, reason: '', date: DateTime(2026, 10, 9)));
    final t = e.timeline;
    expect(t.length, 2);
    expect(t.first.kind, 'bonus');
    expect(t.last.kind, 'advance');
  });
}
