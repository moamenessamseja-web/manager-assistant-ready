import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/rule.dart';
import 'package:manager_assistant/screens/reminder_editor.dart';
import 'package:manager_assistant/screens/rules_screen.dart';
import 'package:manager_assistant/services/notification_prefs.dart';
import 'package:manager_assistant/services/notification_service.dart';
import 'package:manager_assistant/services/recurrence.dart';
import 'package:manager_assistant/services/reminder_manager.dart';
import 'package:manager_assistant/services/reminder_service.dart';
import 'package:manager_assistant/services/rules_service.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بديل لأندرويد: بيسجّل اللي اتجدول واللي اتلغى بدل ما يكلّم الإضافة الحقيقية.
class FakeBackend implements NotificationBackend {
  bool perm = true;
  bool exact = true;
  bool exactThrows = false;
  final scheduled = <({int id, String title, DateTime when, bool exact})>[];
  final cancelled = <int>[];

  @override
  Future<bool> permissionGranted() async => perm;
  @override
  Future<bool> canScheduleExact() async => exact;
  @override
  Future<bool> requestExact() async => true;
  @override
  Future<void> schedule(int id, String title, String body, DateTime when,
      {required bool exact}) async {
    if (exact && exactThrows) throw Exception('exact_alarms_not_permitted');
    scheduled.add((id: id, title: title, when: when, exact: exact));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump();
  }
  await t.pumpAndSettle();
}

