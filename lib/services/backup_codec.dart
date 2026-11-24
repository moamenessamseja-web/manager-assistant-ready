import 'dart:convert';
import '../models/audit_entry.dart';
import '../models/commitment.dart';
import '../models/customer.dart';
import '../models/employee.dart';
import '../models/reminder.dart';
import '../models/rule.dart';
import '../models/shift.dart';
import '../models/shortage.dart';
import '../models/supplier.dart';
import 'sha256.dart';

/// خطأ نسخ احتياطي برسالة عربية جاهزة للعرض.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

/// المفاتيح اللي بتدخل النسخة الاحتياطية (بيانات التشغيل + الإعدادات).
/// خارجها عمدًا: سجل المحادثة، العمليات المعلّقة، مفاتيح منع التكرار، سجل التشخيص.
class BackupKeys {
  BackupKeys._();

  /// قوائم سجلات JSON (كل سجل نص JSON) — بتتفحص سجل سجل قبل أي استرجاع.
  static const lists = <String>[
    'employees',
    'suppliers',
    'customers',
    'commitments',
    'reminders',
    'rules',
    'shifts',
    'daily_closings',
    'shortages',
    'audit_log',
  ];

  /// إعدادات بسيطة: النوع 's' نص · 'b' منطقي · 'i' صحيح.
  static const scalars = <String, String>{
    'pref_theme_mode': 's',
    'pref_language': 's',
    'notif_cat_reminders': 'b',
    'notif_cat_suppliers': 'b',
    'notif_cat_rules': 'b',
    'notif_lead_minutes': 'i',
    'cafe_name': 's',
    'cafe_logo_path': 's',
    'business_day_start_hour': 'i',
  };

  static const photoPrefix = 'backup-file:';
}

/// لقطة جاهزة للكتابة/القراءة: قيم المفاتيح + ملفات الصور (base64).
/// شكل القيمة: {'t': 'sl'|'s'|'b'|'i', 'v': ...}
class BackupSnapshot {
  final Map<String, dynamic> prefs;
  final Map<String, String> files;
  const BackupSnapshot(this.prefs, this.files);
}

class BackupSummary {
  final Map<String, int> counts;
  final double receivables;
  final double suppliersDue;
  const BackupSummary(this.counts, this.receivables, this.suppliersDue);

  Map<String, dynamic> toJson() =>
      {'counts': counts, 'receivables': receivables, 'suppliersDue': suppliersDue};
}

class BackupDecoded {
  final int schemaVersion;
  final DateTime createdAt;
  final String appVersion;
  final BackupSummary summary;
  final BackupSnapshot snapshot;
  const BackupDecoded(this.schemaVersion, this.createdAt, this.appVersion, this.summary, this.snapshot);
}

class BackupCodec {
  BackupCodec._();

  static const String format = 'manager_assistant_backup';
  static const int schemaVersion = 1;
  static const String appId = 'com.moamen.manager_assistant';

  static final Map<String, Object Function(Map<String, dynamic>)> _parsers = {
    'employees': Employee.fromJson,
    'suppliers': Supplier.fromJson,
    'customers': Customer.fromJson,
    'commitments': Commitment.fromJson,
    'reminders': Reminder.fromJson,
    'rules': FollowUpRule.fromJson,
    'shifts': Shift.fromJson,
    'daily_closings': DailyClosing.fromJson,
    'shortages': ShortageItem.fromJson,
    'audit_log': AuditEntry.fromJson,
  };

  // ───────────────────────────── ملخص ─────────────────────────────

  static List<Object> _parseList(String key, List<dynamic> raw) {
    final parse = _parsers[key]!;
    final out = <Object>[];
    for (var i = 0; i < raw.length; i++) {
      try {
        final j = jsonDecode(raw[i] as String);
        if (j is! Map) throw const FormatException('not a map');
        out.add(parse(Map<String, dynamic>.from(j)));
      } catch (_) {
        throw BackupException('الملف فيه سجل تالف في «${_label(key)}» (رقم ${i + 1}). '
            'مفيش حاجة اتغيّرت في بياناتك.');
      }
    }
    return out;
  }

  static String _label(String key) => const {
        'employees': 'الموظفين',
        'suppliers': 'الموردين',
        'customers': 'العملاء',
        'commitments': 'الالتزامات',
        'reminders': 'التذكيرات',
        'rules': 'القواعد',
        'shifts': 'الشيفتات',
        'daily_closings': 'الإقفالات اليومية',
        'shortages': 'النواقص',
        'audit_log': 'سجل التصحيحات',
      }[key]!;

