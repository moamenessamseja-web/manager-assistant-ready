import 'package:flutter/material.dart';
import 'tokens.dart';

/// مكتبة المكونات القابلة لإعادة الاستخدام — أي شاشة محتاجة حالة فاضية/تحميل
/// /خطأ/نجاح أو عنوان قسم أو badge تستخدم من هنا بدل ما تكتب Widget جديد.

/// حالة "لا يوجد بيانات بعد" — موحّدة الشكل في كل الشاشات.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppEmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: AppColors.textDisabled),
          const SizedBox(height: AppSpace.x4),
          Text(title, style: AppText.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.x2),
            Text(subtitle!, style: AppText.bodyMuted, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: AppSpace.x4), action!],
        ]),
      ),
    );
  }
}

/// حالة تحميل موحّدة.
class AppLoadingState extends StatelessWidget {
  final String? message;
  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AppColors.primary),
        if (message != null) ...[
          const SizedBox(height: AppSpace.x3),
          Text(message!, style: AppText.bodyMuted),
        ],
      ]),
    );
  }
}

/// حالة خطأ موحّدة مع زرار إعادة محاولة اختياري.
class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
          const SizedBox(height: AppSpace.x4),
          Text(message, style: AppText.body, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.x4),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ]),
      ),
    );
  }
}

/// شريط حالة نجاح مختصر — لتأكيد عملية داخل الصفحة نفسها (مش SnackBar بالضرورة).
class AppStatusBanner extends StatelessWidget {
  final String message;
  final AppStatusKind kind;
  const AppStatusBanner({super.key, required this.message, this.kind = AppStatusKind.success});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (kind) {
      AppStatusKind.success => (AppColors.successBg, AppColors.success, Icons.check_circle),
      AppStatusKind.warning => (AppColors.warningBg, AppColors.warning, Icons.warning_amber_rounded),
      AppStatusKind.danger => (AppColors.dangerBg, AppColors.danger, Icons.error),
      AppStatusKind.info => (AppColors.infoBg, AppColors.info, Icons.info),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4, vertical: AppSpace.x3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        Icon(icon, color: fg, size: AppIconSize.md),
        const SizedBox(width: AppSpace.x2),
        Expanded(child: Text(message, style: AppText.body.copyWith(color: fg))),
      ]),
    );
  }
}

enum AppStatusKind { success, warning, danger, info }

/// badge صغير (pill) لعرض رقم/حالة مختصرة جوه List tile أو Card.
class AppBadge extends StatelessWidget {
  final String text;
  final AppStatusKind kind;
  const AppBadge(this.text, {super.key, this.kind = AppStatusKind.info});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      AppStatusKind.success => (AppColors.successBg, AppColors.success),
      AppStatusKind.warning => (AppColors.warningBg, AppColors.warning),
      AppStatusKind.danger => (AppColors.dangerBg, AppColors.danger),
      AppStatusKind.info => (AppColors.infoBg, AppColors.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3, vertical: AppSpace.x1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(text, style: AppText.caption.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

/// عنوان قسم موحّد (زي "🔴 متأخر" أو "سجل الدفعات") بدل Text بخط عشوائي
/// في كل شاشة.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const AppSectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.x4, AppSpace.x4, AppSpace.x4, AppSpace.x2),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.h2)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// فتح Bottom Sheet موحّد الشكل (handle + padding + radius) بدل تكرار
/// showModalBottomSheet بإعدادات مختلفة في كل شاشة.
Future<T?> showAppBottomSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpace.x4,
        right: AppSpace.x4,
        top: AppSpace.x2,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpace.x4,
      ),
      child: builder(ctx),
    ),
  );
}
