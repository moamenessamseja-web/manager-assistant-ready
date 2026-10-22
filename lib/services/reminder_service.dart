import 'package:uuid/uuid.dart';
import '../models/reminder.dart';
import '../models/rule.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'notification_prefs.dart';
import 'recurrence.dart';

/// نتيجة إنشاء تذكير من البداية للنهاية — تُستخدم لصياغة رسالة صادقة للمستخدم
/// بدل افتراض أن تسجيل الالتزام في قاعدة البيانات يعني وصول التنبيه فعليًا.
class ReminderOutcome {
  final bool scheduled;
  final String status;
  final Reminder reminder;

  /// اتجدولت لكن النظام مش مدّي صلاحية «منبه دقيق» (ممكن يتأخر دقائق).
  final bool inexact;
  const ReminderOutcome(this.scheduled, this.status, this.reminder,
      {this.inexact = false});

  /// جملة عربية مختصرة تُضاف لرد المساعد عند فشل الجدولة، فاضية لو نجحت.
  String get warningSuffix {
    switch (status) {
      case 'permission_required':
        return '\n⚠️ سجلت البيانات، لكن صلاحية الإشعارات مش مفعّلة — فعّلها من الإعدادات عشان يوصلك التنبيه.';
      case 'muted_by_settings':
        return '\nℹ️ سجلت البيانات، لكن تنبيهات النوع ده متوقفة من إعدادات الإشعارات فمش هيوصلك إشعار.';
      case 'schedule_failed':
        return '\n⚠️ تم تسجيل العملية بنجاح، لكن تعذر ضبط التذكير. تقدر تتابع إعدادات التنبيهات.';
      default:
        return inexact
            ? '\nℹ️ أندرويد ما سمحش بمنبه دقيق، فممكن التنبيه يتأخر دقايق. فعّل «المنبهات والتذكيرات» من إعدادات الإشعارات.'
            : '';
    }
  }
}

class ReminderService {
  /// المواعيد الفعلية اللي هتتجدول لتذكير: موعد واحد، أو سلسلة قادمة للمتكرر.
  /// التنبيه المبكر (إعدادات الإشعارات) بيتطبّق على كل موعد.
  static List<DateTime> timesFor(Reminder r, {DateTime? now}) {
    final base = r.recurrence == 'none'
        ? [r.dueAt]
        : Recurrence.upcoming(r.dueAt, r.recurrence, r.anchor, now: now);
    return [for (final t in base) NotificationPrefs.effectiveTime(t, now: now)];
  }

