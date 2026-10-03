import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import 'notification_debug_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _S();
}

class _S extends State<SettingsScreen> {
  late TextEditingController c;
  @override
  void initState() {
    super.initState();
    c = TextEditingController(text: StorageService.apiKey);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext x) => Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          children: [
            const AppSectionHeader('Gemini API Key'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: c,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'الصق المفتاح هنا'),
                ),
                const SizedBox(height: AppSpace.x3),
                FilledButton(
                  onPressed: () async {
                    await StorageService.setApiKey(c.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المفتاح ✅')));
                    }
                  },
                  child: const Text('حفظ المفتاح'),
                ),
                const SizedBox(height: AppSpace.x2),
                const Text('المفتاح محفوظ محلياً على الجهاز لأغراض الـMVP. لا تضعه داخل الكود أو GitHub.', style: AppText.bodyMuted),
              ]),
            ),
            const Divider(height: AppSpace.x8),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('تشخيص الإشعارات'),
              subtitle: const Text('اعرف ليه تنبيه ما وصلش'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationDebugScreen())),
            ),
          ],
        ),
      );
}
