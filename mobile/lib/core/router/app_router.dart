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

  // Order of the main bottom-nav/rail tabs — mirrors the branch order in the
  // StatefulShellRoute below. Budgets stays in the list even in simple mode
  // (AppShell just hides that destination); its branch always exists.
  static const tabOrder = [home, expenses, incomes, budgets, goals, shared];
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
      StatefulShellRoute.indexedStack(
        builder: (c, s, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (c, s) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.expenses,
              builder: (c, s) => const ExpensesListScreen(),
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
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.incomes,
              builder: (c, s) => const IncomesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.budgets,
              builder: (c, s) => const BudgetsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.goals,
              builder: (c, s) => const GoalsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.shared,
              builder: (c, s) => const SharedGroupsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (c, s) => SharedGroupDetailScreen(
                      groupId: s.pathParameters['id']!),
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
          ]),
          // Non-tab destinations reachable from within the shell (settings,
          // analytics, cash, credit cards, etc.) live in their own branch so
          // they keep the bottom nav/rail chrome, without being one of the
          // 6 primary tabs shown in it.
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.analytics,
              builder: (c, s) => const AnalyticsScreen(),
            ),
            GoRoute(
              path: AppRoutes.simulator,
              builder: (c, s) => const SimulatorScreen(),
            ),
            GoRoute(
              path: AppRoutes.rules,
              builder: (c, s) => const RulesScreen(),
            ),
            GoRoute(
              path: AppRoutes.achievements,
              builder: (c, s) => const AchievementsScreen(),
            ),
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
            GoRoute(
              path: AppRoutes.cash,
              builder: (c, s) => const CashScreen(),
            ),
            GoRoute(
              path: AppRoutes.creditCards,
              builder: (c, s) => const CreditCardsScreen(),
            ),
            GoRoute(
              path: AppRoutes.loanCalculator,
              builder: (c, s) => const LoanCalculatorScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
