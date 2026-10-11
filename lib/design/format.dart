/// تنسيق عربي موحّد للأرقام والتواريخ — بلا أي اعتماد خارجي (لا intl).
/// الهدف: كل الأرقام المالية تظهر بالشكل "3,500 ج" وكل التواريخ
/// "الخميس 8 أكتوبر" في كل الشاشات، بدل DateTime.toString() الخام.

const List<String> _arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// يوم الأسبوع: weekday 1=الإثنين .. 7=الأحد
const List<String> _arWeekdays = [
  '', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
];

/// فاصل آلاف يدوي (يمنع الاعتماد على تنسيق النظام الذي قد يختلف).
String groupThousands(num value, {int decimals = 0}) {
  final negative = value < 0;
  final v = value.abs();
  final fixed = v.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  var out = buf.toString();
  if (parts.length > 1 && (int.tryParse(parts[1]) ?? 0) != 0) {
    out = '$out.${parts[1]}';
  }
  return negative ? '-$out' : out;
}

/// مبلغ مالي بالجنيه: 3500 → "3,500 ج"
String money(num value, {String suffix = 'ج'}) {
  final negative = value < 0;
  final abs = negative ? -value : value;
  final hasFraction = (abs - abs.truncate()).abs() > 0.004;
  final core = groupThousands(abs, decimals: hasFraction ? 2 : 0);
  return '${negative ? '-' : ''}$core $suffix';
}

/// تاريخ عربي واضح: "الخميس 8 أكتوبر 2026"
String arabicDate(DateTime d) {
  final wd = _arWeekdays[d.weekday];
  return '$wd ${d.day} ${_arMonths[d.month - 1]} ${d.year}';
}

/// وقت بصيغة 24 ساعة: "09:05"
String clockTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// تاريخ + وقت: "الخميس 8 أكتوبر · 09:05"
String arabicDateTime(DateTime d) => '${arabicDate(d)} · ${clockTime(d)}';

/// تاريخ مختصر: "8 أكتوبر 2026"
String shortDate(DateTime d) => '${d.day} ${_arMonths[d.month - 1]} ${d.year}';

/// "اليوم" / "أمس" / تاريخ كامل — للـTimelines
String relativeDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'أمس';
  if (diff == -1) return 'غدًا';
  return arabicDate(d);
}
