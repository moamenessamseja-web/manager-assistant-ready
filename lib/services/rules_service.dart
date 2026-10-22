import 'package:uuid/uuid.dart';
import '../models/commitment.dart';
import 'recurrence.dart';
import 'storage_service.dart';
import 'reminder_service.dart';

/// القواعد المتكررة (مثل "كل أول الشهر فكرني بالإيجار").
///
/// **الإشعار** بتاع كل قاعدة بيتجدول مقدّمًا (سلسلة مواعيد قادمة عبر
/// ReminderService.syncRule) فبيوصل حتى لو التطبيق ما اتفتحش. أما **الالتزام**
/// (Commitment) اللي بيظهر في «اليوم»/الذاكرة فبيتنشأ عند فتح التطبيق لأي موعد
/// فات، وبعدين الموعد القادم بيتحرّك.
class RulesService {
  /// الموعد التالي (بنفس الساعة والدقيقة) — راجع [Recurrence.advance].
  static DateTime advance(DateTime from, String frequency, int anchor) =>
      Recurrence.advance(from, frequency, anchor);

  /// يُستدعى عند فتح التطبيق: يحوّل أي موعد فات لالتزام، ثم يجدّد جدولة
  /// الإشعارات القادمة لكل قاعدة شغّالة.
  static Future<int> checkAndTrigger({DateTime? now}) async {
    final n = now ?? DateTime.now();
    var triggered = 0;
    for (final r in StorageService.rules()) {
      if (!r.active) continue;
      var moved = false;
      while (!r.nextDue.isAfter(n)) {
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
        r.nextDue = advance(r.nextDue, r.frequency, r.anchor);
        triggered++;
        moved = true;
      }
      if (moved) await StorageService.saveRule(r);
      await ReminderService.syncRule(r);
    }
    return triggered;
  }
}
