import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/home/providers/dashboard_provider.dart';
import '../../../features/expenses/providers/expenses_provider.dart';
import '../../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../../features/goals/presentation/screens/goals_screen.dart';
import '../../../features/incomes/presentation/screens/incomes_screen.dart';
import '../widgets/offline_banner.dart';
import '../../providers/experience_provider.dart';

/// Index, within [StatefulShellRoute]'s branches, of the 6 primary tabs. Must
/// stay in sync with the branch order in app_router.dart — budgets is always
/// branch 3, even in simple mode (AppShell only hides its nav destination).
const _budgetsBranchIndex = 3;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

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

  // Main tabs shown in the bottom nav — dynamic by experience mode. Values
  // are branch indices into StatefulShellRoute (app_router.dart), NOT
  // positions in this list — simple mode simply omits index 3 (budgets).
  static const _branchIndicesAdvanced = [0, 1, 2, 3, 4, 5];
  static const _branchIndicesSimple = [0, 1, 2, 4, 5];

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
    final branchIndices =
        isSimple ? _branchIndicesSimple : _branchIndicesAdvanced;
    final labels = isSimple ? _labelsSimple : _labelsAdvanced;
    final icons = isSimple ? _iconsSimple : _iconsAdvanced;
    final activeIcons = isSimple ? _activeIconsSimple : _activeIconsAdvanced;

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final isWideDesktop = width >= 1200;

    // Guard: if the user is on the budgets branch but switches to simple
    // mode, redirect home (budgets has no nav destination in that mode).
    if (isSimple && widget.navigationShell.currentIndex == _budgetsBranchIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.navigationShell.goBranch(0);
      });
    }

    // Non-tab destinations (settings, analytics, cash, etc.) live in the
    // last branch and have no corresponding nav destination — none of the
    // items below should show as "selected" while one of them is active.
    final currentBranchIndex = widget.navigationShell.currentIndex;
    final selectedNavIndex = branchIndices.indexOf(currentBranchIndex);

    final content = Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: _AnimatedBranchSwitcher(
            branchIndex: currentBranchIndex,
            child: widget.navigationShell,
          ),
        ),
      ],
    );

    void onDestinationSelected(int navIndex) {
      final branchIndex = branchIndices[navIndex];
      widget.navigationShell.goBranch(
        branchIndex,
        initialLocation: branchIndex == widget.navigationShell.currentIndex,
      );
    }

    final rail = NavigationRail(
      extended: isWideDesktop,
      labelType: isWideDesktop
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      selectedIndex: selectedNavIndex < 0 ? 0 : selectedNavIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: List.generate(
        branchIndices.length,
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
                    selectedIndex: selectedNavIndex < 0 ? 0 : selectedNavIndex,
                    onDestinationSelected: onDestinationSelected,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: List.generate(
                      branchIndices.length,
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
}

/// Plays a short slide+fade whenever [branchIndex] changes, in the direction
/// matching the branch's position in the bottom nav/rail (left when moving to
/// an earlier tab, right when moving to a later one). Unlike wrapping
/// [child] in an AnimatedSwitcher keyed by branchIndex, this never disposes
/// [child] itself — [child] is the StatefulNavigationShell's IndexedStack,
/// and destroying it would defeat the point of using indexedStack (each tab
/// staying alive, keeping its provider state and avoiding a refetch/loading
/// flash on every tab switch).
class _AnimatedBranchSwitcher extends StatefulWidget {
  const _AnimatedBranchSwitcher({
    required this.branchIndex,
    required this.child,
  });
  final int branchIndex;
  final Widget child;

  @override
  State<_AnimatedBranchSwitcher> createState() =>
      _AnimatedBranchSwitcherState();
}

class _AnimatedBranchSwitcherState extends State<_AnimatedBranchSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  int _lastBranchIndex = 0;

  static const _duration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _lastBranchIndex = widget.branchIndex;
    _controller = AnimationController(vsync: this, duration: _duration);
    _slide = const AlwaysStoppedAnimation(Offset.zero);
    _fade = const AlwaysStoppedAnimation(1);
  }

  @override
  void didUpdateWidget(_AnimatedBranchSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.branchIndex != _lastBranchIndex) {
      final goingForward = widget.branchIndex > _lastBranchIndex;
      _lastBranchIndex = widget.branchIndex;
      final curved =
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
      _slide = Tween<Offset>(
        begin: Offset(goingForward ? 0.06 : -0.06, 0),
        end: Offset.zero,
      ).animate(curved);
      _fade = curved;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: child),
      ),
    );
  }
}
