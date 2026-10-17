import '../models/command_result.dart';

/// محلل أوامر محلي — يفهم العامي المصري **بدون إنترنت وبدون أي مفتاح API**.
///
/// المسؤوليات:
/// 1. تطبيع النص العربي والأرقام (عربية/هندية/إنجليزية).
/// 2. تحديد النية محليًا.
/// 3. استخراج الأشخاص والمبالغ والكميات والتواريخ.
/// 4. إرجاع نتيجة منظمة بنفس مفاتيح مخطط Gemini عشان نفس مسار التنفيذ يشتغل.
///
/// مبدأ التصميم: **لا تخمين**. لو النية واضحة والبيانات المطلوبة موجودة،
/// [CommandResult.confident] = true. لو ناقص بيانات، النية تفضل معروفة
/// (isKnown) والتنفيذ نفسه هو اللي يطلب التوضيح. لو النية نفسها مش واضحة،
/// نرجّع 'other' عشان Gemini الاختياري (لو متاح) يحاول، وإلا نسأل المستخدم.
class LocalCommandParser {
  LocalCommandParser._();

  // ═══════════════════════════ تطبيع ═══════════════════════════

  /// تطبيع كامل: أرقام عربية/هندية → إنجليزية، إزالة التشكيل والتطويل،
  /// توحيد الألف/التاء المربوطة/الياء، وتنظيف الترقيم.
  static String normalize(String input) {
    final b = StringBuffer();
    for (final ch in input.split('')) {
      final ai = _arDigits.indexOf(ch);
      final fi = _faDigits.indexOf(ch);
      if (ai >= 0) {
        b.write(ai);
      } else if (fi >= 0) {
        b.write(fi);
      } else {
        b.write(ch);
      }
    }
    var t = b.toString();
    t = t.replaceAll(RegExp(r'[\u064B-\u0652\u0640\u0670]'), '');
    t = t
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا');
    t = t
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و');
    t = t.replaceAll(RegExp(r'''[.,،؟?!:;"'()\[\]{}]'''), ' ');
    t = t
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll('\u200b', '');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const String _arDigits = '٠١٢٣٤٥٦٧٨٩';
  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';

  // ═══════════════════════════ نقطة الدخول ═══════════════════════════

  static CommandResult parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return CommandResult.unknown;

    final n = normalize(text);
    final w = n.split(' ').where((e) => e.isNotEmpty).toList();
    final numbers = _numbersIn(w); // أرقام (إنجليزية بعد التطبيع + كلمات)

    // ── 1) الاستعلامات أولاً (لأن «محضرش» جوّه «حضور») ──
    final queryType = _detectQuery(n, w);
    if (queryType != null) {
      final f = <String, dynamic>{
        'text_original': text,
        'query_type': queryType
      };
      if (queryType == 'supplier_balance') {
        final names = _names(w, numbers, const {});
        if (names.isNotEmpty) f['person'] = names.first;
        return CommandResult(
          intent: 'query_business_data',
          fields: f,
          confident: names.isNotEmpty,
          clarification: names.isEmpty ? '❓ محتاج اسم المورد.' : null,
        );
      }
      return CommandResult(
          intent: 'query_business_data', fields: f, confident: true);
    }

    // ── 2) تحديد النية ──
    final intent = _detectIntent(n, w);
    if (intent == 'other') {
      return CommandResult(
        intent: 'other',
        source: ParseSource.none,
        fields: {'text_original': text},
      );
    }

    final f = <String, dynamic>{'text_original': text};
    final usedIndices = <int>{};

    // الأشياء العامة: كميات + وحدات + مبالغ + تواريخ
    final qu = _quantityUnit(w);
    if (qu != null) {
      usedIndices.addAll(qu.indices);
    }

    // المبلغ: من الأرقام أو من كلمات الأعداد.
    // مهم: الرقم اللي اتستخدم بالفعل ككمية (زي الـ«20» في «20 كيلو») لازم
    // يُستبعد من مرشحي المبلغ المالي — وإلا هيتفسّر غلط كقيمة بالجنيه لمجرد
    // إنه الرقم الوحيد في الجملة (البق اللي ظهر مع «جاب الآن ٢٠ كيلو سكر»:
    // كان بيسجل توريد بقيمة ٢٠ جنيه بدل ما يسأل عن القيمة الحقيقية).
    final qtyIndex = qu == null
        ? null
        : qu.indices.reduce((a, b) => a < b ? a : b); // فهرس رقم الكمية نفسه
    final numbersForAmount = qtyIndex == null
        ? numbers
        : numbers.where((x) => x.start != qtyIndex).toList();
    final amount = _pickAmount(n, w, numbersForAmount);
    if (amount != null) f['amount'] = amount;

    // الأسماء
    final names = _names(w, numbers, usedIndices);
    if (names.isNotEmpty) {
      f['person'] = names.first;
      if (names.length > 1) f['people'] = names;
    }

    // الوظيفة (لتمييز «أحمد سواق» عن «أحمد طباخ»)
    final role = _roleIn(w);
    if (role != null) f['person_role'] = role;

    switch (intent) {
      case 'mark_attendance':
        break;

      case 'add_advance':
      case 'add_deduction':
      case 'add_bonus':
        f['amount'] = amount;
        break;

      case 'add_employee':
        if (names.isNotEmpty) f['employee_name'] = names.first;
        if (role != null) f['employee_role'] = role;
        if (amount != null) f['salary'] = amount;
        break;

      case 'add_supplier':
      case 'supplier_delivery':
      case 'mark_delivery_received':
        if (names.isNotEmpty) f['person'] = names.first;
        break;

      case 'record_purchase':
        if (qu != null) {
          f['purchase_quantity'] = qu.quantity;
          if (qu.unit.isNotEmpty) f['purchase_unit'] = qu.unit;
        }
        // الإجمالي = المبلغ المذكور صراحةً
        f['purchase_total'] = amount;
        break;

      case 'add_supplier_payment':
        f['amount'] = amount;
        break;

      case 'create_commitment':
        f['person'] = names.isNotEmpty ? names.first : 'عام';
        final due = _relativeDate(n);
        if (due != null) f['due_date'] = due;
        break;

      case 'add_rule':
        f['rule_text'] = text;
        f['rule_frequency'] = _ruleFrequency(n);
        f['rule_anchor'] = _ruleAnchor(n);
        break;
    }

    final confident = _isConfident(intent, f);
    return CommandResult(
      intent: intent,
      fields: f,
      confident: confident,
      clarification: confident ? null : _clarify(intent),
    );
  }

