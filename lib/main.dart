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
  await StorageService.init();
  await AppErrorService.init();
  await ChatHistoryService.init();
  await SettingsService.init();
  tz.initializeTimeZones();
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
