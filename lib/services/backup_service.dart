import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_error_service.dart';
import 'app_state.dart';
import 'backup_codec.dart';

/// واجهة التخزين اللي بيحتاجها النسخ الاحتياطي (SharedPreferences في التطبيق،
/// وبديل اختبار بيحاكي فشل الكتابة عشان نجرّب الرجوع التلقائي فعلًا).
abstract class PrefsStore {
  Object? get(String key);
  bool containsKey(String key);
  List<String>? getStringList(String key);
  String? getString(String key);
  Future<bool> setStringList(String key, List<String> v);
  Future<bool> setString(String key, String v);
  Future<bool> setBool(String key, bool v);
  Future<bool> setInt(String key, int v);
  Future<bool> remove(String key);
}

class SharedPrefsStore implements PrefsStore {
  final SharedPreferences p;
  SharedPrefsStore(this.p);
  @override
  Object? get(String key) => p.get(key);
  @override
  bool containsKey(String key) => p.containsKey(key);
  @override
  List<String>? getStringList(String key) => p.getStringList(key);
  @override
  String? getString(String key) => p.getString(key);
  @override
  Future<bool> setStringList(String key, List<String> v) => p.setStringList(key, v);
  @override
  Future<bool> setString(String key, String v) => p.setString(key, v);
  @override
  Future<bool> setBool(String key, bool v) => p.setBool(key, v);
  @override
  Future<bool> setInt(String key, int v) => p.setInt(key, v);
  @override
  Future<bool> remove(String key) => p.remove(key);
}

/// نتيجة الاسترجاع (للعرض بالعربي).
class RestoreResult {
  final BackupSummary restored;
  final String? safetyBackupName;
  const RestoreResult(this.restored, this.safetyBackupName);
}

/// النسخ الاحتياطي والاسترجاع فوق SharedPreferences. المنطق المهم (الغلاف،
/// التحقق، البصمة، فحص السجلات) في [BackupCodec] النقي؛ هنا بس القراءة/الكتابة
/// الفعلية، نسخة الأمان، والرجوع التلقائي لو الكتابة وقفت في النص.
///
/// القاعدة: **لا استرجاع جزئي أبدًا**. الملف بيتفحص كله الأول؛ وبعدين بتتعمل
/// نسخة أمان من البيانات الحالية؛ وبعدين الكتابة، ولو أي كتابة فشلت بنرجّع
/// البيانات القديمة.
class BackupService {
  BackupService._();

  static const kLastBackup = 'last_backup_at';
  static const appVersion = '1.3.1';

  /// مجلد الصور المسترجعة + نسخ الأمان. بيتبدّل في الاختبارات.
  static Future<Directory> Function() baseDir = getApplicationDocumentsDirectory;

  // ───────────────────────────── قراءة الحالة الحالية ─────────────────────────────

  /// بيقرا كل المفاتيح المدعومة من التخزين لشكل {'t','v'}.
  static Map<String, dynamic> readPrefs(PrefsStore p) {
    final out = <String, dynamic>{};
    for (final key in BackupKeys.lists) {
      final v = p.getStringList(key);
      if (v != null) out[key] = {'t': 'sl', 'v': List<String>.from(v)};
    }
    BackupKeys.scalars.forEach((key, t) {
      if (!p.containsKey(key)) return;
      final v = p.get(key);
      if (t == 's' && v is String) out[key] = {'t': 's', 'v': v};
      if (t == 'b' && v is bool) out[key] = {'t': 'b', 'v': v};
      if (t == 'i' && v is int) out[key] = {'t': 'i', 'v': v};
    });
    return out;
  }

