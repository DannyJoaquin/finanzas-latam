import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/models/auth_models.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/pin_setup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/expenses/presentation/screens/expenses_list_screen.dart';
import '../../features/incomes/presentation/screens/incomes_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/cash/presentation/screens/cash_screen.dart';
import '../../features/credit_cards/presentation/screens/credit_cards_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/app_shell.dart';

// Route names
class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const pinSetup = '/pin-setup';
  static const home = '/home';
  static const expenses = '/expenses';
  static const addExpense = '/expenses/add';
  static const incomes = '/incomes';
  static const budgets = '/budgets';
  static const goals = '/goals';
  static const analytics = '/analytics';
  static const settings = '/settings';
  static const cash = '/cash';
  static const creditCards = '/credit-cards';
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
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.pinSetup;
      final isSplash = state.matchedLocation == AppRoutes.splash;

      if (isSplash) return null; // Let splash decide
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && isAuthRoute) return AppRoutes.home;
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
        path: AppRoutes.pinSetup,
        builder: (c, s) => const PinSetupScreen(),
      ),
      ShellRoute(
        builder: (c, s, child) => AppShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (c, s) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.expenses,
            builder: (c, s) => const ExpensesListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (c, s) => const AddExpenseScreen(),
              ),
            ],
          ),
          GoRoute(path: AppRoutes.incomes, builder: (c, s) => const IncomesScreen()),
          GoRoute(path: AppRoutes.budgets, builder: (c, s) => const BudgetsScreen()),
          GoRoute(path: AppRoutes.goals, builder: (c, s) => const GoalsScreen()),
          GoRoute(path: AppRoutes.analytics, builder: (c, s) => const AnalyticsScreen()),
          GoRoute(path: AppRoutes.settings, builder: (c, s) => const SettingsScreen()),
          GoRoute(path: AppRoutes.cash, builder: (c, s) => const CashScreen()),
          GoRoute(path: AppRoutes.creditCards, builder: (c, s) => const CreditCardsScreen()),
        ],
      ),
    ],
  );
});
