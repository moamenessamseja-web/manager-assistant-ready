import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/screens/instructions_screen.dart';
import 'package:manager_assistant/models/customer.dart';
import 'package:manager_assistant/models/supplier.dart';
import 'package:manager_assistant/services/assistant_controller.dart';
import 'package:manager_assistant/services/choice_builder.dart';
import 'package:manager_assistant/services/conversation_context_service.dart';
import 'package:manager_assistant/services/idempotency_service.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// العملاء (المستحقات) من الشات — تكامل كامل: فهم → تحقق → حفظ فعلي.
Customer cust(String id, String name) => Customer(id: id, name: name);
Customer byId(String id) => StorageService.customers().firstWhere((c) => c.id == id);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AssistantController.resetGuardForTest();
    IdempotencyService.resetForTest();
    await StorageService.init();
    await IdempotencyService.init();
    await ConversationContextService.init();
    await ConversationContextService.clearPending();
  });

  group('بيع آجل وزيادات', () {
    test('«زود على جمال ٢٠٠ جنيه» يزوّد المستحق ويحفظ فعلًا', () async {
      await StorageService.saveCustomer(cust('c1', 'جمال'));
      final r = await AssistantController.handle('زود على جمال ٢٠٠ جنيه');
      expect(r, contains('✅'));
      expect(byId('c1').balanceDue, 200);
      expect(byId('c1').sales.length, 1);
    });

    test('بتاريخ ماضي: يتسجل بنفس التاريخ مع الوصف', () async {
      await StorageService.saveCustomer(cust('c1', 'حموده'));
      await AssistantController.handle(
          'ضيف على حموده ١٠٠ جنيه طلبات بتاريخ ٢٠ نوفمبر');
      final s = byId('c1').sales.single;
      expect(s.total, 100);
      expect(s.item, 'طلبات');
      expect(s.date.month, 11);
      expect(s.date.day, 20);
      expect(s.date.isAfter(DateTime.now()), isFalse);
    });

    test('تاريخ في المستقبل مرفوض ومفيش كتابة', () async {
      await StorageService.saveCustomer(cust('c1', 'جمال'));
      final r = await AssistantController.handle('زود على جمال ٢٠٠ جنيه بكرة');
      expect(r, contains('لسه ما جاش'));
      expect(byId('c1').sales, isEmpty);
    });

    test('من غير مبلغ: يسأل ومفيش حركة', () async {
      await StorageService.saveCustomer(cust('c1', 'جمال'));
      final r = await AssistantController.handle('زود على جمال');
      expect(r, contains('المبلغ'));
      expect(byId('c1').sales, isEmpty);
      expect(ConversationContextService.pending(), isNotNull);
      final r2 = await AssistantController.handle('٣٠٠');
      expect(r2, contains('✅'));
      expect(byId('c1').balanceDue, 300);
    });
  });

  group('دفعات وتحصيل', () {
    test('دفعة جزئية ثم كاملة — كل واحدة حركة مستقلة', () async {
      final c = cust('c1', 'جمال')
        ..addSale(CreditSale(id: 's', item: 'طلبات', total: 500, date: DateTime.now().subtract(const Duration(days: 2))));
      await StorageService.saveCustomer(c);
      final a = await AssistantController.handle('جمال دفع ٢٠٠ جنيه');
      expect(a, contains('✅'));
      expect(byId('c1').balanceDue, 300);
      final b = await AssistantController.handle('جمال سدد ٣٠٠ من حسابه');
      expect(b, contains('اتسوّى'));
      expect(byId('c1').balanceDue, 0);
      expect(byId('c1').payments.length, 2);
    });

    test('«خصم من دين محمد ٣٠٠» = دفعة عميل (مش خصم موظف)', () async {
      await StorageService.saveCustomer(cust('c1', 'محمد')
        ..addSale(CreditSale(id: 's', item: 'x', total: 1000, date: DateTime.now().subtract(const Duration(days: 1)))));
      await AssistantController.handle('خصم من دين محمد ٣٠٠ جنيه');
      expect(byId('c1').balanceDue, 700);
    });

    test('دفعة أكبر من المتبقي: تأكيد صريح قبل التسجيل', () async {
      await StorageService.saveCustomer(cust('c1', 'جمال')
        ..addSale(CreditSale(id: 's', item: 'x', total: 100, date: DateTime.now().subtract(const Duration(days: 1)))));
      final r = await AssistantController.handle('جمال دفع ٥٠٠ جنيه');
      expect(r, contains('أكبر'));
      expect(byId('c1').payments, isEmpty); // لسه ما اتسجلش
      final ok = await AssistantController.handle('ايوه سجلها');
      expect(ok, contains('✅'));
      expect(byId('c1').balanceDue, -400); // رصيد له
    });

    test('إلغاء تأكيد الزيادة = مفيش كتابة', () async {
      await StorageService.saveCustomer(cust('c1', 'جمال')
        ..addSale(CreditSale(id: 's', item: 'x', total: 100, date: DateTime.now().subtract(const Duration(days: 1)))));
      await AssistantController.handle('جمال دفع ٥٠٠ جنيه');
      await AssistantController.handle('لا');
      expect(byId('c1').payments, isEmpty);
      expect(ConversationContextService.pending(), isNull);
    });
  });

  group('لا تخمين في الهوية', () {
    test('عميل مش موجود: مفيش كتابة وبيقترح الإضافة', () async {
      final r = await AssistantController.handle('جمال دفع ١٠٠ جنيه');
      expect(r, contains('مفيش عميل'));
      expect(StorageService.customers(), isEmpty);
    });

    test('الاسم مورد بس: ما يتسجلش كعميل ويوضّح الفرق', () async {
      await StorageService.saveSupplier(Supplier(id: 's1', name: 'جمال', itemType: 'لبن'));
      final r = await AssistantController.handle('جمال دفع ١٠٠ جنيه');
      expect(r, contains('كمورد'));
      expect(StorageService.customers(), isEmpty);
      expect(StorageService.suppliers().single.payments, isEmpty);
    });

    test('«دفعت لجمال» يفضل دفع لمورد ومايلمسش حساب عميل بنفس الاسم', () async {
      await StorageService.saveSupplier(Supplier(id: 's1', name: 'جمال', itemType: 'لبن'));
      await StorageService.saveCustomer(cust('c1', 'جمال')
        ..addSale(CreditSale(id: 's', item: 'x', total: 100, date: DateTime.now().subtract(const Duration(days: 1)))));
      await AssistantController.handle('دفعت لجمال ٢٠٠ جنيه');
      expect(StorageService.suppliers().single.payments.length, 1);
      expect(byId('c1').payments, isEmpty);
      expect(byId('c1').balanceDue, 100);
    });

    test('اسمين متشابهين: يسأل ويكمّل بالمعرّف الصح فقط', () async {
      await StorageService.saveCustomer(cust('c1', 'محمد علي'));
      await StorageService.saveCustomer(cust('c2', 'محمد حسن')
        ..addSale(CreditSale(id: 's', item: 'x', total: 500, date: DateTime.now().subtract(const Duration(days: 1)))));
      final r = await AssistantController.handle('محمد دفع ١٠٠ جنيه');
      expect(r, contains('أكتر من عميل'));
      expect(byId('c1').payments, isEmpty);
      expect(byId('c2').payments, isEmpty);
      final p = ConversationContextService.pending()!;
      expect(p.options.length, 2);
      final res = await AssistantController.handle('محمد حسن');
      expect(res, contains('✅'));
      expect(byId('c2').balanceDue, 400);
      expect(byId('c1').payments, isEmpty);
    });
  });

  group('تسجيل عميل ورصيد افتتاحي', () {
    test('اتجاه واضح: عليه فلوس', () async {
      final r = await AssistantController.handle('ضيف عميل جديد حموده عليه ٥٠٠');
      expect(r, contains('✅'));
      final c = StorageService.customers().single;
      expect(c.balanceDue, 500);
      expect(c.sales.single.isOpening, isTrue);
    });

    test('اتجاه مش واضح: يسأل بزرارين وبعدين يسجّل', () async {
      final r = await AssistantController.handle('ضيف عميل جمال ٥٠٠');
      expect(r, contains('عليه فلوس'));
      expect(StorageService.customers(), isEmpty); // لسه
      final id = ConversationContextService.pending()!.id;
      final done = await AssistantController.handleChoice(
          id, const ChatChoice('عليه فلوس', 'عليه فلوس'));
      expect(done, contains('✅'));
      expect(StorageService.customers().single.balanceDue, 500);
    });

    test('له فلوس عندنا: رصيد سالب مش مستحق', () async {
      await AssistantController.handle('سجل عميل جمال له ٣٠٠');
      final c = StorageService.customers().single;
      expect(c.balanceDue, -300);
      expect(totalReceivables([c]), 0);
    });

    test('نفس الاسم مرتين: مفيش سجل مكرر', () async {
      await AssistantController.handle('عميل جديد جمال');
      // نتخطّى حارس «نفس الأمر خلال ثواني» عشان نختبر منع التكرار الدائم (الاسم).
      AssistantController.resetGuardForTest();
      final r = await AssistantController.handle('عميل جديد جمال');
      expect(r, contains('مسجّل بالفعل'));
      expect(StorageService.customers().length, 1);
    });
  });

  group('وعد بالدفع ≠ دفعة', () {
    test('بيسجّل التزام مربوط بالعميل ومايغيّرش الرصيد', () async {
      await StorageService.saveCustomer(cust('c1', 'صبحي')
        ..addSale(CreditSale(id: 's', item: 'x', total: 900, date: DateTime.now().subtract(const Duration(days: 1)))));
      await AssistantController.handle('فكرني صبحي هيدفع ٤٠٠ من دينه بكرة الساعة 5 مساء');
      final cs = StorageService.commitments().where((c) => c.type == 'customer_promise').toList();
      expect(cs.length, 1);
      expect(cs.first.customerId, 'c1');
      expect(cs.first.amount, 400);
      expect(byId('c1').balanceDue, 900); // لسه زي ما هو
      expect(byId('c1').payments, isEmpty);
    });

    test('من غير ساعة: يسأل ومايسجّلش حاجة', () async {
      await StorageService.saveCustomer(cust('c1', 'صبحي'));
      final r = await AssistantController.handle('فكرني صبحي هيدفع ٤٠٠ بكرة');
      expect(r, contains('الساعة'));
      expect(StorageService.commitments(), isEmpty);
    });
  });

  group('منع التكرار', () {
    test('نفس معرّف الرسالة مرتين = حركة واحدة (حتى بعد إعادة التشغيل)', () async {
      await StorageService.saveCustomer(cust('c1', 'جمال'));
      await AssistantController.handle('زود على جمال ٢٠٠ جنيه', messageId: 'm1');
      IdempotencyService.resetForTest();
      await IdempotencyService.init();
      await AssistantController.handle('زود على جمال ٢٠٠ جنيه', messageId: 'm1');
      expect(byId('c1').sales.length, 1);
      expect(byId('c1').balanceDue, 200);
    });

    test('تنفيذ متزامن لنفس العميل ما يضيّعش تعديل', () async {
      await StorageService.saveCustomer(cust('c1', 'جمال'));
      await Future.wait([
        StorageService.mutateCustomer('c1', (c) => c.addSale(CreditSale(id: 'a', item: '', total: 10, date: DateTime.now()))),
        StorageService.mutateCustomer('c1', (c) => c.addSale(CreditSale(id: 'b', item: '', total: 20, date: DateTime.now()))),
        StorageService.mutateCustomer('c1', (c) => c.addPayment(CustomerPayment(id: 'p', amount: 5, date: DateTime.now()))),
      ]);
      final c = byId('c1');
      expect(c.sales.length, 2);
      expect(c.payments.length, 1);
      expect(c.balanceDue, 25);
    });
  });

  group('استعلامات', () {
    setUp(() async {
      await StorageService.saveCustomer(cust('c1', 'جمال')
        ..addSale(CreditSale(id: 's1', item: 'طلبات', total: 800, date: DateTime.now().subtract(const Duration(days: 30))))
        ..addPayment(CustomerPayment(id: 'p1', amount: 200, date: DateTime.now().subtract(const Duration(days: 20))))
        ..addPayment(CustomerPayment(id: 'p2', amount: 100, date: DateTime.now())));
      await StorageService.saveCustomer(cust('c2', 'حموده')
        ..addSale(CreditSale(id: 's2', item: 'x', total: 300, date: DateTime.now().subtract(const Duration(days: 5)))));
      await StorageService.saveCustomer(cust('c3', 'مسدّد')
        ..addSale(CreditSale(id: 's3', item: 'x', total: 50, date: DateTime.now().subtract(const Duration(days: 5))))
        ..addPayment(CustomerPayment(id: 'p3', amount: 50, date: DateTime.now().subtract(const Duration(days: 4)))));
    });

    test('«مين عليه فلوس؟» من حسابات العملاء مع الإجمالي', () async {
      final r = await AssistantController.handle('مين عليه فلوس؟');
      expect(r, contains('جمال'));
      expect(r, contains('حموده'));
      expect(r.contains('مسدّد'), isFalse);
      expect(r, contains('800')); // جمال 500 + حموده 300
    });

    test('«حساب جمال كام؟»', () async {
      final r = await AssistantController.handle('حساب جمال كام؟');
      expect(r, contains('500'));
      expect(r, contains('المتبقي'));
    });

    test('«جمال دفع كام الأسبوع ده؟» تستبعد الدفعات القديمة', () async {
      final r = await AssistantController.handle('جمال دفع كام الأسبوع ده؟');
      expect(r, contains('100'));
      expect(r.contains('300'), isFalse);
    });
  });

  testWidgets('شاشة التعليمات فيها قسم العملاء والمستحقات', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InstructionsScreen()));
    expect(find.text('العملاء والمستحقات (البيع الآجل)'), findsOneWidget);
  });
}
