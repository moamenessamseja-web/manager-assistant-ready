import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';
import '../design/widgets.dart';
import '../design/strings.dart';
import 'notification_debug_screen.dart';

/// الإعدادات — مظهر (فاتح/داكن/حسب النظام) + لغة (عربي/إنجليزي)
/// + مفتاح Gemini الاختياري + تشخيص الإشعارات. كل اختيار يُحفظ فعليًا
/// (To Accio §6). المحرك المحلي يبقى هو المسار الأساسي والافتراضي دايمًا —
/// وجود المفتاح أو غيابه لا يعطّل أي عملية محلية (بريف §8/§9).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _S();
}

class _S extends State<SettingsScreen> {
  late final TextEditingController _keyCtrl =
      TextEditingController(text: StorageService.apiKey);
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
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

  Future<void> _saveKey() async {
    setState(() => _saving = true);
    try {
      final v = _keyCtrl.text.trim();
      // ignore: avoid_print
      print('DEBUG _saveKey about to save v="$v"');
      await StorageService.setApiKey(v);
      // ignore: avoid_print
      print('DEBUG _saveKey after await, apiKey="${StorageService.apiKey}"');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('saved'))),
    );
  }

  Future<void> _clearKey() async {
    setState(() {
      _keyCtrl.clear();
      _saving = true;
    });
    try {
      await StorageService.setApiKey('');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('key_cleared'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = SettingsService.themeMode;
    final hasKey = StorageService.apiKey.isNotEmpty;
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

          // ── مفتاح Gemini (اختياري) ──
          // مسار مساعد فقط لجُمل معقدة ما يفهمهاش المحرك المحلي. غيابه أو
          // فشله لا يعطّل أبدًا أي عملية محلية (بريف §8/§9). المفتاح بتاع
          // المستخدم نفسه — محفوظ على جهازه فقط، ولا يُرفع للمستودع ولا
          // يُضمَّن في الكود أو في أي بناء موزَّع.
          AppSectionHeader(title: L.t('gemini_key')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L.t('gemini_section_note'), style: AppText.bodyMuted),
                const SizedBox(height: AppSpace.x3),
                TextField(
                  controller: _keyCtrl,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: L.t('gemini_key'),
                    hintText: L.t('gemini_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.x2),
                Text(
                  hasKey ? L.t('key_configured') : L.t('key_not_configured'),
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: AppSpace.x3),
                Wrap(
                  spacing: AppSpace.x2,
                  runSpacing: AppSpace.x2,
                  children: [
                    ElevatedButton(
                      onPressed: _saving ? null : _saveKey,
                      child: Text(L.t('save_key')),
                    ),
                    OutlinedButton(
                      onPressed: (_saving || !hasKey) ? null : _clearKey,
                      child: Text(L.t('clear_key')),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.x2),
                Text(L.t('key_note'), style: AppText.caption),
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
