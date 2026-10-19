import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/settings_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/strings.dart';
import 'notification_debug_screen.dart';

/// الإعدادات — مظهر (فاتح/داكن/حسب النظام) + لغة (عربي/إنجليزي)
/// + تشخيص الإشعارات. كل اختيار يُحفظ فعليًا. المحرك المحلي هو الوحيد:
/// مفيش مفتاح API ولا خدمة ذكاء اصطناعي خارجية.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _S();
}

class _S extends State<SettingsScreen> {
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

          // ── وضع العمل ──
          // المحرك المحلي هو المسار الأساسي والافتراضي دايمًا: يفهم الأوامر
          // المدعومة على الجهاز نفسه، ويعمل بالكامل بدون إنترنت وبدون أي مفتاح.
          AppSectionHeader(title: L.t('offline_title')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Text(L.t('offline_note'), style: AppText.bodyMuted),
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
              MaterialPageRoute(
                  builder: (_) => const NotificationDebugScreen()),
            ),
          ),
          const SizedBox(height: AppSpace.x8),
        ],
      ),
    );
  }
}