  /// ينشئ Reminder entity مستقلة، يحفظها، يحاول جدولتها فعليًا عبر Android،
  /// ثم يحدّث حالتها بالنتيجة الحقيقية — لا يُعتبر النجاح مضمونًا إلا بعد
  /// تأكيد الـ Scheduler. [recurrence] غير 'none' = تذكير متكرر (سلسلة).
  static Future<ReminderOutcome> createAndSchedule({
    required String title,
    required String body,
    required DateTime dueAt,
    String recurrence = 'none',
    int anchor = 1,
    String? relatedEntityId,
    String? relatedEntityType,
    String? category, // reminders | suppliers | rules
  }) async {
    final cat = category ?? (relatedEntityType == 'rule' ? 'rules' : 'reminders');
    final r = Reminder(
      id: const Uuid().v4(),
      title: title,
      body: body,
      dueAt: dueAt,
      recurrence: recurrence,
      anchor: anchor,
      relatedEntityId: relatedEntityId,
      relatedEntityType: relatedEntityType,
    );
    // القسم متوقف من إعدادات الإشعارات: نحفظ السجل بدون جدولة أي إشعار.
    if (!NotificationPrefs.allows(cat)) {
      r.status = 'cancelled';
      r.enabled = false;
      await StorageService.saveReminder(r);
      return ReminderOutcome(false, 'muted_by_settings', r);
    }
    await StorageService.saveReminder(r);

    final res = await NotificationService.scheduleSeries(
        r.id.hashCode, title, body, timesFor(r));
    r.status = res.status;
    r.updatedAt = DateTime.now();
    await StorageService.saveReminder(r);

    return ReminderOutcome(res.success, res.status, r,
        inexact: res.success && res.message == 'inexact');
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

  /// يلغي الإشعار ويحذف سجل التذكير نهائيًا.
  static Future<void> delete(String reminderId) async {
    await NotificationService.cancel(reminderId);
    await StorageService.deleteReminder(reminderId);
  }

  /// يشيل كل التذكيرات المرتبطة بكيان (التزام/قاعدة): إشعارات + سجلات.
  static Future<void> removeForEntity(String entityId) async {
    for (final r in StorageService.remindersForEntity(entityId)) {
      await delete(r.id);
    }
  }

  /// يخلّي تذكير القاعدة متزامن مع حالتها: بيشيل القديم، ولو القاعدة شغّالة
  /// بيجدول سلسلة المواعيد القادمة (حتى لو التطبيق ما اتفتحش). idempotent.
  static Future<ReminderOutcome?> syncRule(FollowUpRule rule) async {
    await removeForEntity(rule.id);
    if (!rule.active) return null;
    return createAndSchedule(
      title: 'قاعدة متكررة',
      body: rule.text,
      dueAt: rule.nextDue,
      recurrence: rule.frequency,
      anchor: rule.anchor,
      relatedEntityId: rule.id,
      relatedEntityType: 'rule',
    );
  }

  /// إعادة محاولة جدولة تذكير فشل سابقًا (بعد منح الصلاحية مثلاً).
  static Future<ReminderOutcome> retry(Reminder r) async {
    final res = await NotificationService.scheduleSeries(
        r.id.hashCode, r.title, r.body, timesFor(r));
    r.status = res.status;
    r.updatedAt = DateTime.now();
    await StorageService.saveReminder(r);
    return ReminderOutcome(res.success, res.status, r,
        inexact: res.success && res.message == 'inexact');
  }

  /// يُستدعى عند كل فتح للتطبيق (main.dart) — يعيد تسليح كل التذكيرات النشطة
  /// عبر نفس مسار الجدولة (NotificationService.scheduleSeries). idempotent:
  /// نفس id الإشعار بيستبدل أي جدولة سابقة عند نظام التشغيل، مش بيكررها.
  /// بيعالج كمان التذكيرات اللي فشلت قبل كده (مثلًا الصلاحية اتمنحت بعدها).
  ///
  /// الاستمرار بعد **إعادة تشغيل الجهاز** بيتم أساسًا عن طريق
  /// ScheduledNotificationBootReceiver (مسجّل في المانيفست عبر CI)؛ ودي طبقة
  /// تانية بتتأكد من كل حاجة عند فتح التطبيق.
  static Future<void> rescheduleAllActive({DateTime? now}) async {
    final n = now ?? DateTime.now();
    const retryable = {'scheduled', 'permission_required', 'schedule_failed'};
    for (final r in StorageService.reminders()) {
      if (!r.enabled || !retryable.contains(r.status)) continue;
      if (r.recurrence == 'none' && r.dueAt.isBefore(n)) continue;
      // المتكرر: dueAt = أول موعد جاي (نقدّمه لو فات) علشان القوائم تعرض الصح.
      if (r.recurrence != 'none' && !r.dueAt.isAfter(n)) {
        r.dueAt = Recurrence.upcoming(r.dueAt, r.recurrence, r.anchor,
            count: 1, now: n).first;
      }
      final res = await NotificationService.scheduleSeries(
          r.id.hashCode, r.title, r.body, timesFor(r, now: n));
      r.status = res.status;
      r.updatedAt = DateTime.now();
      await StorageService.saveReminder(r);
    }
  }
}
