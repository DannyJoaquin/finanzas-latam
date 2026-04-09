import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  // Main tabs shown in the bottom nav
  static const _tabs = [
    AppRoutes.home,
    AppRoutes.expenses,
    AppRoutes.incomes,
    AppRoutes.budgets,
    AppRoutes.goals,
  ];

  static const _labels = ['Inicio', 'Gastos', 'Ingresos', 'Presupuestos', 'Metas'];

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
      body: child,
      // Use NavigationBar (Material 3) — cleaner look, better with 5 items
      bottomNavigationBar: NavigationBar(
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