  /// عدّ وأرصدة النسخة (للمعاينة قبل الاسترجاع وللمقارنة في الاختبارات).
  static BackupSummary summarize(Map<String, dynamic> prefs) {
    final counts = <String, int>{};
    var recv = 0.0, due = 0.0;
    for (final key in BackupKeys.lists) {
      final e = prefs[key];
      final raw = e == null ? const <dynamic>[] : (e['v'] as List);
      final parsed = _parseList(key, raw);
      counts[key] = parsed.length;
      if (key == 'customers') recv = totalReceivables(parsed.cast<Customer>());
      if (key == 'suppliers') {
        due = parsed.cast<Supplier>().fold(0.0, (s, x) => s + x.balanceDue);
      }
    }
    return BackupSummary(counts, recv, due);
  }

  // ───────────────────────────── ترميز ─────────────────────────────

  static String encode(BackupSnapshot snap, {required DateTime now, required String appVersion}) {
    final summary = summarize(snap.prefs);
    final payload = jsonEncode({'prefs': snap.prefs, 'files': snap.files});
    return jsonEncode({
      'format': format,
      'schemaVersion': schemaVersion,
      'appId': appId,
      'appVersion': appVersion,
      'createdAt': now.toIso8601String(),
      'summary': summary.toJson(),
      'checksumAlgo': 'sha256',
      'checksum': sha256Hex(utf8.encode(payload)),
      'payload': payload,
    });
  }

  // ───────────────────────────── فك وتحقق ─────────────────────────────

  /// يفك الملف ويتحقق منه **كله** (صيغة، إصدار، سلامة، كل سجل). أي مشكلة =
  /// [BackupException] قبل ما أي حاجة تتكتب — مفيش استرجاع جزئي.
  static BackupDecoded decode(String text) {
    if (text.trim().isEmpty) {
      throw const BackupException('الملف فاضي.');
    }
    Map<String, dynamic> env;
    try {
      final j = jsonDecode(text);
      if (j is! Map) throw const FormatException('not a map');
      env = Map<String, dynamic>.from(j);
    } catch (_) {
      throw const BackupException('الملف ده مش نسخة احتياطية سليمة (تالف أو مقطوع).');
    }
    if (env['format'] != format) {
      throw const BackupException('الملف ده مش نسخة احتياطية من مساعد الإدارة.');
    }
    final ver = env['schemaVersion'];
    if (ver is! int || ver < 1) {
      throw const BackupException('إصدار النسخة غير معروف.');
    }
    if (ver > schemaVersion) {
      throw const BackupException(
          'النسخة دي اتعملت بإصدار أحدث من التطبيق. حدّث التطبيق الأول وبعدين استرجع.');
    }
    if (env['appId'] != appId) {
      throw const BackupException('النسخة دي تخص تطبيق تاني مش مساعد الإدارة.');
    }
    final payload = env['payload'];
    if (payload is! String || env['checksum'] is! String) {
      throw const BackupException('النسخة ناقصة (مفيش بيانات أو بصمة).');
    }
    if (sha256Hex(utf8.encode(payload)) != env['checksum']) {
      throw const BackupException(
          'الملف اتعدّل أو اتلف (البصمة مش مطابقة). مفيش حاجة اتغيّرت في بياناتك.');
    }
    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      throw const BackupException('محتوى النسخة تالف.');
    }
    final rawPrefs = (body['prefs'] is Map) ? Map<String, dynamic>.from(body['prefs'] as Map) : null;
    if (rawPrefs == null) throw const BackupException('محتوى النسخة ناقص.');

    // نقبل المفاتيح المعروفة بس ونتحقق من نوع كل قيمة.
    final prefs = <String, dynamic>{};
    for (final key in BackupKeys.lists) {
      final e = rawPrefs[key];
      if (e == null) continue;
      if (e is! Map || e['t'] != 'sl' || e['v'] is! List || (e['v'] as List).any((x) => x is! String)) {
        throw BackupException('بيانات «${_label(key)}» غير صالحة.');
      }
      prefs[key] = {'t': 'sl', 'v': List<String>.from(e['v'] as List)};
    }
    BackupKeys.scalars.forEach((key, t) {
      final e = rawPrefs[key];
      if (e == null) return;
      final ok = e is Map &&
          e['t'] == t &&
          ((t == 's' && e['v'] is String) ||
              (t == 'b' && e['v'] is bool) ||
              (t == 'i' && e['v'] is int));
      if (!ok) throw BackupException('إعداد «$key» غير صالح.');
      prefs[key] = {'t': t, 'v': e['v']};
    });