  // ═══════════════════════════ النوايا ═══════════════════════════

  static String? _detectQuery(String n, List<String> w) {
    bool c(String s) => n.contains(s);
    if (c('محضرش') ||
        c('مش حاضر') ||
        c('مش حضر') ||
        c('غايب') ||
        c('ما سجلوش') ||
        c('ما سجلش') ||
        c('لسه ما سجل')) {
      return 'absent_today';
    }
    if (c('عليه فلوس') ||
        c('عليهم فلوس') ||
        c('مديون') ||
        c('مين عليه') ||
        c('مين عليهم')) {
      return 'debtors';
    }
    if (c('كام للمورد') ||
        c('رصيد') ||
        (c('حساب') && (c('مورد') || c('للمورد')))) {
      return 'supplier_balance';
    }
    if (w.contains('سلف') &&
        (c('الاسبوع') ||
            c('الشهر') ||
            c('الفتره') ||
            c('الفترة') ||
            c('الاسبوع ده'))) {
      return 'advances_this_week';
    }
    return null;
  }

  static String _detectIntent(String n, List<String> w) {
    bool t(String s) => w.contains(s);
    bool c(String s) => n.contains(s);

    // دفع لمورد
    if (t('دفعت') ||
        t('دفعه') ||
        t('سددت') ||
        t('سدتت') ||
        c('دفعت ل') ||
        c('دفعه لمورد')) {
      return 'add_supplier_payment';
    }
    // استلام توريد
    if (t('استلمت') || t('استلم') || (c('وصل') && (c('توريد') || c('بضاعه')))) {
      return 'mark_delivery_received';
    }
    // توريد متوقع
    if (c('متوقع') || c('هيجي') || c('هتجي') || c('هيوصل') || c('هتوصل')) {
      return 'supplier_delivery';
    }
    // قاعدة متابعة
    if (c('كل ') &&
        (c('شهر') ||
            c('جمعه') ||
            c('اسبوع') ||
            c('سبت') ||
            c('يوم') ||
            c('احد') ||
            c('اثنين'))) {
      return 'add_rule';
    }
    // إضافة موظف (الأخص أولاً)
    if ((t('موظف') || t('موظفين') || t('عامل') || t('عمال')) &&
        (c('جديد') || t('عين') || t('وظف') || t('وظفت') || c('اضف موظف'))) {
      return 'add_employee';
    }
    if (t('عين') || t('وظف') || t('وظفت') || c('موظف جديد')) {
      return 'add_employee';
    }
    // مورد جديد
    if (t('مورد') && (c('جديد') || t('سجل') || t('اضف'))) {
      return 'add_supplier';
    }
    // حضور
    if (t('حضور') ||
        t('حضر') ||
        t('حاضر') ||
        t('حضوره') ||
        (t('اعتبر') && (t('حاضر') || t('حضور')))) {
      return 'mark_attendance';
    }
    // سلفة
    if (t('سلفه') || t('سلف') || c('سلفه ل')) return 'add_advance';
    // مكافأة
    if (t('مكافاه') || t('مكافات') || t('مكافأه')) return 'add_bonus';
    // خصم
    if (t('خصم') || t('اخصم') || c('خصم من')) return 'add_deduction';
    // توريد/مشتريات بقيمة
    if (c('بضاعه') || c('مشتريات') || c('توريد') || t('جاب') || t('سلم')) {
      return 'record_purchase';
    }
    // التزام/دين/مهمة/تذكير
    if (t('التزام') ||
        t('التزامات') ||
        t('دين') ||
        t('مهمه') ||
        t('فكرني') ||
        t('ذكرني')) {
      return 'create_commitment';
    }
    return 'other';
  }

