import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/services/cafe_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// هوية الكافيه: الاسم والشعار — حفظ، استبدال، إعادة تشغيل، وملف مفقود.
void main() {
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CafeProfileService.init();
    dir = Directory.systemTemp.createTempSync('cafe_profile_test');
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  File img(String name, String content) =>
      File('${dir.path}/$name')..writeAsStringSync(content);

  test('الافتراضي: العنوان العام، من غير اسم ولا شعار', () {
    expect(CafeProfileService.displayName, 'مساعد الإدارة');
    expect(CafeProfileService.hasCustomName, isFalse);
    expect(CafeProfileService.logoFile, isNull);
  });

  test('الاسم بيتحفظ وبيفضل بعد إعادة التشغيل، والفاضي بيرجّع العنوان العام', () async {
    await CafeProfileService.setName('  كافيه النيل  ');
    expect(CafeProfileService.displayName, 'كافيه النيل');
    await CafeProfileService.init(); // محاكاة إعادة تشغيل (إعادة قراءة من التخزين)
    expect(CafeProfileService.displayName, 'كافيه النيل');
    await CafeProfileService.setName('   ');
    expect(CafeProfileService.displayName, 'مساعد الإدارة');
  });

  test('اسم طويل جدًا بيتحفظ كامل (العرض بيتقصّ بنقط في الواجهة)', () async {
    final long = 'كافيه ' * 30;
    await CafeProfileService.setName(long);
    expect(CafeProfileService.name, long.trim());
  });

  test('الشعار: اختيار ← إعادة تشغيل ← استبدال (القديم بيتمسح) ← إزالة', () async {
    final a = img('a.jpg', 'A');
    await CafeProfileService.setLogoPath(a.path);
    expect(CafeProfileService.logoFile?.path, a.path);
    await CafeProfileService.init();
    expect(CafeProfileService.logoFile?.path, a.path); // استمرار بعد إعادة التشغيل

    final b = img('b.jpg', 'B');
    await CafeProfileService.setLogoPath(b.path);
    expect(CafeProfileService.logoFile?.path, b.path);
    expect(a.existsSync(), isFalse); // الشعار القديم اتشال

    await CafeProfileService.clearLogo();
    expect(CafeProfileService.logoFile, isNull);
    expect(b.existsSync(), isFalse);
    await CafeProfileService.init();
    expect(CafeProfileService.logoPath, '');
  });

  test('ملف الشعار مفقود: logoFile = null (الواجهة بتعرض الأيقونة) ومفيش استثناء', () async {
    final a = img('gone.jpg', 'X');
    await CafeProfileService.setLogoPath(a.path);
    a.deleteSync();
    expect(CafeProfileService.logoFile, isNull);
    expect(CafeProfileService.displayName, 'مساعد الإدارة');
  });
}
