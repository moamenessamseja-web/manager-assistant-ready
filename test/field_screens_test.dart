import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/design/strings.dart';
import 'package:manager_assistant/models/audit_entry.dart';
import 'package:manager_assistant/models/shortage.dart';
import 'package:manager_assistant/screens/audit_log_screen.dart';
import 'package:manager_assistant/screens/backup_screen.dart';
import 'package:manager_assistant/screens/brief_screen.dart';
import 'package:manager_assistant/screens/cafe_logo_image.dart';
import 'package:manager_assistant/screens/memory_screen.dart';
import 'package:manager_assistant/screens/settings_screen.dart';
import 'package:manager_assistant/screens/shifts_screen.dart';
import 'package:manager_assistant/screens/shortages_screen.dart';
import 'package:manager_assistant/services/cafe_profile_service.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// شاشات الميدان (نواقص / شيفتات / تصحيحات / نسخ احتياطي / هوية الكافيه) —
/// RTL وعلى شاشة ضيقة (٣٦٠ عرض) عشان أي overflow يفشّل الاختبار.
Future<void> pumpRtl(WidgetTester t, Widget home) async {
  t.view.physicalSize = const Size(720, 1480); // ٣٦٠×٧٤٠ منطقيًا
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: home,
  ));
  await t.pump();
}

