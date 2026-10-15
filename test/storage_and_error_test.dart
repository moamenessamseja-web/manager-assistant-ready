import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manager_assistant/models/employee.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:manager_assistant/services/app_error_service.dart';
import 'package:manager_assistant/services/chat_history_service.dart';
import 'package:manager_assistant/services/settings_service.dart';
import 'package:manager_assistant/screens/settings_screen.dart';
import 'package:manager_assistant/design/strings.dart';

/// اختبارات سلامة التخزين (§6) وطبقة الأخطاء (§8) وسجل المحادثة (§7).
/// كلها تعمل offline بدون أي مفتاح.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await AppErrorService.init();
    await ChatHistoryService.init();
    await SettingsService.init();
  });

  group('التخزين — سلامة البيانات (§6)', () {
    test('حفظ موظف ثم قراءته', () async {
      await StorageService.saveEmployee(Employee(
        id: 'e1',
        name: 'أحمد',
        role: 'سواق',
        startDate: DateTime(2026, 1, 1),
        salaryMonthly: 5000,
      ));
      final all = StorageService.employees();
      expect(all.length, 1);
      expect(all.first.name, 'أحمد');
    });

    test('سجل تالف لا يُسقط القائمة ولا يمسح البيانات الأصلية', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('employees', [
        jsonEncode(Employee(
          id: 'e1',
          name: 'أحمد',
          role: 'سواق',
          startDate: DateTime(2026, 1, 1),
          salaryMonthly: 5000,
        ).toJson()),
        '{ هذا ليس JSON صالح',
      ]);

      final all = StorageService.employees();
      expect(all.length, 1, reason: 'السجل السليم لازم يفضل مقروءًا');
      expect(StorageService.lastCorruptCount, 1);
      // لا مسح تلقائي: السجلان لسه موجودين في التخزين كما هما.
      expect(prefs.getStringList('employees')!.length, 2);
    });

    test('كتابة متزامنة متعددة لا تفقد أي سجل (تسلسل الكتابات)', () async {
      await Future.wait([
        for (var i = 0; i < 12; i++)
          StorageService.saveEmployee(Employee(
            id: 'e$i',
            name: 'موظف $i',
            role: 'عامل',
            startDate: DateTime(2026, 1, 1),
            salaryMonthly: 3000,
          )),
      ]);
      expect(StorageService.employees().length, 12);
    });
  });

  group('طبقة الأخطاء الموحّدة (§8)', () {
    test('فشل الحفظ → رسالة حفظ واضحة (وليست نجاحًا)', () {
      final msg = AppErrorService.userMessage(StorageException('x'));
      expect(msg, contains('لم نتمكن من حفظ العملية'));
      expect(msg, contains('لم يتم تأكيد تسجيلها'));
    });

    test('خطأ شبكة → رسالة الخدمة الإضافية الاختيارية', () {
      final msg = AppErrorService.userMessage(
          Exception('SocketException: failed host lookup'));
      expect(msg, contains('خدمة المساعدة الإضافية'));
    });

    test('خطأ غير متوقع → رسالة عامة بدون تفاصيل تقنية', () {
      final msg = AppErrorService.userMessage(Exception(
          'RangeError: index out of bounds at lib/services/x.dart:42'));
      expect(msg, isNot(contains('RangeError')));
      expect(msg, isNot(contains('.dart')));
    });

    test('السجل لا يحتوي أي مفتاح أو رمز سري', () {
      AppErrorService.log(
          't', 'GET https://x/y?key=AIzaSyABCDEFGHIJKLMNOPQRSTUV');
      final last = AppErrorService.entries().first;
      expect(last.contains('AIzaSy'), isFalse);
      expect(last.contains('[redacted]'), isTrue);
    });
  });

  group('سجل المحادثة (§7)', () {
    test('الرسائل تبقى بعد إعادة القراءة وتحتفظ بنوعها', () async {
      await ChatHistoryService.append(ChatMessage(
        id: 'm1',
        role: ChatRole.user,
        text: 'سجل حضور أحمد',
        time: DateTime(2026, 1, 1, 10),
      ));
      await ChatHistoryService.append(ChatMessage(
        id: 'm2',
        role: ChatRole.assistant,
        text: 'تم تسجيل الحضور',
        time: DateTime(2026, 1, 1, 10, 1),
      ));

      final all = ChatHistoryService.all();
      expect(all.length, 2);
      expect(all.first.text, 'سجل حضور أحمد');
      expect(all.first.role, ChatRole.user);
      expect(all.last.role, ChatRole.assistant);
    });

    test('المسح الصريح يحذف السجل بالكامل', () async {
      await ChatHistoryService.append(ChatMessage(
        id: 'm1',
        role: ChatRole.user,
        text: 'x',
        time: DateTime.now(),
      ));
      await ChatHistoryService.clear();
      expect(ChatHistoryService.all(), isEmpty);
    });

    test('سجل محادثة تالف لا يُسقط التطبيق', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_history_v1', '{ ليس JSON');
      expect(ChatHistoryService.all(), isEmpty);
    });
  });

  group('مفتاح Gemini الاختياري (§8/§9 — مسار مساعد فقط)', () {
    test('فاضي افتراضيًا — المسار المحلي هو الافتراضي دايمًا', () {
      expect(StorageService.apiKey, isEmpty);
    });

    test('حفظ المفتاح ثم قراءته', () async {
      await StorageService.setApiKey('AIzaSyTestKeyOnly1234567890');
      expect(StorageService.apiKey, 'AIzaSyTestKeyOnly1234567890');
    });

    test('مسح المفتاح يرجّعه فاضي', () async {
      await StorageService.setApiKey('AIzaSyTestKeyOnly1234567890');
      expect(StorageService.apiKey, isNotEmpty);
      await StorageService.setApiKey('');
      expect(StorageService.apiKey, isEmpty);
    });

    // حارس انحدار: الإصدار السابق حذف هذا الحقل من الواجهة رغم أن البريف
    // يمنع ذلك صراحةً. لو اتحذف تاني، الاختبار ده يفشل بدل ما نكتشف
    // الاختفاء بالصدفة.
    testWidgets('شاشة الإعدادات لازم تعرض حقل مفتاح Gemini وتحفظه فعليًا',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      final field = find.byType(TextField);
      expect(field, findsOneWidget,
          reason: 'لازم يكون فيه حقل نصي واحد لمفتاح Gemini في الإعدادات');

      await tester.enterText(field, 'AIzaSyWidgetTestKey000000000');
      final saveButton = find.widgetWithText(ElevatedButton, L.t('save_key'));
      // الشاشة ListView طويلة وزرار الحفظ ممكن يكون تحت حدود الفيوبورت
      // الافتراضي للاختبار — نمرّر له الشاشة فعليًا قبل الضغط عليه.
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(StorageService.apiKey, 'AIzaSyWidgetTestKey000000000');
    });
  });
}
