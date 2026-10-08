import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/rules_service.dart';
import 'services/reminder_service.dart';
import 'services/app_state.dart';
import 'screens/main_shell.dart';
import 'design/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  tz.initializeTimeZones();
  await NotificationService.init();
  await NotificationService.requestPermission();
  await ReminderService.rescheduleAllActive();
  await RulesService.checkAndTrigger();
  runApp(const ManagerApp());
}

class ManagerApp extends StatelessWidget {
  const ManagerApp({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'مساعد الإدارة',
          theme: AppTheme.light(),
          home: const Directionality(textDirection: TextDirection.rtl, child: MainShell()),
        ),
      );
}
