import 'package:shared_preferences/shared_preferences.dart';

/// تفضيلات الإشعارات المحفوظة محليًا — **كل خيار هنا بيأثر فعليًا** على الجدولة
/// (ReminderService.createAndSchedule)، مفيش أي زر شكلي.
///
/// الأقسام: reminders (تذكيرات والتزامات عامة) / suppliers (توريدات الموردين
/// المتوقعة) / rules (القواعد المتكررة). [leadMinutes] = التنبيه قبل الموعد.
class NotificationPrefs {
  NotificationPrefs._();

  static const kReminders = 'notif_cat_reminders';
  static const kSuppliers = 'notif_cat_suppliers';
  static const kRules = 'notif_cat_rules';
  static const kLead = 'notif_lead_minutes';

  /// القيم المسموحة للتنبيه المبكر (بالدقائق).
  static const List<int> leadOptions = [0, 10, 30, 60];

  static bool reminders = true;
  static bool suppliers = true;
  static bool rules = true;
  static int leadMinutes = 0;

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    reminders = p.getBool(kReminders) ?? true;
    suppliers = p.getBool(kSuppliers) ?? true;
    rules = p.getBool(kRules) ?? true;
    final l = p.getInt(kLead) ?? 0;
    leadMinutes = leadOptions.contains(l) ? l : 0;
  }

  /// هل القسم [category] ('reminders' | 'suppliers' | 'rules') مفعّل؟
  static bool allows(String category) {
    switch (category) {
      case 'suppliers':
        return suppliers;
      case 'rules':
        return rules;
      default:
        return reminders;
    }
  }

  static Future<void> setCategory(String category, bool value) async {
    final p = await SharedPreferences.getInstance();
    switch (category) {
      case 'suppliers':
        suppliers = value;
        await p.setBool(kSuppliers, value);
        break;
      case 'rules':
        rules = value;
        await p.setBool(kRules, value);
        break;
      default:
        reminders = value;
        await p.setBool(kReminders, value);
    }
  }

  static Future<void> setLeadMinutes(int minutes) async {
    leadMinutes = leadOptions.contains(minutes) ? minutes : 0;
    final p = await SharedPreferences.getInstance();
    await p.setInt(kLead, leadMinutes);
  }

  /// موعد الإشعار الفعلي = الموعد − التنبيه المبكر، بشرط ما يبقاش في الماضي
  /// (لو الموعد نفسه لسه جاي، بنرجع للموعد الأصلي بدل ما نفوّت التنبيه).
  static DateTime effectiveTime(DateTime due, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (leadMinutes <= 0) return due;
    final early = due.subtract(Duration(minutes: leadMinutes));
    if (early.isBefore(n) && due.isAfter(n)) return due;
    return early;
  }
}
