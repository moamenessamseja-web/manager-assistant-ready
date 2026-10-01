import 'package:uuid/uuid.dart';
import '../models/commitment.dart';
import '../models/rule.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// يفحص القواعد المتكررة (مثل "كل أول الشهر فكرني بالإيجار")
/// وينشئ منها التزامات (Commitment) جديدة كل ما يحين موعدها،
/// ثم يحرّك موعدها القادم تلقائياً.
class RulesService {
  static DateTime _advance(DateTime from, String frequency, int anchor) {
    switch (frequency) {
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'monthly':
      default:
        var y = from.year, m = from.month + 1;
        if (m > 12) {
          m = 1;
          y++;
        }
        final lastDay = DateTime(y, m + 1, 0).day;
        final day = anchor.clamp(1, lastDay);
        return DateTime(y, m, day, 9, 0);
    }
  }

  /// يُستدعى عند فتح التطبيق: يحوّل أي قاعدة مستحقة إلى تذكير فعلي.
  static Future<int> checkAndTrigger() async {
    final now = DateTime.now();
    var triggered = 0;
    for (final r in StorageService.rules()) {
      if (!r.active) continue;
      while (!r.nextDue.isAfter(now)) {
        final c = Commitment(
          id: const Uuid().v4(),
          textOriginal: r.text,
          person: 'قاعدة متكررة',
          type: 'rule',
          amount: r.amount,
          dueDate: r.nextDue,
          remindAt: r.nextDue,
          followUpRule: r.text,
        );
        await StorageService.saveCommitment(c);
        await NotificationService.scheduleCommitment(c);
        r.nextDue = _advance(r.nextDue, r.frequency, r.anchor);
        triggered++;
      }
      await StorageService.saveRule(r);
    }
    return triggered;
  }
}
