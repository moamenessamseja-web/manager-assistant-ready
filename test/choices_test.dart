import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/services/assistant_controller.dart';
import 'package:manager_assistant/services/choice_builder.dart';
import 'package:manager_assistant/services/conversation_context_service.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

PendingOperation _pending({
  List<String> missing = const ['due_date', 'time'],
  Map<String, dynamic> fields = const {},
  List<ContextPerson> options = const [],
  String? id,
}) =>
    PendingOperation(
      id: id,
      intent: 'create_commitment',
      fields: {'person': 'عام', 'text_original': 'اتصل بالعميل', ...fields},
      missing: missing,
      options: options,
      createdAt: DateTime.now(),
    );

void main() {
  group('ChoiceBuilder — الأزرار بتتولّد من حالة العملية', () {
    test('لا عملية معلّقة = لا أزرار', () {
      expect(ChoiceBuilder.forPending(null), isEmpty);
    });

    test('ناقص اليوم → النهارده/بكرة/بعد بكرة + إلغاء', () {
      final c = ChoiceBuilder.forPending(_pending());
      expect(c.map((e) => e.label), ['النهارده', 'بكرة', 'بعد بكرة', 'إلغاء']);
      expect(c.last.kind, ChoiceKind.cancel);
    });

    test('الساعة ملتبسة (٥ بدون ص/م) → زرين فقط: صباحًا/مساءً', () {
      final c = ChoiceBuilder.forPending(_pending(
        missing: ['time'],
        fields: {'due_date': '2030-01-01', 'time_hour_raw': 5},
      ));
      expect(c.map((e) => e.label), ['5 صباحًا', '5 مساءً', 'إلغاء']);
    });

    test('الساعة ناقصة واليوم هو النهارده → الساعات اللي فاتت مش بتظهر', () {
      final now = DateTime(2026, 10, 20, 13, 0);
      final c = ChoiceBuilder.forPending(
          _pending(missing: ['time'], fields: {'due_date': '2026-10-20'}),
          now: now);
      expect(c.map((e) => e.label), ['٣ عصرًا', '٥ مساءً', '٨ مساءً', 'إلغاء']);
    });

    test('اسم ملتبس → زر لكل شخص بمعرّفه، والأسماء المتكررة مرقّمة', () {
      final c = ChoiceBuilder.forPending(_pending(
        missing: ['person'],
        options: const [
          ContextPerson(id: 'e1', name: 'أحمد'),
          ContextPerson(id: 'e2', name: 'أحمد'),
          ContextPerson(id: 'e3', name: 'خالد'),
        ],
      ));
      expect(c.map((e) => e.label), ['أحمد (1)', 'أحمد (2)', 'خالد', 'إلغاء']);
      expect(c.take(3).map((e) => e.value), ['e1', 'e2', 'e3']);
      expect(c.first.kind, ChoiceKind.person);
    });

    test('ناقص المبلغ فقط → إلغاء بس (المبلغ بيتكتب/بيتقال)', () {
      final c = ChoiceBuilder.forPending(_pending(missing: ['amount']));
      expect(c.map((e) => e.label), ['إلغاء']);
    });
  });

  group('PendingOperation id', () {
    test('بيتحفظ ويرجع نفس الـ id', () {
      final p = _pending(id: 'op-1');
      expect(PendingOperation.fromJson(p.toJson()).id, 'op-1');
    });

    test('سجل قديم بدون id بيرجع بـ id ثابت (مش بيكسر)', () {
      final j = _pending().toJson()..remove('id');
      final a = PendingOperation.fromJson(j).id;
      final b = PendingOperation.fromJson(j).id;
      expect(a, isNotEmpty);
      expect(a, b);
    });

    test('copyWith يحافظ على الـ id', () {
      final p = _pending(id: 'op-2');
      expect(p.copyWith(missing: ['time']).id, 'op-2');
    });
  });

  group('handleChoice — مربوط بالعملية الصح', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      await ConversationContextService.init();
      await ConversationContextService.clearPending();
    });

    test('زر قديم (id مختلف) ما يلمسش العملية الحالية', () async {
      await ConversationContextService.setPending(_pending(id: 'new-op'));
      final r = await AssistantController.handleChoice(
          'old-op', const ChatChoice('إلغاء', 'cancel', ChoiceKind.cancel));
      expect(r, contains('قديمة'));
      expect(ConversationContextService.pending()?.id, 'new-op');
    });

    test('إلغاء بالـ id الصح يمسح العملية', () async {
      await ConversationContextService.setPending(_pending(id: 'op-3'));
      final r = await AssistantController.handleChoice(
          'op-3', const ChatChoice('إلغاء', 'cancel', ChoiceKind.cancel));
      expect(r, contains('ألغيت'));
      expect(ConversationContextService.pending(), isNull);
    });

    test('اختيار «بكرة» يكمّل الحقل ويسأل عن الساعة (من غير ما ينفّذ حاجة)',
        () async {
      await ConversationContextService.setPending(_pending(id: 'op-4'));
      final r = await AssistantController.handleChoice(
          'op-4', const ChatChoice('بكرة', 'بكرة'));
      expect(r, contains('الساعة'));
      final p = ConversationContextService.pending();
      expect(p?.id, 'op-4'); // نفس العملية، مش جديدة
      expect(p?.fields['due_date'], isNotNull);
      expect(p?.missing, ['time']);
      expect(StorageService.commitments(), isEmpty); // لسه ما اتسجلش حاجة
    });

    test('زر شخص بمعرّف مش من الخيارات يترفض', () async {
      await ConversationContextService.setPending(_pending(
        id: 'op-5',
        missing: ['person'],
        options: const [ContextPerson(id: 'e1', name: 'أحمد')],
      ));
      final r = await AssistantController.handleChoice(
          'op-5', const ChatChoice('؟', 'zzz', ChoiceKind.person));
      expect(r, contains('مش من الخيارات'));
      expect(ConversationContextService.pending()?.id, 'op-5');
    });
  });
}
