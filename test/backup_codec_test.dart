import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/employee.dart';
import 'package:manager_assistant/models/shift.dart';
import 'package:manager_assistant/services/backup_codec.dart';
import 'package:manager_assistant/services/closing_service.dart';
import 'package:manager_assistant/services/sha256.dart';
import 'support/backup_sample.dart';

/// النسخة الاحتياطية — دورة كاملة (تصدير ← فك ← مقارنة) + حالات الملفات الفاسدة.
String photoReader(String path) => base64Encode(utf8.encode('IMG:$path'));

String makeBackup([Map<String, dynamic>? data]) {
  final snap = BackupCodec.packPhotos(data ?? sampleData(), photoReader);
  return BackupCodec.encode(snap, now: DateTime(2026, 11, 22, 10), appVersion: '1.3.1');
}

/// يبني ملف بغلاف صحيح (بصمة سليمة) حوالين payload معيّن — لاختبار الفحص الداخلي.
String envelopeFor(String payload, {int ver = 1, String app = BackupCodec.appId}) => jsonEncode({
      'format': BackupCodec.format,
      'schemaVersion': ver,
      'appId': app,
      'appVersion': '1',
      'createdAt': '2026-11-22T10:00:00.000',
      'checksum': sha256Hex(utf8.encode(payload)),
      'payload': payload,
    });

BackupException expectFails(String text) {
  try {
    BackupCodec.decode(text);
  } on BackupException catch (e) {
    return e;
  }
  throw 'كان المفروض الملف يترفض';
}

