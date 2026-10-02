import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// شاشة تشخيص غير مخصصة للمستخدم العادي — تساعد في معرفة سبب عدم وصول
/// تنبيه بسرعة: هل الصلاحية ممنوحة؟ هل فيه تذكيرات متعطلة؟ هل الجدولة فعلاً حصلت؟
class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});
  @override
  State<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  bool? _granted;
  int _pendingCount = 0;
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final granted = await NotificationService.permissionGranted();
    final pending = await NotificationService.pending();
    setState(() {
      _granted = granted;
      _pendingCount = pending.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminders = StorageService.reminders()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final failed = reminders.where((r) => r.status != 'scheduled' && r.status != 'cancelled').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('تشخيص الإشعارات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_granted == true ? Icons.check_circle : Icons.cancel,
                      color: _granted == true ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Text('صلاحية الإشعارات: ${_granted == null ? '...' : (_granted! ? 'ممنوحة' : 'غير ممنوحة')}'),
                ]),
                const SizedBox(height: 8),
                Text('الإشعارات المجدولة حالياً عند النظام: $_pendingCount'),
                Text('إجمالي التذكيرات المسجلة: ${reminders.length}'),
                Text('تذكيرات بها مشكلة: ${failed.length}',
                    style: TextStyle(color: failed.isEmpty ? null : Colors.orange, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await NotificationService.requestPermission();
                  await _refresh();
                },
                child: const Text('طلب الصلاحية'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final res = await NotificationService.scheduleAt(
                    999999,
                    'اختبار الإشعارات',
                    'لو وصلك ده، الجدولة شغالة صح ✅',
                    DateTime.now().add(const Duration(seconds: 5)),
                  );
                  setState(() => _testResult = res.success
                      ? 'اتجدول بنجاح — هيوصل خلال 5 ثواني'
                      : 'فشل: ${res.status} ${res.message ?? ''}');
                  await _refresh();
                },
                child: const Text('اختبار إشعار'),
              ),
            ),
          ]),
          if (_testResult.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_testResult)),
          const Divider(height: 32),
          const Text('آخر التذكيرات:', style: TextStyle(fontWeight: FontWeight.bold)),
          if (reminders.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا يوجد تذكيرات بعد.')),
          ...reminders.take(30).map((r) => ListTile(
                dense: true,
                leading: Icon(
                  r.status == 'scheduled'
                      ? Icons.check_circle_outline
                      : r.status == 'cancelled'
                          ? Icons.block
                          : Icons.error_outline,
                  color: r.status == 'scheduled'
                      ? Colors.green
                      : r.status == 'cancelled'
                          ? Colors.grey
                          : Colors.red,
                ),
                title: Text(r.title),
                subtitle: Text('${r.status} — ${r.dueAt.toString().substring(0, 16)}'),
              )),
        ],
      ),
    );
  }
}
