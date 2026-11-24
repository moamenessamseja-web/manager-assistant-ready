import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/audit_entry.dart';
import 'package:manager_assistant/models/customer.dart';
import 'package:manager_assistant/models/employee.dart';
import 'package:manager_assistant/models/shift.dart';
import 'package:manager_assistant/models/supplier.dart';
import 'package:manager_assistant/services/closing_service.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سجل التصحيحات + استمرار الشيفتات والإقفال اليومي على التخزين الفعلي.
AuditEntry audit(String id, Map<String, dynamic> original, {String type = 'advance'}) => AuditEntry(
    id: id, at: DateTime(2026, 11, 22, 10), action: 'void', ownerType: 'employee', ownerId: 'e1',
    ownerName: 'أحمد', recordType: type, recordId: original['id'] as String, summary: 'سلفة 100',
    amount: 100, reason: 'غلطة في الرقم', original: original);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('التصحيح بدل الحذف الصامت', () {
    test('إلغاء سلفة: الرصيد بيتصحّح والحركة الأصلية محفوظة كاملة بالسبب والوقت', () async {
      final e = Employee(id: 'e1', name: 'أحمد', role: '', startDate: DateTime(2026, 11, 1), salaryMonthly: 3000)
        ..advances.add(Advance(id: 'a1', amount: 100, date: DateTime(2026, 11, 20), note: 'غلط'))
        ..advances.add(Advance(id: 'a2', amount: 50, date: DateTime(2026, 11, 21)));
      await StorageService.saveEmployee(e);
      expect(StorageService.employees().single.totalAdvances, 150);

      // نفس تسلسل voidWithAudit: التصحيح الأول، وبعدين الإلغاء الفعلي
      final target = e.advances.first;
      await StorageService.addAudit(audit('au1', target.toJson()));
      e.advances.removeWhere((a) => a.id == 'a1');
      await StorageService.saveEmployee(e);

      expect(StorageService.employees().single.totalAdvances, 50); // اتحسب من الفعّالة بس
      final log = StorageService.auditLog().single;
      expect(log.reason, 'غلطة في الرقم');
      expect(log.original['amount'], 100);
      expect(log.original['id'], 'a1');
      expect(log.at, DateTime(2026, 11, 22, 10));
    });

    test('فشل الإلغاء الفعلي: التصحيح بيتشال (مفيش أثر وهمي)', () async {
      await StorageService.addAudit(audit('au1', {'id': 'x', 'amount': 1}));
      await StorageService.removeAudit('au1');
      expect(StorageService.auditLog(), isEmpty);
    });

    test('إلغاء بيع/دفعة عميل بيعدّل الرصيد وبيتسجل، وماينفعش الإلغاء يتكرر', () async {
      final c = Customer(id: 'c1', name: 'حموده')
        ..addSale(CreditSale(id: 's1', item: 'طلبات', total: 300, date: DateTime(2026, 11, 20)))
        ..addPayment(CustomerPayment(id: 'p1', amount: 100, date: DateTime(2026, 11, 21)));
      await StorageService.saveCustomer(c);
      expect(StorageService.customers().single.balanceDue, 200);
      await StorageService.addAudit(audit('au2', c.payments.single.toJson(), type: 'payment'));
      final ok = await StorageService.mutateCustomer('c1', (x) {
        final before = x.payments.length;
        x.payments.removeWhere((p) => p.id == 'p1');
        return x.payments.length != before;
      });
      expect(ok, isTrue);
      expect(StorageService.customers().single.balanceDue, 300);
      // إلغاء نفس الحركة تاني = مفيش حاجة تتغيّر
      final again = await StorageService.mutateCustomer('c1', (x) {
        final before = x.payments.length;
        x.payments.removeWhere((p) => p.id == 'p1');
        return x.payments.length != before;
      });
      expect(again, isFalse);
      expect(StorageService.auditLog().length, 1);
    });

    test('سجل التصحيحات بيفضل بعد إعادة التشغيل', () async {
      await StorageService.addAudit(audit('au1', {'id': 'a1', 'amount': 100}));
      await StorageService.init();
      expect(StorageService.auditLog().single.id, 'au1');
    });
  });

  group('الشيفتات والإقفال اليومي على التخزين', () {
    test('شيفتين في يوم ← إقفال يومي ← إعادة تشغيل ← نفس الأرقام ومفيش عدّ مزدوج', () async {
      final c = Customer(id: 'c1', name: 'حموده');
      await StorageService.saveCustomer(c);
      final all = <Shift>[];
      Future<Shift> run(DateTime open, DateTime close, double cashSales, double collect, double cash) async {
        final s = ClosingService.startShift(all, id: 'sh${all.length + 1}', name: 'شيفت', openingCash: cash, now: open);
        all.add(s);
        s.cashSales = cashSales;
        await StorageService.saveShift(s);
        final cust = StorageService.customers().single
          ..addPayment(CustomerPayment(id: 'p${all.length}', amount: collect, date: open.add(const Duration(hours: 1))));
        await StorageService.saveCustomer(cust);
        ClosingService.closeShift(s,
            now: close,
            countedCash: cash + cashSales + collect,
            employees: StorageService.employees(),
            suppliers: StorageService.suppliers(),
            customers: StorageService.customers());
        await StorageService.saveShift(s);
        return s;
      }

      await run(DateTime(2026, 11, 21, 8), DateTime(2026, 11, 21, 16), 500, 60, 100);
      await run(DateTime(2026, 11, 21, 17), DateTime(2026, 11, 22, 1), 700, 40, 660);

      final d = ClosingService.consolidate(StorageService.shifts(), '2026-11-21',
          newId: 'd1', now: DateTime(2026, 11, 22, 1, 5),
          employees: StorageService.employees(), suppliers: StorageService.suppliers(),
          customers: StorageService.customers());
      await StorageService.saveDailyClosing(d);

      await StorageService.init(); // إعادة تشغيل
      final shifts = StorageService.shifts();
      final daily = StorageService.dailyClosings().single;
      expect(shifts.length, 2);
      expect(shifts.every((s) => s.isClosed), isTrue);
      expect(daily.totals.cashSales, 1200);
      expect(daily.totals.collections, 100); // 60 + 40 مرة واحدة
      expect(daily.shiftIds.length, 2);
      expect(ClosingService.isDailyStale(daily, shifts), isFalse);
      // الشيفتات الأصلية محفوظة لسه بلقطاتها
      expect(shifts.first.snapshot!.collections, 60);
      expect(shifts.first.variance(shifts.first.snapshot!), 0);
    });

    test('شيفت مفتوح بيفضل مفتوح بعد إعادة التشغيل، وماينفعش فتح تاني', () async {
      final all = <Shift>[];
      final s = ClosingService.startShift(all,
          id: 'sh1', name: 'صباحي', openingCash: 50, now: DateTime(2026, 11, 22, 8));
      await StorageService.saveShift(s);
      await StorageService.init();
      final open = ClosingService.openShiftOf(StorageService.shifts());
      expect(open, isNotNull);
      expect(open!.openingCash, 50);
      expect(
          () => ClosingService.startShift(StorageService.shifts(),
              id: 'x', name: 'تاني', openingCash: 0, now: DateTime(2026, 11, 22, 9)),
          throwsA(isA<ClosingException>()));
    });

    test('حركة سلف وسداد مورد في الشيفت بتظهر كاش خارج، والتوريد بالأجل رصيد', () async {
      final e = Employee(id: 'e1', name: 'أحمد', role: '', startDate: DateTime(2026, 11, 1), salaryMonthly: 3000)
        ..advances.add(Advance(id: 'a', amount: 40, date: DateTime(2026, 11, 22, 10)));
      final su = Supplier(id: 's1', name: 'جمال', itemType: 'لبن')
        ..purchases.add(SupplierPurchase(id: 'p', item: 'لبن', total: 300, date: DateTime(2026, 11, 22, 11)))
        ..payments.add(SupplierPayment(id: 'y', amount: 80, date: DateTime(2026, 11, 22, 12)));
      await StorageService.saveEmployee(e);
      await StorageService.saveSupplier(su);
      final s = ClosingService.startShift([], id: 'sh1', name: 'صباحي', openingCash: 0, now: DateTime(2026, 11, 22, 9));
      ClosingService.closeShift(s,
          now: DateTime(2026, 11, 22, 18),
          employees: StorageService.employees(),
          suppliers: StorageService.suppliers(),
          customers: StorageService.customers());
      expect(s.snapshot!.advances, 40);
      expect(s.snapshot!.supplierPayments, 80);
      expect(s.snapshot!.cashOut, 120);
      expect(s.snapshot!.supplierPurchases, 300); // رصيد مش كاش
      expect(s.snapshot!.cashIn, 0);
    });
  });
}