  // ═══════════════════════════ الاستخراج ═══════════════════════════

  /// كل الأرقام في النص (أرقام فعلية + كلمات أعداد) مع موضعها.
  /// يُرجّع قائمة [Num] مرتبة حسب الظهور.
  static List<_Num> _numbersIn(List<String> w) {
    final out = <_Num>[];
    for (var i = 0; i < w.length; i++) {
      final tok = w[i];
      // رقم صريح (مع احتمال بادئة «ب»)
      final dm = RegExp(r'^ب?(\d+(?:\.\d+)?)$').firstMatch(tok);
      if (dm != null) {
        out.add(_Num(double.parse(dm.group(1)!), i, i));
        continue;
      }
      // كلمة عدد (مع احتمال بادئة «ب»)
      final word =
          tok.startsWith('ب') && tok.length > 2 && !_numWords.containsKey(tok)
              ? tok.substring(1)
              : tok;
      if (_numDirect.containsKey(word)) {
        out.add(_Num(_numDirect[word]!, i, i));
        continue;
      }
      final base = _numWords[word];
      if (base != null) {
        if (i + 1 < w.length && _numMult.containsKey(w[i + 1])) {
          out.add(_Num(base * _numMult[w[i + 1]]!, i, i + 1));
          i++;
        } else {
          out.add(_Num(base, i, i));
        }
        continue;
      }
      if (_numMult.containsKey(word)) {
        out.add(_Num(_numMult[word]!, i, i));
      }
    }
    return out;
  }

