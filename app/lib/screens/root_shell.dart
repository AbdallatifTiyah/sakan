import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_lang.dart';
import 'home_screen.dart';
import 'seekers_screen.dart';
import 'settings_screen.dart';

/// الهيكل الجذري — شريط تنقّل سفلي بثلاث وجهات (بند ١٣): الرئيسية/الباحثين/
/// الإعدادات. كل وجهة شاشتها الكاملة (Scaffold خاص فيها) محفوظة بـIndexedStack
/// عشان حالتها (نتائج بحث، فلاتر) ما تضيع عند التبديل بين الوجهات.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [HomeScreen(), SeekersScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: sAppLang,
      builder: (context, lang, _) {
        return Scaffold(
          body: IndexedStack(index: _index, children: _screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: SColors.card,
            indicatorColor: SColors.blue100,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded, color: SColors.blue600),
                label: tt('الرئيسية', 'Home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.groups_outlined),
                selectedIcon: const Icon(Icons.groups_rounded, color: SColors.blue600),
                label: tt('الباحثين', 'Seekers'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded, color: SColors.blue600),
                label: tt('الإعدادات', 'Settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}
