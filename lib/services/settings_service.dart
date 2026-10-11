import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design/strings.dart';

/// إعدادات المستخدم المحفوظة (To Accio §6): الثيم واللغة.
/// محفوظة على الجهاز وتبقى بعد إعادة التشغيل — بلا أي قيم وهمية.
class SettingsService {
  SettingsService._();

  static const _kTheme = 'pref_theme_mode';
  static const _kLang = 'pref_language';

  static ThemeMode _themeMode = ThemeMode.system;

  static ThemeMode get themeMode => _themeMode;

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _themeMode = _parseTheme(p.getString(_kTheme));
    L.setLang(p.getString(_kLang) ?? 'ar');
  }

  static ThemeMode _parseTheme(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeKey(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, _themeKey(m));
  }

  static Future<void> setLanguage(String code) async {
    L.setLang(code);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLang, L.lang);
  }
}
