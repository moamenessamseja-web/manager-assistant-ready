import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/customer.dart';
import 'package:manager_assistant/models/employee.dart';
import 'package:manager_assistant/services/backup_codec.dart';
import 'package:manager_assistant/services/backup_service.dart';
import 'package:manager_assistant/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/backup_sample.dart';

/// بديل تخزين بيفشل في كتابة مفتاح معيّن — عشان نجرّب الرجوع التلقائي فعلًا.
class FaultyStore implements PrefsStore {
  final PrefsStore inner;
  final Set<String> failOn;
  bool armed = false;
  FaultyStore(this.inner, this.failOn);
  bool _fail(String k) => armed && failOn.contains(k);
  @override
  Object? get(String k) => inner.get(k);
  @override
  bool containsKey(String k) => inner.containsKey(k);
  @override
  List<String>? getStringList(String k) => inner.getStringList(k);
  @override
  String? getString(String k) => inner.getString(k);
  @override
  Future<bool> setStringList(String k, List<String> v) async => _fail(k) ? false : inner.setStringList(k, v);
  @override
  Future<bool> setString(String k, String v) async => _fail(k) ? false : inner.setString(k, v);
  @override
  Future<bool> setBool(String k, bool v) async => _fail(k) ? false : inner.setBool(k, v);
  @override
  Future<bool> setInt(String k, int v) async => _fail(k) ? false : inner.setInt(k, v);
  @override
  Future<bool> remove(String k) async => _fail(k) ? false : inner.remove(k);
}

Future<void> seed(SharedPreferences p, Directory photos) async {
  final data = sampleData();
  // صور حقيقية على القرص بمسارات الجهاز القديم
  final empPhoto = File('${photos.path}/e1_1.jpg')..writeAsBytesSync(utf8.encode('EMPLOYEE-PHOTO-BYTES'));
  final logo = File('${photos.path}/logo_1.jpg')..writeAsBytesSync(utf8.encode('LOGO-BYTES'));
  final emps = (data['employees']['v'] as List).map((s) {
    final m = Map<String, dynamic>.from(jsonDecode(s as String) as Map);
    if (m['id'] == 'e1') m['photoPath'] = empPhoto.path;
    return jsonEncode(m);
  }).toList();
  data['employees'] = {'t': 'sl', 'v': emps};
  data['cafe_logo_path'] = {'t': 's', 'v': logo.path};
  for (final e in data.entries) {
    final t = e.value['t'];
    if (t == 'sl') await p.setStringList(e.key, List<String>.from(e.value['v'] as List));
    if (t == 's') await p.setString(e.key, e.value['v'] as String);
    if (t == 'b') await p.setBool(e.key, e.value['v'] as bool);
    if (t == 'i') await p.setInt(e.key, e.value['v'] as int);
  }
}

/// لقطة قابلة للمقارنة من الحالة الحالية (من غير مسارات الصور اللي بتتغيّر).
Map<String, dynamic> comparable(PrefsStore p) {
  final raw = BackupService.readPrefs(p);
  final out = <String, dynamic>{};
  raw.forEach((k, v) {
    if (k == 'cafe_logo_path') return;
    if (k == 'employees') {
      out[k] = (v['v'] as List).map((s) {
        final m = Map<String, dynamic>.from(jsonDecode(s as String) as Map);
        m.remove('photoPath');
        return m;
      }).toList();
    } else if (v['t'] == 'sl') {
      out[k] = (v['v'] as List).map((s) => jsonDecode(s as String)).toList();
    } else {
      out[k] = v['v'];
    }
  });
  return out;
}

