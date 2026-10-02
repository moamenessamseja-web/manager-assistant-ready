import 'package:uuid/uuid.dart';
import '../models/reminder.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// نتيجة إنشاء تذكير من البداية للنهاية — تُستخدم لصياغة رسالة صادقة للمستخدم
/// بدل افتراض أن تسجيل الالتزام في قاعدة البيانات يعني وصول التنبيه فعليًا.
class ReminderOutcome {
  final bool scheduled;
  final String status;
  final Reminder reminder;
  const ReminderOutcome(this.scheduled, this.status, this.reminder);

  /// جملة عربية مختصرة تُضاف لرد المساعد عند فشل الجدولة، فاضية لو نجحت.
  String get warningSuffix {
    switch (status) {
      case 'permission_required':
        return '\n⚠️ سجلت البيانات، لكن صلاحية الإشعارات مش مفعّلة — فعّلها من الإعدادات عشان يوصلك التنبيه.';
      case 'schedule_failed':
        return '\n⚠️ سجلت البيانات، لكن حصلت مشكلة في جدولة التنبيه. جرّب تاني من شاشة القواعد والتنبيهات.';
      default:
        return '';
    }
  }
}

class ReminderService {
  /// ينشئ Reminder entity مستقلة، يحفظها، يحاول جدولتها فعليًا عبر Android،
  /// ثم يحدّث حالتها بالنتيجة الحقيقية — لا يُعتبر النجاح مضمونًا إلا بعد
  /// تأكيد الـ Scheduler.
  static Future<ReminderOutcome> createAndSchedule({
    required String title,
    required String body,
    required DateTime dueAt,
    String recurrence = 'none',
    String? relatedEntityId,
    String? relatedEntityType,
  }) async {
    final r = Reminder(
      id: const Uuid().v4(),
      title: title,
      body: body,
      dueAt: dueAt,
      recurrence: recurrence,
      relatedEntityId: relatedEntityId,
      relatedEntityType: relatedEntityType,
    );
    await StorageService.saveReminder(r);

    final res = await NotificationService.scheduleAt(r.id.hashCode, title, body, dueAt);
    r.status = res.status;
    r.updatedAt = DateTime.now();
    await StorageService.saveReminder(r);

    return ReminderOutcome(res.success, res.status, r);
  }

  static Future<void> cancel(String reminderId) async {
    await NotificationService.cancel(reminderId);
    final r = StorageService.reminders().where((x) => x.id == reminderId);
    if (r.isNotEmpty) {
      final rem = r.first;
      rem.status = 'cancelled';
      rem.enabled = false;
      rem.updatedAt = DateTime.now();
      await StorageService.saveReminder(rem);
    }
  }

  /// إعادة محاولة جدولة تذكير فشل سابقًا (بعد منح الصلاحية مثلاً).
  static Future<ReminderOutcome> retry(Reminder r) async {
    final res = await NotificationService.scheduleAt(r.id.hashCode, r.title, r.body, r.dueAt);
    r.status = res.status;
    r.updatedAt = DateTime.now();
    await StorageService.saveReminder(r);
    return ReminderOutcome(res.success, res.status, r);
  }
}
