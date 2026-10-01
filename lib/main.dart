import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/rules_service.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  tz.initializeTimeZones();
  await NotificationService.init();
  await RulesService.checkAndTrigger();
  runApp(const ManagerApp());
}

class ManagerApp extends StatelessWidget {
  const ManagerApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مساعد الإدارة',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        home: const Directionality(textDirection: TextDirection.rtl, child: MainShell()),
      );
}
