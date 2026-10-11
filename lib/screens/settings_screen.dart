import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/app_state.dart';
import '../services/settings_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/strings.dart';
import 'notification_debug_screen.dart';

/// الإعدادات — مظهر (فاتح/داكن/حسب النظام) + لغة (عربي/إنجليزي)
/// + مفتاح Gemini + تشخيص الإشعارات. كل اختيار يُحفظ فعليًا (To Accio §6).
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

  Future<void> _setTheme(ThemeMode m) async {
    await SettingsService.setThemeMode(m);
    AppState.instance.notify(); // يُعيد بناء MaterialApp بالثيم الجديد
    if (mounted) setState(() {});
  }

  Future<void> _setLang(String code) async {
    await SettingsService.setLanguage(code);
    AppState.instance.notify(); // يُعيد بناء MaterialApp بالاتجاه الجديد
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mode = SettingsService.themeMode;
    return Scaffold(
      appBar: AppBar(title: Text(L.t('settings'))),
      body: ListView(
        children: [
          // ── المظهر ──
          AppSectionHeader(title: L.t('appearance')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Wrap(
              spacing: AppSpace.x2,
              children: [
                for (final (label, m) in [
                  (L.t('theme_light'), ThemeMode.light),
                  (L.t('theme_dark'), ThemeMode.dark),
                  (L.t('theme_system'), ThemeMode.system),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: mode == m,
                    onSelected: (_) => _setTheme(m),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.x4),

          // ── اللغة ──
          AppSectionHeader(title: L.t('language')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.x2,
                  children: [
                    for (final (label, code) in [
                      (L.t('lang_arabic'), 'ar'),
                      (L.t('lang_english'), 'en'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: L.lang == code,
                        onSelected: (_) => _setLang(code),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.x2),
                Text(L.t('language_note'), style: AppText.caption),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.x4),
          const Divider(height: 1),

          // ── المفتاح ──
          AppSectionHeader(title: L.t('gemini_key')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: c,
                  obscureText: true,
                  decoration: InputDecoration(hintText: L.t('gemini_hint')),
                ),
                const SizedBox(height: AppSpace.x3),
                FilledButton(
                  onPressed: () async {
                    await StorageService.setApiKey(c.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(L.t('saved'))),
                      );
                    }
                  },
                  child: Text(L.t('save_key')),
                ),
                const SizedBox(height: AppSpace.x2),
                Text(L.t('key_note'), style: AppText.bodyMuted),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.x4),
          const Divider(height: 1),

          // ── عام ──
          AppSectionHeader(title: L.t('general')),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(L.t('notif_diag')),
            subtitle: Text(L.t('notif_diag_sub')),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationDebugScreen()),
            ),
          ),
          const SizedBox(height: AppSpace.x8),
        ],
      ),
    );
  }
}