  static String? _readFileB64(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return base64Encode(f.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  /// نص النسخة الاحتياطية الكاملة للحالة الحالية.
  static String buildBackupText(PrefsStore p, {DateTime? now}) {
    final snap = BackupCodec.packPhotos(readPrefs(p), _readFileB64);
    return BackupCodec.encode(snap, now: now ?? DateTime.now(), appVersion: appVersion);
  }

  static String fileNameFor(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'manager_assistant_backup_${t.year}-${two(t.month)}-${two(t.day)}_${two(t.hour)}${two(t.minute)}.json';
  }

  /// بيكتب النسخة في ملف مؤقت جاهز للمشاركة، ويسجّل تاريخ آخر نسخة.
  static Future<File> exportToTempFile(PrefsStore p, {DateTime? now, Directory? dir}) async {
    final t = now ?? DateTime.now();
    final text = buildBackupText(p, now: t);
    final d = dir ?? await getTemporaryDirectory();
    final f = File('${d.path}/${fileNameFor(t)}');
    await f.writeAsString(text, flush: true);
    await p.setString(kLastBackup, t.toIso8601String());
    return f;
  }

  static DateTime? lastBackupAt(PrefsStore p) {
    final v = p.getString(kLastBackup);
    return v == null ? null : DateTime.tryParse(v);
  }

  // ───────────────────────────── نسخ الأمان ─────────────────────────────

  static Future<Directory> _safetyDir() async {
    final d = Directory('${(await baseDir()).path}/safety_backups');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// آخر نسخ أمان (الأحدث أولًا).
  static Future<List<File>> safetyBackups() async {
    final d = await _safetyDir();
    final files = d.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  static Future<File> _writeSafetyBackup(PrefsStore p, DateTime now) async {
    final d = await _safetyDir();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'before_restore_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
    final f = File('${d.path}/$name');
    await f.writeAsString(buildBackupText(p, now: now), flush: true);
    // نحتفظ بآخر ٥ بس
    final all = await safetyBackups();
    for (final old in all.skip(5)) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
    return f;
  }

  // ───────────────────────────── الاسترجاع ─────────────────────────────

  static Future<void> _applyEntry(PrefsStore p, String key, dynamic e) async {
    final t = e['t'];
    bool ok;
    if (t == 'sl') {
      ok = await p.setStringList(key, List<String>.from(e['v'] as List));
    } else if (t == 's') {
      ok = await p.setString(key, e['v'] as String);
    } else if (t == 'b') {
      ok = await p.setBool(key, e['v'] as bool);
    } else {
      ok = await p.setInt(key, e['v'] as int);
    }
    if (!ok) throw StateError('write failed: $key');
  }

  /// يسترجع [decoded] (اتفحص بالفعل بـ[BackupCodec.decode]). الاسترجاع = استبدال
  /// كامل (مش دمج) فمفيش سجلات مكررة، والـIDs والعلاقات زي ما هي.
  static Future<RestoreResult> restore(PrefsStore p, BackupDecoded decoded,
      {DateTime? now}) async {
    final t = now ?? DateTime.now();

    // 1) نسخة أمان من الحالة الحالية قبل أي تغيير. لو فشلت = نوقف (مفيش مخاطرة).
    File safety;
    try {
      safety = await _writeSafetyBackup(p, t);
    } catch (e, st) {
      AppErrorService.log('backup.safety', e, st);
      throw const BackupException(
          'معرفناش نعمل نسخة أمان من بياناتك الحالية، فوقفنا الاسترجاع. مفيش حاجة اتغيّرت.');
    }

    // 2) الصور في مكان دائم (بعد ما نتأكد إننا قادرين نكتب).
    final base = await baseDir();
    final photoDir = Directory('${base.path}/restored_photos');
    final written = <File>[];
    final names = decoded.snapshot.files.keys.toSet();
    try {
      if (!photoDir.existsSync()) photoDir.createSync(recursive: true);
      for (final entry in decoded.snapshot.files.entries) {
        final f = File('${photoDir.path}/${entry.key}');
        await f.writeAsBytes(base64Decode(entry.value), flush: true);
        written.add(f);
      }
    } catch (e, st) {
      AppErrorService.log('backup.photos', e, st);
      for (final f in written) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
      throw const BackupException('فشل حفظ الصور. مفيش حاجة اتغيّرت في بياناتك.');
    }
    final target = BackupCodec.unpackPhotos(
        decoded.snapshot.prefs, names, (n) => '${photoDir.path}/$n');

    // 3) الكتابة مع لقطة للرجوع.
    final before = readPrefs(p);
    final allKeys = [...BackupKeys.lists, ...BackupKeys.scalars.keys];
    try {
      for (final key in allKeys) {
        final e = target[key];
        if (e != null) {
          await _applyEntry(p, key, e);
        } else if (p.containsKey(key)) {
          if (!await p.remove(key)) throw StateError('remove failed: $key');
        }
      }
    } catch (e, st) {
      AppErrorService.log('backup.apply', e, st);
      // رجوع تلقائي للبيانات القديمة
      for (final key in allKeys) {
        try {
          final b = before[key];
          if (b != null) {
            await _applyEntry(p, key, b);
          } else {
            await p.remove(key);
          }
        } catch (_) {}
      }
      for (final f in written) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
      throw const BackupException(
          'حصلت مشكلة أثناء الاسترجاع، ورجّعنا بياناتك زي ما كانت. جرّب تاني.');
    }
    AppState.instance.notify();
    return RestoreResult(decoded.summary, safety.uri.pathSegments.last);
  }
}
