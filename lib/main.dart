import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/rules_service.dart';
import 'services/reminder_service.dart';
import 'services/app_state.dart';
import 'services/settings_service.dart';
import 'services/app_error_service.dart';
import 'services/chat_history_service.dart';
import 'screens/main_shell.dart';
import 'design/app_theme.dart';
import 'design/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // أي فشل أو تعليق في تهيئة التخزين كان بيسيب الشاشة سوداء للأبد لأن runApp
  // ما كانتش بتتنادى (APK 76). دلوقتي بنعرض رسالة خطأ مقروءة بدل الشاشة السوداء.
  try {
    await StorageService.init().timeout(const Duration(seconds: 15));
    await AppErrorService.init();
    await ChatHistoryService.init();
    await SettingsService.init();
    tz.initializeTimeZones();
  } catch (e) {
    final msg = e.toString();
    runApp(_StartupErrorApp(
        details: msg.length > 400 ? msg.substring(0, 400) : msg));
    return;
  }
  // بدء خدمات التنبيهات — أي فشل هنا لا يمنع فتح التطبيق ولا يعطّل أي عملية
  // محلية، والتفاصيل التقنية تُسجَّل محليًا فقط (§6/§8).
  try {
    await NotificationService.init();
    await NotificationService.requestPermission();
    await ReminderService.rescheduleAllActive();
    await RulesService.checkAndTrigger();
  } catch (e, st) {
    AppErrorService.log('startup', e, st);
  }
  runApp(const ManagerApp());
}

/// شاشة بدء طارئة: تظهر فقط لو فشلت تهيئة التخزين، بدل شاشة سوداء صامتة.
class _StartupErrorApp extends StatelessWidget {
  final String details;
  const _StartupErrorApp({required this.details});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تعذّر بدء التطبيق',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                          'حصلت مشكلة أثناء تجهيز التخزين المحلي. بياناتك لم تُمسح. '
                          'صوّر هذه الشاشة وابعتها للمطوّر.'),
                      const SizedBox(height: 16),
                      SelectableText(details,
                          textDirection: TextDirection.ltr),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class ManagerApp extends StatelessWidget {
  const ManagerApp({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: L.t('app_title'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          // الثيم واللغة محفوظان محليًا (To Accio §6)؛ تغييرهما يستدعي
          // AppState.notify() من شاشة الإعدادات فيُعاد بناء MaterialApp.
          themeMode: SettingsService.themeMode,
          // ملحوظة مهمة: من غير const هنا، MainShell مش هيتبني تاني لما
          // AppState يبعت إشعار — Flutter بيتجاهل إعادة بناء الـconst
          // widgets تمامًا حتى لو الأب اتبنى من جديد.
          home: Directionality(textDirection: L.direction, child: MainShell()),
        ),
      );
}
