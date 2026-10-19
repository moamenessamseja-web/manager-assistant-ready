import 'package:flutter/material.dart';
import '../design/tokens.dart';

/// تعليمات الاستخدام — أمثلة عملية بالعامية المصرية، مش مصطلحات تقنية.
/// الأمثلة دي **أمثلة مش أوامر إجبارية**: المساعد بيفهم صيغ كتير، ولو ناقص
/// حاجة هيسألك أو يديك أزرار تختار منها. (مفيش ادّعاء إنه بيفهم كل جملة.)
class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  static const List<_Section> _sections = [
    _Section('تسجيل التوريد والمشتريات', Icons.local_shipping_outlined, [
      '«المورد عجمي جاب ٢٠ كيلو سكر» ← هيسألك: كام قيمة التوريد؟ (٢٠ كيلو كمية، مش فلوس).',
      '«جمال هيجيب بكرة الساعة ٥ العصر ٥ كراتين لبن إجمالي ١٠٠٠ جنيه» ← يتسجّل توريد متوقع وتنبيه، من غير ما يتحسب مشتريات لحد ما تأكد الاستلام.',
      '«استلمنا من جمال» أو زر «تأكيد الاستلام» في شاشة اليوم ← يتسجّل الاستلام مرة واحدة بس.',
    ]),
    _Section('كتابة المبالغ (فلوس)', Icons.payments_outlined, [
      '«دفعت ٥٠٠ جنيه لجمال» ← ٥٠٠ مبلغ لأن جنبها «جنيه».',
      '«سلفة لأحمد ٢٠٠ جنيه» أو «اخصم من أحمد ١٠٠».',
      'لو كتبت رقم من غير ما يتفهم هو إيه، المساعد هيسألك بدل ما يخمّن.',
    ]),
    _Section('الكميات والوحدات', Icons.scale_outlined, [
      '«اشتريت ٥ كراتين» أو «٣ كيلو سكر» أو «١٢ زجاجة» ← الرقم اللي بعده وحدة (كيلو، كرتونة، زجاجة، علبة، كيس…) بيتحسب كمية.',
      'الوحدات بتتفهم بأكتر من شكل: كرتونة / كرتونه / كرتون / كراتين.',
    ]),
    _Section('العمال والموردين', Icons.groups_outlined, [
      '«حضر محمود وخالد» أو «أحمد محضرش النهارده».',
      '«مين محضرش النهارده؟» وبعدها «سجلهم حضور».',
      'لو الاسم متكرر هتلاقي زر لكل شخص تختار منه.',
    ]),
    _Section('التذكيرات والالتزامات', Icons.alarm_outlined, [
      '«فكرني بكرة الساعة ٥ العصر أتصل بالعميل».',
      '«افتكر أدفع الإيجار يوم ٢٠ أكتوبر الساعة ٩ صباحًا».',
      'لازم يوم وساعة واضحين. لو ناقص حاجة هيسألك، ولو قلت «الساعة ٥» من غير صباحًا/مساءً هيسألك تقصد أنهي.',
    ]),
    _Section('أسئلة المساعد والأزرار', Icons.touch_app_outlined, [
      'لما المساعد يسألك، هتلاقي أزرار قصيرة (اليوم / بكرة / الساعة / أسماء…) تضغط عليها بدل ما تكتب.',
      'زر «إلغاء» بيلغي العملية المعلّقة. زر قديم ما بيأثرش على عملية جديدة.',
      'تقدر تسأل من حقل «اسأل المساعد» في شاشتي اليوم والبريف من غير ما تفتح المحادثة.',
    ]),
    _Section('تصحيح عملية قبل الحفظ', Icons.edit_note_outlined, [
      'قبل الحفظ تقدر تكتب «لا» أو تضغط «إلغاء» وتبعت الأمر صح.',
      'بعد الحفظ، عدّل أو احذف من الشاشة الخاصة بالسجل (عامل / مورد).',
    ]),
    _Section('إيه اللي بيشتغل من غير إنترنت؟', Icons.wifi_off_outlined, [
      'الأوامر المحلية المفهومة والتسجيل والأرصدة والتذكيرات بتشتغل من غير إنترنت.',
      'الكلام الصوتي بيعتمد على خدمة التعرف على الكلام اللي على جهازك، ومش مضمون بدون إنترنت على كل الأجهزة. الكتابة دايمًا شغالة.',
      'المساعد مش بيفهم كل جملة؛ لو ما فهمش هيقولك ويقترح عليك.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعليمات الاستخدام')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.x3),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpace.x3),
            child: Text(
              'اتكلم أو اكتب بطريقتك العادية. الأمثلة تحت للتوضيح بس، مش لازم تحفظها.',
            ),
          ),
          for (final s in _sections)
            Card(
              child: ExpansionTile(
                leading: Icon(s.icon),
                title: Text(s.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in s.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('• $line'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section {
  final String title;
  final IconData icon;
  final List<String> lines;
  const _Section(this.title, this.icon, this.lines);
}
