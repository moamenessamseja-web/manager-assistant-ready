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
    // التاريخ والساعة (للتوريد المتوقع والتذكيرات فقط نحسب الساعة). الأرقام
    // اللي اتستهلكت كتاريخ/ساعة ما تتحسبش مبلغ ولا اسم أبدًا.
    final wantTime = intent == 'supplier_delivery' ||
        intent == 'create_commitment' ||
        intent == 'add_rule';
    final dt = _dateTimeOf(n, w, numbers, wantTime: wantTime);
    usedIndices.addAll(dt.used);
    // اسم الصنف (الكلمة بعد «كمية + وحدة») — ما يتحوّلش لشخص.
    final itemIdx = (qu != null &&
            (intent == 'record_purchase' ||
                intent == 'supplier_delivery' ||
                intent == 'mark_delivery_received'))
        ? _itemIndex(w, qu)
        : null;
    if (itemIdx != null) usedIndices.add(itemIdx);

    // المبلغ: من الأرقام أو من كلمات الأعداد.
    // مهم: الرقم اللي اتستخدم بالفعل ككمية (زي الـ«20» في «20 كيلو») لازم
    // يُستبعد من مرشحي المبلغ المالي — وإلا هيتفسّر غلط كقيمة بالجنيه لمجرد
    // إنه الرقم الوحيد في الجملة (البق اللي ظهر مع «جاب الآن ٢٠ كيلو سكر»:
    // كان بيسجل توريد بقيمة ٢٠ جنيه بدل ما يسأل عن القيمة الحقيقية).
    final qtyIndex = qu == null
        ? null
        : qu.indices.reduce((a, b) => a < b ? a : b); // فهرس رقم الكمية نفسه
    final numbersForAmount = numbers
        .where((x) => x.start != qtyIndex && !dt.used.contains(x.start))
        .toList();
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
    if (dt.date != null) f['due_date'] = dt.date;
    if (dt.time != null) f['time'] = dt.time;
    if (dt.hourRaw != null) f['time_hour_raw'] = dt.hourRaw;

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
        if (intent != 'add_supplier' && qu != null) {
          f['delivery_quantity'] = qu.quantity;
          if (qu.unit.isNotEmpty) f['delivery_unit'] = qu.unit;
          if (itemIdx != null) f['delivery_item'] = w[itemIdx];
        }
        break;

      case 'record_purchase':
        if (qu != null) {
          f['purchase_quantity'] = qu.quantity;
          if (qu.unit.isNotEmpty) f['purchase_unit'] = qu.unit;
          if (itemIdx != null) f['purchase_item'] = w[itemIdx];
        }
        // الإجمالي = المبلغ المذكور صراحةً
        f['purchase_total'] = amount;
        break;

      case 'add_supplier_payment':
        f['amount'] = amount;
        break;

      case 'create_commitment':
        // «فكرني/افتكر/مهمة» = تذكير عام؛ أول كلمة متبقية فيه فعل/مفعول
        // («أدفع الإيجار») مش اسم شخص. الاسم بس في الالتزامات/الديون.
        final isReminder = w.contains('فكرني') ||
            w.contains('ذكرني') ||
            w.contains('افتكر') ||
            w.contains('مهمه');
        f['person'] = (!isReminder && names.isNotEmpty) ? names.first : 'عام';
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
      clarification: confident ? null : _clarify(intent, f),
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
    if (c('متوقع') ||
        c('هيجي') ||
        c('هتجي') ||
        c('هيوصل') ||
        c('هتوصل') ||
        c('هيسلم') ||
        c('هتسلم') ||
        c('هيورد') ||
        c('هتورد')) {
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
        t('ذكرني') ||
        t('افتكر')) {
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
    final attached = <int>{}; // مرشحين اتفصلت منهم «و» العطف الملتصقة
    for (var i = 0; i < w.length; i++) {
      if (used.contains(i)) continue;
      var tok = w[i];
      if (tok.length < 2) continue;
      // «محمود وخالد»: الواو ملتصقة بالاسم التاني — بنفصلها لو اللي قبله اسم
      // مرشح متجاور، إلا لو الكلمة اسم معروف يبدأ بواو (وليد/وائل...).
      if (tok.length >= 4 &&
          tok.startsWith('و') &&
          candidates.containsKey(i - 1) &&
          !_waNames.contains(tok)) {
        final rest = tok.substring(1);
        if (!_isStopToken(rest) &&
            !_units.contains(rest) &&
            !_roles.contains(rest) &&
            RegExp(r'^[\u0621-\u064A]{3,}$').hasMatch(rest)) {
          candidates[i] = rest;
          attached.add(i);
          continue;
        }
      }
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
      if ((i == last + 2 && w[last + 1] == 'و') ||
          (i == last + 1 && attached.contains(i))) {
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
    if (_stop.contains(tok) || _dateWords.contains(tok)) return true;
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

  // ───────────────────── التاريخ والساعة (بدون أي افتراض) ─────────────────────

  static const Map<String, int> _months = {
    'يناير': 1,
    'فبراير': 2,
    'مارس': 3,
    'ابريل': 4,
    'مايو': 5,
    'يونيو': 6,
    'يوليو': 7,
    'اغسطس': 8,
    'سبتمبر': 9,
    'اكتوبر': 10,
    'نوفمبر': 11,
    'ديسمبر': 12,
  };

  /// أيام الأسبوع بصيغة DateTime.weekday (الاثنين=1 ... الأحد=7).
  static const Map<String, int> _weekdays = {
    'الاتنين': 1,
    'الاثنين': 1,
    'التلات': 2,
    'الثلاثاء': 2,
    'الاربع': 3,
    'الاربعاء': 3,
    'الخميس': 4,
    'الجمعه': 5,
    'السبت': 6,
    'الاحد': 7,
  };

  static const Set<String> _amWords = {'صباحا', 'صباح', 'الصبح', 'الفجر'};
  static const Set<String> _pmWords = {'مساء', 'المساء', 'العصر', 'المغرب', 'عشاء'};
  static const Set<String> _nightWords = {'بالليل', 'الليل', 'ليلا'};
  static const Set<String> _noonWords = {'الظهر', 'ظهرا', 'الضهر'};

  /// أسماء حقيقية بتبدأ بواو — ما تتفصلش منها الواو كأنها عطف.
  static const Set<String> _waNames = {
    'وليد', 'وائل', 'وسيم', 'وحيد', 'وجدي', 'وفاء', 'وردة', 'ورده', 'وسام',
    'وديع', 'وجيه', 'وهبه', 'وهبي',
  };

  /// كلمات التاريخ/الساعة/التوريد المتوقع — مش أسماء أشخاص.
  static final Set<String> _dateWords = {
    'الساعه', 'ساعه', 'صباحا', 'صباح', 'الصبح', 'مساء', 'المساء', 'العصر',
    'المغرب', 'الظهر', 'ظهرا', 'بالليل', 'الليل', 'ليلا', 'الفجر', 'عشاء',
    'يوم', 'ايام', 'يومين', 'بعد', 'ونص', 'ونصف', 'وربع', 'وثلث', 'الليله',
    'هيجيب', 'هتجيب', 'هيسلم', 'هتسلم', 'هيورد', 'هتورد', 'هيجيبو', 'افتكر',
    ..._weekdays.keys,
    ..._months.keys,
  };

  static bool _isInt(double v) => v == v.roundToDouble();

  /// فهرس كلمة الصنف: أول كلمة عربية بعد «كمية + وحدة» ولا تكون «من/ل/رقم».
  static int? _itemIndex(List<String> w, _QuantityUnit qu) {
    final idx = qu.indices.reduce((a, b) => a > b ? a : b) + 1;
    if (idx >= w.length) return null;
    final tok = w[idx];
    if (tok.length < 2 ||
        _isStopToken(tok) ||
        _units.contains(tok) ||
        _roles.contains(tok) ||
        _numWords.containsKey(tok) ||
        !RegExp(r'^[\u0621-\u064A]{2,}$').hasMatch(tok)) {
      return null;
    }
    return idx;
  }

  /// يستخرج اليوم والساعة بدون أي افتراض. لو الساعة من غير تحديد صباح/مساء
  /// بنرجّع [hourRaw] ونسأل، بدل ما نخمّن.
  static _DT _dateTimeOf(String n, List<String> w, List<_Num> nums,
      {bool wantTime = true, int? hourHint}) {
    final r = _DT();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime addDays(int k) => DateTime(today.year, today.month, today.day + k);
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    DateTime? day;
    if (n.contains('بعد بكره')) {
      day = addDays(2);
    } else if (w.contains('بكره') || w.contains('غدا')) {
      day = addDays(1);
    } else if (w.contains('النهارده') ||
        w.contains('اليوم') ||
        w.contains('الليله')) {
      day = today;
    }
    if (day == null) {
      for (final x in nums) {
        final before = x.start > 0 ? w[x.start - 1] : '';
        final after = x.end + 1 < w.length ? w[x.end + 1] : '';
        if (before == 'بعد' &&
            (after == 'يوم' || after == 'ايام') &&
            _isInt(x.value) &&
            x.value > 0 &&
            x.value <= 365) {
          day = addDays(x.value.toInt());
          r.used.addAll([x.start, x.end]);
          break;
        }
      }
    }
    if (day == null && n.contains('بعد يومين')) day = addDays(2);
    if (day == null && n.contains('بعد اسبوع')) day = addDays(7);
    if (day == null) {
      for (final x in nums) {
        final after = x.end + 1 < w.length ? w[x.end + 1] : '';
        final m = _months[after];
        if (m != null && _isInt(x.value) && x.value >= 1 && x.value <= 31) {
          var cand = DateTime(today.year, m, x.value.toInt());
          if (cand.isBefore(today)) cand = DateTime(today.year + 1, m, x.value.toInt());
          day = cand;
          r.used.addAll([x.start, x.end]);
          break;
        }
      }
    }
    if (day == null) {
      for (var i = 0; i < w.length; i++) {
        final m = RegExp(r'^(\d{1,2})/(\d{1,2})$').firstMatch(w[i]);
        if (m == null) continue;
        final dd = int.parse(m.group(1)!);
        final mm = int.parse(m.group(2)!);
        if (mm < 1 || mm > 12 || dd < 1 || dd > 31) continue;
        var cand = DateTime(today.year, mm, dd);
        if (cand.isBefore(today)) cand = DateTime(today.year + 1, mm, dd);
        day = cand;
        r.used.add(i);
        break;
      }
    }
    if (day == null) {
      for (final t in w) {
        final wd = _weekdays[t];
        if (wd == null) continue;
        var diff = (wd - today.weekday + 7) % 7;
        if (diff == 0) diff = 7;
        day = addDays(diff);
        break;
      }
    }
    if (day != null) r.date = ymd(day);

    if (!wantTime) return r;

    String? pcat;
    for (final t in w) {
      if (_amWords.contains(t)) {
        pcat = 'am';
      } else if (_pmWords.contains(t)) {
        pcat = 'pm';
      } else if (_nightWords.contains(t)) {
        pcat = 'night';
      } else if (_noonWords.contains(t)) {
        pcat = 'noon';
      }
      if (pcat != null) break;
    }
    bool isPeriod(String t) =>
        _amWords.contains(t) ||
        _pmWords.contains(t) ||
        _nightWords.contains(t) ||
        _noonWords.contains(t);

    int? hour;
    var minute = 0;
    for (var i = 0; i < w.length; i++) {
      if (w[i] != 'الساعه' && w[i] != 'ساعه') continue;
      final x = nums.where((e) => e.start == i + 1).toList();
      if (x.isNotEmpty && _isInt(x.first.value)) {
        hour = x.first.value.toInt();
        r.used.addAll([x.first.start, x.first.end]);
        final ni = x.first.end + 1;
        if (ni < w.length) {
          if (w[ni] == 'ونص' || w[ni] == 'ونصف') {
            minute = 30;
          } else if (w[ni] == 'وربع') {
            minute = 15;
          } else if (w[ni] == 'وثلث') {
            minute = 20;
          }
        }
      }
      break;
    }
    if (hour == null) {
      for (final x in nums) {
        final after = x.end + 1 < w.length ? w[x.end + 1] : '';
        if (isPeriod(after) && _isInt(x.value) && x.value >= 0 && x.value <= 24) {
          hour = x.value.toInt();
          r.used.addAll([x.start, x.end]);
          break;
        }
      }
    }
    if (hour == null && pcat != null && hourHint != null) hour = hourHint;
    if (hour == null || hour > 24) return r;

    var h = hour;
    if (h == 24) h = 0;
    if (h == 0 || h >= 13) {
      // 24 ساعة صريحة — مفيش لبس.
    } else if (pcat == null) {
      r.hourRaw = h; // 1..12 من غير صباح/مساء → نسأل.
      return r;
    } else if (pcat == 'am') {
      if (h == 12) h = 0;
    } else if (pcat == 'pm') {
      if (h != 12) h += 12;
    } else if (pcat == 'noon') {
      if (h >= 1 && h <= 5) h += 12;
    } else if (pcat == 'night') {
      if (h == 12) {
        h = 0;
      } else if (h >= 6) {
        h += 12;
      }
    }
    r.time =
        '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return r;
  }

  /// يستخرج حقول ناقصة من رد قصير على سؤال استيضاح («٣٠٠» / «بكرة الساعة ٥
  /// العصر» / «مساء»)، بدل ما نعتمد إن الرد نفسه يكون أمر كامل.
  /// [expect] = الحقول الناقصة في العملية المعلّقة.
  static Map<String, dynamic> extractSlots(String raw,
      {Set<String> expect = const {}, int? hourHint}) {
    final n = normalize(raw);
    final w = n.split(' ').where((e) => e.isNotEmpty).toList();
    final nums = _numbersIn(w);
    final qu = _quantityUnit(w);
    final dt = _dateTimeOf(n, w, nums, wantTime: true, hourHint: hourHint);
    final f = <String, dynamic>{};
    if (dt.date != null) f['due_date'] = dt.date;
    if (dt.time != null) f['time'] = dt.time;
    if (dt.hourRaw != null) f['time_hour_raw'] = dt.hourRaw;
    final used = <int>{...dt.used, if (qu != null) ...qu.indices};
    final rest = nums.where((x) => !used.contains(x.start)).toList();
    if (expect.contains('time') &&
        dt.time == null &&
        dt.hourRaw == null &&
        rest.length == 1 &&
        _isInt(rest.first.value) &&
        rest.first.value >= 1 &&
        rest.first.value <= 12) {
      f['time_hour_raw'] = rest.first.value.toInt();
    }
    if (expect.contains('amount') && rest.isNotEmpty) {
      final a = _pickAmount(n, w, rest);
      if (a != null) f['amount'] = a;
    }
    if (expect.contains('person') || expect.contains('employee_name')) {
      final names = _names(w, nums, used);
      if (names.isNotEmpty) {
        f['person'] = names.first;
        if (names.length > 1) f['people'] = names;
      }
    }
    return f;
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
      case 'supplier_delivery':
        return hasName && f['due_date'] != null && f['time'] != null;
      case 'add_supplier':
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
        // لازم يوم + ساعة صريحين — مفيش افتراض «بكرة» ولا ساعة من عندنا.
        return f['due_date'] != null && f['time'] != null;
      case 'add_rule':
        return true;
      default:
        return false;
    }
  }

  static String? _clarify(String intent, Map<String, dynamic> f) {
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
        final who = (f['person'] as String?) ?? '';
        if (who.isEmpty) return '❓ محتاج اسم المورد وقيمة التوريد.';
        final q = f['purchase_quantity'] == null
            ? ''
            : ' (${f['purchase_quantity']} ${f['purchase_unit'] ?? ''} ${f['purchase_item'] ?? ''})'
                .replaceAll(RegExp(r'\s+'), ' ');
        return '❓ كام إجمالي قيمة التوريد من $who$q؟ (أو سعر الوحدة)';
      case 'supplier_delivery':
      case 'create_commitment':
        return null; // المتحكّم بيسأل عن الناقص بالظبط (اسم/يوم/ساعة).
      case 'add_supplier':
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
    'كراتين',
    'شكاير',
    'كيس',
    'اكياس',
    'باكيت',
    'علب',
    'قطعه',
    'قطع',
    'لترات',
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
class _DT {
  String? date; // YYYY-MM-DD
  String? time; // HH:mm (24h)
  int? hourRaw; // ساعة 1..12 من غير صباح/مساء
  final Set<int> used = <int>{};
}

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