void main() {
  late FakeBackend fake;
  final realBackend = NotificationService.backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await NotificationPrefs.init();
    fake = FakeBackend();
    NotificationService.backend = fake;
  });
  tearDown(() => NotificationService.backend = realBackend);

  group('Recurrence — حسابات نقية', () {
    test('١٢ ص = 0 و١٢ م = 12 وتحويل 12⇄24', () {
      expect(Recurrence.hour24(12, false), 0);
      expect(Recurrence.hour24(12, true), 12);
      expect(Recurrence.hour24(5, true), 17);
      expect(Recurrence.hour24(9, false), 9);
      expect(Recurrence.to12(0), (hour12: 12, pm: false));
      expect(Recurrence.to12(17), (hour12: 5, pm: true));
      expect(Recurrence.to12(12), (hour12: 12, pm: true));
    });

    test('أول موعد: يومي/أسبوعي/شهري (بعد الآن دائمًا وبنفس الساعة)', () {
      final now = DateTime(2026, 10, 20, 10, 0); // الثلاثاء
      expect(
          Recurrence.firstOccurrence(
              frequency: 'daily', anchor: 1, hour: 9, minute: 30, now: now),
          DateTime(2026, 10, 21, 9, 30));
      expect(
          Recurrence.firstOccurrence(
              frequency: 'daily', anchor: 1, hour: 18, minute: 0, now: now),
          DateTime(2026, 10, 20, 18, 0));
      // أسبوعي: الخميس (٤) → 22 أكتوبر
      expect(
          Recurrence.firstOccurrence(
              frequency: 'weekly', anchor: 4, hour: 8, minute: 0, now: now),
          DateTime(2026, 10, 22, 8, 0));
      // أسبوعي: نفس يوم الثلاثاء بس الساعة فاتت → الأسبوع الجاي
      expect(
          Recurrence.firstOccurrence(
              frequency: 'weekly', anchor: 2, hour: 8, minute: 0, now: now),
          DateTime(2026, 10, 27, 8, 0));
      // شهري: يوم ٥ فات → الشهر الجاي
      expect(
          Recurrence.firstOccurrence(
              frequency: 'monthly', anchor: 5, hour: 9, minute: 15, now: now),
          DateTime(2026, 11, 5, 9, 15));
    });

    test('شهري: يوم ٣١ بيتقصّ لآخر الشهر ويحافظ على الساعة', () {
      final next = Recurrence.advance(DateTime(2026, 1, 31, 14, 45), 'monthly', 31);
      expect(next, DateTime(2026, 2, 28, 14, 45));
      expect(Recurrence.advance(next, 'monthly', 31), DateTime(2026, 3, 31, 14, 45));
    });

    test('المواعيد القادمة: عددها حسب التكرار وكلها بعد الآن', () {
      final now = DateTime(2026, 10, 20, 10, 0);
      final d = Recurrence.upcoming(DateTime(2026, 10, 1, 9, 0), 'daily', 1, now: now);
      expect(d.length, 30);
      expect(d.every((t) => t.isAfter(now)), isTrue);
      expect(d.first, DateTime(2026, 10, 21, 9, 0));
      expect(Recurrence.upcoming(now.add(const Duration(days: 1)), 'weekly', 2,
              now: now).length, 26);
      expect(Recurrence.upcoming(now.add(const Duration(days: 1)), 'monthly', 5,
              now: now).length, 12);
      expect(Recurrence.upcoming(now.subtract(const Duration(hours: 1)), 'none', 1,
              now: now), isEmpty);
    });
  });

  group('NotificationService — الجدولة الفعلية', () {
    test('بيجدول المستقبلي فقط، ومنبه دقيق لو مسموح', () async {
      final now = DateTime.now();
      final r = await NotificationService.scheduleSeries(7, 't', 'b', [
        now.subtract(const Duration(hours: 1)),
        now.add(const Duration(hours: 1)),
        now.add(const Duration(days: 1)),
      ]);
      expect(r.success, isTrue);
      expect(r.message, isNull);
      expect(fake.scheduled.length, 2);
      expect(fake.scheduled.every((s) => s.exact), isTrue);
      expect(fake.scheduled.map((s) => s.id).toSet().length, 2); // ids مختلفة
    });

    test('من غير صلاحية المنبه الدقيق → تقريبي ومعلَّم inexact', () async {
      fake.exact = false;
      final r = await NotificationService.scheduleSeries(
          7, 't', 'b', [DateTime.now().add(const Duration(hours: 1))]);
      expect(r.success, isTrue);
      expect(r.message, 'inexact');
      expect(fake.scheduled.single.exact, isFalse);
    });

    test('الدقيق بيفشل فجأة → بيرجع لتقريبي بدل ما يضيع التذكير', () async {
      fake.exactThrows = true;
      final r = await NotificationService.scheduleSeries(
          7, 't', 'b', [DateTime.now().add(const Duration(hours: 1))]);
      expect(r.success, isTrue);
      expect(r.message, 'inexact');
      expect(fake.scheduled.length, 1);
    });

    test('من غير صلاحية الإشعارات → permission_required وصادق', () async {
      fake.perm = false;
      final r = await NotificationService.scheduleSeries(
          7, 't', 'b', [DateTime.now().add(const Duration(hours: 1))]);
      expect(r.success, isFalse);
      expect(r.status, 'permission_required');
      expect(fake.scheduled, isEmpty);
    });

    test('الإلغاء بيشيل الإشعار الأساسي وكل السلسلة', () async {
      await NotificationService.cancel('abc');
      expect(fake.cancelled.length, 60);
      expect(fake.cancelled.first, 'abc'.hashCode);
    });
  });

  group('ReminderManager — تذكير لمرة واحدة بيتحفظ فعلًا', () {
    final when = DateTime.now().add(const Duration(days: 2));

    test('بيتحفظ كالتزام + تذكير مجدول، وبيفضل بعد إعادة التشغيل', () async {
      final out = await ReminderManager.createOneOff(
          text: 'دفع الإيجار', amount: 8000, when: when);
      expect(out, isNotNull);
      expect(out!.status, 'scheduled');
      expect(fake.scheduled.single.when, when);

      // نحاكي إغلاق التطبيق وفتحه: إعادة تحميل التخزين من الـ prefs.
      await StorageService.init();
      final c = StorageService.commitments().single;
      expect(c.type, 'task');
      expect(c.textOriginal, 'دفع الإيجار');
      expect(c.amount, 8000);
      expect(c.remindAt, when);
      final rems = StorageService.remindersForEntity(c.id);
      expect(rems.single.status, 'scheduled');
      expect(rems.single.dueAt, when);
    });

    test('نفس الـ id مرتين (ضغطتين) = تذكير واحد', () async {
      await ReminderManager.createOneOff(text: 'أ', when: when, id: 'x1');
      final again =
          await ReminderManager.createOneOff(text: 'أ', when: when, id: 'x1');
      expect(again, isNull);
      expect(StorageService.commitments().length, 1);
      expect(StorageService.reminders().length, 1);
    });

    test('التعديل بيحدّث الموعد ويلغي القديم ويجدول الجديد', () async {
      await ReminderManager.createOneOff(text: 'أ', when: when);
      final c = StorageService.commitments().single;
      fake.cancelled.clear();
      fake.scheduled.clear();
      final newWhen = when.add(const Duration(hours: 5));
      await ReminderManager.updateOneOff(c, text: 'ب', when: newWhen);
      expect(fake.cancelled, isNotEmpty);
      expect(fake.scheduled.single.when, newWhen);
      final saved = StorageService.commitments().single;
      expect(saved.textOriginal, 'ب');
      expect(saved.remindAt, newWhen);
      expect(StorageService.reminders().length, 1);
      expect(StorageService.reminders().single.dueAt, newWhen);
    });

    test('الحذف بيشيل الالتزام والتذكير ويلغي الإشعار', () async {
      await ReminderManager.createOneOff(text: 'أ', when: when);
      final c = StorageService.commitments().single;
      fake.cancelled.clear();
      await ReminderManager.deleteOneOff(c);
      expect(StorageService.commitments(), isEmpty);
      expect(StorageService.reminders(), isEmpty);
      expect(fake.cancelled, isNotEmpty);
    });

    test('التحقق: نص فاضي أو موعد فات مرفوض', () {
      final now = DateTime(2026, 10, 20, 10);
      expect(ReminderManager.validateOneOff('', now.add(const Duration(hours: 1)), now: now),
          contains('اكتب'));
      expect(ReminderManager.validateOneOff('س', now.subtract(const Duration(minutes: 1)), now: now),
          contains('فات'));
      expect(ReminderManager.validateOneOff('س', now.add(const Duration(minutes: 1)), now: now),
          isNull);
    });

    test('من غير صلاحية الإشعارات: السجل يتحفظ والحالة صادقة', () async {
      fake.perm = false;
      final out = await ReminderManager.createOneOff(text: 'أ', when: when);
      expect(out!.status, 'permission_required');
      expect(StorageService.commitments().length, 1);
      expect(StorageService.reminders().single.status, 'permission_required');
    });

    test('بعد منح الصلاحية، إعادة الجدولة عند فتح التطبيق بتصلّحها', () async {
      fake.perm = false;
      await ReminderManager.createOneOff(text: 'أ', when: when);
      fake.perm = true;
      await ReminderService.rescheduleAllActive();
      expect(StorageService.reminders().single.status, 'scheduled');
      expect(fake.scheduled.length, 1);
    });
  });

  group('قواعد متكررة — الإشعارات بتتجدول مقدّمًا', () {
    test('قاعدة أسبوعية: بتتحفظ وبتتجدول سلسلة ٢٦ موعد بنفس الساعة', () async {
      final res = await ReminderManager.createRule(
          text: 'ملخص الأسبوع', frequency: 'weekly', anchor: 5, hour: 20, minute: 15);
      expect(res.outcome!.status, 'scheduled');
      expect(fake.scheduled.length, 26);
      expect(fake.scheduled.every((s) => s.when.hour == 20 && s.when.minute == 15), isTrue);
      expect(fake.scheduled.every((s) => s.when.weekday == 5), isTrue);
      await StorageService.init(); // إعادة تشغيل
      final r = StorageService.rules().single;
      expect(r.frequency, 'weekly');
      expect(r.nextDue.hour, 20);
      final rem = StorageService.remindersForEntity(r.id).single;
      expect(rem.recurrence, 'weekly');
      expect(rem.anchor, 5);
    });

    test('إيقاف القاعدة بيلغي إشعاراتها، وتشغيلها بيرجّعها', () async {
      final res = await ReminderManager.createRule(
          text: 'ق', frequency: 'daily', anchor: 1, hour: 9, minute: 0);
      fake.cancelled.clear();
      fake.scheduled.clear();
      await ReminderManager.setRuleActive(res.rule, false);
      expect(fake.cancelled, isNotEmpty);
      expect(fake.scheduled, isEmpty);
      expect(StorageService.remindersForEntity(res.rule.id), isEmpty);
      await ReminderManager.setRuleActive(res.rule, true);
      expect(fake.scheduled.length, 30);
      expect(StorageService.remindersForEntity(res.rule.id).length, 1);
    });

    test('حذف القاعدة بيشيل إشعاراتها', () async {
      final res = await ReminderManager.createRule(
          text: 'ق', frequency: 'monthly', anchor: 1, hour: 9, minute: 0);
      fake.cancelled.clear();
      await ReminderManager.deleteRule(res.rule);
      expect(StorageService.rules(), isEmpty);
      expect(StorageService.reminders(), isEmpty);
      expect(fake.cancelled, isNotEmpty);
    });

    test('فتح التطبيق بعد موعد فات: التزام للموعد الفايت + موعد جاي بنفس الساعة',
        () async {
      final now = DateTime(2026, 10, 20, 12, 0);
      final past = DateTime(2026, 10, 18, 9, 30);
      await StorageService.saveRule(FollowUpRule(
          id: 'r1', text: 'إيجار', frequency: 'daily', anchor: 1, nextDue: past));
      final n = await RulesService.checkAndTrigger(now: now);
      expect(n, 3); // 18 و19 و20 (٩:٣٠ قبل ١٢:٠٠)
      final r = StorageService.rules().single;
      expect(r.nextDue, DateTime(2026, 10, 21, 9, 30));
      expect(StorageService.commitments().where((c) => c.type == 'rule').length, 3);
      // ما اتعملش تذكير لموعد في الماضي، والجاي اتجدول (اللي مستقبلي بالنسبة للساعة الفعلية)
      expect(StorageService.remindersForEntity('r1').length, 1);
    });
  });

  group('واجهة الإنشاء (زي المنبه)', () {
    testWidgets('AlarmTimeField: ص/م يغيّر الساعة 24 صح', (tester) async {
      TimeOfDay t = const TimeOfDay(hour: 14, minute: 30); // ٢:٣٠ م
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (c, set) => AlarmTimeField(
                time: t, onChanged: (v) => set(() => t = v)),
          ),
        ),
      ));
      await tester.tap(find.text('ص'));
      await tester.pump();
      expect(t, const TimeOfDay(hour: 2, minute: 30));
      await tester.tap(find.text('م'));
      await tester.pump();
      expect(t, const TimeOfDay(hour: 14, minute: 30));
    });

    testWidgets('إضافة تذكير من القائمة الجانبية: يتحفظ ويظهر في القائمة',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RulesScreen()));
      await tester.pump();
      expect(find.text('لا توجد تذكيرات بعد'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_alarm));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('reminder-text')), 'اتصل بالمورد');
      await tester.tap(find.byKey(const ValueKey('reminder-save')));
      await settle(tester);
      final c = StorageService.commitments();
      expect(c.length, 1);
      expect(c.single.textOriginal, 'اتصل بالمورد');
      expect(c.single.type, 'task');
      expect(StorageService.reminders().single.status, 'scheduled');
      expect(fake.scheduled.length, 1);
      expect(find.text('اتصل بالمورد'), findsOneWidget);
    });

    testWidgets('نص فاضي مرفوض ومفيش حاجة بتتسجل', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RulesScreen()));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_alarm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminder-save')));
      await tester.pump();
      expect(find.text('اكتب نص التذكير.'), findsOneWidget);
      expect(StorageService.commitments(), isEmpty);
      expect(fake.scheduled, isEmpty);
    });
  });
}
