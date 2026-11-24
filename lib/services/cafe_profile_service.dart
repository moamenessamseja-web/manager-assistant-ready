import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';

/// هوية الكافيه: الاسم والشعار. محفوظين محليًا (مفاتيح `cafe_name` و
/// `cafe_logo_path`) وبيدخلوا في النسخة الاحتياطية — فمفيش بناء APK لكل عميل.
/// فاضي = العنوان العام «مساعد الإدارة» (الكافيه التجريبي مش بيتأثر).
class CafeProfileService {
  CafeProfileService._();

  static const kName = 'cafe_name';
  static const kLogo = 'cafe_logo_path';
  static const defaultTitle = 'مساعد الإدارة';

  static String _name = '';
  static String _logoPath = '';

  static String get name => _name;
  static String get logoPath => _logoPath;

  /// الاسم المعروض: اسم الكافيه أو العنوان العام لو لسه ما اتحددش.
  static String get displayName => _name.trim().isEmpty ? defaultTitle : _name.trim();
  static bool get hasCustomName => _name.trim().isNotEmpty;

  /// الشعار لو الملف موجود فعلًا (ملف مفقود = null → الأيقونة العامة).
  static File? get logoFile {
    if (_logoPath.isEmpty) return null;
    final f = File(_logoPath);
    return f.existsSync() ? f : null;
  }

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _name = p.getString(kName) ?? '';
    _logoPath = p.getString(kLogo) ?? '';
  }

  static Future<void> setName(String value) async {
    final v = value.trim();
    final p = await SharedPreferences.getInstance();
    final ok = await p.setString(kName, v);
    if (!ok) throw StateError('فشل حفظ اسم الكافيه');
    _name = v;
    AppState.instance.notify();
  }

  /// بيحط مسار شعار جديد (الملف اتنسخ بالفعل لمجلد التطبيق) ويمسح القديم.
  static Future<void> setLogoPath(String path) async {
    final p = await SharedPreferences.getInstance();
    final old = _logoPath;
    final ok = await p.setString(kLogo, path);
    if (!ok) throw StateError('فشل حفظ الشعار');
    _logoPath = path;
    if (old.isNotEmpty && old != path) {
      try {
        final f = File(old);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    AppState.instance.notify();
  }

  static Future<void> clearLogo() async {
    final p = await SharedPreferences.getInstance();
    final old = _logoPath;
    await p.remove(kLogo);
    _logoPath = '';
    if (old.isNotEmpty) {
      try {
        final f = File(old);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    AppState.instance.notify();
  }
}
