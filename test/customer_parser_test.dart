import 'package:flutter_test/flutter_test.dart';
import 'package:manager_assistant/models/customer.dart';
import 'package:manager_assistant/services/local_command_parser.dart';

/// فهم أوامر العملاء (المستحقات) + حسابات الفترات — نقي (من غير تخزين)، offline.
CommandResultLike p(String s) => CommandResultLike(LocalCommandParser.parse(s));

class CommandResultLike {
  final dynamic r;
  CommandResultLike(this.r);
  String get intent => r.intent as String;
  bool get confident => r.confident as bool;
  Map<String, dynamic> get f => Map<String, dynamic>.from(r.fields as Map);
}

void main() {
  group('عملاء — بيع آجل / زيادة', () {
    test('«ضيف على حموده ١٠٠ جنيه طلبات بتاريخ ٢٠ نوفمبر»', () {
      final r = p('ضيف على حموده ١٠٠ جنيه طلبات بتاريخ ٢٠ نوفمبر');
      expect(r.intent, 'customer_charge');
      expect(r.f['person'], 'حموده');
      expect(r.f['amount'], 100.0);
      expect(r.f['sale_item'], 'طلبات');
      final d = DateTime.parse(r.f['entry_date'] as String);
      expect(d.month, 11);
      expect(d.day, 20);
      // تاريخ ماضي أو النهارده — مش السنة الجاية.
      expect(d.isAfter(DateTime.now()), isFalse);
      expect(r.f.containsKey('due_date'), isFalse);
    });

    test('«زود على جمال ٢٠٠ جنيه»', () {
      final r = p('زود على جمال ٢٠٠ جنيه');
      expect(r.intent, 'customer_charge');
      expect(r.f['person'], 'جمال');
      expect(r.f['amount'], 200.0);
      expect(r.confident, isTrue);
    });

    test('«سجل طلبات على محمد بخمسمية جنيه» (كلمات أعداد)', () {
      final r = p('سجل طلبات على محمد بخمسمية جنيه');
      expect(r.intent, 'customer_charge');
      expect(r.f['person'], 'محمد');
      expect(r.f['amount'], 500.0);
    });

    test('أرقام هندية + «امبارح»', () {
      final r = p('زود على جمال ٢٥٠ جنيه امبارح');
      expect(r.intent, 'customer_charge');
      expect(r.f['amount'], 250.0);
      final d = DateTime.parse(r.f['entry_date'] as String);
      final now = DateTime.now();
      final y = DateTime(now.year, now.month, now.day - 1);
      expect(DateTime(d.year, d.month, d.day), y);
    });

    test('كمية ≠ مبلغ: «٥ كراتين لبن ٢٠٠ جنيه»', () {
      final r = p('ضيف على جمال ٥ كراتين لبن ٢٠٠ جنيه');
      expect(r.intent, 'customer_charge');
      expect(r.f['amount'], 200.0);
      expect(r.f['sale_quantity'], 5.0);
      expect(r.f['sale_unit'], 'كراتين');
    });

    test('من غير مبلغ = مش واضح (يسأل)', () {
      final r = p('زود على جمال');
      expect(r.intent, 'customer_charge');
      expect(r.confident, isFalse);
    });

    test('«ضيف على علي ١٠٠ جنيه» (علي اسم شخص)', () {
      final r = p('ضيف على علي ١٠٠ جنيه');
      expect(r.intent, 'customer_charge');
      expect(r.f['person'], 'علي');
    });
  });

  group('عملاء — دفعات وتحصيل', () {
    test('«جمال دفع ٢٠٠ جنيه»', () {
      final r = p('جمال دفع ٢٠٠ جنيه');
      expect(r.intent, 'customer_payment');
      expect(r.f['person'], 'جمال');
      expect(r.f['amount'], 200.0);
    });

    test('«حموده سدد ١٠٠ من حسابه»', () {
      final r = p('حموده سدد ١٠٠ من حسابه');
      expect(r.intent, 'customer_payment');
      expect(r.f['person'], 'حموده');
      expect(r.f['amount'], 100.0);
    });

    test('«خصم من دين محمد ٣٠٠ جنيه» دفعة عميل مش خصم موظف', () {
      final r = p('خصم من دين محمد ٣٠٠ جنيه');
      expect(r.intent, 'customer_payment');
      expect(r.f['person'], 'محمد');
      expect(r.f['amount'], 300.0);
    });

    test('دفع بدون مبلغ = يسأل', () {
      final r = p('حموده سدد من حسابه');
      expect(r.intent, 'customer_payment');
      expect(r.confident, isFalse);
    });
  });

  group('عملاء — ما يتلخبطوش مع الموظفين والموردين', () {
    test('«دفعت لجمال ٥٠٠» = دفع لمورد (المتكلم دفع)', () {
      expect(p('دفعت لجمال ٥٠٠').intent, 'add_supplier_payment');
    });
    test('«اخصم من أحمد ١٠٠ جنيه» = خصم موظف زي ما هو', () {
      expect(p('اخصم من أحمد ١٠٠ جنيه').intent, 'add_deduction');
    });
    test('«ضيف سلفة على احمد ٢٠٠» = سلفة موظف مش بيع آجل', () {
      expect(p('ضيف سلفة على احمد ٢٠٠').intent, 'add_advance');
    });
    test('تذكير عادي ما يتحوّلش لوعد دفع', () {
      expect(p('فكرني ادفع الايجار بكرة الساعة 9 صباحا').intent,
          'create_commitment');
    });
  });

  group('عملاء — تسجيل عميل ورصيد افتتاحي', () {
    test('«ضيف عميل جديد حموده عليه ٥٠٠» اتجاه واضح', () {
      final r = p('ضيف عميل جديد حموده عليه ٥٠٠');
      expect(r.intent, 'add_customer');
      expect(r.f['customer_name'], 'حموده');
      expect(r.f['opening_balance'], 500.0);
      expect(r.f['opening_direction'], 'owes');
    });
    test('«سجل عميل جمال له ٣٠٠» = له فلوس عندنا', () {
      final r = p('سجل عميل جمال له ٣٠٠');
      expect(r.f['opening_direction'], 'credit');
    });
    test('رصيد من غير اتجاه = الاتجاه مش متحدد (لازم سؤال)', () {
      final r = p('ضيف عميل جمال ٥٠٠');
      expect(r.intent, 'add_customer');
      expect(r.f['opening_balance'], 500.0);
      expect(r.f.containsKey('opening_direction'), isFalse);
    });
    test('عميل بدون رصيد', () {
      final r = p('عميل جديد جمال');
      expect(r.intent, 'add_customer');
      expect(r.f.containsKey('opening_balance'), isFalse);
    });
  });

  group('عملاء — وعد بالدفع (مش دفعة)', () {
    test('«فكرني صبحي هيدفع ٤٠٠ من دينه بكرة الساعة 5 مساء»', () {
      final r = p('فكرني صبحي هيدفع ٤٠٠ من دينه بكرة الساعة 5 مساء');
      expect(r.intent, 'customer_promise');
      expect(r.f['person'], 'صبحي');
      expect(r.f['amount'], 400.0);
      expect(r.f['time'], '17:00');
      expect(r.confident, isTrue);
    });
    test('من غير ساعة = مش جاهز (يسأل، مفيش ساعة مخترعة)', () {
      final r = p('فكرني صبحي هيدفع ٤٠٠ من دينه بكرة');
      expect(r.intent, 'customer_promise');
      expect(r.confident, isFalse);
      expect(r.f.containsKey('time'), isFalse);
    });
    test('«صبحي وعدني يدفع باقي الحساب يوم الخميس» — بدون مبلغ، بدون اسم وهمي',
        () {
      final r = p('صبحي وعدني يدفع باقي الحساب يوم الخميس');
      expect(r.intent, 'customer_promise');
      expect(r.f['person'], 'صبحي');
      expect(r.f.containsKey('amount'), isFalse);
      expect(r.f.containsKey('people'), isFalse);
    });
  });

  group('عملاء — استعلامات', () {
    test('«حساب جمال كام؟»', () {
      final r = p('حساب جمال كام؟');
      expect(r.f['query_type'], 'account_lookup');
      expect(r.f['person'], 'جمال');
    });
    test('«وريني حساب حموده»', () {
      final r = p('وريني حساب حموده');
      expect(r.f['query_type'], 'account_lookup');
      expect(r.f['person'], 'حموده');
    });
    test('«مين عليه فلوس؟»', () {
      expect(p('مين عليه فلوس؟').f['query_type'], 'debtors');
    });
    test('«جمال دفع كام الأسبوع ده؟»', () {
      final r = p('جمال دفع كام الأسبوع ده؟');
      expect(r.f['query_type'], 'customer_payments_period');
      expect(r.f['person'], 'جمال');
      expect(r.f['period'], 'week');
    });
    test('«مين دفع النهارده؟»', () {
      final r = p('مين دفع النهارده؟');
      expect(r.f['query_type'], 'customer_payments_period');
      expect(r.f['period'], 'today');
    });
    test('حساب المورد القديم ما اتغيّرش', () {
      expect(p('كام للمورد محمود؟').f['query_type'], 'supplier_balance');
      expect(p('رصيد المورد جمال').f['query_type'], 'supplier_balance');
    });
    test('«مين أخد سلف الأسبوع ده؟» لسه سلف موظفين', () {
      expect(p('مين أخد سلف الأسبوع ده؟').f['query_type'],
          'advances_this_week');
    });
  });

  group('حسابات الفترات — الرصيد الكلي ≠ حركة الأسبوع', () {
    CreditSale sale(String id, double t, DateTime d, {bool opening = false}) =>
        CreditSale(
            id: id, item: opening ? 'رصيد سابق' : 'طلبات', total: t, date: d, opening: opening);
    CustomerPayment pay(String id, double a, DateTime d, {bool opening = false}) =>
        CustomerPayment(id: id, amount: a, date: d, opening: opening);

    test('weekStartSaturday: السبت أول يوم', () {
      // 2026-11-21 = سبت → بداية الأسبوع نفس اليوم.
      expect(weekStartSaturday(DateTime(2026, 11, 21, 15)), DateTime(2026, 11, 21));
      // الأربعاء 2026-11-25 → السبت 21.
      expect(weekStartSaturday(DateTime(2026, 11, 25)), DateTime(2026, 11, 21));
      // الجمعة 2026-11-27 → السبت 21.
      expect(weekStartSaturday(DateTime(2026, 11, 27)), DateTime(2026, 11, 21));
    });

    test('الإجمالي الكلي منفصل عن الأسبوع، والافتتاحي مش مبيعات ولا تحصيل', () {
      final from = DateTime(2026, 11, 21);
      final to = DateTime(2026, 11, 28);
      final a = Customer(id: 'a', name: 'أ')
        ..addSale(sale('o', 1000, DateTime(2026, 11, 22), opening: true)) // افتتاحي
        ..addSale(sale('s0', 300, DateTime(2026, 11, 1))) // قبل الأسبوع
        ..addSale(sale('s1', 200, DateTime(2026, 11, 23))) // في الأسبوع
        ..addPayment(pay('p0', 100, DateTime(2026, 11, 2))) // قبل الأسبوع
        ..addPayment(pay('p1', 150, DateTime(2026, 11, 24))); // في الأسبوع
      final b = Customer(id: 'b', name: 'ب')
        ..addPayment(pay('po', 500, DateTime(2026, 11, 22), opening: true)) // له افتتاحي
        ..addSale(sale('s2', 50, DateTime(2026, 11, 25)));
      final s = receivablesSummary([a, b], from, to);
      // أ: 1000+300+200-100-150 = 1250 ؛ ب: 50-500 = -450 (له) → مش بيتخصم.
      expect(s.outstanding, 1250);
      expect(s.charges, 250); // 200 + 50 (من غير الافتتاحي)
      expect(s.collected, 150); // من غير الافتتاحي له
    });

    test('نفس العملية مش بتتعد مرتين (id مكرر)', () {
      final c = Customer(id: 'a', name: 'أ');
      expect(c.addSale(sale('x', 100, DateTime(2026, 11, 22))), isTrue);
      expect(c.addSale(sale('x', 100, DateTime(2026, 11, 22))), isFalse);
      expect(c.addPayment(pay('y', 40, DateTime(2026, 11, 22))), isTrue);
      expect(c.addPayment(pay('y', 40, DateTime(2026, 11, 22))), isFalse);
      expect(c.balanceDue, 60);
    });

    test('JSON: علامة opening بتتحفظ، والبيانات القديمة (من غيرها) بتتقرا', () {
      final c = Customer(id: 'a', name: 'أ')
        ..addSale(sale('o', 100, DateTime(2026, 11, 22), opening: true));
      final r = Customer.fromJson(c.toJson());
      expect(r.sales.single.opening, isTrue);
      final legacy = CreditSale.fromJson({
        'id': 'l', 'item': 'رصيد سابق', 'total': 300, 'date': '2026-10-01T00:00:00.000'
      });
      expect(legacy.isOpening, isTrue); // الاسم القديم متعرّف عليه
      expect(legacy.opening, isFalse);
    });
  });
}
