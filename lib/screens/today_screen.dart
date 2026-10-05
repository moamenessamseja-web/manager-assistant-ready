import 'package:flutter/material.dart';
import '../models/commitment.dart';
import '../services/storage_service.dart';
import '../services/reminder_service.dart';
import '../services/assistant_controller.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'notification_debug_screen.dart';

const _arabicWeekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _arabicMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String _greeting(DateTime now) {
  if (now.hour < 5) return 'سهران لسه؟';
  if (now.hour < 12) return 'صباح الخير ☀️';
  if (now.hour < 17) return 'يومك سعيد';
  if (now.hour < 21) return 'مساء الخير 🌇';
  return 'مساء الخير 🌙';
}

String _arabicDate(DateTime now) =>
    '${_arabicWeekdays[now.weekday - 1]}، ${now.day} ${_arabicMonths[now.month - 1]}';

/// اليوم — Operational dashboard: إيه اللي محتاج انتباه دلوقتي، مش مجرد تقرير.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _S();
}

class _S extends State<TodayScreen> {
  final _capture = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _capture.dispose();
    super.dispose();
  }

  // نقطة دخول سريعة للمساعد من نفس شاشة اليوم — بدون الخروج للشات —
  // بتستخدم نفس AssistantController.handle الموجود، من غير أي منطق AI جديد.
  Future<void> _quickCapture() async {
    final text = _capture.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final reply = await AssistantController.handle(text);
      _capture.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reply)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = today.toIso8601String().substring(0, 10);

    final commitments = StorageService.commitments();
    final overdue = commitments.where((x) => x.status == 'pending' && x.dueDate.isBefore(today)).toList();
    final dueToday = commitments
        .where((x) =>
            x.status == 'pending' &&
            x.dueDate.year == today.year &&
            x.dueDate.month == today.month &&
            x.dueDate.day == today.day)
        .toList();
    final upcoming = commitments.where((x) => x.status == 'pending' && x.dueDate.isAfter(today)).toList();

    // تذكيرات فعلية فشلت في الوصول — مش مجرد عرض نظري؛ متصلة بمعمارية الـ
    // Reminder الحقيقية (notification_service + reminder_service).
    final brokenReminders = StorageService.reminders().where((r) => r.status != 'scheduled' && r.status != 'cancelled').toList();

    // حالة العمل الحية: موردين وعاملين نشطين فقط (غير مؤرشفين).
    final activeEmployees = StorageService.employees().where((e) => !e.archived).toList();
    final absentToday = activeEmployees.where((e) => !e.attendance.contains(todayStr)).length;
    final activeSuppliers = StorageService.suppliers().where((s) => !s.archived).toList();
    final suppliersDue = activeSuppliers.fold<double>(0, (sum, s) => sum + s.balanceDue);
    final customersOverdue = overdue.where((c) => c.type == 'debt_to_collect').fold<double>(0, (sum, c) => sum + (c.amount ?? 0));

    final nothingPending = overdue.isEmpty && dueToday.isEmpty && upcoming.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('ماذا عليك اليوم؟')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.x4, AppSpace.x2, AppSpace.x4, AppSpace.x1),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(now), style: AppText.h1),
              const SizedBox(height: AppSpace.x1),
              Text(_arabicDate(now), style: AppText.bodyMuted),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x2),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _capture,
                      enabled: !_busy,
                      onSubmitted: (_) => _quickCapture(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'قول أو اكتب أي حاجة محتاج تسجلها…',
                      ),
                    ),
                  ),
                  _busy
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpace.x2),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: _quickCapture),
                ]),
              ),
            ),
          ),
          if (brokenReminders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.x4, AppSpace.x2, AppSpace.x4, AppSpace.x2),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationDebugScreen())),
                child: AppStatusBanner(
                  message: '${brokenReminders.length} تذكير ما وصلش صح — افتح تشخيص الإشعارات',
                  kind: AppStatusKind.warning,
                ),
              ),
            ),
          if (activeEmployees.isNotEmpty || activeSuppliers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
              child: Wrap(spacing: AppSpace.x2, runSpacing: AppSpace.x2, children: [
                if (activeEmployees.isNotEmpty)
                  AppBadge(
                    '$absentToday من ${activeEmployees.length} لسه ما حضرش',
                    kind: absentToday > 0 ? AppStatusKind.warning : AppStatusKind.success,
                  ),
                if (customersOverdue > 0) AppBadge('${customersOverdue.toStringAsFixed(0)} ج متأخرة عند عملاء', kind: AppStatusKind.danger),
                if (suppliersDue > 0) AppBadge('${suppliersDue.toStringAsFixed(0)} ج مستحق لموردين', kind: AppStatusKind.info),
              ]),
            ),
          _section(context, '🔴 متأخر', overdue),
          _section(context, '🟡 اليوم', dueToday),
          _section(context, '🟢 قادم', upcoming),
          if (nothingPending)
            const Padding(
              padding: EdgeInsets.only(top: AppSpace.x10),
              child: AppEmptyState(
                icon: Icons.event_available_outlined,
                title: 'لا توجد التزامات بعد',
                subtitle: 'ابدأ من الشات: "أحمد عليه 3500 هيدفع الخميس"',
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Commitment> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppSectionHeader(title),
      ...items.map((x) => Card(
            child: ListTile(
              title: Text('${x.person}${x.amount == null ? '' : ' - ${x.amount!.toStringAsFixed(0)} ج'}'),
              subtitle: Text(x.textOriginal),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'تأجيل يوم',
                  icon: const Icon(Icons.snooze),
                  onPressed: () => _postpone(x),
                ),
                IconButton(
                  tooltip: 'تم',
                  icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                  onPressed: () => _markDone(x),
                ),
              ]),
            ),
          )),
    ]);
  }

  Future<void> _markDone(Commitment x) async {
    x.status = 'done';
    await StorageService.saveCommitment(x);
    // لازم نلغي الـ Reminder entity المرتبطة فعليًا، مش الـ Commitment نفسه —
    // الاتنين معرفات مختلفة في معمارية الـ Reminder.
    for (final r in StorageService.remindersForEntity(x.id)) {
      await ReminderService.cancel(r.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _postpone(Commitment x) async {
    x.dueDate = x.dueDate.add(const Duration(days: 1));
    x.remindAt = x.remindAt.add(const Duration(days: 1));
    await StorageService.saveCommitment(x);
    final linked = StorageService.remindersForEntity(x.id);
    if (linked.isNotEmpty) {
      final r = linked.first;
      r.dueAt = x.remindAt;
      await ReminderService.retry(r);
    }
    if (mounted) setState(() {});
  }
}