    final files = <String, String>{};
    final rawFiles = body['files'];
    if (rawFiles != null) {
      if (rawFiles is! Map) throw const BackupException('الصور في النسخة غير صالحة.');
      final nameOk = RegExp(r'^[A-Za-z0-9._-]{1,120}$');
      rawFiles.forEach((k, v) {
        if (k is! String || v is! String || !nameOk.hasMatch(k)) {
          throw const BackupException('اسم صورة غير صالح في النسخة.');
        }
        try {
          base64Decode(v);
        } catch (_) {
          throw const BackupException('صورة تالفة في النسخة.');
        }
        files[k] = v;
      });
    }

    final summary = summarize(prefs); // بيفحص كل سجل
    DateTime created;
    try {
      created = DateTime.parse(env['createdAt'] as String);
    } catch (_) {
      throw const BackupException('تاريخ النسخة غير صالح.');
    }
    return BackupDecoded(ver, created, (env['appVersion'] ?? '') as String, summary,
        BackupSnapshot(prefs, files));
  }

  // ───────────────────────────── الصور ─────────────────────────────

  static String _baseName(String path) {
    final i = path.lastIndexOf(RegExp(r'[\\/]'));
    return i < 0 ? path : path.substring(i + 1);
  }

  /// يشيل مسارات الصور المطلقة (بتفرق من جهاز لجهاز) ويحط مكانها
  /// `backup-file:<اسم>` ويحط بايتات الصورة في الملفات. صورة مفقودة = مسار فاضي.
  static BackupSnapshot packPhotos(Map<String, dynamic> prefs, String? Function(String path) readBase64) {
    final out = Map<String, dynamic>.from(prefs);
    final files = <String, String>{};

    String pack(String path) {
      if (path.isEmpty) return '';
      final b64 = readBase64(path);
      if (b64 == null) return '';
      final name = _baseName(path);
      files[name] = b64;
      return '${BackupKeys.photoPrefix}$name';
    }

    final emp = prefs['employees'];
    if (emp != null) {
      final list = <String>[];
      for (final s in (emp['v'] as List)) {
        final m = Map<String, dynamic>.from(jsonDecode(s as String) as Map);
        final p = (m['photoPath'] ?? '') as String;
        if (p.isNotEmpty) m['photoPath'] = pack(p);
        list.add(jsonEncode(m));
      }
      out['employees'] = {'t': 'sl', 'v': list};
    }
    final logo = prefs['cafe_logo_path'];
    if (logo != null) {
      out['cafe_logo_path'] = {'t': 's', 'v': pack(logo['v'] as String)};
    }
    return BackupSnapshot(out, files);
  }

  /// العكس: يرجّع مسارات الصور لمسارات الجهاز الجديدة. مرجع لصورة مش موجودة = مسار فاضي.
  static Map<String, dynamic> unpackPhotos(
      Map<String, dynamic> prefs, Set<String> availableFiles, String Function(String name) destPathFor) {
    final out = Map<String, dynamic>.from(prefs);

    String unpack(String v) {
      if (!v.startsWith(BackupKeys.photoPrefix)) return '';
      final name = v.substring(BackupKeys.photoPrefix.length);
      return availableFiles.contains(name) ? destPathFor(name) : '';
    }

    final emp = prefs['employees'];
    if (emp != null) {
      final list = <String>[];
      for (final s in (emp['v'] as List)) {
        final m = Map<String, dynamic>.from(jsonDecode(s as String) as Map);
        final p = (m['photoPath'] ?? '') as String;
        if (p.isNotEmpty) m['photoPath'] = unpack(p);
        list.add(jsonEncode(m));
      }
      out['employees'] = {'t': 'sl', 'v': list};
    }
    final logo = prefs['cafe_logo_path'];
    if (logo != null) out['cafe_logo_path'] = {'t': 's', 'v': unpack(logo['v'] as String)};
    return out;
  }
}
