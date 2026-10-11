import 'package:flutter/material.dart';
import '../models/commitment.dart';
import '../services/storage_service.dart';
import '../services/reminder_service.dart';
import '../services/app_state.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'notification_debug_screen.dart';

/// اليوم — Premium Operational Dashboard
/// يجيب أسئلة التشغيل الأربعة فورًا:
///   1. إيه اللي محتاج انتباهي؟
///   2. إيه أهم التزاماتي؟
///   3. إيه النشاط المالي؟
///   4. مين محتاج متابعة؟
///
/// يستمع لـ AppState عشان يتحديث تلقائيًا.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _S();
}

class _S extends State<TodayScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = today.toIso8601String().substring(0, 10);

    final commitments = StorageService.commitments();
    final overdue = commitments
        .where((x) => x.status == 'pending' && x.dueDate.isBefore(today))
        .toList();
    final dueToday = commitments
        .where((x) =>
            x.status == 'pending' &&
            x.dueDate.year == today.year &&
            x.dueDate.month == today.month &&
            x.dueDate.day == today.day)
        .toList();
    final upcoming = commitments
        .where((x) => x.status == 'pending' && x.dueDate.isAfter(today))
        .toList();

    final brokenReminders = StorageService.reminders()
        .where((r) => r.status != 'scheduled' && r.status != 'cancelled')
        .toList();

    final activeEmployees = StorageService.employees()
        .where((e) => !e.archived)
        .toList();
    final attendedToday =
        activeEmployees.where((e) => e.attendance.contains(todayStr)).length;
    final absentToday = activeEmployees.length - attendedToday;
    final activeSuppliers = StorageService.suppliers()
        .where((s) => !s.archived)
        .toList();
    final suppliersDue =
        activeSuppliers.fold<double>(0, (sum, s) => sum + s.balanceDue);
    final customersOverdue = overdue
        .where((c) => c.type == 'debt_to_collect')
        .fold<double>(0, (sum, c) => sum + (c.amount ?? 0));

    // Date formatting
    final dayNames = ['السبت', 'الجمعة', 'الخميس', 'الأربعاء', 'الثلاثاء', 'الإثنين', 'الأحد'];
    final monthNames = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final dayName = dayNames[now.weekday % 7];
    final monthName = monthNames[now.month - 1];
    final dateStr = '$dayName ${now.day} $monthName ${now.year}';

    return CustomScrollView(
      slivers: [
        // ── Premium Header ──────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x4, AppSpace.x4, AppSpace.x4, AppSpace.x3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date + notification row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dateStr,
                            style: AppText.bodyMuted.copyWith(fontSize: 13),
                          ),
                        ),
                        if (brokenReminders.isNotEmpty)
                          _NotificationBadge(count: brokenReminders.length),
                      ],
                    ),
                    const SizedBox(height: AppSpace.x1),
                    // Greeting
                    Text(
                      'ماذا عليك اليوم؟',
                      style: AppText.h1.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: AppSpace.x1),
                    // Status pills row
                    if (activeEmployees.isNotEmpty || activeSuppliers.isNotEmpty)
                      Wrap(
                        spacing: AppSpace.x2,
                        runSpacing: AppSpace.x1,
                        children: [
                          if (activeEmployees.isNotEmpty)
                            AppBadge(
                              label: absentToday > 0
                                  ? '$absentToday غياب اليوم'
                                  : 'الحضور كامل',
                              kind: absentToday > 0
                                  ? BadgeKind.warning
                                  : BadgeKind.success,
                            ),
                          if (suppliersDue > 0)
                            AppBadge(
                              label: '${suppliersDue.toStringAsFixed(0)} ج مستحق',
                              kind: BadgeKind.accent,
                            ),
                          if (customersOverdue > 0)
                            AppBadge(
                              label: '${customersOverdue.toStringAsFixed(0)} ج متأخرة',
                              kind: BadgeKind.danger,
                            ),
                          if (overdue.isNotEmpty)
                            AppBadge(
                              label: '${overdue.length} متأخر',
                              kind: BadgeKind.danger,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Priority Alert (if overdue) ────────────────────
        if (overdue.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x4, AppSpace.x4, AppSpace.x4, 0,
              ),
              child: _PriorityAlert(
                count: overdue.length,
                total: overdue
                    .where((c) => c.type == 'debt_to_collect')
                    .fold<double>(0, (s, c) => s + (c.amount ?? 0)),
              ),
            ),
          ),

        // ── Key Metrics Grid ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نظرة عامة',
                  style: AppText.titleMedium.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpace.x3),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        label: 'التزامات اليوم',
                        value: '${dueToday.length}',
                        icon: Icons.today,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: _MiniMetric(
                        label: 'الحضور',
                        value: '$attendedToday/${activeEmployees.length}',
                        icon: Icons.people_outline,
                        color: absentToday > 0 ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.x3),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        label: 'مستحق للموردين',
                        value: '${suppliersDue.toStringAsFixed(0)} ج',
                        icon: Icons.local_shipping_outlined,
                        color: suppliersDue > 0 ? AppColors.accent : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: _MiniMetric(
                        label: 'التزامات قادمة',
                        value: '${upcoming.length}',
                        icon: Icons.event_outlined,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Due Today Section ───────────────────────────────
        if (dueToday.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x4, 0, AppSpace.x4, AppSpace.x2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpace.x2),
                  Expanded(
                    child: Text(
                      'التزامات اليوم',
                      style: AppText.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${dueToday.length}',
                    style: AppText.label.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _CommitmentTile(
                  commitment: dueToday[i],
                  accent: AppColors.warning,
                  isDueToday: true,
                ),
                childCount: dueToday.length,
              ),
            ),
          ),
        ],

        // ── Overdue Section ─────────────────────────────────
        if (overdue.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x4, AppSpace.x4, AppSpace.x4, AppSpace.x2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpace.x2),
                  Expanded(
                    child: Text(
                      'متأخر',
                      style: AppText.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  AppBadge(
                    label: '${overdue.length}',
                    kind: BadgeKind.danger,
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _CommitmentTile(
                  commitment: overdue[i],
                  accent: AppColors.danger,
                  isOverdue: true,
                ),
                childCount: overdue.length,
              ),
            ),
          ),
        ],

        // ── Upcoming Section ─────────────────────────────────
        if (upcoming.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x4, AppSpace.x4, AppSpace.x4, AppSpace.x2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpace.x2),
                  Expanded(
                    child: Text(
                      'قادم',
                      style: AppText.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${upcoming.length} القادمة',
                    style: AppText.bodyMuted.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4, 0, AppSpace.x4, AppSpace.x4,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _CommitmentTile(
                  commitment: upcoming[i],
                  accent: AppColors.success,
                  isUpcoming: true,
                ),
                childCount: upcoming.length > 3 ? 3 : upcoming.length,
              ),
            ),
          ),
          if (upcoming.length > 3)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x4, 0, AppSpace.x4, AppSpace.x8,
                ),
                child: Center(
                  child: Text(
                    '+ ${upcoming.length - 3} أخرى',
                    style: AppText.bodyMuted,
                  ),
                ),
              ),
            ),
        ],

        // ── Empty State ──────────────────────────────────────
        if (overdue.isEmpty && dueToday.isEmpty && upcoming.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.x4),
                  Text(
                    'لا توجد التزامات',
                    style: AppText.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.x2),
                  Text(
                    'كل شيء منظم 🎉',
                    style: AppText.bodyMuted,
                  ),
                ],
              ),
            ),
          ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpace.x8),
        ),
      ],
    );
  }
}

