import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../../features/home/providers/dashboard_provider.dart';
import '../../../features/expenses/providers/expenses_provider.dart';
import '../../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../../features/goals/presentation/screens/goals_screen.dart';
import '../../../features/incomes/presentation/screens/incomes_screen.dart';
import '../widgets/offline_banner.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh all main providers when user returns to app
      ref.invalidate(dashboardProvider);
      ref.invalidate(insightsProvider);
      ref.invalidate(expensesProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(goalsProvider);
      ref.invalidate(incomesProvider);
    }
  }

  // Main tabs shown in the bottom nav
  static const _tabs = [
    AppRoutes.home,
    AppRoutes.expenses,
    AppRoutes.incomes,
    AppRoutes.budgets,
    AppRoutes.goals,
  ];

  static const _labels = ['Inicio', 'Gastos', 'Ingresos', 'Presup.', 'Metas'];

  static const _icons = [
    Icons.home_outlined,
    Icons.receipt_long_outlined,
    Icons.trending_up_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.savings_outlined,
  ];

  static const _activeIcons = [
    Icons.home,
    Icons.receipt_long,
    Icons.trending_up,
    Icons.account_balance_wallet,
    Icons.savings,
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabIndex(location);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withAlpha(18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBar(
              height: 74,
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(_tabs[i]),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: List.generate(
                _tabs.length,
                (i) => NavigationDestination(
                  icon: Icon(_icons[i]),
                  selectedIcon: Icon(_activeIcons[i]),
                  label: _labels[i],
                ),
              ),
            ),
          ),
        ),
      ),
      // FAB only on Expenses list screen for quick add
      floatingActionButton: location == AppRoutes.expenses
          ? FloatingActionButton(
              onPressed: () => context.go(AppRoutes.addExpense),
              tooltip: 'Agregar gasto',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  int _tabIndex(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }
}
