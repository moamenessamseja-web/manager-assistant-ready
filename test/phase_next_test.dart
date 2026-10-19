import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/commitment.dart';
import 'package:manager_assistant/models/supplier.dart';
import 'package:manager_assistant/screens/ask_assistant.dart';
import 'package:manager_assistant/screens/instructions_screen.dart';
import 'package:manager_assistant/services/assistant_controller.dart';
import 'package:manager_assistant/services/chat_history_service.dart';
import 'package:manager_assistant/services/idempotency_service.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    IdempotencyService.resetForTest();
    await StorageService.init();
    await IdempotencyService.init();
  });

  group('IdempotencyService — منع التكرار الدائم', () {
    test('بيسجّل ويرجّع نفس الرد (حتى بعد إعادة تحميل التخزين)', () async {
      await IdempotencyService.remember('k1', '✅ تمام');
      expect(IdempotencyService.lookup('k1'), '✅ تمام');
      IdempotencyService.resetForTest(); // نحاكي إعادة تشغيل التطبيق
      await IdempotencyService.init();
      expect(IdempotencyService.lookup('k1'), '✅ تمام');
      expect(IdempotencyService.lookup('غير-موجود'), isNull);
    });

    test('المفتاح ينتهي بعد ٧ أيام', () async {
      final t = DateTime(2026, 10, 1);
      await IdempotencyService.remember('old', '✅ x', now: t);
      expect(IdempotencyService.lookup('old', now: t.add(const Duration(days: 6))),
          '✅ x');
      expect(IdempotencyService.lookup('old', now: t.add(const Duration(days: 8))),
          isNull);
    });

    test('السجل محدود (بيشيل الأقدم)', () async {
      final base = DateTime(2026, 10, 1);
      for (var i = 0; i < IdempotencyService.maxEntries + 5; i++) {
        await IdempotencyService.remember('k$i', '✅ $i',
            now: base.add(Duration(minutes: i)));
      }
      final at = base.add(const Duration(days: 1));
      expect(IdempotencyService.lookup('k0', now: at), isNull);
      expect(
          IdempotencyService.lookup('k${IdempotencyService.maxEntries + 4}',
              now: at),
          isNotNull);
    });

    test('نفس معرّف الرسالة = نفس الرد من غير تنفيذ تاني', () async {
      await IdempotencyService.remember('msg:m1', '✅ اتسجلت سلفة');
      final r = await AssistantController.handle('أي كلام تاني',
          messageId: 'm1');
      expect(r, '✅ اتسجلت سلفة');
    });
  });

  group('تأكيد استلام توريد متوقع من «اليوم»', () {
    final due = DateTime(2030, 1, 1, 17);

    Future<void> seed() async {
      await StorageService.saveSupplier(Supplier(
        id: 's1',
        name: 'جمال',
        itemType: 'لبن',
        deliveries: [
          Delivery(
              id: 'd1',
              item: 'لبن',
              quantity: 5,
              unit: 'كرتونة',
              expectedDate: due),
        ],
      ));
      await StorageService.saveCommitment(Commitment(
        id: 'c1',
        textOriginal: 'توريد لبن',
        person: 'جمال',
        type: 'supplier',
        amount: 1000,
        dueDate: due,
        remindAt: due,
      ));
    }

    test('يسجّل الاستلام والمشتريات مرة واحدة ويقفل الالتزام', () async {
      await seed();
      final r1 =
          await AssistantController.receiveExpectedDelivery('c1', total: 1000);
      expect(r1, contains('✅'));
      var s = StorageService.suppliers().first;
      expect(s.deliveries.first.received, isTrue);
      expect(s.purchases.length, 1);
      expect(s.goodsTotal, 1000);
      expect(StorageService.commitments().first.status, 'done');

      // ضغطة تانية / إعادة محاولة: نفس الرد، ومفيش مشتريات جديدة.
      final r2 =
          await AssistantController.receiveExpectedDelivery('c1', total: 1000);
      expect(r2, r1);
      s = StorageService.suppliers().first;
      expect(s.purchases.length, 1);
    });

    test('التزام مش موجود أو مش توريد → رفض بدون كتابة', () async {
      await seed();
      expect(await AssistantController.receiveExpectedDelivery('nope'),
          contains('⚠️'));
      await StorageService.saveCommitment(Commitment(
        id: 'c2',
        textOriginal: 'مهمة',
        person: 'عام',
        type: 'task',
        dueDate: due,
        remindAt: due,
      ));
      expect(await AssistantController.receiveExpectedDelivery('c2'),
          contains('مش توريد'));
      expect(StorageService.suppliers().first.purchases, isEmpty);
    });

    test('قيمة صفر أو سالبة مرفوضة', () async {
      await seed();
      final r =
          await AssistantController.receiveExpectedDelivery('c1', total: 0);
      expect(r, contains('أكبر من صفر'));
      expect(StorageService.suppliers().first.deliveries.first.received, isFalse);
    });
  });

  group('واجهات اسأل المساعد والتعليمات', () {
    testWidgets('حقل «اسأل المساعد» يفتح الورقة ويحتفظ بالسؤال', (tester) async {
      await ChatHistoryService.init();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AskAssistantBar()),
      ));
      await tester.enterText(find.byType(TextField), 'حساب المورد جمال');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('اسأل المساعد'), findsWidgets);
      expect(find.text('حساب المورد جمال'), findsWidgets);
    });

    testWidgets('صفحة التعليمات فيها الأقسام المطلوبة', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: InstructionsScreen()));
      expect(find.text('تعليمات الاستخدام'), findsOneWidget);
      expect(find.text('الكميات والوحدات'), findsOneWidget);
      expect(find.text('التذكيرات والالتزامات'), findsOneWidget);
      expect(find.text('إيه اللي بيشتغل من غير إنترنت؟'), findsOneWidget);
    });
  });
}