/// Premium mini metric for the metrics grid
class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.x3),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: AppIconSize.md, color: color),
          ),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppText.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: AppText.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Priority alert banner for overdue items
class _PriorityAlert extends StatelessWidget {
  final int count;
  final double total;

  const _PriorityAlert({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            AppColors.danger.withValues(alpha: 0.08),
            AppColors.danger.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 22,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count التزام متأخر',
                        style: AppText.titleMedium.copyWith(
                          fontSize: 15,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (total > 0)
                        Text(
                          'إجمالي: ${total.toStringAsFixed(0)} ج',
                          style: AppText.bodyMuted.copyWith(
                            fontSize: 13,
                            color: AppColors.danger,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_left,
                  size: AppIconSize.lg,
                  color: AppColors.danger,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium commitment tile
class _CommitmentTile extends StatelessWidget {
  final Commitment commitment;
  final Color accent;
  final bool isDueToday;
  final bool isOverdue;
  final bool isUpcoming;

  const _CommitmentTile({
    required this.commitment,
    required this.accent,
    this.isDueToday = false,
    this.isOverdue = false,
    this.isUpcoming = false,
  });

  String get _typeLabel {
    switch (commitment.type) {
      case 'debt_to_collect':
        return 'تحصيل';
      case 'debt_to_pay':
        return 'دفعة';
      case 'task':
        return 'مهمة';
      default:
        return '';
    }
  }

  IconData get _icon {
    switch (commitment.type) {
      case 'debt_to_collect':
        return Icons.account_balance_wallet_outlined;
      case 'debt_to_pay':
        return Icons.payments_outlined;
      case 'task':
        return Icons.task_alt_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = commitment.dueDate.toString().substring(0, 10);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x2),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const SizedBox(width: AppSpace.x3),
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(_icon, size: AppIconSize.md, color: accent),
            ),
            const SizedBox(width: AppSpace.x3),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          commitment.person,
                          style: AppText.titleMedium.copyWith(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (commitment.amount != null)
                        Text(
                          '${commitment.amount!.toStringAsFixed(0)} ج',
                          style: AppText.label.copyWith(
                            color: accent,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          commitment.textOriginal,
                          style: AppText.bodyMuted.copyWith(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.snooze, size: 20, color: AppColors.textSecondary),
                  onPressed: () => _postpone(context),
                  tooltip: 'تأجيل',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.check_circle_outline, size: 20, color: AppColors.success),
                  onPressed: () => _markDone(context),
                  tooltip: 'تم',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markDone(BuildContext context) async {
    commitment.status = 'done';
    await StorageService.saveCommitment(commitment);
    for (final r in StorageService.remindersForEntity(commitment.id)) {
      await ReminderService.cancel(r.id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم ✅'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _postpone(BuildContext context) async {
    commitment.dueDate = commitment.dueDate.add(const Duration(days: 1));
    commitment.remindAt = commitment.remindAt.add(const Duration(days: 1));
    await StorageService.saveCommitment(commitment);
    final linked = StorageService.remindersForEntity(commitment.id);
    if (linked.isNotEmpty) {
      final r = linked.first;
      r.dueAt = commitment.remindAt;
      await ReminderService.retry(r);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التأجيل 📅'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Notification badge in header
class _NotificationBadge extends StatelessWidget {
  final int count;

  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationDebugScreen()),
        ),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x3,
            vertical: AppSpace.x2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_outlined,
                size: AppIconSize.md,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
