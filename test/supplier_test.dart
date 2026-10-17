import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/supplier.dart';

/// اختبارات القبول الإلزامية (To Accio.md §2):
/// فصل قيمة البضاعة عن الدفعات النقدية.
void main() {
  Supplier fresh() => Supplier(id: 'sup1', name: 'محمود', itemType: 'بن');

  test('1) توريد 20 كيلو بن بـ2000 بدون دفع: البضاعة +2000 والمدفوع ثابت والمستحق +2000', () {
    final s = fresh();
    s.purchases.add(SupplierPurchase(
      id: 'p1', item: 'بن', quantity: 20, unit: 'كيلو', unitPrice: 100, total: 2000,
      date: DateTime(2026, 10, 1),
    ));
    expect(s.goodsTotal, 2000);
    expect(s.totalPaid, 0); // لا تُسجَّل دفعة
    expect(s.balanceDue, 2000);
  });

  test('2) توريد ثانٍ قبل سداد الأول = سجلان مستقلان', () {
    final s = fresh();
    s.purchases.add(SupplierPurchase(
      id: 'p1', item: 'بن', quantity: 20, unit: 'كيلو', total: 2000, date: DateTime(2026, 10, 1),
    ));
    s.purchases.add(SupplierPurchase(
      id: 'p2', item: 'لبن', quantity: 10, unit: 'لتر', total: 700, date: DateTime(2026, 10, 3),
    ));
    expect(s.purchases.length, 2);
    expect(s.purchasesTotal, 2700);
    expect(s.balanceDue, 2700);
  });

  test('3) دفع 500 فقط: المدفوع +500 والمستحق 1500', () {
    final s = fresh();
    s.purchases.add(SupplierPurchase(
      id: 'p1', item: 'بن', quantity: 20, unit: 'كيلو', total: 2000, date: DateTime(2026, 10, 1),
    ));
    s.payments.add(SupplierPayment(id: 'pay1', amount: 500, date: DateTime(2026, 10, 4)));
    expect(s.totalPaid, 500);
    expect(s.goodsTotal, 2000);
    expect(s.balanceDue, 1500);
  });

  test('4) الحفظ/الاسترجاع (JSON) يحافظ على السجلات والإجماليات', () {
    final s = fresh();
    s.purchases.add(SupplierPurchase(
      id: 'p1', item: 'بن', quantity: 20, unit: 'كيلو', unitPrice: 100, total: 2000,
      date: DateTime(2026, 10, 1), note: 'توريد الصبح',
    ));
    s.payments.add(SupplierPayment(
        id: 'pay1', amount: 500, date: DateTime(2026, 10, 4), method: 'كاش'));

    final s2 = Supplier.fromJson(s.toJson());
    expect(s2.purchases.length, 1);
    expect(s2.payments.length, 1);
    expect(s2.purchases.first.item, 'بن');
    expect(s2.purchases.first.quantity, 20);
    expect(s2.purchases.first.unit, 'كيلو');
    expect(s2.purchases.first.unitPrice, 100);
    expect(s2.purchases.first.total, 2000);
    expect(s2.payments.first.method, 'كاش');
    expect(s2.goodsTotal, 2000);
    expect(s2.balanceDue, 1500);
  });

  test('5) توافق خلفي: مورد قديم (totalOwed=2000, مدفوع 500) يفضل شغال زي ما هو', () {
    // شكل البيانات القديمة: مفيش purchases، وفيه totalOwed مختصر.
    final legacy = Supplier.fromJson({
      'id': 'old', 'name': 'قديم', 'itemType': 'خضار',
      'totalOwed': 2000,
      'payments': [{'id': 'x', 'amount': 500, 'date': '2026-09-01T10:00:00.000'}],
      'deliveries': [],
    });
    expect(legacy.purchases, isEmpty);
    expect(legacy.goodsTotal, 2000);
    expect(legacy.totalPaid, 500);
    expect(legacy.balanceDue, 1500); // نفس الرقم قبل الترقية — بلا تغيير صامت
    expect(legacy.hasHistory, isTrue);
  });

  test('6) سعر الوحدة المستنتج: إجمالي 2000 على 20 كيلو = 100/كيلو', () {
    final p = SupplierPurchase(
        id: 'p', item: 'بن', quantity: 20, unit: 'كيلو', unitPrice: 2000 / 20,
        total: 2000, date: DateTime.now());
    expect(p.unitPrice, 100);
    expect(p.quantityLabel, '20 كيلو');
    expect(p.unitPriceLabel, '100 ج/كيلو');
  });

  test('7) توزيع الدفعات FIFO: الدفعة تسدّد الأقدم أولاً', () {
    final s = fresh();
    s.purchases.add(SupplierPurchase(
      id: 'p1', item: 'بن', quantity: 20, unit: 'كيلو', total: 2000, date: DateTime(2026, 10, 1),
    ));
    s.purchases.add(SupplierPurchase(
      id: 'p2', item: 'لبن', quantity: 10, unit: 'لتر', total: 700, date: DateTime(2026, 10, 3),
    ));
    s.payments.add(SupplierPayment(id: 'pay1', amount: 2500, date: DateTime(2026, 10, 5)));

    final rows = s.allocatePayments(); // من الأحدث للأقدم
    final first = rows.firstWhere((r) => r.purchase?.id == 'p1'); // الأقدم
    final second = rows.firstWhere((r) => r.purchase?.id == 'p2');

    expect(first.paid, 2000);
    expect(first.remaining, 0);
    expect(first.isSettled, isTrue);
    expect(second.paid, 500);
    expect(second.remaining, 200);
    expect(rows.fold<double>(0, (t, r) => t + r.remaining), 200);
    expect(rows.fold<double>(0, (t, r) => t + r.paid), s.totalPaid);
  });

  test('8) رصيد قديم مختصر يظهر كسطر بند منفصل بلا تفاصيل', () {
    final s = Supplier(
        id: 'x', name: 'قديم', itemType: '', totalOwed: 1000, createdAt: DateTime(2026, 9, 1));
    s.purchases.add(SupplierPurchase(id: 'p', item: 'بن', total: 500, date: DateTime(2026, 10, 1)));
    final rows = s.allocatePayments();
    expect(rows.length, 2);
    expect(rows.any((r) => r.isLegacy && r.total == 1000), isTrue);
    expect(rows.any((r) => !r.isLegacy && r.total == 500), isTrue);
  });

  group('أرشفة الموردين (Phase C)', () {
    List<Supplier> three() {
      final a = Supplier(id: 'a', name: 'محمود', itemType: 'بن');
      final b = Supplier(id: 'b', name: 'جمال', itemType: 'لبن')..archived = true;
      final c = Supplier(id: 'c', name: 'عجمي', itemType: 'سكر');
      return [a, b, c];
    }

    test('المورد المؤرشف يختفي من النشطين تمامًا', () {
      final active = filterSuppliers(three(), 'active');
      expect(active.map((s) => s.id), ['a', 'c']);
    });

    test('المؤرشف يظهر في «المؤرشفون» و«الكل»', () {
      expect(filterSuppliers(three(), 'archived').map((s) => s.id), ['b']);
      expect(filterSuppliers(three(), 'all').length, 3);
    });

    test('قيمة فلتر غير معروفة = نشطون (مش الكل)', () {
      expect(filterSuppliers(three(), 'whatever').length, 2);
    });

    test('الأرشفة وإلغاؤها يحفظان السجل والأرصدة وترجّع المورد للنشطين', () {
      final list = three();
      final s = list.first
        ..purchases.add(SupplierPurchase(
          id: 'p1', item: 'بن', quantity: 20, unit: 'كيلو', total: 2000,
          date: DateTime(2026, 10, 1),
        ));
      s.archived = true;
      expect(filterSuppliers(list, 'active').map((x) => x.id), ['c']);
      expect(s.goodsTotal, 2000);
      expect(s.balanceDue, 2000);
      expect(s.purchases.length, 1);
      s.archived = false;
      expect(filterSuppliers(list, 'active').map((x) => x.id), ['a', 'c']);
    });
  });
}
