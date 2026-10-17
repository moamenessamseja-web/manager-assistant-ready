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
      // فعل «جاب» نفسه ما يتحسبش اسم وهمي تاني (كان بيحصل قبل الإصلاح).
      expect((r.fields['people'] as List?) ?? const [], isEmpty);
    });

    // مثال البريف بالظبط (مهمة_2026-10-16 §1): توريد مكتمل بكمية بس من غير
    // قيمة مذكورة صراحةً. قبل الإصلاح كان بيحصل خطآن مركّبان:
    // 1) الكمية (٢٠) كانت بتُفسَّر غلط كقيمة توريد = ٢٠ جنيه.
    // 2) «المورد» (الكلمة الوظيفية العامة) كانت بتُستخرج كاسم مستقل، فيحصل
    //    تنفيذ العملية مرتين — مرة لـ«المورد» ومرة لـ«عجمي».
    test('«المورد عجمي جاب الآن ٢٠ كيلو سكر» — كمية من غير قيمة: لا تخمين ولا تكرار',
        () {
      final r =
          LocalCommandParser.parse('المورد عجمي جاب الآن ٢٠ كيلو سكر');
      expect(r.intent, 'record_purchase');
      // اسم واحد بس: «عجمي» — مش «المورد» ومش الاتنين.
      expect(r.fields['person'], 'عجمي');
      expect((r.fields['people'] as List?) ?? const [], isEmpty);
      // الكمية اتسجلت صح كـ«كمية»، مش كقيمة مالية.
      expect(r.fields['purchase_quantity'], 20);
      expect(r.fields['purchase_unit'], 'كيلو');
      // ومفيش قيمة اتخمّنت من عدم — ده لازم يخلّي الأمر غير واثق فيسأل.
      expect(r.fields['amount'], isNull);
      expect(r.fields['purchase_total'], isNull);
      expect(r.confident, isFalse);
      expect(r.clarification, isNotNull);
    });

    test('«المورد عجمي دفع كذا» ما زال بيميّز اسم المورد الحقيقي من «المورد»',
        () {
      final r = LocalCommandParser.parse('دفعت للمورد عجمي 500 جنيه');
      expect(r.intent, 'add_supplier_payment');
      expect(r.fields['person'], 'عجمي');
      expect(r.fields['amount'], 500);
    });

    test('كمية+وحدة مع قيمة صريحة لسه بتتسجل صح (مفيش تأثير جانبي للإصلاح)',
        () {
      final r =
          LocalCommandParser.parse('سالم جاب 20 كيلو سكر بـ300 جنيه');
      expect(r.intent, 'record_purchase');
      expect(r.fields['purchase_quantity'], 20);
      expect(r.fields['purchase_unit'], 'كيلو');
      expect(r.fields['purchase_total'], 300);
      expect(r.confident, isTrue);
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

  group('Phase B — كمية ≠ مبلغ، يوم/ساعة صريحين، واو العطف الملتصقة', () {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    test('«٢٠ كيلو سكر» كمية، مش مبلغ — ويسأل عن القيمة', () {
      final r = LocalCommandParser.parse('المورد عجمي جاب الآن ٢٠ كيلو سكر');
      expect(r.intent, 'record_purchase');
      expect(r.confident, isFalse);
      expect(r.fields['amount'], isNull);
      expect(r.fields['purchase_quantity'], 20);
      expect(r.fields['purchase_unit'], 'كيلو');
      expect(r.fields['purchase_item'], 'سكر');
      expect(r.clarification, contains('قيمة'));
    });

    test('«جمال هيجيب بكرة ٥ كراتين لبن إجمالي ١٠٠٠ جنيه» → توريد متوقع، ويسأل عن الساعة',
        () {
      final r = LocalCommandParser.parse(
          'جمال هيجيب بكرة ٥ كراتين لبن إجمالي ١٠٠٠ جنيه');
      expect(r.intent, 'supplier_delivery');
      expect(r.fields['person'], 'جمال');
      expect(r.fields['due_date'], ymd(tomorrow));
      expect(r.fields['delivery_quantity'], 5);
      expect(r.fields['delivery_unit'], 'كراتين');
      expect(r.fields['delivery_item'], 'لبن');
      expect(r.fields['amount'], 1000);
      expect(r.fields['time'], isNull); // مفيش ساعة من عندنا
      expect(r.confident, isFalse);
    });

    test('توريد متوقع بيوم وساعة صريحين = واضح', () {
      final r = LocalCommandParser.parse(
          'جمال هيجيب بكرة الساعة ٥ العصر ٥ كراتين لبن إجمالي ١٠٠٠ جنيه');
      expect(r.intent, 'supplier_delivery');
      expect(r.fields['time'], '17:00');
      expect(r.fields['due_date'], ymd(tomorrow));
      expect(r.fields['amount'], 1000);
      expect(r.confident, isTrue);
    });

    test('تذكير بتاريخ وساعة صريحين', () {
      final r = LocalCommandParser.parse(
          'افتكر ادفع الايجار يوم ٢٠ اكتوبر الساعة ٩ صباحا');
      expect(r.intent, 'create_commitment');
      expect(r.fields['person'], 'عام');
      expect((r.fields['due_date'] as String).endsWith('-10-20'), isTrue);
      expect(r.fields['time'], '09:00');
      expect(r.fields['amount'], isNull); // ٢٠ و٩ مش مبالغ
      expect(r.confident, isTrue);
    });

    test('تذكير بدون ساعة أو بساعة ملتبسة → مش واضح (يسأل، ما يخمّنش)', () {
      final noTime = LocalCommandParser.parse('فكرني بكرة اتصل بالعميل');
      expect(noTime.intent, 'create_commitment');
      expect(noTime.fields['time'], isNull);
      expect(noTime.confident, isFalse);
      final ambiguous =
          LocalCommandParser.parse('فكرني بكرة الساعة ٥ اتصل بالعميل');
      expect(ambiguous.fields['time'], isNull);
      expect(ambiguous.fields['time_hour_raw'], 5);
      expect(ambiguous.confident, isFalse);
      final noDay = LocalCommandParser.parse('فكرني الساعة ٥ العصر اتصل بالعميل');
      expect(noDay.fields['due_date'], isNull);
      expect(noDay.confident, isFalse);
    });

    test('واو العطف الملتصقة: «محمود وخالد» شخصين، مش واحد', () {
      final r = LocalCommandParser.parse('حضر محمود وخالد');
      expect(r.intent, 'mark_attendance');
      expect(r.fields['people'], ['محمود', 'خالد']);
    });

    test('اسم بيبدأ بواو لا تتفصل منه الواو', () {
      final r = LocalCommandParser.parse('حضر وليد');
      expect(r.fields['person'], 'وليد');
    });

    test('استخراج الخانات من ردود قصيرة', () {
      expect(
          LocalCommandParser.extractSlots('٣٠٠', expect: {'amount'})['amount'],
          300);
      final when = LocalCommandParser.extractSlots('بكرة الساعة ٥ العصر');
      expect(when['due_date'], ymd(tomorrow));
      expect(when['time'], '17:00');
      expect(
          LocalCommandParser.extractSlots('مساء', hourHint: 5)['time'], '17:00');
      expect(
          LocalCommandParser.extractSlots('٥', expect: {'time'})['time_hour_raw'],
          5);
    });
  });
}
