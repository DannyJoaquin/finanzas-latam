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
import '../../providers/experience_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
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

  // Main tabs shown in the bottom nav — dynamic by experience mode
  static const _tabsAdvanced = [
    AppRoutes.home,
    AppRoutes.expenses,
    AppRoutes.incomes,
    AppRoutes.budgets,
    AppRoutes.goals,
    AppRoutes.shared,
  ];

  static const _tabsSimple = [
    AppRoutes.home,
    AppRoutes.expenses,
    AppRoutes.incomes,
    AppRoutes.goals,
    AppRoutes.shared,
  ];

  static const _labelsAdvanced = [
    'Inicio',
    'Gastos',
    'Ingresos',
    'Presup.',
    'Metas',
    'Grupos'
  ];
  static const _labelsSimple = [
    'Inicio',
    'Gastos',
    'Ingresos',
    'Metas',
    'Grupos'
  ];

  static const _iconsAdvanced = [
    Icons.home_outlined,
    Icons.receipt_long_outlined,
    Icons.trending_up_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.savings_outlined,
    Icons.group_outlined,
  ];
  static const _iconsSimple = [
    Icons.home_outlined,
    Icons.receipt_long_outlined,
    Icons.trending_up_outlined,
    Icons.savings_outlined,
    Icons.group_outlined,
  ];

  static const _activeIconsAdvanced = [
    Icons.home,
    Icons.receipt_long,
    Icons.trending_up,
    Icons.account_balance_wallet,
    Icons.savings,
    Icons.group,
  ];
  static const _activeIconsSimple = [
    Icons.home,
    Icons.receipt_long,
    Icons.trending_up,
    Icons.savings,
    Icons.group,
  ];

  @override
  Widget build(BuildContext context) {
    final isSimple = ref.watch(isSimpleModeProvider);
    final tabs = isSimple ? _tabsSimple : _tabsAdvanced;
    final labels = isSimple ? _labelsSimple : _labelsAdvanced;
    final icons = isSimple ? _iconsSimple : _iconsAdvanced;
    final activeIcons = isSimple ? _activeIconsSimple : _activeIconsAdvanced;

    final location = widget.location;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final isWideDesktop = width >= 1200;

    // Guard: if the user is on /budgets but switches to simple mode, redirect home.
    if (isSimple && location.startsWith(AppRoutes.budgets)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.home);
      });
    }

    final currentIndex = _tabIndex(location, tabs);
    final content = Column(
      children: [
        const OfflineBanner(),
        Expanded(child: widget.child),
      ],
    );
    final rail = NavigationRail(
      extended: isWideDesktop,
      labelType: isWideDesktop
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => context.go(tabs[i]),
      destinations: List.generate(
        tabs.length,
        (i) => NavigationRailDestination(
          icon: Icon(icons[i]),
          selectedIcon: Icon(activeIcons[i]),
          label: Text(labels[i]),
        ),
      ),
    );

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                SafeArea(child: rail),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
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
                    onDestinationSelected: (i) => context.go(tabs[i]),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: List.generate(
                      tabs.length,
                      (i) => NavigationDestination(
                        icon: Icon(icons[i]),
                        selectedIcon: Icon(activeIcons[i]),
                        label: labels[i],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  int _tabIndex(String location, List<String> tabs) {
    final sharedIndex = tabs.indexOf(AppRoutes.shared);
    if (sharedIndex >= 0 &&
        (location == AppRoutes.shared || location.startsWith('${AppRoutes.shared}/'))) {
      return sharedIndex;
    }

    for (var i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i])) return i;
    }
    return 0;
  }
}