  /// اختيار المبلغ المالي: الأوضح أولاً، ومن غير تخمين.
  /// 1) رقم متبوع بـ «جنيه/ج/قرش/ريال/دولار».
  /// 2) رقم ببادئة «ب» (زي «ب2000»).
  /// 3) رقم واحد فقط في الجملة.
  /// 4) أكبر عدد من كلمات الأعداد (زي «خمسة آلاف» = 5000).
  static double? _pickAmount(String n, List<String> w, List<_Num> nums) {
    if (nums.isEmpty) return null;
    const markers = {
      'جنيه',
      'ج',
      'قرش',
      'ريال',
      'دولار',
      'بقيمه',
      'بمبلغ',
      'مبلغ'
    };
    for (final num in nums) {
      final after = num.end + 1 < w.length ? w[num.end + 1] : '';
      final before = num.start - 1 >= 0 ? w[num.start - 1] : '';
      if (markers.contains(after) || markers.contains(before)) return num.value;
      final raw = w[num.start];
      if (RegExp(r'^ب\d').hasMatch(raw)) return num.value;
    }
    if (nums.length == 1) return nums.first.value;
    // كلمات أعداد فقط (مفيش أرقام صريحة) → الأكبر هو المبلغ عادةً
    final hasDigits = nums.any((x) => RegExp(r'\d').hasMatch(w[x.start]));
    if (!hasDigits) {
      return nums.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    }
    return null;
  }

  /// كمية + وحدة (زي «20 كيلو»).
  static _QuantityUnit? _quantityUnit(List<String> w) {
    for (var i = 1; i < w.length; i++) {
      if (_units.contains(w[i])) {
        final prev = w[i - 1];
        final m = RegExp(r'^ب?(\d+(?:\.\d+)?)$').firstMatch(prev);
        if (m != null) {
          return _QuantityUnit(double.parse(m.group(1)!), w[i], {i - 1, i});
        }
        final base = _numWords[prev];
        if (base != null) return _QuantityUnit(base, w[i], {i - 1, i});
      }
    }
    return null;
  }

  /// أسماء الأشخاص: أي كلمة عربية متبقية بعد استبعاد الكلمات الوظيفية
  /// والأرقام والوحدات والوظائف.
  ///
  /// **مهم (إصلاح بَق تعدد الأسماء الوهمي):** بنرجّع أول مرشح دايمًا كاسم
  /// أساسي، لكن ما بنضيفش مرشح تاني لقائمة «الأسماء المتعددة» إلا لو كان
  /// متصل بالمرشح اللي قبله بواو عطف واحدة بالظبط («محمود و خالد و حسن»).
  /// أي كلمة عربية فاضلة تانية في الجملة (زي اسم صنف «سكر» في «جاب 20 كيلو
  /// سكر») بتتجاهل كاسم تاني بدل ما تتحوّل لشخص وهمي يتنفذ عليه نفس الأمر.
  static List<String> _names(
      List<String> w, List<_Num> nums, Set<int> extraUsed) {
    final used = <int>{...extraUsed};
    for (final num in nums) {
      used.add(num.start);
      used.add(num.end);
    }
    final candidates = <int, String>{};
    for (var i = 0; i < w.length; i++) {
      if (used.contains(i)) continue;
      var tok = w[i];
      if (tok.length < 2) continue;
      if (_isStopToken(tok)) continue;
      // بادئة شائعة ملتصقة: «لسالم» → «سالم»، «بأحمد» → «أحمد».
      tok = _stripClitic(tok);
      if (_isStopToken(tok)) continue;
      if (_units.contains(tok)) continue;
      if (_roles.contains(tok)) continue;
      if (!RegExp(r'^[\u0621-\u064A]{2,}$').hasMatch(tok)) continue;
      candidates[i] = tok;
    }
    if (candidates.isEmpty) {
      // «علي» كلمة وظيفية (على) واسم شخص شائع في نفس الوقت — لو مفيش أي
      // مرشح تاني، نعتبرها اسمًا بدل ما نتجاهل الأمر.
      return w.contains('علي') ? const ['علي'] : const [];
    }
    final indices = candidates.keys.toList()..sort();
    final out = <String>[candidates[indices.first]!];
    var last = indices.first;
    for (final i in indices.skip(1)) {
      if (i == last + 2 && w[last + 1] == 'و') {
        out.add(candidates[i]!);
        last = i;
      } else {
        // مش متصلة بواو عطف مباشرة — كلمة فاضلة (غالبًا اسم صنف)، مش شخص
        // إضافي. نوقف هنا ونسيب الباقي.
        break;
      }
    }
    return out;
  }

