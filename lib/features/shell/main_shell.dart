import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../budget/budget_screen.dart';
import '../calendar/calendar_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../shared/quick_add_sheet.dart';
import '../tasks/tasks_screen.dart';
import '../vault/vault_screen.dart';

class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

final shellTabProvider =
    NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _screens = [
    DashboardScreen(),
    BudgetScreen(),
    CalendarScreen(),
    TasksScreen(),
    VaultScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellTabProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
      ),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.black,
              onPressed: () => showQuickAddSheet(context),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.cardBg,
        indicatorColor: AppColors.electricBlue.withValues(alpha: 0.18),
        selectedIndex: currentIndex,
        onDestinationSelected: (idx) =>
            ref.read(shellTabProvider.notifier).setTab(idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.emerald),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.emerald),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded,
                color: AppColors.electricBlue),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_box_outlined),
            selectedIcon: Icon(Icons.check_box_rounded,
                color: AppColors.electricBlue),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded, color: AppColors.purple),
            label: 'Vault',
          ),
        ],
      ),
    );
  }
}
