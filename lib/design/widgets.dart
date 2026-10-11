import 'package:flutter/material.dart';
import 'tokens.dart';
import 'app_theme.dart';

/// ─────────────────────────────────────────────────────────────
///  PREMIUM DESIGN WIDGETS
///  Reusable components following the premium design system
/// ─────────────────────────────────────────────────────────────

/// Premium Status Badge — pill-shaped with glyph + label + color
enum BadgeKind { success, warning, danger, info, accent, neutral }

class AppBadge extends StatelessWidget {
  final BadgeKind kind;
  final String label;
  final bool compact;

  const AppBadge({
    super.key,
    required this.kind,
    required this.label,
    this.compact = false,
  });

  Color get _bg {
    switch (kind) {
      case BadgeKind.success: return AppColors.successTint;
      case BadgeKind.warning: return AppColors.warningTint;
      case BadgeKind.danger: return AppColors.dangerTint;
      case BadgeKind.info: return AppColors.infoTint;
      case BadgeKind.accent: return AppColors.accentTint;
      case BadgeKind.neutral: return AppColors.surfaceMuted;
    }
  }

  Color get _fg {
    switch (kind) {
      case BadgeKind.success: return AppColors.success;
      case BadgeKind.warning: return AppColors.warning;
      case BadgeKind.danger: return AppColors.danger;
      case BadgeKind.info: return AppColors.info;
      case BadgeKind.accent: return AppColors.accentStrong;
      case BadgeKind.neutral: return AppColors.textSecondary;
    }
  }

  IconData? get _icon {
    switch (kind) {
      case BadgeKind.success: return Icons.check_circle_outline;
      case BadgeKind.warning: return Icons.schedule;
      case BadgeKind.danger: return Icons.error_outline;
      case BadgeKind.info: return Icons.info_outline;
      case BadgeKind.accent: return Icons.star_outline;
      case BadgeKind.neutral: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpace.x2 : AppSpace.x3,
        vertical: compact ? 2 : AppSpace.x1,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: _fg),
            SizedBox(width: compact ? 2 : 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: _fg,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium Empty State — centered, with icon, title, subtitle, action
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(icon, size: AppIconSize.xl, color: AppColors.textDisabled),
            ),
            const SizedBox(height: AppSpace.x4),
            Text(title, style: AppText.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpace.x2),
              Text(subtitle!, style: AppText.bodyMuted, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpace.x4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Premium Loading State — centered with optional message
class AppLoadingState extends StatelessWidget {
  final String? message;
  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpace.x3),
            Text(message!, style: AppText.bodyMuted),
          ],
        ],
      ),
    );
  }
}

/// Premium Section Header — title + optional trailing
class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsets? padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: AppSpace.x4,
        vertical: AppSpace.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.titleMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Premium Status Banner — full-width with left border accent
enum BannerKind { success, warning, danger, info }

class AppStatusBanner extends StatelessWidget {
  final BannerKind kind;
  final String message;
  final IconData? icon;
  final VoidCallback? onTap;

  const AppStatusBanner({
    super.key,
    required this.kind,
    required this.message,
    this.icon,
    this.onTap,
  });

  Color get _color {
    switch (kind) {
      case BannerKind.success: return AppColors.success;
      case BannerKind.warning: return AppColors.warning;
      case BannerKind.danger: return AppColors.danger;
      case BannerKind.info: return AppColors.info;
    }
  }

  Color get _bg {
    switch (kind) {
      case BannerKind.success: return AppColors.successTint;
      case BannerKind.warning: return AppColors.warningTint;
      case BannerKind.danger: return AppColors.dangerTint;
      case BannerKind.info: return AppColors.infoTint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon_ = icon ?? Icons.info_outline;
    final content = Row(
      children: [
        Icon(icon_, size: AppIconSize.md, color: _color),
        const SizedBox(width: AppSpace.x2),
        Expanded(
          child: Text(
            message,
            style: AppText.body.copyWith(fontSize: 14, color: _color),
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_left, size: AppIconSize.md, color: _color),
      ],
    );

    if (onTap != null) {
      return Material(
        color: _bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpace.x3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: content,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpace.x3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: content,
    );
  }
}

/// Premium Card — flat with hairline border + optional shadow
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: elevated ? AppShadow.raised : AppShadow.flat,
      ),
      padding: padding ?? const EdgeInsets.all(AppSpace.x4),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Premium List Tile — 72px with icon, title, subtitle, trailing
class AppListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x4,
            vertical: AppSpace.x3,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpace.x3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppText.titleMedium.copyWith(fontSize: 16)),
                    if (subtitle != null)
                      Text(subtitle!, style: AppText.bodyMuted.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium Metric Card — for dashboard KPIs
class AppMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? sub;
  final VoidCallback? onTap;

  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return AppCard(
      onTap: onTap,
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: AppIconSize.lg, color: color),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.chevron_left,
                  size: AppIconSize.md,
                  color: AppColors.textDisabled,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.x3),
          Text(
            value,
            style: AppText.h1.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.bodyMuted.copyWith(fontSize: 13)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: AppText.caption),
          ],
        ],
      ),
    );
  }
}

/// Premium Quick Action Button — for dashboard quick actions
class AppQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const AppQuickAction({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x3,
            vertical: AppSpace.x3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: AppIconSize.lg, color: c),
              ),
              const SizedBox(height: AppSpace.x2),
              Text(
                label,
                style: AppText.bodyMuted.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show a premium bottom sheet
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget body,
  String? title,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: AppShadow.floating,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: AppSpace.x3),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppText.h2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: AppIconSize.lg),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: AppSpace.x2),
            Flexible(child: body),
          ],
        ),
      ),
    ),
  );
}