void main() {
  late SharedPreferences p;
  late PrefsStore store;
  late Directory root, photosOld, docs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    p = await SharedPreferences.getInstance();
    store = SharedPrefsStore(p);
    await StorageService.init();
    root = Directory.systemTemp.createTempSync('ma_backup_test');
    photosOld = Directory('${root.path}/old_photos')..createSync();
    docs = Directory('${root.path}/docs')..createSync();
    BackupService.baseDir = () async => docs;
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('دورة استرجاع كاملة على التخزين الفعلي', () {
    test('تصدير ← مسح كل حاجة ← استرجاع ← نفس البيانات والأرصدة والأعداد', () async {
      await seed(p, photosOld);
      final before = comparable(store);
      final custBefore = totalReceivables(StorageService.customers());
      final supDue = StorageService.suppliers().fold(0.0, (s, x) => s + x.balanceDue);
      final e1Before = StorageService.employees().firstWhere((e) => e.id == 'e1');
      expect(custBefore, 700);
      expect(supDue, 600);

      final text = BackupService.buildBackupText(store, now: DateTime(2026, 11, 22, 10));
      // مسح كل شيء (زي تليفون جديد) + مسح الصور القديمة
      await p.clear();
      photosOld.deleteSync(recursive: true);
      expect(StorageService.customers(), isEmpty);
      expect(StorageService.employees(), isEmpty);

      final decoded = BackupCodec.decode(text);
      final res = await BackupService.restore(store, decoded, now: DateTime(2026, 11, 22, 11));
      expect(res.restored.counts['customers'], 2);

      // نفس السجلات حرفيًا (غير مسارات الصور)
      expect(comparable(store), before);
      // نفس الأرصدة والأعداد من خلال التخزين الفعلي
      expect(totalReceivables(StorageService.customers()), custBefore);
      expect(StorageService.suppliers().fold(0.0, (s, x) => s + x.balanceDue), supDue);
      expect(StorageService.employees().length, 2);
      expect(StorageService.customers().length, 2);
      expect(StorageService.commitments().single.customerId, 'c1');
      final e1 = StorageService.employees().firstWhere((e) => e.id == 'e1');
      expect(e1.totalAdvances, e1Before.totalAdvances);
      expect(e1.payments.single.amount, 900);
      expect(StorageService.shifts().single.snapshot!.cashSales, 700);
      expect(StorageService.dailyClosings().single.totals.collections, 100);
      expect(StorageService.shortages().single.status, 'ordered');
      expect(StorageService.auditLog().single.reason, 'غلطة');
      // الصور رجعت لمسار جديد وبنفس المحتوى
      expect(e1.photoPath.startsWith(docs.path), isTrue);
      expect(File(e1.photoPath).readAsStringSync(), 'EMPLOYEE-PHOTO-BYTES');
      final logoPath = (BackupService.readPrefs(store)['cafe_logo_path']['v']) as String;
      expect(File(logoPath).readAsStringSync(), 'LOGO-BYTES');
      // الإعدادات
      expect(p.getString('cafe_name'), 'كافيه النيل');
      expect(p.getBool('notif_cat_rules'), false);
      expect(p.getInt('notif_lead_minutes'), 15);
    });

    test('الاسترجاع استبدال مش دمج: مفيش سجلات مكررة ولا بقايا من بيانات تانية', () async {
      await seed(p, photosOld);
      final text = BackupService.buildBackupText(store);
      // بيانات حالية مختلفة: عميل إضافي وموظف إضافي
      final extra = Customer(id: 'cX', name: 'غريب')..addSale(CreditSale(id: 'x', item: '', total: 9, date: DateTime(2026, 11, 22)));
      await StorageService.saveCustomer(extra);
      await StorageService.saveEmployee(Employee(
          id: 'eX', name: 'زيادة', role: '', startDate: DateTime(2026, 11, 22), salaryMonthly: 1));
      await BackupService.restore(store, BackupCodec.decode(text));
      expect(StorageService.customers().map((c) => c.id).toList()..sort(), ['c1', 'c2']);
      expect(StorageService.employees().map((c) => c.id).toList()..sort(), ['e1', 'e2']);
      // استرجاع نفس الملف مرتين = نفس النتيجة (مفيش تكرار)
      await BackupService.restore(store, BackupCodec.decode(text));
      expect(StorageService.customers().length, 2);
      expect(StorageService.suppliers().single.payments.length, 1);
    });

    test('نسخة أمان تلقائية قبل الاسترجاع، والاسترجاع منها بيرجّع الحالة القديمة', () async {
      await seed(p, photosOld);
      final text = BackupService.buildBackupText(store);
      // حالة حالية مختلفة تمامًا
      await StorageService.saveCustomer(Customer(id: 'now', name: 'الحالي')
        ..addSale(CreditSale(id: 'n', item: '', total: 55, date: DateTime(2026, 11, 22))));
      final currentBefore = comparable(store);
      final res = await BackupService.restore(store, BackupCodec.decode(text), now: DateTime(2026, 11, 22, 12, 30, 5));
      expect(res.safetyBackupName, contains('before_restore_20261122_123005'));
      expect(StorageService.customers().any((c) => c.id == 'now'), isFalse);
      final safeties = await BackupService.safetyBackups();
      expect(safeties.length, 1);
      // الرجوع للحالة السابقة من نسخة الأمان
      await BackupService.restore(store, BackupCodec.decode(safeties.first.readAsStringSync()),
          now: DateTime(2026, 11, 22, 12, 40));
      expect(comparable(store), currentBefore);
    });

    test('نسخ الأمان محدودة بآخر ٥', () async {
      await seed(p, photosOld);
      final decoded = BackupCodec.decode(BackupService.buildBackupText(store));
      for (var i = 0; i < 7; i++) {
        await BackupService.restore(store, decoded, now: DateTime(2026, 11, 22, 12, i));
      }
      expect((await BackupService.safetyBackups()).length, 5);
    });
  });

  group('ملفات فاسدة ومفيش استرجاع جزئي', () {
    test('ملف تالف/مقطوع ماينفعش يغيّر ولا مفتاح', () async {
      await seed(p, photosOld);
      final snapshotBefore = BackupService.readPrefs(store);
      final text = BackupService.buildBackupText(store);
      for (final bad in ['', 'x', text.substring(0, text.length - 40), text.replaceFirst('"checksum":"', '"checksum":"0')]) {
        expect(() => BackupCodec.decode(bad), throwsA(isA<BackupException>()));
      }
      // decode بيرفض قبل ما أي restore يتنادى — الحالة ثابتة
      expect(jsonEncode(BackupService.readPrefs(store)), jsonEncode(snapshotBefore));
    });

    test('فشل كتابة في النص = رجوع تلقائي لبيانات اللحظة (الكل أو لا شيء)', () async {
      await seed(p, photosOld);
      final text = BackupService.buildBackupText(store);
      // حالة حالية مختلفة
      await StorageService.saveCustomer(Customer(id: 'now', name: 'الحالي')
        ..addSale(CreditSale(id: 'n', item: '', total: 55, date: DateTime(2026, 11, 22))));
      final before = jsonEncode(BackupService.readPrefs(store));
      final faulty = FaultyStore(store, {'rules'})..armed = true; // مفتاح في نص ترتيب الكتابة
      try {
        await BackupService.restore(faulty, BackupCodec.decode(text));
        throw 'كان المفروض يفشل';
      } on BackupException catch (e) {
        expect(e.message, contains('رجّعنا بياناتك'));
      }
      faulty.armed = false;
      expect(jsonEncode(BackupService.readPrefs(store)), before);
      expect(StorageService.customers().any((c) => c.id == 'now'), isTrue);
    });
  });

  group('تصدير لملف قابل للمشاركة', () {
    test('اسم الملف بتاريخه، والمحتوى بيتفك، وتاريخ آخر نسخة بيتسجّل', () async {
      await seed(p, photosOld);
      final f = await BackupService.exportToTempFile(store, now: DateTime(2026, 11, 22, 9, 5), dir: root);
      expect(f.path.endsWith('manager_assistant_backup_2026-11-22_0905.json'), isTrue);
      final d = BackupCodec.decode(f.readAsStringSync());
      expect(d.summary.counts['employees'], 2);
      expect(BackupService.lastBackupAt(store), DateTime(2026, 11, 22, 9, 5));
    });
  });
}
