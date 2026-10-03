import 'package:flutter/material.dart';

/// Design tokens — المصدر الوحيد للألوان/المسافات/الزوايا في التطبيق.
/// أي شاشة محتاجة تعديل بصري تاخد القيم من هنا بدل ما تكتب أرقام سايبة.
class AppColors {
  AppColors._();

  // Neutral surface scale (light)
  static const bg = Color(0xFFF7F8F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEFF2F1);
  static const border = Color(0xFFE2E6E5);
  static const textPrimary = Color(0xFF17201F);
  static const textSecondary = Color(0xFF5B6664);
  static const textDisabled = Color(0xFF9AA3A1);

  // Teal accent
  static const primary = Color(0xFF0E7C70);
  static const primaryDark = Color(0xFF0A5A52);
  static const primaryLight = Color(0xFFE1F2EF);

  // Status
  static const success = Color(0xFF2E9E5B);
  static const successBg = Color(0xFFE6F6EC);
  static const warning = Color(0xFFE08A1E);
  static const warningBg = Color(0xFFFCF0DD);
  static const danger = Color(0xFFD64545);
  static const dangerBg = Color(0xFFFAE4E4);
  static const info = Color(0xFF2E7BD6);
  static const infoBg = Color(0xFFE5F0FB);
}

/// نظام مسافات 8pt — كل Padding/Gap في التطبيق لازم يكون multiple من AppSpace.x1
class AppSpace {
  AppSpace._();
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

class AppIconSize {
  AppIconSize._();
  static const sm = 18.0;
  static const md = 22.0;
  static const lg = 28.0;
}

/// Typography hierarchy — أسماء دلالية بدل "fontSize: 14" سايبة في كل شاشة.
class AppText {
  AppText._();
  static const display = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.textPrimary);
  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.textPrimary);
  static const h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.textPrimary);
  static const titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: AppColors.textPrimary);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.textPrimary);
  static const bodyMuted = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.textSecondary);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: AppColors.textSecondary);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3, color: AppColors.textPrimary);
}
