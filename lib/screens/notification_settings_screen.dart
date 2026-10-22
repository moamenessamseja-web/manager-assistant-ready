import 'package:flutter/material.dart';
import '../design/tokens.dart';
import '../services/notification_prefs.dart';
import '../services/notification_service.dart';

/// إعدادات الإشعارات — بتضبط **سلوك** الإشعارات الجاية. (مركز الإشعارات/الجرس
/// شاشة منفصلة بتعرض السجل والحالة.) كل خيار هنا بيتحفظ وبيأثر فعليًا على
/// جدولة الإشعارات الجديدة.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool? _permission;
  bool? _exact;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    bool ok;
    try {
      ok = await NotificationService.permissionGranted();
    } catch (_) {
      ok = true;
    }
    bool exact;
    try {
      exact = await NotificationService.exactAlarmsAllowed();
    } catch (_) {
      exact = false;
    }
    if (mounted) {
      setState(() {
        _permission = ok;
        _exact = exact;
      });
    }
  }

  Future<void> _toggle(String category, bool v) async {
    await NotificationPrefs.setCategory(category, v);
    if (mounted) setState(() {});
  }

  Future<void> _setLead(int m) async {
    await NotificationPrefs.setLeadMinutes(m);
    if (mounted) setState(() {});
  }

  String _leadLabel(int m) => m == 0 ? 'في الموعد' : 'قبلها بـ $m دقيقة';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الإشعارات')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.x4),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                _permission == false
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
              ),
              title: Text(_permission == null
                  ? 'جاري فحص الصلاحية...'
                  : (_permission!
                      ? 'صلاحية الإشعارات مفعّلة'
                      : 'صلاحية الإشعارات غير مفعّلة')),
              trailing: _permission == false
                  ? TextButton(
                      onPressed: () async {
                        await NotificationService.requestPermission();
                        await _loadPermission();
                      },
                      child: const Text('تفعيل'),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpace.x2),
          Card(
            child: ListTile(
              leading: Icon(_exact == true ? Icons.alarm_on : Icons.alarm_off),
              title: Text(_exact == null
                  ? 'جاري فحص المنبهات الدقيقة...'
                  : (_exact!
                      ? 'المنبهات الدقيقة مسموحة — التنبيه في ميعاده بالظبط'
                      : 'المنبهات الدقيقة غير مسموحة — ممكن التنبيه يتأخر دقايق')),
              trailing: _exact == false
                  ? TextButton(
                      onPressed: () async {
                        await NotificationService.requestExactAlarms();
                        await _loadPermission();
                      },
                      child: const Text('السماح'),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpace.x3),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.x2),
            child: Text('أنواع الإشعارات',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('التذكيرات والالتزامات'),
            subtitle: const Text('تذكير طلبته بنفسك أو التزام مسجّل'),
            value: NotificationPrefs.reminders,
            onChanged: (v) => _toggle('reminders', v),
          ),
          SwitchListTile(
            title: const Text('توريدات الموردين المتوقعة'),
            subtitle: const Text('تنبيه وقت التوريد المتوقع لتأكيد الاستلام'),
            value: NotificationPrefs.suppliers,
            onChanged: (v) => _toggle('suppliers', v),
          ),
          SwitchListTile(
            title: const Text('القواعد المتكررة'),
            subtitle: const Text('زي «كل أول الشهر فكرني بالإيجار»'),
            value: NotificationPrefs.rules,
            onChanged: (v) => _toggle('rules', v),
          ),
          const SizedBox(height: AppSpace.x3),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.x2),
            child: Text('توقيت التنبيه',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Wrap(
            spacing: AppSpace.x2,
            children: [
              for (final m in NotificationPrefs.leadOptions)
                ChoiceChip(
                  label: Text(_leadLabel(m)),
                  selected: NotificationPrefs.leadMinutes == m,
                  onSelected: (_) => _setLead(m),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.x4),
          const Text(
            'ملاحظات: التغيير هنا بيسري على الإشعارات الجديدة فقط. صوت الإشعار '
            'بيتحكم فيه نظام أندرويد من إعدادات التطبيق ← الإشعارات ← «تذكيرات '
            'الإدارة»، ولسه مفيش اختيار نغمة مخصّصة جوه التطبيق.',
          ),
        ],
      ),
    );
  }
}