  /// هل الكلمة كلمة وظيفية (تُستبعد من استخراج الأسماء)؟ بيراعي أل التعريف
  /// الملتصقة بكلمة وظيفية معروفة أصلاً — زي «المورد» (= «مورد» + «ال»)،
  /// «الموظف»، إلخ. مُطبَّق فقط لو الباقي بعد شطب «ال» كلمة وظيفية معروفة
  /// بالفعل، عشان ما نتلفش أسماء أشخاص حقيقية بتبدأ بـ«ال» زي «الحسيني».
  static bool _isStopToken(String tok) {
    if (_stop.contains(tok)) return true;
    if (tok.length > 4 && tok.startsWith('ال')) {
      final rest = tok.substring(2);
      if (_stop.contains(rest)) return true;
    }
    return false;
  }

  /// تقصّ اللاصقة الأمامية (ل/ب) من الكلمة الملتصقة (زي «لسالم» → «سالم»)
  /// بشرط ألا تكون الكلمة نفسها كلمة معروفة، وأن يبقى منها اسم معقول.
  static String _stripClitic(String tok) {
    if (tok.length >= 5 && (tok.startsWith('ل') || tok.startsWith('ب'))) {
      final rest = tok.substring(1);
      if (rest.length >= 3 && RegExp(r'^[\u0621-\u064A]+$').hasMatch(rest))
        return rest;
    }
    return tok;
  }

  static String? _roleIn(List<String> w) {
    for (final t in w) {
      if (_roles.contains(t)) return t;
    }
    return null;
  }

  /// تاريخ نسبي مبدئي (بكرة/النهاردة/بعد بكرة) بصيغة YYYY-MM-DD.
  static String? _relativeDate(String n) {
    final now = DateTime.now();
    DateTime d;
    if (n.contains('بعد بكره') || n.contains('بعد بكرة')) {
      d = now.add(const Duration(days: 2));
    } else if (n.contains('بكره') || n.contains('بكرة') || n.contains('غدا')) {
      d = now.add(const Duration(days: 1));
    } else if (n.contains('النهارده') || n.contains('اليوم')) {
      d = now;
    } else {
      return null;
    }
    return d.toIso8601String().substring(0, 10);
  }

  static String _ruleFrequency(String n) {
    if (n.contains('يوم')) return 'daily';
    if (n.contains('اسبوع') ||
        n.contains('جمعه') ||
        n.contains('سبت') ||
        n.contains('احد')) {
      return 'weekly';
    }
    return 'monthly';
  }

  static int? _ruleAnchor(String n) {
    final m = RegExp(r'(\d+)').firstMatch(n);
    if (m != null) {
      final v = int.tryParse(m.group(1)!);
      if (v != null && v > 0) return v;
    }
    const days = {
      'اثنين': 1,
      'تلاتاء': 2,
      'اربعاء': 3,
      'خميس': 4,
      'جمعه': 5,
      'سبت': 6,
      'احد': 7
    };
    for (final e in days.entries) {
      if (n.contains(e.key)) return e.value;
    }
    return null;
  }

  // ═══════════════════════════ الثقة والتوضيح ═══════════════════════════

  static double _amt(Map<String, dynamic> f) =>
      (f['amount'] as num?)?.toDouble() ?? 0;

