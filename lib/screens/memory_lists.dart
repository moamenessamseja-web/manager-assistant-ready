import 'package:flutter/material.dart';
import '../design/format.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../services/storage_service.dart';

/// قائمة التذكيرات (للقراءة فقط) — بتتفتح من كارت «تذكيرات» في الذاكرة.
/// فتح الشاشة ما بيعدّلش ولا بيحذف ولا بيضيف أي سجل.
class RemindersListScreen extends StatelessWidget {
  const RemindersListScreen({super.key});

  String _statusAr(String s, bool enabled) {
    if (!enabled || s == 'cancelled') return 'متوقف';
    switch (s) {
      case 'scheduled':
        return 'مجدول';
      case 'permission_required':
        return 'محتاج صلاحية';
      case 'channel_disabled':
        return 'القناة متوقفة';
      case 'schedule_failed':
        return 'فشلت الجدولة';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = StorageService.reminders()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return Scaffold(
      appBar: AppBar(title: const Text('التذكيرات')),
      body: items.isEmpty
          ? const AppEmptyState(
              icon: Icons.notifications_none,
              title: 'لا توجد تذكيرات بعد',
              subtitle: 'مثال من الشات: «فكرني بكرة الساعة ٥ العصر أتصل بالعميل»',
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpace.x3),
              children: [
                for (final r in items)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        r.dueAt.isBefore(DateTime.now()) && r.enabled
                            ? Icons.warning_amber_rounded
                            : Icons.notifications_outlined,
                      ),
                      title: Text(r.title),
                      subtitle: Text(
                          '${r.body}\n${arabicDateTime(r.dueAt)} — ${_statusAr(r.status, r.enabled)}'),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// قائمة الالتزامات (للقراءة فقط) — بتتفتح من كارت «التزامات» في الذاكرة.
class CommitmentsListScreen extends StatelessWidget {
  const CommitmentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = StorageService.commitments()
      ..sort((a, b) {
        final ap = a.status == 'pending' ? 0 : 1;
        final bp = b.status == 'pending' ? 0 : 1;
        if (ap != bp) return ap.compareTo(bp);
        return a.dueDate.compareTo(b.dueDate);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('الالتزامات')),
      body: items.isEmpty
          ? const AppEmptyState(
              icon: Icons.schedule,
              title: 'لا توجد التزامات بعد',
              subtitle: 'مثال من الشات: «جمال هيجيب بكرة الساعة ٥ العصر ٥ كراتين لبن»',
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpace.x3),
              children: [
                for (final c in items)
                  Card(
                    child: ListTile(
                      leading: Icon(c.status == 'done'
                          ? Icons.check_circle_outline
                          : Icons.schedule),
                      title: Text(c.person == 'عام' ? c.textOriginal : c.person),
                      subtitle: Text(
                          '${c.person == 'عام' ? '' : '${c.textOriginal}\n'}${arabicDateTime(c.dueDate)}${c.amount == null ? '' : ' — ${c.amount!.toStringAsFixed(0)} ج'}'),
                      isThreeLine: c.person != 'عام',
                      trailing: Text(c.status == 'done' ? 'تم' : 'قائم'),
                    ),
                  ),
              ],
            ),
    );
  }
}
