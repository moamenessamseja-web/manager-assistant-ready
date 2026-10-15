import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/services/local_command_parser.dart';

/// اختبارات المحلل المحلي — **بدون إنترنت وبدون أي مفتاح API**.
/// أي فشل هنا معناها أن العمليات المحلية لا تعمل offline.
void main() {
  group('التطبيع (normalize)', () {
    test('الأرقام العربية والهندية تُصبح إنجليزية', () {
      expect(LocalCommandParser.normalize('١٠٠٠ جنيه'), '1000 جنيه');
      expect(LocalCommandParser.normalize('۵۰۰ ريال'), '500 ريال');
    });

    test('إزالة التشكيل وتوحيد الألف/التاء/الياء', () {
      expect(LocalCommandParser.normalize('أَحْمَد'), 'احمد');
      expect(LocalCommandParser.normalize('سلفة'), 'سلفه');
      expect(LocalCommandParser.normalize('على'), 'علي');
    });
  });

  group('الحضور', () {
    test('«سجل حضور أحمد»', () {
      final r = LocalCommandParser.parse('سجل حضور أحمد');
      expect(r.intent, 'mark_attendance');
      expect(r.fields['person'], 'احمد');
      expect(r.confident, isTrue);
    });

    test('«أحمد حضر النهارده»', () {
      final r = LocalCommandParser.parse('أحمد حضر النهارده');
      expect(r.intent, 'mark_attendance');
      expect(r.fields['person'], 'احمد');
    });

    test('«اعتبر أحمد حاضر»', () {
      final r = LocalCommandParser.parse('اعتبر أحمد حاضر');
      expect(r.intent, 'mark_attendance');
      expect(r.fields['person'], 'احمد');
    });

    test('اسم ناقص → نية معروفة لكن غير واثقة (تسأل مش تخمّن)', () {
      final r = LocalCommandParser.parse('سجل حضور');
      expect(r.intent, 'mark_attendance');
      expect(r.confident, isFalse);
      expect(r.clarification, isNotNull);
    });
  });

  group('الاستعلامات', () {
    test('«مين محضرش النهارده؟»', () {
      final r = LocalCommandParser.parse('مين محضرش النهارده؟');
      expect(r.intent, 'query_business_data');
      expect(r.fields['query_type'], 'absent_today');
      expect(r.confident, isTrue);
    });

    test('«مين عليه فلوس؟»', () {
      final r = LocalCommandParser.parse('مين عليه فلوس؟');
      expect(r.fields['query_type'], 'debtors');
    });

    test('«كام للمورد محمود؟»', () {
      final r = LocalCommandParser.parse('كام للمورد محمود؟');
      expect(r.fields['query_type'], 'supplier_balance');
      expect(r.fields['person'], 'محمود');
    });

    test('«مين أخد سلف الأسبوع ده؟»', () {
      final r = LocalCommandParser.parse('مين أخد سلف الأسبوع ده؟');
      expect(r.fields['query_type'], 'advances_this_week');
    });
  });

  group('المعاملات المالية', () {
    test('«خصم ألف جنيه من أحمد»', () {
      final r = LocalCommandParser.parse('خصم ألف جنيه من أحمد');
      expect(r.intent, 'add_deduction');
      expect(r.fields['person'], 'احمد');
      expect(r.fields['amount'], 1000);
      expect(r.confident, isTrue);
    });

    test('«على أحمد سلفة ١٠٠٠ جنيه»', () {
      final r = LocalCommandParser.parse('على أحمد سلفة ١٠٠٠ جنيه');
      expect(r.intent, 'add_advance');
      expect(r.fields['person'], 'احمد');
      expect(r.fields['amount'], 1000);
    });

    test('«دفعت لسالم ألفين»', () {
      final r = LocalCommandParser.parse('دفعت لسالم ألفين');
      expect(r.intent, 'add_supplier_payment');
      expect(r.fields['amount'], 2000);
      expect(r.fields['person'].toString().contains('سالم'), isTrue);
    });

    test('«سالم جاب بضاعة بخمسة آلاف»', () {
      final r = LocalCommandParser.parse('سالم جاب بضاعة بخمسة آلاف');
      expect(r.intent, 'record_purchase');
      expect(r.fields['person'], 'سالم');
      expect(r.fields['purchase_total'], 5000);
    });
  });

  group('أسماء متعددة والوظيفة', () {
    test('«سجل حضور محمود و خالد و حسن»', () {
      final r = LocalCommandParser.parse('سجل حضور محمود و خالد و حسن');
      final people = (r.fields['people'] as List?) ?? const [];
      expect(people.length, 3);
      expect(r.fields['person'], 'محمود');
    });

    test('«خصم ١٠٠٠ من أحمد سواق»', () {
      final r = LocalCommandParser.parse('خصم ١٠٠٠ من أحمد سواق');
      expect(r.fields['person'], 'احمد');
      expect(r.fields['person_role'], 'سواق');
    });
  });

  group('أوامر غير مفهومة', () {
    test('نص عشوائي → other (يسقط لـ Gemini لو متاح أو يسأل)', () {
      final r = LocalCommandParser.parse('الجو حر النهارده');
      expect(r.isKnown, isFalse);
      expect(r.intent, 'other');
    });
  });
}
