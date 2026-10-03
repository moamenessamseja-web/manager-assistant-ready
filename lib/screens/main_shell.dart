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

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // الشاشات الأساسية (شريط سفلي) — الأكثر استخدامًا يوميًا
  static const List<Widget> _primary = [
    ChatScreen(),
    TodayScreen(),
    MemoryScreen(),
    StaffScreen(),
    SuppliersScreen(),
  ];

  // شاشات ثانوية (تُفتح من القائمة الجانبية) — تُستخدم بشكل أقل تكرارًا
  static const List<Widget> _secondary = [
    RulesScreen(),
    BriefScreen(),
    SettingsScreen(),
  ];

  static const _secondaryTitles = ['القواعد والتنبيهات', 'بريف الأسبوع', 'الإعدادات'];
  static const _secondaryIcons = [Icons.rule, Icons.insights, Icons.settings];

  @override
  Widget build(BuildContext context) {
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
            for (var i = 0; i < _secondary.length; i++)
              ListTile(
                leading: Icon(_secondaryIcons[i]),
                title: Text(_secondaryTitles[i]),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => _secondary[i]));
                },
              ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: _primary),
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
