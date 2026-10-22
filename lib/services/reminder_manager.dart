import 'package:uuid/uuid.dart';
import '../models/commitment.dart';
import '../models/rule.dart';
import 'recurrence.dart';
import 'reminder_service.dart';
import 'storage_service.dart';

/// واجهة الإدارة اللي الشاشات (القائمة الجانبية «القواعد والتنبيهات») بتستعملها
/// لإنشاء/تعديل/حذف التذكيرات — **من غير أي اعتماد على الشات**.
///
/// مفيش نظام موازي: بتكتب نفس السجلات اللي الشات بيكتبها (Commitment + Reminder
/// عبر ReminderService، وFollowUpRule للمتكرر)، فكل حاجة بتظهر في «اليوم» و«الذاكرة»
/// وقوائم التذكيرات، وبتتجدول فعليًا عبر NotificationService.
class ReminderManager {
  ReminderManager._();

  /// null = تمام. غير كده = رسالة خطأ عربي للمستخدم.
  static String? validateOneOff(String text, DateTime when, {DateTime? now}) {
    if (text.trim().isEmpty) return 'اكتب نص التذكير.';
    if (!when.isAfter(now ?? DateTime.now())) {
      return 'الموعد ده فات — اختار تاريخ وساعة جاية.';
    }
    return null;
  }

  // ───────────────────────── تذكير لمرة واحدة (التزام نوع task) ─────────────────────────

  /// ينشئ التزام + تذكير مجدول. [id] ثابت لكل نموذج: لو اتبعت تاني بنفس الـ id
  /// (ضغطتين) بنرجّع null من غير ما نكرر.
  static Future<ReminderOutcome?> createOneOff({
    required String text,
    double? amount,
    required DateTime when,
    String? id,
  }) async {
    final cid = id ?? const Uuid().v4();
    if (StorageService.commitments().any((x) => x.id == cid)) return null;
    final c = Commitment(
      id: cid,
      textOriginal: text.trim(),
      person: 'عام',
      type: 'task',
      amount: amount,
      dueDate: when,
      remindAt: when,
    );
    await StorageService.saveCommitment(c);
    return _schedule(c);
  }

  static Future<ReminderOutcome> _schedule(Commitment c) {
    return ReminderService.createAndSchedule(
      title: 'تذكير',
      body: c.textOriginal,
      dueAt: c.remindAt,
      relatedEntityId: c.id,
      relatedEntityType: 'commitment',
    );
  }

  static Future<ReminderOutcome> updateOneOff(
    Commitment c, {
    required String text,
    double? amount,
    required DateTime when,
  }) async {
    c.textOriginal = text.trim();
    c.amount = amount;
    c.dueDate = when;
    c.remindAt = when;
    await StorageService.saveCommitment(c);
    await ReminderService.removeForEntity(c.id);
    return _schedule(c);
  }

  static Future<void> markDone(Commitment c) async {
    c.status = 'done';
    await StorageService.saveCommitment(c);
    await ReminderService.removeForEntity(c.id);
  }

  static Future<void> deleteOneOff(Commitment c) async {
    await ReminderService.removeForEntity(c.id);
    await StorageService.deleteCommitment(c.id);
  }

  // ───────────────────────── قواعد متكررة ─────────────────────────

  static String? validateRule(String text, String frequency, int anchor) {
    if (text.trim().isEmpty) return 'اكتب نص القاعدة.';
    if (frequency == 'monthly' && (anchor < 1 || anchor > 31)) {
      return 'يوم الشهر لازم يكون من ١ لـ ٣١.';
    }
    if (frequency == 'weekly' && (anchor < 1 || anchor > 7)) {
      return 'اختار يوم من أيام الأسبوع.';
    }
    return null;
  }

  static Future<({FollowUpRule rule, ReminderOutcome? outcome})> createRule({
    required String text,
    double? amount,
    required String frequency,
    required int anchor,
    required int hour,
    required int minute,
    String? id,
    DateTime? now,
  }) async {
    final rid = id ?? const Uuid().v4();
    final existing = StorageService.rules().where((r) => r.id == rid);
    if (existing.isNotEmpty) return (rule: existing.first, outcome: null);
    final r = FollowUpRule(
      id: rid,
      text: text.trim(),
      frequency: frequency,
      anchor: anchor,
      amount: amount,
      nextDue: Recurrence.firstOccurrence(
          frequency: frequency,
          anchor: anchor,
          hour: hour,
          minute: minute,
          now: now),
    );
    await StorageService.saveRule(r);
    final outcome = await ReminderService.syncRule(r);
    return (rule: r, outcome: outcome);
  }

  static Future<ReminderOutcome?> updateRule(
    FollowUpRule r, {
    required String text,
    double? amount,
    required String frequency,
    required int anchor,
    required int hour,
    required int minute,
    DateTime? now,
  }) async {
    r.text = text.trim();
    r.amount = amount;
    r.frequency = frequency;
    r.anchor = anchor;
    r.nextDue = Recurrence.firstOccurrence(
        frequency: frequency,
        anchor: anchor,
        hour: hour,
        minute: minute,
        now: now);
    await StorageService.saveRule(r);
    return ReminderService.syncRule(r);
  }

  static Future<ReminderOutcome?> setRuleActive(FollowUpRule r, bool active) async {
    r.active = active;
    if (active && !r.nextDue.isAfter(DateTime.now())) {
      r.nextDue = Recurrence.upcoming(r.nextDue, r.frequency, r.anchor,
          count: 1).first;
    }
    await StorageService.saveRule(r);
    return ReminderService.syncRule(r);
  }

  static Future<void> deleteRule(FollowUpRule r) async {
    await ReminderService.removeForEntity(r.id);
    await StorageService.deleteRule(r.id);
  }
}
