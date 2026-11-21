import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/employee.dart';

Employee emp({String payType = 'monthly', double rate = 0, double monthly = 3000, int shift = 0}) =>
    Employee(
        id: 'e', name: 'أحمد', role: 'عامل', startDate: DateTime(2026, 11, 1),
        salaryMonthly: monthly, payType: payType, payRate: rate, shiftHours: shift);

void main() {
  group('نظام الأجر — متوافق مع القديم', () {
    test('الشهري زي ما كان بالظبط', () {
      final e = emp()..attendance.addAll(['2026-11-01', '2026-11-02', '2026-11-03']);
      expect(e.attendancePay, closeTo(300, 0.001)); // 3000/30*3
      expect(e.remainingSalary, 3000);
      expect(e.isMonthly, isTrue);
    });

    test('بيانات قديمة (من غير حقول الأجر) تتقرا شهري', () {
      final e = Employee.fromJson({
        'id': 'x', 'name': 'قديم', 'startDate': '2026-10-01T00:00:00.000', 'salaryMonthly': 2000,
      });
      expect(e.payType, 'monthly');
      expect(e.payRate, 0);
      expect(e.tips, isEmpty);
      expect(e.toJson().containsKey('payType'), isFalse); // ما نلوّثش البيانات القديمة
    });

    test('يومية: السعر × أيام الحضور', () {
      final e = emp(payType: 'daily', rate: 150, monthly: 0)
        ..attendance.addAll(['2026-11-01', '2026-11-02']);
      expect(e.attendancePay, 300);
    });

    test('بالشيفت: نفس يوم الحضور = شيفت', () {
      final e = emp(payType: 'shift', rate: 200, monthly: 0, shift: 12)
        ..attendance.addAll(['2026-11-01', '2026-11-02', '2026-11-04']);
      expect(e.attendancePay, 600);
    });

    test('بالساعة: من الحضور/الانصراف الفعلي، وإلا طول الشيفت', () {
      final e = emp(payType: 'hourly', rate: 20, monthly: 0, shift: 8)
        ..attendance.addAll(['2026-11-01', '2026-11-02']);
      e.attendanceLog.add(AttendanceEntry(
          id: 'a', day: '2026-11-01',
          checkIn: DateTime(2026, 11, 1, 9), checkOut: DateTime(2026, 11, 1, 19))); // 10 س
      expect(e.workedHours, 18); // 10 فعلي + 8 شيفت للتاني
      expect(e.attendancePay, 360);
    });

    test('بالساعة من غير ساعات ولا شيفت: ما نخمّنش (صفر + تنبيه)', () {
      final e = emp(payType: 'hourly', rate: 20, monthly: 0)..attendance.add('2026-11-01');
      expect(e.attendancePay, 0);
      expect(e.daysWithoutHours, 1);
    });

    test('المتبقي لغير الشهري = المستحق − السلف (مش مرتب ثابت)', () {
      final e = emp(payType: 'daily', rate: 100, monthly: 0)
        ..attendance.addAll(['2026-11-01', '2026-11-02', '2026-11-03'])
        ..advances.add(Advance(id: 'a', amount: 50, date: DateTime(2026, 11, 3), note: ''));
      expect(e.remainingSalary, 250);
    });

    test('الإكراميات منفصلة: ما بتدخلش في الأجر ولا صافي المستحق', () {
      final e = emp(payType: 'daily', rate: 100, monthly: 0)..attendance.add('2026-11-01');
      final before = e.netPayable;
      e.tips.add(EmployeeTip(id: 't', amount: 75, date: DateTime(2026, 11, 1)));
      expect(e.totalTips, 75);
      expect(e.netPayable, before);
      expect(e.attendancePay, 100);
    });

    test('JSON يحفظ كل الإعدادات والإكراميات', () {
      final e = emp(payType: 'shift', rate: 200, monthly: 0, shift: 12)
        ..shiftPattern = 'rotating'
        ..tips.add(EmployeeTip(id: 't', amount: 30, date: DateTime(2026, 11, 2), note: 'ن'));
      final r = Employee.fromJson(e.toJson());
      expect(r.payType, 'shift');
      expect(r.payRate, 200);
      expect(r.shiftHours, 12);
      expect(r.shiftPattern, 'rotating');
      expect(r.totalTips, 30);
    });
  });
}
