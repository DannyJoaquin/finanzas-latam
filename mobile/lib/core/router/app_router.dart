import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/models/auth_models.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/pin_setup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/expenses/presentation/screens/expenses_list_screen.dart';
import '../../features/expenses/presentation/screens/recurring_expenses_screen.dart';
import '../../features/incomes/presentation/screens/incomes_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/analytics/presentation/screens/simulator_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/categories_management_screen.dart';
import '../../features/settings/presentation/screens/notification_settings_screen.dart';
import '../../features/cash/presentation/screens/cash_screen.dart';
import '../../features/credit_cards/presentation/screens/credit_cards_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/rules/presentation/screens/rules_screen.dart';
import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/settings/presentation/screens/loan_calculator_screen.dart';
import '../../features/shared/presentation/screens/shared_groups_screen.dart';
import '../../features/shared/presentation/screens/shared_group_detail_screen.dart';
import '../../features/shared/presentation/screens/add_shared_expense_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/app_shell.dart';

// Route names
class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const pinSetup = '/pin-setup';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const expenses = '/expenses';
  static const addExpense = '/expenses/add';
  static const recurringExpenses = '/expenses/recurring';
  static const incomes = '/incomes';
  static const budgets = '/budgets';
  static const goals = '/goals';
  static const analytics = '/analytics';
  static const simulator = '/simulator';
  static const rules = '/rules';
  static const achievements = '/achievements';
  static const settings = '/settings';
  static const settingsCategories = '/settings/categories';
  static const settingsNotifications = '/settings/notifications';
  static const cash = '/cash';
  static const creditCards = '/credit-cards';
  static const loanCalculator = '/loan-calculator';
  static const shared = '/shared';
  static String sharedGroupDetail(String id) => '/shared/$id';
  static String sharedAddExpense(String id) => '/shared/$id/add-expense';

  // Order of the main bottom-nav/rail tabs, used to pick a slide direction
  // when navigating between them (advanced mode superset; budgets is simply
  // absent from the tab list in simple mode).
  static const tabOrder = [home, expenses, incomes, budgets, goals, shared];

  static int tabIndexOf(String location) {
    if (location == shared || location.startsWith('$shared/')) {
      return tabOrder.indexOf(shared);
    }
    for (var i = 0; i < tabOrder.length; i++) {
      if (location.startsWith(tabOrder[i])) return i;
    }
    return -1;
  }
}

// Tracks the previously active tab so route transitions can pick a slide
// direction consistent with the tab's position in the bottom nav/rail,
// instead of GoRouter's platform default (which always slides one way).
int _lastTabIndex = 0;

Page<void> _tabPage(GoRouterState state, Widget child) {
  final newIndex = AppRoutes.tabIndexOf(state.uri.path);
  final fromIndex = _lastTabIndex;
  if (newIndex >= 0) _lastTabIndex = newIndex;

  final goingForward = newIndex >= 0 && newIndex > fromIndex;
  final beginOffset =
      newIndex < 0 ? const Offset(0, 0.02) : Offset(goingForward ? 0.06 : -0.06, 0);

  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: beginOffset, end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

// A ChangeNotifier that GoRouter uses as refreshListenable.
// It notifies the router whenever auth state changes WITHOUT causing
// appRouterProvider itself to rebuild (which would reset the nav stack).
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(Ref ref) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // The notifier is owned by this provider; disposed when the provider is.
  final notifier = _AuthRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);

      // Don't redirect while auth state is still loading (e.g. during login).
      if (authAsync.isLoading) return null;

      final isLoggedIn = authAsync.valueOrNull?.isAuthenticated ?? false;
      final userId = authAsync.valueOrNull?.user?.id;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.resetPassword ||
          state.matchedLocation == AppRoutes.pinSetup;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (isSplash) return null; // Let splash decide
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && isAuthRoute) {
        // Show onboarding first if this user hasn't completed it before
        if (!hasCompletedOnboarding(userId: userId))
          return AppRoutes.onboarding;
        return AppRoutes.home;
      }
      // Redirect authenticated user to onboarding if not completed
      if (isLoggedIn &&
          !isOnboarding &&
          !hasCompletedOnboarding(userId: userId)) {
        return AppRoutes.onboarding;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (c, s) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (c, s) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (c, s) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (c, s) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (c, s) => ResetPasswordScreen(
          token: s.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        builder: (c, s) => const PinSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (c, s) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (c, s, child) => AppShell(location: s.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (c, s) => _tabPage(s, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            pageBuilder: (c, s) => _tabPage(s, const ExpensesListScreen()),
            routes: [
              GoRoute(
                path: 'add',
                builder: (c, s) => const AddExpenseScreen(),
              ),
              GoRoute(
                path: 'recurring',
                builder: (c, s) => const RecurringExpensesScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.incomes,
            pageBuilder: (c, s) => _tabPage(s, const IncomesScreen()),
          ),
          GoRoute(
            path: AppRoutes.budgets,
            pageBuilder: (c, s) => _tabPage(s, const BudgetsScreen()),
          ),
          GoRoute(
            path: AppRoutes.goals,
            pageBuilder: (c, s) => _tabPage(s, const GoalsScreen()),
          ),
          GoRoute(
              path: AppRoutes.analytics,
              builder: (c, s) => const AnalyticsScreen()),
          GoRoute(
              path: AppRoutes.simulator,
              builder: (c, s) => const SimulatorScreen()),
          GoRoute(
              path: AppRoutes.rules, builder: (c, s) => const RulesScreen()),
          GoRoute(
              path: AppRoutes.achievements,
              builder: (c, s) => const AchievementsScreen()),
          GoRoute(
            path: AppRoutes.settings,
            builder: (c, s) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'categories',
                builder: (c, s) => const CategoriesManagementScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (c, s) => const NotificationSettingsScreen(),
              ),
            ],
          ),
          GoRoute(path: AppRoutes.cash, builder: (c, s) => const CashScreen()),
          GoRoute(
              path: AppRoutes.creditCards,
              builder: (c, s) => const CreditCardsScreen()),
          GoRoute(
              path: AppRoutes.loanCalculator,
              builder: (c, s) => const LoanCalculatorScreen()),
          GoRoute(
            path: AppRoutes.shared,
            pageBuilder: (c, s) => _tabPage(s, const SharedGroupsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (c, s) =>
                    SharedGroupDetailScreen(groupId: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'add-expense',
                    builder: (c, s) => AddSharedExpenseScreen(
                        groupId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
