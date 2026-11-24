import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/customer.dart';
import 'package:manager_assistant/models/employee.dart';
import 'package:manager_assistant/models/shift.dart';
import 'package:manager_assistant/models/supplier.dart';
import 'package:manager_assistant/services/closing_service.dart';

/// إقفال الشيفت والإقفال اليومي — منطق نقي، من غير تخزين.
Employee emp() => Employee(
    id: 'e1', name: 'أحمد', role: 'عامل', startDate: DateTime(2026, 11, 1), salaryMonthly: 3000);
Supplier sup() => Supplier(id: 's1', name: 'جمال', itemType: 'لبن');
Customer cust() => Customer(id: 'c1', name: 'حموده');

Shift open(List<Shift> all, DateTime at, {double cash = 0, String name = 'شيفت'}) =>
    ClosingService.startShift(all,
        id: 'sh${all.length + 1}', name: name, openingCash: cash, now: at);

Shift close(Shift s, DateTime at, List<Employee> e, List<Supplier> su, List<Customer> c,
        {double? counted}) =>
    ClosingService.closeShift(s,
        now: at, countedCash: counted, employees: e, suppliers: su, customers: c);

void main() {
  group('اليوم التشغيلي', () {
    test('الساعة ٢ بعد نص الليل تابعة لليوم اللي قبله', () {
      expect(ClosingService.businessDateOf(DateTime(2026, 11, 22, 2)), '2026-11-21');
      expect(ClosingService.businessDateOf(DateTime(2026, 11, 22, 6)), '2026-11-22');
      expect(ClosingService.businessDateOf(DateTime(2026, 11, 21, 23, 59)), '2026-11-21');
    });

    test('شيفت بيعدّي نص الليل يفضل في يوم فتحه ويشمل حركات ما بعد نص الليل', () {
      final e = emp(), c = cust();
      final all = <Shift>[];
      final s = open(all, DateTime(2026, 11, 21, 20), cash: 100);
      all.add(s);
      c.addPayment(CustomerPayment(id: 'p', amount: 70, date: DateTime(2026, 11, 22, 1)));
      close(s, DateTime(2026, 11, 22, 3), [e], [sup()], [c]);
      expect(s.businessDate, '2026-11-21');
      expect(s.snapshot!.collections, 70);
    });
  });

  group('كاش مقابل أرصدة', () {
    test('بيع آجل وتوريد بالأجل مش كاش، والتحصيل وسداد المورد كاش', () {
      final e = emp(), su = sup(), c = cust();
      final all = <Shift>[];
      final s = open(all, DateTime(2026, 11, 21, 9), cash: 200);
      all.add(s);
      s.cashSales = 1000;
      s.entries
        ..add(CashEntry(id: 'i', kind: 'income', amount: 20, date: DateTime(2026, 11, 21, 10)))
        ..add(CashEntry(id: 'x', kind: 'expense', amount: 30, date: DateTime(2026, 11, 21, 10)));
      c.addSale(CreditSale(id: 'cs', item: 'طلبات', total: 100, date: DateTime(2026, 11, 21, 11)));
      c.addPayment(CustomerPayment(id: 'cp', amount: 50, date: DateTime(2026, 11, 21, 12)));
      su.purchases.add(SupplierPurchase(
          id: 'pu', item: 'لبن', total: 300, date: DateTime(2026, 11, 21, 13)));
      su.payments.add(SupplierPayment(id: 'sp', amount: 80, date: DateTime(2026, 11, 21, 14)));
      e.advances.add(Advance(id: 'a', amount: 40, date: DateTime(2026, 11, 21, 15)));
      e.payments.add(EmployeePayment(id: 'ep', amount: 500, date: DateTime(2026, 11, 21, 16)));
      close(s, DateTime(2026, 11, 21, 17), [e], [su], [c], counted: 600);
      final t = s.snapshot!;
      expect(t.creditSales, 100); // رصيد: مش كاش
      expect(t.supplierPurchases, 300); // رصيد: مش كاش
      expect(t.cashIn, 1000 + 20 + 50);
      expect(t.cashOut, 80 + 40 + 500 + 30);
      expect(t.netCashMovement, 420);
      expect(s.expectedCash(t), 620); // 200 + 420
      expect(s.variance(t), -20); // 600 معدود − 620 متوقع
    });

    test('الأرصدة الافتتاحية مش بتتحسب مبيعات ولا تحصيل', () {
      final c = cust()
        ..addSale(CreditSale(
            id: 'o', item: 'رصيد سابق', total: 900, date: DateTime(2026, 11, 21, 10), opening: true))
        ..addPayment(CustomerPayment(
            id: 'po', amount: 400, date: DateTime(2026, 11, 21, 10), opening: true));
      final all = <Shift>[];
      final s = open(all, DateTime(2026, 11, 21, 9));
      all.add(s);
      close(s, DateTime(2026, 11, 21, 18), [], [], [c]);
      expect(s.snapshot!.creditSales, 0);
      expect(s.snapshot!.collections, 0);
    });

    test('الخصومات والمكافآت والإكراميات مش حركة كاش', () {
      final e = emp()
        ..deductions.add(EmployeeDeduction(
            id: 'd', amount: 50, reason: 'x', date: DateTime(2026, 11, 21, 10)))
        ..bonuses.add(EmployeeBonus(
            id: 'b', amount: 70, reason: 'x', date: DateTime(2026, 11, 21, 10)))
        ..tips.add(EmployeeTip(id: 't', amount: 30, date: DateTime(2026, 11, 21, 10)));
      final all = <Shift>[];
      final s = open(all, DateTime(2026, 11, 21, 9));
      all.add(s);
      close(s, DateTime(2026, 11, 21, 18), [e], [], []);
      expect(s.snapshot!.cashOut, 0);
      expect(s.snapshot!.cashIn, 0);
    });
  });

  group('شيفتات متعددة وإقفال يومي', () {
    test('اليوم = مجموع لقطات الشيفتات، وكل حركة بتتعد مرة واحدة', () {
      final e = emp(), c = cust();
      final all = <Shift>[];
      final s1 = open(all, DateTime(2026, 11, 21, 8), cash: 100, name: 'صباحي');
      all.add(s1);
      s1.cashSales = 500;
      c.addPayment(CustomerPayment(id: 'p1', amount: 60, date: DateTime(2026, 11, 21, 9)));
      close(s1, DateTime(2026, 11, 21, 16), [e], [], [c]);
      final s2 = open(all, DateTime(2026, 11, 21, 16, 30), cash: 150, name: 'مسائي');
      all.add(s2);
      s2.cashSales = 700;
      c.addPayment(CustomerPayment(id: 'p2', amount: 40, date: DateTime(2026, 11, 21, 20)));
      close(s2, DateTime(2026, 11, 22, 1), [e], [], [c]);

      final d = ClosingService.consolidate(all, '2026-11-21',
          newId: 'd1', now: DateTime(2026, 11, 22, 1, 5), employees: [e], suppliers: [], customers: [c]);
      expect(d.shiftIds, ['sh1', 'sh2']);
      expect(d.totals.cashSales, 1200);
      expect(d.totals.collections, 100); // 60 + 40 — مش 200
      expect(d.outsideShifts.collections, 0);
      // الشيفتات الأصلية لسه زي ما هي
      expect(s1.snapshot!.collections, 60);
      expect(s2.snapshot!.collections, 40);
    });

    test('حركة خارج أي شيفت بتظهر لوحدها ومش داخلة في الإجمالي', () {
      final c = cust();
      final all = <Shift>[];
      final s1 = open(all, DateTime(2026, 11, 21, 8));
      all.add(s1);
      close(s1, DateTime(2026, 11, 21, 12), [], [], [c]);
      c.addPayment(CustomerPayment(id: 'gap', amount: 25, date: DateTime(2026, 11, 21, 13)));
      final d = ClosingService.consolidate(all, '2026-11-21',
          newId: 'd', now: DateTime(2026, 11, 21, 23), employees: [], suppliers: [], customers: [c]);
      expect(d.totals.collections, 0);
      expect(d.outsideShifts.collections, 25);
    });

    test('مفيش إقفال يومي مع شيفت مفتوح أو من غير شيفتات', () {
      final all = <Shift>[];
      final s = open(all, DateTime(2026, 11, 21, 8));
      all.add(s);
      expect(
          () => ClosingService.consolidate(all, '2026-11-21',
              newId: 'd', now: DateTime(2026, 11, 21, 23), employees: [], suppliers: [], customers: []),
          throwsA(isA<ClosingException>()));
      expect(
          () => ClosingService.consolidate(all, '2026-11-20',
              newId: 'd', now: DateTime(2026, 11, 21, 23), employees: [], suppliers: [], customers: []),
          throwsA(isA<ClosingException>()));
    });

    test('إعادة التجميع بتحدّث نفس الإقفال (مفيش تكرار) وبتكشف إنه قديم', () {
      final all = <Shift>[];
      final s1 = open(all, DateTime(2026, 11, 21, 8));
      all.add(s1);
      s1.cashSales = 100;
      close(s1, DateTime(2026, 11, 21, 12), [], [], []);
      final d = ClosingService.consolidate(all, '2026-11-21',
          newId: 'd1', now: DateTime(2026, 11, 21, 13), employees: [], suppliers: [], customers: []);
      expect(ClosingService.isDailyStale(d, all), isFalse);
      final s2 = open(all, DateTime(2026, 11, 21, 14));
      all.add(s2);
      s2.cashSales = 50;
      close(s2, DateTime(2026, 11, 21, 18), [], [], []);
      expect(ClosingService.isDailyStale(d, all), isTrue);
      final d2 = ClosingService.consolidate(all, '2026-11-21',
          existing: d, newId: 'zzz', now: DateTime(2026, 11, 21, 19), employees: [], suppliers: [], customers: []);
      expect(identical(d, d2), isTrue);
      expect(d2.id, 'd1');
      expect(d2.totals.cashSales, 150);
      expect(ClosingService.isDailyStale(d2, all), isFalse);
    });
  });

  group('قواعد الشيفت', () {
    test('ماينفعش شيفتين مفتوحين، والجديد بيبدأ بعد نهاية السابق', () {
      final all = <Shift>[];
      final s1 = open(all, DateTime(2026, 11, 21, 8));
      all.add(s1);
      expect(() => open(all, DateTime(2026, 11, 21, 9)), throwsA(isA<ClosingException>()));
      close(s1, DateTime(2026, 11, 21, 12), [], [], []);
      final s2 = open(all, DateTime(2026, 11, 21, 11)); // ساعة قبل إقفال السابق
      expect(s2.openedAt.isAfter(s1.closedAt!), isTrue);
    });

    test('الكاش الافتتاحي المقترح = المعدود في آخر شيفت، وإلا المتوقع', () {
      final all = <Shift>[];
      final s1 = open(all, DateTime(2026, 11, 21, 8), cash: 100);
      all.add(s1);
      s1.cashSales = 300;
      close(s1, DateTime(2026, 11, 21, 12), [], [], [], counted: 390);
      expect(ClosingService.suggestedOpeningCash(all), 390);
      s1.countedCash = null;
      expect(ClosingService.suggestedOpeningCash(all), 400);
    });

    test('ماينفعش تقفل شيفت مقفول مرتين', () {
      final all = <Shift>[];
      final s1 = open(all, DateTime(2026, 11, 21, 8));
      all.add(s1);
      close(s1, DateTime(2026, 11, 21, 12), [], [], []);
      expect(() => close(s1, DateTime(2026, 11, 21, 13), [], [], []),
          throwsA(isA<ClosingException>()));
    });

    test('تغيير الحركات بعد الإقفال ما بيغيّرش اللقطة، وبيظهر كاختلاف', () {
      final c = cust();
      final all = <Shift>[];
      final s = open(all, DateTime(2026, 11, 21, 8));
      all.add(s);
      c.addPayment(CustomerPayment(id: 'p', amount: 100, date: DateTime(2026, 11, 21, 9)));
      close(s, DateTime(2026, 11, 21, 12), [], [], [c]);
      expect(ClosingService.driftOf(s, now: DateTime(2026, 11, 22), employees: [], suppliers: [], customers: [c]),
          isNull);
      c.payments.clear(); // إلغاء بعد الإقفال
      final drift = ClosingService.driftOf(s,
          now: DateTime(2026, 11, 22), employees: [], suppliers: [], customers: [c]);
      expect(drift, isNotNull);
      expect(drift!.collections, 0);
      expect(s.snapshot!.collections, 100); // اللقطة ثابتة
    });

    test('JSON للشيفت واللقطة والإقفال اليومي بيرجع زي ما هو', () {
      final all = <Shift>[];
      final s = open(all, DateTime(2026, 11, 21, 8), cash: 55, name: 'صباحي');
      all.add(s);
      s.cashSales = 10;
      s.entries.add(CashEntry(id: 'x', kind: 'expense', amount: 5, note: 'ثلج', date: DateTime(2026, 11, 21, 9)));
      close(s, DateTime(2026, 11, 21, 12), [], [], [], counted: 60);
      final r = Shift.fromJson(s.toJson());
      expect(r.name, 'صباحي');
      expect(r.entries.single.note, 'ثلج');
      expect(r.snapshot!.expenses, 5);
      expect(r.countedCash, 60);
      expect(r.isClosed, isTrue);
      final d = ClosingService.consolidate(all, '2026-11-21',
          newId: 'd', now: DateTime(2026, 11, 21, 13), employees: [], suppliers: [], customers: []);
      final rd = DailyClosing.fromJson(d.toJson());
      expect(rd.totals.expenses, 5);
      expect(rd.shiftIds, ['sh1']);
    });
  });
}
