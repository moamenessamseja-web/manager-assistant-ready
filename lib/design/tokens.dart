import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
///  PREMIUM DESIGN SYSTEM — مساعد الإدارة
///  "Midnight Executive + Warm Ivory" inspired palette
///  Calm, professional, with restrained depth and brass accents
/// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ── Canvas & Surfaces ───────────────────────────────────────
  /// Warm off-white — the page canvas
  static const background   = Color(0xFFFAF9F7);
  /// Pure white — every card, sheet, input, list row
  static const surface      = Color(0xFFFFFFFF);
  /// Warm cream — recessed surfaces, photo slots, skeletons
  static const surfaceMuted = Color(0xFFF4F2EE);
  /// Warm mid — section dividers, subtle backgrounds
  static const surfaceMid   = Color(0xFFEDEAE5);
  /// Warm dark — elevated panels, toasts
  static const surfaceDark  = Color(0xFF2C2C2E);

  // ── Borders ────────────────────────────────────────────────
  static const border       = Color(0xFFE8E4DC);
  static const borderStrong = Color(0xFFD5CFC2);

  // ── Text ──────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF5C5C5E);
  static const textDisabled  = Color(0xFFA0A09E);

  // ── Brand (preserved teal) ─────────────────────────────────
  static const primary       = Color(0xFF0E7C70);
  static const primaryStrong = Color(0xFF086059);
  static const primaryTint   = Color(0xFFE6F2F0);
  static const primaryLight  = Color(0xFFD0EAE6);

  // ── Accent — Warm Brass Gold ───────────────────────────────
  static const accent       = Color(0xFFC9A84C);
  static const accentStrong = Color(0xFF7A5C1A);
  static const accentTint   = Color(0xFFFDF1DC);

  // ── Semantic States ────────────────────────────────────────
  static const success       = Color(0xFF157347);
  static const successTint   = Color(0xFFE6F4EC);
  static const warning       = Color(0xFF9A5B00);
  static const warningTint   = Color(0xFFFBEEDA);
  static const danger        = Color(0xFFB3261E);
  static const dangerTint    = Color(0xFFFEE9E7);
  static const info          = Color(0xFF0E6E8C);
  static const infoTint      = Color(0xFFE5F0FA);

  // ── Chart colors ───────────────────────────────────────────
  static const chart1 = Color(0xFF0E7C70);
  static const chart2 = Color(0xFFC9A84C);
  static const chart3 = Color(0xFF6B7A8F);
  static const chart4 = Color(0xFFD07A4E);
  static const chart5 = Color(0xFF9B8EA0);
  static const chartGrid = Color(0xFFEDEAE5);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFAF9F7)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0E7C70), Color(0xFF086059)],
  );
}

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

class AppRadius {
  AppRadius._();
  static const double xs   = 6.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double xxl  = 24.0;
  static const double full = 9999.0;
}

class AppTouch {
  AppTouch._();
  static const double min = 44.0;
  static const double iconBtn = 40.0;
  static const double navItem = 64.0;
  static const double actionRow = 56.0;
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

  /// Level 1 — raised: subtle premium lift
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x0A1C1C1E), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x051C1C1E), blurRadius: 20, offset: Offset(0, 8)),
  ];

  /// Level 2 — floating: sheets, dialogs
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x141C1C1E), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A1C1C1E), blurRadius: 32, offset: Offset(0, 16)),
  ];
}
