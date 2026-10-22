/// منطق التكرار والوقت — **نقي** (بدون تخزين/واجهة/إضافات) علشان يتختبر.
///
/// الأسبوع بنفس اتفاق DateTime.weekday: ١=الإثنين … ٧=الأحد. كل التواريخ
/// بالتوقيت المحلي للجهاز، والحساب بـ DateTime(y, m, d+k, h, mm) علشان تغيّر
/// التوقيت الصيفي ما يزحزحش الساعة.
class Recurrence {
  Recurrence._();

  /// الحد الأقصى لعدد المواعيد القادمة اللي بنجدولها مقدّمًا لكل تذكير متكرر
  /// (علشان الإشعار يوصل حتى لو التطبيق ما اتفتحش). بيتجدد كل مرة التطبيق يفتح.
  static int seriesLimit(String frequency) {
    switch (frequency) {
      case 'daily':
        return 30;
      case 'weekly':
        return 26;
      case 'monthly':
        return 12;
      default:
        return 1;
    }
  }

  /// 12 ساعة (١–١٢ + ص/م) → 24 ساعة. ١٢ ص = 0، ١٢ م = 12.
  static int hour24(int hour12, bool pm) {
    assert(hour12 >= 1 && hour12 <= 12);
    final h = hour12 % 12;
    return pm ? h + 12 : h;
  }

  /// 24 ساعة → (ساعة 12, هل مساء).
  static ({int hour12, bool pm}) to12(int hour24) {
    final pm = hour24 >= 12;
    final h = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return (hour12: h, pm: pm);
  }

  static int _lastDay(int y, int m) => DateTime(y, m + 1, 0).day;

  /// الموعد التالي بعد [from] بنفس الساعة والدقيقة.
  static DateTime advance(DateTime from, String frequency, int anchor) {
    switch (frequency) {
      case 'daily':
        return DateTime(from.year, from.month, from.day + 1, from.hour, from.minute);
      case 'weekly':
        return DateTime(from.year, from.month, from.day + 7, from.hour, from.minute);
      case 'monthly':
      default:
        var y = from.year, m = from.month + 1;
        if (m > 12) {
          m = 1;
          y++;
        }
        final day = anchor.clamp(1, _lastDay(y, m));
        return DateTime(y, m, day, from.hour, from.minute);
    }
  }

  /// أول موعد **بعد** [now] لقاعدة متكررة بساعة ودقيقة محددتين.
  static DateTime firstOccurrence({
    required String frequency,
    required int anchor,
    required int hour,
    required int minute,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    switch (frequency) {
      case 'daily':
        var c = DateTime(n.year, n.month, n.day, hour, minute);
        if (!c.isAfter(n)) c = DateTime(n.year, n.month, n.day + 1, hour, minute);
        return c;
      case 'weekly':
        final a = anchor.clamp(1, 7);
        final add = (a - n.weekday) % 7;
        var c = DateTime(n.year, n.month, n.day + add, hour, minute);
        if (!c.isAfter(n)) c = DateTime(n.year, n.month, n.day + add + 7, hour, minute);
        return c;
      case 'monthly':
      default:
        var y = n.year, m = n.month;
        var c = DateTime(y, m, anchor.clamp(1, _lastDay(y, m)), hour, minute);
        if (!c.isAfter(n)) {
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
          c = DateTime(y, m, anchor.clamp(1, _lastDay(y, m)), hour, minute);
        }
        return c;
    }
  }

  /// المواعيد القادمة (بعد [now]) بدءًا من [next]، حتى [count] موعد
  /// (الافتراضي = [seriesLimit]). لو [next] في الماضي بنقدّمه لحد ما يبقى جاي.
  static List<DateTime> upcoming(
    DateTime next,
    String frequency,
    int anchor, {
    int? count,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final limit = count ?? seriesLimit(frequency);
    if (frequency == 'none') return next.isAfter(n) ? [next] : const [];
    var t = next;
    var guard = 0;
    while (!t.isAfter(n) && guard++ < 5000) {
      t = advance(t, frequency, anchor);
    }
    final out = <DateTime>[];
    while (out.length < limit) {
      out.add(t);
      t = advance(t, frequency, anchor);
    }
    return out;
  }
}