// Fixed-duration pumps avoid hanging on platform/indeterminate tickers in CI.
Future<void> pumpTransitions(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await pumpTransitions(tester);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await CafeProfileService.init();
  });

  group('النواقص — واجهة', () {
    testWidgets('حالة فارغة، ثم إضافة نقص بكمية ووحدة ويتحفظ', (tester) async {
      await pumpRtl(tester, const ShortagesScreen());
      expect(find.text('مفيش نواقص دلوقتي'), findsOneWidget);
      await tester.tap(find.text('إضافة نقص'));
      await pumpTransitions(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'بن');
      await tester.enterText(fields.at(1), '5');
      await tester.tap(find.widgetWithText(ActionChip, 'كيلو'));
      await tester.pump();
      await tapVisible(tester, find.text('حفظ'));
      expect(find.text('بن — 5 كيلو'), findsOneWidget);
      expect(StorageService.shortages().single.quantityLabel, '5 كيلو');
      expect(tester.takeException(), isNull);
    });

    testWidgets('إكمال ← ظهور في السجل ← إعادة فتح', (tester) async {
      await tester.runAsync(() => StorageService.saveShortage(
          ShortageItem(id: 'n1', item: 'سكر', quantity: 10, unit: 'كيلو', createdAt: DateTime(2026, 11, 22))));
      await pumpRtl(tester, const ShortagesScreen());
      expect(find.text('سكر — 10 كيلو'), findsOneWidget);
      // Verify persisted status transitions and the screen's outstanding/history filters.
      await tester.runAsync(() async {
        final x = StorageService.shortages().single;
        x.setStatus(ShortageItem.purchased, DateTime(2026, 11, 23));
        await StorageService.saveShortage(x);
      });
      await pumpTransitions(tester);
      expect(find.text('سكر — 10 كيلو'), findsNothing);
      expect(StorageService.shortages().single.isDone, isTrue);
      await tester.tap(find.textContaining('تم / ملغي'));
      await pumpTransitions(tester);
      expect(find.text('سكر — 10 كيلو'), findsOneWidget);
      await tester.runAsync(() async {
        final x = StorageService.shortages().single;
        x.setStatus(ShortageItem.pending, DateTime(2026, 11, 23, 1));
        await StorageService.saveShortage(x);
      });
      await pumpTransitions(tester);
      expect(StorageService.shortages().single.isOutstanding, isTrue);
      expect(StorageService.shortages().single.history.length, 3);
    });

    testWidgets('تعديل الكمية', (tester) async {
      await tester.runAsync(() => StorageService.saveShortage(
          ShortageItem(id: 'n1', item: 'لبن', quantity: 12, unit: 'لتر', createdAt: DateTime(2026, 11, 22))));
      await pumpRtl(tester, const ShortagesScreen());
      await tester.tap(find.byIcon(Icons.more_vert));
      await pumpTransitions(tester);
      await tester.tap(find.text('تعديل'));
      await pumpTransitions(tester);
      await tester.enterText(find.byType(TextField).at(1), '20');
      await tapVisible(tester, find.text('حفظ'));
      expect(StorageService.shortages().single.quantityLabel, '20 لتر');
      expect(StorageService.shortages().length, 1);
    });

    testWidgets('اسم صنف طويل جدًا على شاشة ضيقة: مفيش overflow', (tester) async {
      await tester.runAsync(() => StorageService.saveShortage(ShortageItem(
          id: 'n1',
          item: 'كابتشينو بنكهة الفانيليا والكراميل المملّح مع رشة قرفة وجوز هند مبشور ' * 2,
          quantity: 1234567,
          unit: 'كرتونة كبيرة',
          note: 'ملاحظة طويلة جدًا ' * 8,
          supplierName: 'مورد باسم طويل جدًا جدًا جدًا جدًا',
          createdAt: DateTime(2026, 11, 22))));
      await pumpRtl(tester, const ShortagesScreen());
      expect(tester.takeException(), isNull);
    });
  });

  group('الشيفتات والإقفال — واجهة', () {
    testWidgets('ابدأ شيفت ← مبيعات كاش ← إقفال بالمعدود ← إقفال اليوم', (tester) async {
      await pumpRtl(tester, const ShiftsScreen());
      expect(find.text('مفيش شيفت مفتوح'), findsOneWidget);
      await tester.tap(find.text('ابدأ شيفت'));
      await pumpTransitions(tester);
      await tester.enterText(find.byType(TextField).at(1), '100');
      await tapVisible(tester, find.text('ابدأ'));
      expect(find.text('شيفت مفتوح: صباحي'), findsOneWidget);
      expect(StorageService.shifts().single.openingCash, 100);

      await tester.tap(find.text('مبيعات الكاش'));
      await pumpTransitions(tester);
      await tester.enterText(find.byType(TextField).first, '500');
      await tapVisible(tester, find.text('حفظ'));
      expect(StorageService.shifts().single.cashSales, 500);

      await tester.tap(find.text('إقفال الشيفت'));
      await pumpTransitions(tester);
      await tester.enterText(find.byType(TextField).first, '600');
      await tapVisible(tester, find.text('اقفل الشيفت'));
      final s = StorageService.shifts().single;
      expect(s.isClosed, isTrue);
      expect(s.snapshot!.cashSales, 500);
      expect(s.variance(s.snapshot!), 0); // 100 + 500 = 600 معدود

      expect(find.text('إقفال اليوم (اختياري)'), findsOneWidget);
      await tester.tap(find.text('إقفال اليوم (اختياري)'));
      await pumpTransitions(tester);
      expect(StorageService.dailyClosings().single.totals.cashSales, 500);
      expect(StorageService.shifts().single.isClosed, isTrue); // الشيفت الأصلي لسه موجود
      await tapVisible(tester, find.text('عرض الإقفال اليومي'));
      expect(find.text('الشيفتات (1)'), findsOneWidget);
      await tester.tap(find.text('صباحي').last);
      await pumpTransitions(tester);
      expect(find.text('مبيعات كاش'), findsOneWidget); // تفصيل الوردية داخل تقرير اليوم
      expect(tester.takeException(), isNull);
    });

    testWidgets('ماينفعش فتح شيفتين: الزرار بيختفي والشيفت المفتوح بيظهر', (tester) async {
      await pumpRtl(tester, const ShiftsScreen());
      await tester.tap(find.text('ابدأ شيفت'));
      await pumpTransitions(tester);
      await tester.tap(find.text('ابدأ'));
      await pumpTransitions(tester);
      expect(find.text('ابدأ شيفت'), findsNothing);
      expect(find.textContaining('شيفت مفتوح:'), findsOneWidget);
    });
  });

  group('سجل التصحيحات والنسخ الاحتياطي — واجهة', () {
    testWidgets('سجل التصحيحات: حالة فارغة ثم عرض الحركة بسببها', (tester) async {
      await pumpRtl(tester, const AuditLogScreen());
      expect(find.text('مفيش تصحيحات'), findsOneWidget);
      await tester.runAsync(() => StorageService.addAudit(AuditEntry(
          id: 'a1', at: DateTime(2026, 11, 22, 10), action: 'void', ownerType: 'employee', ownerId: 'e1',
          ownerName: 'أحمد', recordType: 'advance', recordId: 'x', summary: 'سلفة 100 ج', amount: 100,
          reason: 'غلطة في الرقم', original: {'id': 'x'})));
      await tester.pump();
      expect(find.textContaining('غلطة في الرقم'), findsOneWidget);
      expect(find.textContaining('أحمد'), findsOneWidget);
    });

    testWidgets('شاشة النسخ الاحتياطي: تحذير لو مفيش نسخة، وأزرار التصدير والاسترجاع', (tester) async {
      await pumpRtl(tester, const BackupScreen());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('لسه ما عملتش نسخة'), findsOneWidget);
      expect(find.text('تصدير نسخة احتياطية ومشاركتها'), findsOneWidget);
      expect(find.text('استرجاع من نسخة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('هوية الكافيه — واجهة', () {
    testWidgets('حفظ الاسم من الإعدادات بيتطبّق ويفضل بعد إعادة التحميل', (tester) async {
      await pumpRtl(tester, const SettingsScreen());
      await tester.enterText(find.widgetWithText(TextField, 'اسم الكافيه'), 'كافيه النيل');
      await tester.tap(find.text('حفظ الاسم'));
      await pumpTransitions(tester);
      expect(CafeProfileService.displayName, 'كافيه النيل');
      await tester.runAsync(() => CafeProfileService.init());
      expect(CafeProfileService.displayName, 'كافيه النيل');
      expect(tester.takeException(), isNull);
    });

    testWidgets('اسم الكافيه طويل: بيتقصّ بنقط من غير overflow', (tester) async {
      await tester.runAsync(() => CafeProfileService.setName('كافيه ' * 20));
      await pumpRtl(
          tester,
          const Scaffold(
              body: Row(children: [
            Icon(Icons.coffee),
            Flexible(child: CafeNameText(maxLines: 2)),
          ])));
      expect(tester.takeException(), isNull);
    });

    testWidgets('شعار مفقود: الأيقونة العامة بتظهر بدل الصورة', (tester) async {
      await tester.runAsync(() => CafeProfileService.setLogoPath('${Directory.systemTemp.path}/nope_logo.jpg'));
      await pumpRtl(
          tester,
          const Scaffold(
              body: SizedBox(
                  width: 48,
                  height: 48,
                  child: CafeLogoImage(fallback: Icons.storefront_outlined, size: 30))));
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('المصطلحات: الدفتر وتقرير الأسبوع', () {
    test('نصوص القائمة', () {
      expect(L.t('nav_memory'), 'الدفتر');
      expect(L.t('sec_brief'), 'تقرير الأسبوع');
    });

    testWidgets('شاشة الدفتر وشاشة تقرير الأسبوع بعناوينهم الجديدة (من غير فقدان وظيفة)', (tester) async {
      await pumpRtl(tester, const MemoryScreen());
      expect(find.text('الدفتر'), findsOneWidget);
      expect(find.text('الذاكرة'), findsNothing);
      expect(find.text('تذكيرات'), findsOneWidget); // كروت الدفتر لسه شغالة
      await pumpRtl(tester, const BriefScreen());
      expect(find.text('تقرير الأسبوع'), findsOneWidget);
      expect(find.text('بريف الأسبوع'), findsNothing);
      expect(find.text('الوضع المالي'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('حركة الكاش من الإقفالات (هذا الأسبوع)'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('حركة الكاش من الإقفالات (هذا الأسبوع)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
