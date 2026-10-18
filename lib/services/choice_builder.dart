import 'conversation_context_service.dart';

enum ChoiceKind { person, text, cancel }

/// زر اختيار داخل الشات. [value] = معرّف الشخص (kind=person) أو النص اللي
/// هيتبعت للمساعد كرد (kind=text). مفيش أي زر «شكلي»: كل زر بيتنفّذ عبر
/// AssistantController.handleChoice مربوطًا بمعرّف العملية المعلّقة.
class ChatChoice {
  final String label;
  final String value;
  final ChoiceKind kind;
  const ChatChoice(this.label, this.value, [this.kind = ChoiceKind.text]);
}

/// يولّد الأزرار **من حالة العملية المعلّقة الفعلية** (الناقص/الملتبس)، مش
/// قائمة ثابتة. نقي (بدون تخزين/واجهة) علشان يتختبر بسهولة.
class ChoiceBuilder {
  ChoiceBuilder._();

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<ChatChoice> forPending(PendingOperation? p, {DateTime? now}) {
    if (p == null) return const [];
    final n = now ?? DateTime.now();
    final out = <ChatChoice>[];

    if (p.options.isNotEmpty) {
      // أسماء ملتبسة: زر لكل شخص بمعرّفه الحقيقي (ترقيم لو الاسم متكرر).
      final counts = <String, int>{};
      for (final o in p.options) {
        counts[o.name] = (counts[o.name] ?? 0) + 1;
      }
      final seen = <String, int>{};
      for (final o in p.options) {
        final k = (seen[o.name] ?? 0) + 1;
        seen[o.name] = k;
        final label = counts[o.name]! > 1 ? '${o.name} ($k)' : o.name;
        out.add(ChatChoice(label, o.id, ChoiceKind.person));
      }
    } else if (p.missing.contains('due_date')) {
      out.addAll(const [
        ChatChoice('النهارده', 'النهارده'),
        ChatChoice('بكرة', 'بكرة'),
        ChatChoice('بعد بكرة', 'بعد بكرة'),
      ]);
    } else if (p.missing.contains('time')) {
      final raw = (p.fields['time_hour_raw'] as num?)?.toInt();
      if (raw != null) {
        out.addAll([
          ChatChoice('$raw صباحًا', 'الساعة $raw صباحا'),
          ChatChoice('$raw مساءً', 'الساعة $raw مساء'),
        ]);
      } else {
        final today = p.fields['due_date'] == _ymd(n);
        // الساعة (24h) · الاسم الظاهر · النص المفهوم للـ parser.
        const slots = [
          [9, '٩ صباحًا', 'الساعة 9 صباحا'],
          [12, '١٢ ظهرًا', 'الساعة 12 الظهر'],
          [15, '٣ عصرًا', 'الساعة 3 العصر'],
          [17, '٥ مساءً', 'الساعة 5 مساء'],
          [20, '٨ مساءً', 'الساعة 8 مساء'],
        ];
        for (final s in slots) {
          // لو اليوم هو النهارده: ما نعرضش ساعات فاتت.
          if (today && (s[0] as int) <= n.hour) continue;
          out.add(ChatChoice(s[1] as String, s[2] as String));
        }
      }
    }
    // إلغاء متاح دايمًا طالما فيه عملية معلّقة.
    out.add(const ChatChoice('إلغاء', 'cancel', ChoiceKind.cancel));
    return out;
  }
}
