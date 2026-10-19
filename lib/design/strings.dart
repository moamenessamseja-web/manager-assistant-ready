import 'package:flutter/material.dart';

/// طبقة نصوص بسيطة (عربي/إنجليزي) لواجهة التطبيق (To Accio §6).
/// التطبيق عربي أولاً — الترجمة تغطّي هيكل الواجهة (العناوين، التنقل،
/// الإعدادات، الأزرار العامة). نص بيانات المستخدم يفضل زي ما هو.
class L {
  L._();

  static String _lang = 'ar';

  static String get lang => _lang;
  static bool get isArabic => _lang != 'en';
  static TextDirection get direction =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;
  static Locale get locale => Locale(_lang);

  static void setLang(String code) => _lang = (code == 'en') ? 'en' : 'ar';

  static const Map<String, String> _ar = {
    'app_title': 'مساعد الإدارة',
    'nav_today': 'القائمة',
    'nav_chat': 'المحادثة',
    'nav_memory': 'الذاكرة',
    'nav_brief': 'بريف',
    'nav_staff': 'الموظفين',
    'nav_suppliers': 'الموردين',
    'sec_rules': 'القواعد والتنبيهات',
    'sec_brief': 'بريف الأسبوع',
    'sec_settings': 'الإعدادات',
    'sec_help': 'تعليمات الاستخدام',
    'settings': 'الإعدادات',
    'appearance': 'المظهر',
    'theme': 'الثيم',
    'theme_light': 'فاتح',
    'theme_dark': 'داكن',
    'theme_system': 'حسب النظام',
    'language': 'اللغة',
    'lang_arabic': 'العربية',
    'lang_english': 'English',
    'language_note':
        'تغيير اللغة يغيّر اتجاه الواجهة (RTL/LTR). بياناتك كما هي.',
    'saved': 'تم الحفظ ✅',
    'notif_diag': 'تشخيص الإشعارات',
    'notif_diag_sub': 'اعرف ليه تنبيه ما وصلش',
    'general': 'عام',
    'offline_title': 'وضع العمل',
    'offline_note': 'التطبيق يفهم أوامرك ويسجّل عملياتك محليًا على جهازك — '
        'من غير إنترنت ومن غير أي مفتاح API. الحضور والسلف والخصومات والتوريدات '
        'واستعلامات الحسابات كلها تعمل offline.',
  };

  static const Map<String, String> _en = {
    'app_title': 'Manager Assistant',
    'nav_today': 'Today',
    'nav_chat': 'Chat',
    'nav_memory': 'Memory',
    'nav_brief': 'Brief',
    'nav_staff': 'Staff',
    'nav_suppliers': 'Suppliers',
    'sec_rules': 'Rules & alerts',
    'sec_brief': 'Weekly brief',
    'sec_settings': 'Settings',
    'sec_help': 'How to use',
    'settings': 'Settings',
    'appearance': 'Appearance',
    'theme': 'Theme',
    'theme_light': 'Light',
    'theme_dark': 'Dark',
    'theme_system': 'System',
    'language': 'Language',
    'lang_arabic': 'العربية',
    'lang_english': 'English',
    'language_note':
        'Changing the language also flips the UI direction (RTL/LTR). Your data stays as-is.',
    'saved': 'Saved ✅',
    'notif_diag': 'Notification diagnostics',
    'notif_diag_sub': 'Find out why an alert did not arrive',
    'general': 'General',
    'offline_title': 'How it works',
    'offline_note': 'The app understands your commands and records your business '
        'locally on your device — no internet and no API key required. Attendance, '
        'advances, deductions, deliveries and account queries all work offline.',
  };

  static String t(String key) => (isArabic ? _ar : _en)[key] ?? _ar[key] ?? key;
}
