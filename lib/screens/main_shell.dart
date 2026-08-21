import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'alarm_timer_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          AlarmTimerScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Colors.transparent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            selectedIcon: Icon(Icons.checklist_rounded,
                color: AppColors.primary),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_rounded),
            selectedIcon: Icon(Icons.alarm_rounded, color: AppColors.primary),
            label: 'Alarm & Timer',
          ),
        ],
      ),
    );
  }
}
