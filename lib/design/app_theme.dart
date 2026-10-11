import 'package:flutter/material.dart';
import 'tokens.dart';

/// ThemeData موحّد — تطبيقه في MaterialApp يعني كل الشاشات
/// بتاخد نفس شكل الأزرار/الحقول/الـChips/الكروت/الـListTile
/// /الـDialog/الـBottomSheet تلقائيًا.
///
/// مستوحى من نظام MulkCare: أزرق البحر للبنية، الفيروزي للتفاعل،
/// الذهب للفت الانتباه فقط، خط Tajawal، وراديوس متراتب.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Tajawal';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.35,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.4,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.45,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.45,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.5,
          letterSpacing: 0,
        ),
        titleSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.6,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.8,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.7,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.7,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.6,
          letterSpacing: 0,
        ),
        labelMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          height: 1.6,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.6,
          letterSpacing: 0,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(
          size: AppIconSize.lg,
          color: AppColors.primary,
        ),
      ),

      iconTheme: const IconThemeData(
        size: AppIconSize.md,
        color: AppColors.textPrimary,
      ),

      // Cards — flat + hairline (elevation is tonal first, shadow second)
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Filled buttons — deep sea primary, md radius
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceMid,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(0, AppTouch.min),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x5,
            vertical: AppSpace.x3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, AppTouch.min),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x5,
            vertical: AppSpace.x3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: const BorderSide(color: AppColors.border, width: 1),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondaryStrong,
          minimumSize: const Size(0, AppTouch.min),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x4,
            vertical: AppSpace.x2,
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),

      // Input decoration — sm radius, 52px, hairline
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x4,
          vertical: AppSpace.x4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textDisabled,
          letterSpacing: 0,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          letterSpacing: 0,
        ),
      ),

      // Bottom sheet — xl radius floating
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      // Chip / Badge — full pill
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          letterSpacing: 0,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x2,
          vertical: AppSpace.x1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        side: BorderSide.none,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // List tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpace.x4,
          vertical: AppSpace.x1,
        ),
        minVerticalPadding: AppSpace.x2,
        iconColor: AppColors.textSecondary,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          letterSpacing: 0,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          letterSpacing: 0,
        ),
      ),

      // Navigation bar — 64px, primary-tint pill indicator
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.primaryTint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
              letterSpacing: 0,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            letterSpacing: 0,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              size: AppIconSize.lg,
              color: AppColors.primary,
            );
          }
          return const IconThemeData(
            size: AppIconSize.lg,
            color: AppColors.textSecondary,
          );
        }),
      ),

      // Snackbar — inverse surface
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white,
          letterSpacing: 0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceMuted,
        circularTrackColor: AppColors.surfaceMuted,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryTint;
          }
          return AppColors.surfaceMuted;
        }),
      ),
    );
  }

  /// ثيم داكن — نفس بنية الثيم الفاتح بألوان ليلية (To Accio §6).
  static ThemeData dark() {
    const bg = Color(0xFF0C1720);
    const surface = Color(0xFF14232F);
    const surfaceMuted = Color(0xFF1C2E3C);
    const border = Color(0xFF2A3E4E);
    const textPrimary = Color(0xFFE6EDF3);
    const textSecondary = Color(0xFF9FB0BF);
    const indicator = Color(0xFF1F3A4D);

    final base = light();
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: surface,
      onSurface: textPrimary,
      outline: border,
      error: AppColors.danger,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      cardColor: surface,
      dialogBackgroundColor: surface,
      textTheme: base.textTheme.apply(bodyColor: textPrimary, displayColor: textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(size: AppIconSize.lg, color: AppColors.secondary),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0,
        ),
      ),
      iconTheme: const IconThemeData(size: AppIconSize.md, color: textPrimary),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontFamily: fontFamily),
        labelStyle: const TextStyle(color: textSecondary, fontFamily: fontFamily),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: surface),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      dividerTheme: const DividerThemeData(color: border),
      listTileTheme: const ListTileThemeData(iconColor: textSecondary, textColor: textPrimary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: indicator,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: fontFamily, fontSize: 12, color: textPrimary),
        ),
        iconTheme: WidgetStateProperty.all(const IconThemeData(color: textPrimary)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceMuted,
        secondarySelectedColor: indicator,
        selectedColor: indicator,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: textPrimary, fontFamily: fontFamily),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, AppTouch.min),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF24445C),
        contentTextStyle: TextStyle(fontFamily: fontFamily, color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
        linearTrackColor: surfaceMuted,
        circularTrackColor: surfaceMuted,
      ),
    );
  }
}

/// AppText aliases — مستويات MulkCare السبع
/// display / h1 / h2 / h3(titleMedium) / body / label / caption
class AppText {
  AppText._();

  static const display = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
    letterSpacing: 0,
  );

  static const h1 = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
    letterSpacing: 0,
  );

  static const h2 = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.45,
    letterSpacing: 0,
  );

  /// h3 — عناوين الكروت والصفوف
  static const titleMedium = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
    letterSpacing: 0,
  );

  static const body = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.8,
    letterSpacing: 0,
  );

  static const bodyMuted = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
    letterSpacing: 0,
  );

  static const label = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.6,
    letterSpacing: 0,
  );

  static const caption = TextStyle(
    fontFamily: 'Tajawal',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.7,
    letterSpacing: 0,
  );
}
