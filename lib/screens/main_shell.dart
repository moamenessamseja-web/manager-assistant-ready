import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'today_screen.dart';
import 'memory_screen.dart';
import 'staff_screen.dart';
import 'suppliers_screen.dart';
import 'rules_screen.dart';
import 'brief_screen.dart';
import 'settings_screen.dart';
import '../design/tokens.dart';
import '../services/app_state.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // أي كتابة بيانات في أي شاشة (حتى لو مش الشاشة الظاهرة دلوقتي) بتستدعي
    // setState هنا، وده بيجبر IndexedStack يبني كل الشاشات من جديد بأحدث
    // بيانات — بدل ما المستخدم يحتاج يقفل التطبيق ويفتحه تاني.
    AppState.instance.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  // شاشات ثانوية (تُفتح من القائمة الجانبية) — تُستخدم بشكل أقل تكرارًا
  static const _secondaryTitles = ['القواعد والتنبيهات', 'بريف الأسبوع', 'الإعدادات'];
  static const _secondaryIcons = [Icons.rule, Icons.insights, Icons.settings];

  @override
  Widget build(BuildContext context) {
    // عمدًا مش const: لازم instance جديدة في كل build() عشان Flutter
    // يعيد نداء build() على كل شاشة تاني، بدل ما يتجاهلها كـconst مطابقة
    // للي قبلها. الـkeys بتحافظ على الـState الداخلي لكل شاشة (زي محتوى
    // الشات) مستقر عبر عمليات إعادة البناء.
    final primary = <Widget>[
      ChatScreen(key: const ValueKey('tab-chat')),
      TodayScreen(key: const ValueKey('tab-today')),
      MemoryScreen(key: const ValueKey('tab-memory')),
      StaffScreen(key: const ValueKey('tab-staff')),
      SuppliersScreen(key: const ValueKey('tab-suppliers')),
    ];
    final secondary = <Widget>[
      RulesScreen(key: const ValueKey('sec-rules')),
      BriefScreen(key: const ValueKey('sec-brief')),
      SettingsScreen(key: const ValueKey('sec-settings')),
    ];
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text('مساعد الإدارة', style: AppText.h1.copyWith(color: Colors.white)),
              ),
            ),
            for (var i = 0; i < secondary.length; i++)
              ListTile(
                leading: Icon(_secondaryIcons[i]),
                title: Text(_secondaryTitles[i]),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => secondary[i]));
                },
              ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: primary),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'menuBtn',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        child: const Icon(Icons.menu),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat), label: 'الشات'),
          NavigationDestination(icon: Icon(Icons.today), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.search), label: 'الذاكرة'),
          NavigationDestination(icon: Icon(Icons.people), label: 'العاملين'),
          NavigationDestination(icon: Icon(Icons.local_shipping), label: 'الموردين'),
        ],
      ),
    );
  }
}
