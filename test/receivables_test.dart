import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/customer.dart';
import 'package:manager_assistant/screens/receivables_screen.dart';
import 'package:manager_assistant/screens/customer_details_screen.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CreditSale sale(String id, double total, {DateTime? d}) => CreditSale(
    id: id, item: 'بن', quantity: 2, unit: 'كيلو', total: total, date: d ?? DateTime(2026, 10, 1));
CustomerPayment pay(String id, double a, {DateTime? d}) =>
    CustomerPayment(id: id, amount: a, date: d ?? DateTime(2026, 10, 2));

/// داخل testWidgets الكتابة اللي بتبدأ من الواجهة بتحتاج حلقة أحداث حقيقية
/// (runAsync) + pump بالتناوب، وإلا فضلت معلّقة وسمّمت الاختبارات اللي بعدها.
Future<void> settleStorage(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump();
  }
  await t.pumpAndSettle();
}

void main() {
  group('Customer — حسابات المستحقات', () {
    test('الرصيد = المبيعات − المدفوع', () {
      final c = Customer(id: 'a', name: 'أحمد');
      expect(c.addSale(sale('s1', 500)), isTrue);
      expect(c.addSale(sale('s2', 300)), isTrue);
      expect(c.addPayment(pay('p1', 200)), isTrue);
      expect(c.totalSales, 800);
      expect(c.totalPaid, 200);
      expect(c.balanceDue, 600);
      expect(c.owes, isTrue);
    });

    test('نفس id مرتين = تجاهل (الحفظ المزدوج ما بيكرّرش)', () {
      final c = Customer(id: 'a', name: 'أحمد');
      expect(c.addSale(sale('s1', 500)), isTrue);
      expect(c.addSale(sale('s1', 500)), isFalse);
      expect(c.addPayment(pay('p1', 100)), isTrue);
      expect(c.addPayment(pay('p1', 100)), isFalse);
      expect(c.balanceDue, 400);
    });

    test('مبلغ صفر أو سالب مرفوض', () {
      final c = Customer(id: 'a', name: 'أحمد');
      expect(c.addSale(sale('s0', 0)), isFalse);
      expect(c.addPayment(pay('p0', -5)), isFalse);
      expect(c.hasHistory, isFalse);
    });

    test('دفع زيادة = رصيد لصالح العميل (مش مستحق لنا)', () {
      final c = Customer(id: 'a', name: 'أحمد')
        ..addSale(sale('s1', 100))
        ..addPayment(pay('p1', 150));
      expect(c.balanceDue, -50);
      expect(c.owes, isFalse);
    });

    test('toJson/fromJson يحافظوا على كل السجل', () {
      final c = Customer(id: 'a', name: 'أحمد', phone: '010')
        ..addSale(sale('s1', 500))
        ..addPayment(pay('p1', 200));
      final r = Customer.fromJson(c.toJson());
      expect(r.name, 'أحمد');
      expect(r.phone, '010');
      expect(r.balanceDue, 300);
      expect(r.sales.single.item, 'بن');
      expect(r.sales.single.quantity, 2);
    });

    test('إجمالي المستحقات = أرصدة المدينين فقط (بما فيهم المؤرشف لو عليه فلوس)', () {
      final a = Customer(id: 'a', name: 'أ')..addSale(sale('s1', 500));
      final b = Customer(id: 'b', name: 'ب')
        ..addSale(sale('s2', 100))
        ..addPayment(pay('p', 100)); // مسدّد
      final c = Customer(id: 'c', name: 'ج')
        ..addSale(sale('s3', 50))
        ..addPayment(pay('p2', 80)); // رصيد له — مش بيتخصم من مستحقاتنا
      final d = Customer(id: 'd', name: 'د', archived: true)
        ..addSale(sale('s4', 200));
      expect(totalReceivables([a, b, c, d]), 700);
    });

    test('الفلتر: النشطون افتراضيًا، وقيمة غريبة = نشطون', () {
      final all = [
        Customer(id: 'a', name: 'أ'),
        Customer(id: 'b', name: 'ب', archived: true),
      ];
      expect(filterCustomers(all, 'active').map((c) => c.id), ['a']);
      expect(filterCustomers(all, 'archived').map((c) => c.id), ['b']);
      expect(filterCustomers(all, 'all').length, 2);
      expect(filterCustomers(all, '???').map((c) => c.id), ['a']);
    });
  });

  group('تخزين العملاء', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    test('حفظ وقراءة، وتعديل نفس العميل مش بيكرّره', () async {
      final c = Customer(id: 'a', name: 'أحمد')..addSale(sale('s1', 500));
      await StorageService.saveCustomer(c);
      c.addPayment(pay('p1', 100));
      await StorageService.saveCustomer(c);
      final list = StorageService.customers();
      expect(list.length, 1);
      expect(list.single.balanceDue, 400);
    });

    test('البحث بالاسم يستبعد المؤرشف إلا لو طُلب صراحةً', () async {
      await StorageService.saveCustomer(Customer(id: 'a', name: 'أحمد'));
      await StorageService.saveCustomer(
          Customer(id: 'b', name: 'خالد', archived: true));
      expect(StorageService.customersMatching('خالد'), isEmpty);
      expect(
          StorageService.customersMatching('خالد', includeArchived: true).length,
          1);
      expect(StorageService.customersMatching('أحمد').length, 1);
    });
  });

  group('واجهة المستحقات', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    testWidgets('حالة فاضية + إضافة عميل + ظهوره في القائمة', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ReceivablesScreen()));
      await tester.pump();
      expect(find.text('لا يوجد عملاء بعد'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'اسم العميل'), 'سالم');
      await tester.enterText(
          find.widgetWithText(TextField, 'رصيد سابق عليه (اختياري)'), '٣٠٠');
      await tester.tap(find.text('حفظ'));
      await settleStorage(tester);
      final saved = StorageService.customers();
      expect(saved.length, 1);
      expect(saved.single.name, 'سالم');
      expect(saved.single.balanceDue, 300); // الأرقام العربية اتفهمت
      expect(find.text('سالم'), findsOneWidget);
    });

    testWidgets('اسم مكرر مرفوض، واسم فاضي مرفوض', (tester) async {
      await tester.runAsync(() =>
          StorageService.saveCustomer(Customer(id: 'a', name: 'سالم')));
      await tester.pumpWidget(const MaterialApp(home: ReceivablesScreen()));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      expect(find.text('اكتب اسم العميل.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'اسم العميل'), 'سالم');
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      expect(find.text('فيه عميل بنفس الاسم بالفعل.'), findsOneWidget);
      expect(StorageService.customers().length, 1);
    });

    testWidgets('تسجيل دفعة من شاشة العميل يحدّث الرصيد', (tester) async {
      final c = Customer(id: 'a', name: 'سالم')..addSale(sale('s1', 500));
      await tester.runAsync(() => StorageService.saveCustomer(c));
      await tester.pumpWidget(
          const MaterialApp(home: CustomerDetailsScreen(customerId: 'a')));
      await tester.pump();
      await tester.tap(find.text('تسجيل دفعة'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'المبلغ المدفوع (جنيه)'), '200');
      await tester.tap(find.text('حفظ'));
      await settleStorage(tester);
      expect(StorageService.customers().single.balanceDue, 300);
      expect(StorageService.customers().single.payments.length, 1);
    });

    testWidgets('عميل عليه فلوس ما ينفعش يتأرشف', (tester) async {
      final c = Customer(id: 'a', name: 'سالم')..addSale(sale('s1', 500));
      await tester.runAsync(() => StorageService.saveCustomer(c));
      await tester.pumpWidget(
          const MaterialApp(home: CustomerDetailsScreen(customerId: 'a')));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.archive_outlined));
      await tester.pump();
      expect(find.textContaining('سدّد الحساب'), findsOneWidget);
      expect(StorageService.customers().single.archived, isFalse);
    });
  });
}