void main() {
  group('SHA-256', () {
    test('متجهات قياسية', () {
      expect(sha256Hex(utf8.encode('')),
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(sha256Hex(utf8.encode('abc')),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    });
  });

  group('دورة كاملة: تصدير ← فك ← مقارنة', () {
    test('كل السجلات والأرصدة والأعداد بترجع مطابقة', () {
      final original = sampleData();
      final d = BackupCodec.decode(makeBackup(original));
      expect(d.schemaVersion, 1);
      expect(d.createdAt, DateTime(2026, 11, 22, 10));
      final c = d.summary.counts;
      expect(c['employees'], 2);
      expect(c['suppliers'], 1);
      expect(c['customers'], 2);
      expect(c['commitments'], 1);
      expect(c['reminders'], 1);
      expect(c['rules'], 1);
      expect(c['shifts'], 1);
      expect(c['daily_closings'], 1);
      expect(c['shortages'], 1);
      expect(c['audit_log'], 1);
      // أرصدة: حموده 500+300-100 = 700 ، جمال العميل له 80 (سالب) → المستحقات 700 فقط
      expect(d.summary.receivables, 700);
      expect(d.summary.suppliersDue, 600); // 1000 - 400
      // السجلات غير الصور مطابقة حرفيًا (بعد فك JSON)
      for (final key in BackupKeys.lists.where((k) => k != 'employees')) {
        expect(d.snapshot.prefs[key]['v'], original[key]['v']);
      }
      for (final key in BackupKeys.scalars.keys.where((k) => k != 'cafe_logo_path')) {
        expect(d.snapshot.prefs[key], original[key]);
      }
    });

    test('الصور: بتتحزّم وتترجع لمسارات الجهاز الجديد، والباقي متطابق', () {
      final d = BackupCodec.decode(makeBackup());
      expect(d.snapshot.files.keys.toSet(), {'e1_1.jpg', 'logo_1.jpg'});
      final restored = BackupCodec.unpackPhotos(
          d.snapshot.prefs, d.snapshot.files.keys.toSet(), (n) => '/new/dir/$n');
      final e1 = Employee.fromJson(
          Map<String, dynamic>.from(jsonDecode(restored['employees']['v'][0]) as Map));
      expect(e1.photoPath, '/new/dir/e1_1.jpg');
      expect(e1.totalAdvances, 200);
      expect(e1.payments.single.amount, 900);
      expect(e1.totalTips, 30);
      expect(restored['cafe_logo_path']['v'], '/new/dir/logo_1.jpg');
      // موظفة من غير صورة فضلت من غير صورة
      final e2 = Employee.fromJson(
          Map<String, dynamic>.from(jsonDecode(restored['employees']['v'][1]) as Map));
      expect(e2.photoPath, '');
    });

    test('صورة مفقودة وقت التصدير = مسار فاضي (مفيش مسار معلّق)', () {
      final snap = BackupCodec.packPhotos(sampleData(), (p) => null);
      expect(snap.files, isEmpty);
      final e1 = Employee.fromJson(
          Map<String, dynamic>.from(jsonDecode(snap.prefs['employees']['v'][0]) as Map));
      expect(e1.photoPath, '');
      expect(snap.prefs['cafe_logo_path']['v'], '');
    });

    test('نسخة من بيانات فاضية (تطبيق جديد) بتتصدّر وتتفك', () {
      final d = BackupCodec.decode(makeBackup(<String, dynamic>{}));
      expect(d.summary.counts['employees'], 0);
      expect(d.summary.receivables, 0);
    });
  });

  group('ملفات مرفوضة (ومفيش كتابة)', () {
    test('فاضي / مش JSON / مقطوع', () {
      expect(expectFails('').message, contains('فاضي'));
      expect(expectFails('hello').message, contains('مش نسخة احتياطية سليمة'));
      final good = makeBackup();
      expect(expectFails(good.substring(0, good.length ~/ 2)).message, contains('مقطوع'));
    });

    test('JSON تاني مش نسخة احتياطية', () {
      expect(expectFails('{"a":1}').message, contains('مش نسخة احتياطية من مساعد الإدارة'));
      expect(expectFails('[1,2]').message, contains('سليمة'));
    });

    test('بصمة مش مطابقة (اتعدّل رقم جوّه الملف)', () {
      final good = makeBackup();
      final env = Map<String, dynamic>.from(jsonDecode(good) as Map);
      // الأرقام جوّه سجلات JSON متهرّبة بـ \" في الـpayload
      final before = env['payload'] as String;
      env['payload'] = before.replaceFirst(r'amount\":200.0', r'amount\":999.0');
      expect(env['payload'], isNot(equals(before)));
      expect(expectFails(jsonEncode(env)).message, contains('البصمة'));
    });

    test('إصدار أحدث من التطبيق', () {
      final p = jsonEncode({'prefs': {}, 'files': {}});
      expect(expectFails(envelopeFor(p, ver: 99)).message, contains('أحدث'));
      expect(expectFails(envelopeFor(p, ver: 0)).message, contains('إصدار'));
    });

    test('تطبيق تاني', () {
      final p = jsonEncode({'prefs': {}, 'files': {}});
      expect(expectFails(envelopeFor(p, app: 'com.other.app')).message, contains('تطبيق تاني'));
    });

    test('سجل تالف جوّه قائمة بصمتها سليمة (مفيش استرجاع جزئي)', () {
      final data = sampleData();
      data['customers'] = {
        't': 'sl',
        'v': [(data['customers']['v'] as List)[0], 'مش JSON خالص'] // العميل التاني تالف
      };
      final payload = jsonEncode({'prefs': data, 'files': {}});
      final e = expectFails(envelopeFor(payload));
      expect(e.message, contains('العملاء'));
      expect(e.message, contains('رقم 2'));
      expect(e.message, contains('مفيش حاجة اتغيّرت'));
      // سجل موظف ناقص حقول أساسية
      final d2 = sampleData();
      d2['employees'] = {'t': 'sl', 'v': ['{"id":"e"}']};
      expect(expectFails(envelopeFor(jsonEncode({'prefs': d2, 'files': {}}))).message,
          contains('الموظفين'));
    });

    test('نوع قيمة غلط، وصورة بـ base64 تالف أو اسم خطر', () {
      var data = sampleData();
      data['notif_lead_minutes'] = {'t': 'i', 'v': 'abc'};
      expect(expectFails(envelopeFor(jsonEncode({'prefs': data, 'files': {}}))).message, contains('غير صالح'));
      data = sampleData();
      expect(
          expectFails(envelopeFor(jsonEncode({'prefs': data, 'files': {'a.jpg': '###'}}))).message,
          contains('صورة تالفة'));
      expect(
          expectFails(envelopeFor(jsonEncode({'prefs': data, 'files': {'../evil.jpg': 'QQ=='}}))).message,
          contains('اسم صورة'));
    });

    test('مفاتيح غريبة بتتجاهل (توافق للأمام) ومش بتدخل اللقطة', () {
      final data = sampleData()..['chat_history_v1'] = {'t': 'sl', 'v': ['x']};
      final d = BackupCodec.decode(envelopeFor(jsonEncode({'prefs': data, 'files': {}})));
      expect(d.snapshot.prefs.containsKey('chat_history_v1'), isFalse);
      expect(d.summary.counts['employees'], 2);
    });
  });

  group('التوافق مع الإقفال بعد الاسترجاع', () {
    test('نفس لقطة الشيفت ونفس الإقفال اليومي بعد الدورة', () {
      final d = BackupCodec.decode(makeBackup());
      final sh = Shift.fromJson(
          Map<String, dynamic>.from(jsonDecode(d.snapshot.prefs['shifts']['v'][0]) as Map));
      final dc = DailyClosing.fromJson(
          Map<String, dynamic>.from(jsonDecode(d.snapshot.prefs['daily_closings']['v'][0]) as Map));
      expect(ClosingService.isDailyStale(dc, [sh]), isFalse);
      expect(sh.expectedCash(sh.snapshot!), 100 + 700 + 100);
    });
  });
}
