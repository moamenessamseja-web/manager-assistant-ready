import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/cafe_profile_service.dart';
import 'cafe_logo_image.dart';
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
  final _cafeName = TextEditingController(text: CafeProfileService.name);

  @override
  void dispose() {
    _cafeName.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _saveCafeName() async {
    try {
      await CafeProfileService.setName(_cafeName.text);
      if (mounted) {
        FocusScope.of(context).unfocus();
        _snack(CafeProfileService.hasCustomName ? 'تم حفظ اسم الكافيه' : 'رجعنا للعنوان العام');
      }
    } catch (_) {
      if (mounted) _snack('تعذّر حفظ الاسم');
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
      if (picked == null) return;
      // نسخة داخل مجلد التطبيق (نفس طريقة صور الموظفين) عشان ما تضيعش مع الكاش.
      final dir = await getApplicationDocumentsDirectory();
      final logoDir = Directory('${dir.path}/cafe_logo');
      if (!logoDir.existsSync()) logoDir.createSync(recursive: true);
      final dest = '${logoDir.path}/logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(dest);
      await CafeProfileService.setLogoPath(dest);
      if (mounted) {
        setState(() {});
        _snack('تم تحديث الشعار');
      }
    } catch (_) {
      if (mounted) _snack('تعذّر اختيار الصورة');
    }
  }

  Future<void> _removeLogo() async {
    await CafeProfileService.clearLogo();
    if (mounted) setState(() {});
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
          // ── هوية الكافيه ──
          AppSectionHeader(title: 'هوية الكافيه'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const CafeLogoImage(
                        fallback: Icons.storefront_outlined, color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: Wrap(spacing: AppSpace.x2, children: [
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(CafeProfileService.logoFile != null ? 'استبدال الشعار' : 'اختيار شعار'),
                      ),
                      if (CafeProfileService.logoPath.isNotEmpty)
                        TextButton(onPressed: _removeLogo, child: const Text('إزالة')),
                    ]),
                  ),
                ]),
                const SizedBox(height: AppSpace.x3),
                TextField(
                  controller: _cafeName,
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveCafeName(),
                  decoration: const InputDecoration(
                    labelText: 'اسم الكافيه',
                    helperText: 'بيظهر في القائمة والمحادثة بدل «مساعد الإدارة». سيبه فاضي للعنوان العام.',
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton(onPressed: _saveCafeName, child: const Text('حفظ الاسم')),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.x2),
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