  static bool _isConfident(String intent, Map<String, dynamic> f) {
    final hasName = (f['person'] as String?)?.isNotEmpty == true;
    switch (intent) {
      case 'mark_attendance':
      case 'add_supplier':
      case 'supplier_delivery':
      case 'mark_delivery_received':
        return hasName;
      case 'add_advance':
      case 'add_deduction':
      case 'add_bonus':
      case 'add_supplier_payment':
        return hasName && _amt(f) > 0;
      case 'record_purchase':
        return hasName && _amt(f) > 0;
      case 'add_employee':
        return hasName;
      case 'create_commitment':
        return true;
      case 'add_rule':
        return true;
      default:
        return false;
    }
  }

  static String? _clarify(String intent) {
    switch (intent) {
      case 'mark_attendance':
        return '❓ محتاج اسم الموظف.';
      case 'add_advance':
      case 'add_deduction':
      case 'add_bonus':
        return '❓ محتاج اسم الموظف والمبلغ.';
      case 'add_supplier_payment':
        return '❓ محتاج اسم المورد والمبلغ المدفوع.';
      case 'record_purchase':
        return '❓ محتاج اسم المورد وقيمة التوريد (أو الكمية وسعر الوحدة).';
      case 'add_supplier':
      case 'supplier_delivery':
      case 'mark_delivery_received':
        return '❓ محتاج اسم المورد.';
      default:
        return null;
    }
  }

  // ═══════════════════════════ قواميس ═══════════════════════════

  static const Map<String, double> _numWords = {
    'واحد': 1,
    'اتنين': 2,
    'اثنين': 2,
    'تلاته': 3,
    'ثلاثه': 3,
    'تلات': 3,
    'اربعه': 4,
    'اربع': 4,
    'خمسه': 5,
    'خمس': 5,
    'سته': 6,
    'ست': 6,
    'سبعه': 7,
    'سبع': 7,
    'تمانيه': 8,
    'ثمانيه': 8,
    'تمان': 8,
    'تسعه': 9,
    'تسع': 9,
    'عشره': 10,
    'عشر': 10,
    'حداشر': 11,
    'اتناشر': 12,
    'عشرين': 20,
    'تلاتين': 30,
    'ثلاثين': 30,
    'اربعين': 40,
    'خمسين': 50,
    'ستين': 60,
    'سبعين': 70,
    'تمانين': 80,
    'ثمانين': 80,
    'تسعين': 90,
    'ميه': 100,
    'مئه': 100,
    'مائه': 100,
    'ميتين': 200,
    'تلتميه': 300,
    'ثلاثميه': 300,
    'ربعميه': 400,
    'اربعميه': 400,
    'خمسميه': 500,
    'ستميه': 600,
    'سبعميه': 700,
    'تمنميه': 800,
    'ثمانميه': 800,
    'تسعميه': 900,
  };

  static const Map<String, double> _numDirect = {
    'الفين': 2000,
    'مليونين': 2000000
  };

  static const Map<String, double> _numMult = {
    'الف': 1000,
    'الاف': 1000,
    'لاف': 1000,
    'مليون': 1000000,
    'ملايين': 1000000,
  };

  static const Set<String> _units = {
    'كيلو',
    'كيلوجرام',
    'كجم',
    'جرام',
    'لتر',
    'كرتونه',
    'كرتون',
    'شكاره',
    'شوال',
    'عبوه',
    'علبه',
    'جامبو',
    'دسته',
    'طن',
    'صندوق',
    'برميل',
    'متر',
  };

  static const Set<String> _roles = {
    'سواق',
    'سائق',
    'طباخ',
    'شيف',
    'عامل',
    'عمال',
    'محاسب',
    'فراش',
    'جرسون',
    'مندوب',
    'مدير',
    'مهندس',
    'كهربايي',
    'سباك',
    'نجار',
    'حنفي',
    'ممرض',
  };

