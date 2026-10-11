import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
///  DESIGN SYSTEM — مساعد الإدارة
///  "Coastal premium" — مستوحى من نظام MulkCare
///  أزرق البحر العميق (بنية) + فيروزي البحيرة (تفاعل) +
///  ذهب الشمس (لفت الانتباه فقط) على خلفية ضباب البحر الفاتحة.
/// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ── Canvas & Surfaces ───────────────────────────────────────
  /// ضباب البحر — خلفية الصفحة
  static const background   = Color(0xFFF5F7FA);
  /// أبيض نقي — كل كارت وشيت وحقل وصف
  static const surface      = Color(0xFFFFFFFF);
  /// الطبقة الغائرة — خانات الصور والهياكل العظمية
  static const surfaceMuted = Color(0xFFEDF1F6);
  /// الرمادي الأوسط — الفواصل والأسطح المعطّلة
  static const surfaceMid   = Color(0xFFE9EEF3);
  /// الأسطح المعكوسة — التوستس وتلميحات الرسوم
  static const surfaceDark  = Color(0xFF072F47);

  // ── Borders ────────────────────────────────────────────────
  static const border       = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);

  // ── Text ──────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF55657A);
  static const textDisabled  = Color(0xFF98A4B3);

  // ── Brand — أزرق البحر العميق (البنية) ─────────────────────
  static const primary       = Color(0xFF084A6F);
  static const primaryStrong = Color(0xFF063A55);
  static const primaryTint   = Color(0xFFE4EEF4);
  static const primaryLight  = Color(0xFFD3E5EF);

  // ── Interaction — فيروزي البحيرة (التفاعل) ─────────────────
  static const secondary       = Color(0xFF00A3A3);
  static const secondaryStrong = Color(0xFF0A6E75);
  static const secondaryTint   = Color(0xFFDFF3F3);

  // ── Accent — ذهب الشمس (لفت الانتباه فقط) ──────────────────
  static const accent       = Color(0xFFF4B400);
  static const accentStrong = Color(0xFF8A6400);
  static const accentTint   = Color(0xFFFDF1D4);

  // ── Semantic States (أرضية فاتحة + نص قوي) ─────────────────
  static const success     = Color(0xFF157347);
  static const successTint = Color(0xFFE6F4EC);
  static const warning     = Color(0xFF9A5B00);
  static const warningTint = Color(0xFFFBEEDA);
  static const danger      = Color(0xFFB3261E);
  static const dangerTint  = Color(0xFFFBE9E7);
  static const info        = Color(0xFF0A6E75);
  static const infoTint    = Color(0xFFDFF3F3);

  // ── Chart ramp: بحر → بحيرة → شمس → تراكوتا → رمادي مزرق ────
  static const chart1 = Color(0xFF084A6F);
  static const chart2 = Color(0xFF00A3A3);
  static const chart3 = Color(0xFFF4B400);
  static const chart4 = Color(0xFFD07A4E);
  static const chart5 = Color(0xFF6B7A8F);
  static const chartGrid = Color(0xFFE6EBF1);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FA)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF084A6F), Color(0xFF063A55)],
  );
}

/// مقياس المسافات — x يطابق 4× (xxs=4 xs=8 sm=12 md=16 lg=24 xl=32 2xl=48 3xl=64)
class AppSpace {
  AppSpace._();
  static const double x1 = 4.0;
  static const double x2 = 8.0;
  static const double x3 = 12.0;
  static const double x4 = 16.0;
  static const double x5 = 20.0;
  static const double x6 = 24.0;
  static const double x8 = 32.0;
  static const double x10 = 40.0;
  static const double x12 = 48.0;
  static const double x16 = 64.0;
}

/// هرمية الراديوس — deliberately non-uniform (MulkCare):
/// xs 6 / sm 10 / md 14 / lg 18 (workhorse) / xl 24 (sheets) / full
class AppRadius {
  AppRadius._();
  static const double xs   = 6.0;
  static const double sm   = 10.0;
  static const double md   = 14.0;
  static const double lg   = 18.0;
  static const double xl   = 24.0;
  static const double xxl  = 24.0;
  static const double full = 9999.0;
}

class AppTouch {
  AppTouch._();
  static const double min = 44.0;
  static const double iconBtn = 44.0;
  static const double navItem = 64.0;
  static const double actionRow = 72.0;
}

class AppIconSize {
  AppIconSize._();
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xl2 = 40.0;
}

class AppShadow {
  AppShadow._();

  /// Level 0 — flat, hairline only
  static const List<BoxShadow> flat = [];

  /// Level 1 — raised: البحر الملوّن (deep-sea tinted), لا أسود رمادي
  /// 0 1px 2px rgba(8,42,64,0.05), 0 8px 20px -12px rgba(8,42,64,0.14)
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x0D082A40), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x24082A40),
      blurRadius: 20,
      spreadRadius: -12,
      offset: Offset(0, 8),
    ),
  ];

  /// Level 2 — floating: sheets, dialogs
  /// 0 2px 4px rgba(8,42,64,0.06), 0 16px 32px -16px rgba(8,42,64,0.20)
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x0F082A40), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(
      color: Color(0x33082A40),
      blurRadius: 32,
      spreadRadius: -16,
      offset: Offset(0, 16),
    ),
  ];
}
