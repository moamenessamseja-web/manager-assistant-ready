import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/commitment.dart';
import 'package:manager_assistant/screens/memory_lists.dart';
import 'package:manager_assistant/screens/memory_screen.dart';
import 'package:manager_assistant/services/notification_prefs.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotificationPrefs — الإعدادات بتتحفظ وبتأثر فعلًا', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPrefs.init();
    });

    test('الافتراضي: كل الأقسام مفعّلة والتنبيه في الموعد', () {
      expect(NotificationPrefs.allows('reminders'), isTrue);
      expect(NotificationPrefs.allows('suppliers'), isTrue);
      expect(NotificationPrefs.allows('rules'), isTrue);
      expect(NotificationPrefs.leadMinutes, 0);
    });

    test('إيقاف قسم يتحفظ ويرجع بعد إعادة التحميل', () async {
      await NotificationPrefs.setCategory('suppliers', false);
      expect(NotificationPrefs.allows('suppliers'), isFalse);
      NotificationPrefs.suppliers = true; // نحاكي إعادة تشغيل التطبيق
      await NotificationPrefs.init();
      expect(NotificationPrefs.allows('suppliers'), isFalse);
      expect(NotificationPrefs.allows('rules'), isTrue);
    });

    test('التنبيه المبكر يقدّم الموعد، ولا يفوّت موعدًا قريبًا', () async {
      final now = DateTime(2026, 10, 20, 8, 0);
      await NotificationPrefs.setLeadMinutes(30);
      expect(NotificationPrefs.effectiveTime(DateTime(2026, 10, 20, 10, 0), now: now),
          DateTime(2026, 10, 20, 9, 30));
      // موعد بعد ١٠ دقايق والتنبيه المبكر ٣٠ → هيبقى في الماضي، فنبقى على الموعد.
      final soon = DateTime(2026, 10, 20, 8, 10);
      expect(NotificationPrefs.effectiveTime(soon, now: now), soon);
      await NotificationPrefs.setLeadMinutes(0);
    });

    test('قيمة تنبيه غير مسموحة ترجع للصفر', () async {
      await NotificationPrefs.setLeadMinutes(17);
      expect(NotificationPrefs.leadMinutes, 0);
    });
  });

  group('كروت الذاكرة — التنقل (Phase C)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    testWidgets('كارت «تذكيرات» يفتح قائمة التذكيرات وترجع الرجوع، بدون تعديل بيانات',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MemoryScreen()));
      await tester.pump();
      await tester.tap(find.text('تذكيرات'));
      await tester.pumpAndSettle();
      expect(find.byType(RemindersListScreen), findsOneWidget);
      expect(find.text('لا توجد تذكيرات بعد'), findsOneWidget); // حالة فارغة
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MemoryScreen), findsOneWidget);
      expect(StorageService.reminders(), isEmpty);
    });

    testWidgets('كارت «التزامات» يفتح قائمة الالتزامات ويحافظ على السجلات',
        (tester) async {
      // داخل testWidgets لازم الكتابة في التخزين تتم في المنطقة الحقيقية (runAsync)
      // وإلا الاستمرارات تفضل معلّقة في FakeAsync بلا pump.
      await tester.runAsync(() => StorageService.saveCommitment(Commitment(
            id: 'c1',
            textOriginal: 'توريد لبن',
            person: 'جمال',
            type: 'supplier',
            dueDate: DateTime(2030, 1, 1, 17),
            remindAt: DateTime(2030, 1, 1, 17),
          )));
      await tester.pumpWidget(const MaterialApp(home: MemoryScreen()));
      await tester.pump();
      await tester.tap(find.text('التزامات'));
      await tester.pumpAndSettle();
      expect(find.byType(CommitmentsListScreen), findsOneWidget);
      expect(find.text('جمال'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(StorageService.commitments().length, 1);
      expect(StorageService.commitments().first.status, 'pending');
    });
  });
}
