import 'package:flutter/material.dart';
import '../design/format.dart';
import '../design/widgets.dart';
import '../models/commitment.dart';
import '../models/rule.dart';
import '../services/app_state.dart';
import '../services/reminder_manager.dart';
import '../services/storage_service.dart';
import 'notification_settings_screen.dart';
import 'reminder_editor.dart';

/// القواعد والتنبيهات — الطريقة **الأساسية والمستقلة** لإدارة التذكيرات
/// (من غير اعتماد على الشات): تبويب «تذكيرات» (مرة واحدة) وتبويب «قواعد
/// متكررة». كله بيتحفظ في نفس التخزين، وبيظهر في «اليوم» و«الذاكرة»، وبيتجدول
/// فعليًا كإشعارات أندرويد (ReminderManager → ReminderService → NotificationService).
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});
  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _snack(String? m) {
    if (m == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _add() async => _snack(await showReminderEditor(context));

  Future<bool> _confirm(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    return ok == true;
  }

  /// حالة التنبيه الفعلية (من سجل Reminder المرتبط) — مش افتراض إنه اتجدول.
  String _status(String entityId, DateTime due, {bool done = false}) {
    if (done) return 'تم';
    final rs = StorageService.remindersForEntity(entityId);
    if (rs.isEmpty) return 'بدون تنبيه';
    final r = rs.last;
    if (!r.enabled || r.status == 'cancelled') return 'التنبيه متوقف';
    switch (r.status) {
      case 'scheduled':
        return (r.recurrence == 'none' && due.isBefore(DateTime.now()))
            ? 'فات موعده'
            : '✓ التنبيه مجدول';
      case 'permission_required':
        return '⚠ صلاحية الإشعارات غير مفعّلة';
      case 'schedule_failed':
        return '⚠ فشلت الجدولة';
      default:
        return r.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القواعد والتنبيهات'),
        actions: [
          IconButton(
            tooltip: 'إعدادات الإشعارات',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'تذكيرات'), Tab(text: 'قواعد متكررة')],
        ),
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => TabBarView(
          controller: _tabs,
          children: [_oneOffs(), _rules()],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: _add,
          tooltip: 'تذكير جديد',
          child: const Icon(Icons.add_alarm)),
    );
  }

  Widget _oneOffs() {
    final items = StorageService.commitments()
        .where((c) => c.type == 'task')
        .toList()
      ..sort((a, b) {
        final ap = a.status == 'pending' ? 0 : 1;
        final bp = b.status == 'pending' ? 0 : 1;
        if (ap != bp) return ap.compareTo(bp);
        return a.remindAt.compareTo(b.remindAt);
      });
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.notifications_none,
        title: 'لا توجد تذكيرات بعد',
        subtitle: 'اضغط زر المنبه + لإضافة تذكير بتاريخ وساعة',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [for (final c in items) _oneOffTile(c)],
    );
  }

  Widget _oneOffTile(Commitment c) {
    final done = c.status == 'done';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(done ? Icons.check_circle_outline : Icons.alarm),
        title: Text(c.textOriginal),
        subtitle: Text(
            '${arabicDateTime12(c.remindAt)}\n${_status(c.id, c.remindAt, done: done)}'),
        isThreeLine: true,
        onTap: done ? null : () async => _snack(await showReminderEditor(context, oneOff: c)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!done)
            IconButton(
              tooltip: 'تم',
              icon: const Icon(Icons.check),
              onPressed: () => ReminderManager.markDone(c),
            ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await _confirm('حذف التذكير؟')) {
                await ReminderManager.deleteOneOff(c);
              }
            },
          ),
        ]),
      ),
    );
  }

  Widget _rules() {
    final rules = StorageService.rules();
    if (rules.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_repeat,
        title: 'لا يوجد قواعد متابعة بعد',
        subtitle: 'مثال: كل أول الشهر فكرني بالإيجار — اضغط زر المنبه + واختار «شهري»',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [for (final r in rules) _ruleTile(r)],
    );
  }

  Widget _ruleTile(FollowUpRule r) {
    const names = {'monthly': 'شهرية', 'weekly': 'أسبوعية', 'daily': 'يومية'};
    final freqAr = names[r.frequency] ?? r.frequency;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
            r.active ? Icons.notifications_active : Icons.notifications_off),
        title: Text(r.text),
        subtitle: Text(
            '$freqAr — القادمة: ${arabicDateTime12(r.nextDue)}\n${r.active ? _status(r.id, r.nextDue) : 'متوقفة'}'),
        isThreeLine: true,
        onTap: () async => _snack(await showReminderEditor(context, rule: r)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Switch(
            value: r.active,
            onChanged: (v) => ReminderManager.setRuleActive(r, v),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await _confirm('حذف القاعدة؟')) {
                await ReminderManager.deleteRule(r);
              }
            },
          ),
        ]),
      ),
    );
  }
}