  /// كلمات وظيفية/أفعال/أسماء عمليات — تُستبعد من استخراج الأسماء.
  static const Set<String> _stop = {
    'من',
    'ل',
    'الي',
    'علي',
    'في',
    'عن',
    'مع',
    'و',
    'او',
    'ان',
    'انا',
    'هو',
    'هي',
    'ده',
    'دي',
    'دول',
    'اللي',
    'يعني',
    'عايز',
    'عاوز',
    'اريد',
    'عشان',
    'بقيمه',
    'بمبلغ',
    'مبلغ',
    'جنيه',
    'ج',
    'قرش',
    'ريال',
    'دولار',
    'كمان',
    'بس',
    'تمام',
    'خلاص',
    'لو',
    'سمحت',
    'بعد',
    'قبل',
    'امبارح',
    'امس',
    'النهارده',
    'اليوم',
    'بكره',
    'بكرة',
    'غدا',
    'الاسبوع',
    'الشهر',
    'السنه',
    'كل',
    'يوم',
    'جمعه',
    'سبت',
    'احد',
    'خميس',
    'اثنين',
    'تلاتاء',
    'اربعاء',
    'شهر',
    'اسبوع',
    'سنه',
    'اول',
    'اخر',
    'الجاي',
    'الجي',
    'الماضي',
    'فات',
    'جديد',
    'جديده',
    'سجل',
    'سجلهم',
    'احسب',
    'حضر',
    'حضور',
    'حاضر',
    'حاضرين',
    'اعتبر',
    'يعتبر',
    'تم',
    'خصم',
    'اخصم',
    'سلفه',
    'سلف',
    'دفعه',
    'دفعت',
    'دفع',
    'مكافاه',
    'مكافات',
    'توريد',
    'توريدات',
    'بضاعه',
    'بضاعة',
    'مشتريات',
    'مشتري',
    'مورد',
    'موردين',
    'موظف',
    'موظفين',
    'عين',
    'وظف',
    'وظفت',
    'استلم',
    'استلمت',
    'وصل',
    'وصلت',
    // فعلا «جاب»/«سلم» بيحدّدوا نية record_purchase لكن ما كاناش مستبعدين من
    // استخراج الأسماء — فكان بيتكوّن اسم تاني وهمي من الفعل نفسه (مثلاً
    // «سالم جاب بضاعة...» كانت بتطلع أسماء: سالم + جاب)، وده بيخلي العملية
    // تتنفذ مرتين لشخصين، واحد منهم مش حقيقي.
    'جاب',
    'سلم',
    'متوقع',
    'متوقعه',
    'هيجي',
    'هتجي',
    'هيوصل',
    'هتوصل',
    'مين',
    'كام',
    'الفلوس',
    'فلوس',
    'دين',
    'التزام',
    'التزامات',
    'مهمه',
    'فكرني',
    'ذكرني',
    'رصيد',
    'حساب',
    'المستحق',
    'مستحقات',
    'محضرش',
    'ما',
    'مش',
    'مسجلش',
    'لسه',
    'عليه',
    'عليهم',
    'حاجه',
    'حاجته',
    'قيمه',
    'اجمالي',
    'سعر',
    'كميه',
    'عدد',
    'وحده',
    'اضف',
    'ضيف',
    'رصيده',
    'حسابه',
    'عاوزين',
    'محتاج',
    'فاكر',
    'الف',
    'الاف',
    'مليون',
    'دلوقتي',
    'الان',
    'كده',
    'زي',
    'بقا',
    'يبقى',
    'للمورد',
    'لمورد',
    'للموردين',
    'للموظف',
    'لموظف',
    'للموظفين',
    'للمحل',
    'اخد',
    'خد',
    'اخده',
    'واخد',
    'ادفع',
  };
}

/// رقم مع موضعه في قائمة الكلمات.
class _Num {
  final double value;
  final int start;
  final int end;
  const _Num(this.value, this.start, this.end);
}

/// كمية + وحدة + مواضعها.
class _QuantityUnit {
  final double quantity;
  final String unit;
  final Set<int> indices;
  const _QuantityUnit(this.quantity, this.unit, this.indices);
}
