import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/customer.dart';
import 'package:manager_assistant/models/shortage.dart';
import 'package:manager_assistant/models/supplier.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// النواقص — قائمة احتياج شراء (مش مخزون ومش مالية).
ShortageItem item(String id, String name, {double? q, String unit = ''}) =>
    ShortageItem(id: id, item: name, quantity: q, unit: unit, createdAt: DateTime(2026, 11, 22, 9));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('دورة حياة النقص', () {
    test('إضافة بكمية ووحدة وملاحظة ومورد، وبتفضل بعد إعادة القراءة', () async {
      await StorageService.saveSupplier(Supplier(id: 's1', name: 'جمال', itemType: 'لبن'));
      final x = item('n1', 'بن', q: 5, unit: 'كيلو')
        ..note = 'من النوع الغامق'
        ..supplierId = 's1'
        ..supplierName = 'جمال';
      await StorageService.saveShortage(x);
      await StorageService.init(); // محاكاة إعادة تشغيل
      final r = StorageService.shortages().single;
      expect(r.item, 'بن');
      expect(r.quantityLabel, '5 كيلو');
      expect(r.note, 'من النوع الغامق');
      expect(r.supplierName, 'جمال');
      expect(r.status, ShortageItem.pending);
      expect(r.isOutstanding, isTrue);
    });

    test('أمثلة الملف: بن ٥ كيلو · لبن ١٢ لتر · سكر ١٠ كيلو · أكواب ٥٠٠ قطعة', () {
      expect(item('1', 'بن', q: 5, unit: 'كيلو').quantityLabel, '5 كيلو');
      expect(item('2', 'لبن', q: 12, unit: 'لتر').quantityLabel, '12 لتر');
      expect(item('3', 'سكر', q: 10, unit: 'كيلو').quantityLabel, '10 كيلو');
      expect(item('4', 'أكواب', q: 500, unit: 'قطعة').quantityLabel, '500 قطعة');
      expect(item('5', 'نعناع', q: 2.5, unit: 'كيلو').quantityLabel, '2.5 كيلو');
      expect(item('6', 'فلتر').quantityLabel, ''); // من غير كمية
    });

    test('مطلوب ← تم الطلب ← تم الشراء، والتاريخ بيتحفظ بالترتيب', () async {
      final x = item('n1', 'سكر', q: 10, unit: 'كيلو');
      await StorageService.saveShortage(x);
      x.setStatus(ShortageItem.ordered, DateTime(2026, 11, 22, 10));
      await StorageService.saveShortage(x);
      x.setStatus(ShortageItem.purchased, DateTime(2026, 11, 22, 15));
      await StorageService.saveShortage(x);
      final r = StorageService.shortages().single;
      expect(r.status, ShortageItem.purchased);
      expect(r.isDone, isTrue);
      expect(r.isOutstanding, isFalse);
      expect(r.completedAt, DateTime(2026, 11, 22, 15));
      expect(r.history.map((e) => e.status).toList(),
          [ShortageItem.pending, ShortageItem.ordered, ShortageItem.purchased]);
    });

    test('إعادة فتح نقص اتشترى: بيرجع مطلوب، ومسح وقت الإكمال، والتاريخ بيفضل', () async {
      final x = item('n1', 'لبن', q: 12, unit: 'لتر')
        ..setStatus(ShortageItem.purchased, DateTime(2026, 11, 22, 12));
      await StorageService.saveShortage(x);
      final y = StorageService.shortages().single
        ..setStatus(ShortageItem.pending, DateTime(2026, 11, 23, 8));
      await StorageService.saveShortage(y);
      final r = StorageService.shortages().single;
      expect(r.isOutstanding, isTrue);
      expect(r.completedAt, isNull);
      expect(r.history.length, 3); // مطلوب، تم الشراء، مطلوب (إعادة فتح)
    });

    test('تعديل الكمية والوحدة ما بيكرّرش السجل ولا بيمسح التاريخ', () async {
      final x = item('n1', 'أكواب', q: 500, unit: 'قطعة');
      await StorageService.saveShortage(x);
      final y = StorageService.shortages().single
        ..quantity = 800
        ..unit = 'كرتونة';
      await StorageService.saveShortage(y);
      expect(StorageService.shortages().length, 1);
      expect(StorageService.shortages().single.quantityLabel, '800 كرتونة');
      expect(StorageService.shortages().single.history.length, 1);
    });

    test('تغيير الحالة لنفس الحالة أو حالة غلط = تجاهل (من غير سجل مكرر)', () {
      final x = item('n1', 'بن');
      x.setStatus(ShortageItem.pending, DateTime(2026, 11, 22));
      x.setStatus('garbage', DateTime(2026, 11, 22));
      expect(x.history.length, 1);
    });

    test('إلغاء الطلب بيخرجه من المطلوب وبيفضل في السجل', () async {
      final x = item('n1', 'فلتر')..setStatus(ShortageItem.cancelled, DateTime(2026, 11, 22, 11));
      await StorageService.saveShortage(x);
      final r = StorageService.shortages().single;
      expect(r.isOutstanding, isFalse);
      expect(r.isDone, isFalse);
      expect(r.status, ShortageItem.cancelled);
    });

    test('المتابعة: المطلوب (مطلوب + تم الطلب) مفصول عن المكتمل', () async {
      await StorageService.saveShortage(item('a', 'بن'));
      await StorageService.saveShortage(item('b', 'سكر')..setStatus(ShortageItem.ordered, DateTime(2026, 11, 22, 10)));
      await StorageService.saveShortage(item('c', 'لبن')..setStatus(ShortageItem.purchased, DateTime(2026, 11, 22, 11)));
      final all = StorageService.shortages();
      expect(all.where((x) => x.isOutstanding).map((x) => x.id).toSet(), {'a', 'b'});
      expect(all.where((x) => !x.isOutstanding).map((x) => x.id).toSet(), {'c'});
    });
  });

  group('مفيش خلط مع المالية أو المخزون', () {
    test('تسجيل/إكمال نقص مبيغيّرش حسابات الموردين ولا العملاء', () async {
      final sup = Supplier(id: 's1', name: 'جمال', itemType: 'لبن')
        ..purchases.add(SupplierPurchase(id: 'p', item: 'لبن', total: 1000, date: DateTime(2026, 11, 20)))
        ..payments.add(SupplierPayment(id: 'y', amount: 400, date: DateTime(2026, 11, 21)));
      final cust = Customer(id: 'c1', name: 'حموده')
        ..addSale(CreditSale(id: 'x', item: '', total: 300, date: DateTime(2026, 11, 20)));
      await StorageService.saveSupplier(sup);
      await StorageService.saveCustomer(cust);
      final x = item('n1', 'لبن', q: 12, unit: 'لتر')
        ..supplierId = 's1'
        ..supplierName = 'جمال';
      await StorageService.saveShortage(x);
      x.setStatus(ShortageItem.ordered, DateTime(2026, 11, 22, 10));
      x.setStatus(ShortageItem.purchased, DateTime(2026, 11, 22, 12));
      await StorageService.saveShortage(x);
      expect(StorageService.suppliers().single.balanceDue, 600);
      expect(StorageService.suppliers().single.deliveries, isEmpty);
      expect(StorageService.suppliers().single.purchases.length, 1);
      expect(totalReceivables(StorageService.customers()), 300);
    });

    test('JSON بيرجع كامل (بما فيه التاريخ والمورد)', () {
      final x = item('n1', 'بن', q: 5, unit: 'كيلو')
        ..supplierId = 's1'
        ..supplierName = 'جمال'
        ..setStatus(ShortageItem.ordered, DateTime(2026, 11, 22, 10), note: 'اتصلت');
      final r = ShortageItem.fromJson(x.toJson());
      expect(r.supplierId, 's1');
      expect(r.history.last.note, 'اتصلت');
      expect(r.status, ShortageItem.ordered);
    });
  });
}
