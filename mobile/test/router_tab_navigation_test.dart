import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:zentri/main.dart';
import 'package:zentri/core/constants/storage_keys.dart';
import 'package:zentri/core/network/dio_client.dart';
import 'package:zentri/core/providers/experience_provider.dart';
import 'package:zentri/features/auth/providers/auth_provider.dart';
import 'package:zentri/features/auth/models/auth_models.dart';
import 'package:zentri/features/home/providers/dashboard_provider.dart';
import 'package:zentri/features/expenses/providers/expenses_provider.dart';
import 'package:zentri/features/home/models/dashboard_model.dart';
import 'package:zentri/features/onboarding/presentation/screens/onboarding_screen.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
  @override
  Future<String?> getTemporaryPath() async => '.';
}

/// A Dio adapter that resolves every request instantly with an empty
/// success body — used so any provider we didn't explicitly override (e.g.
/// insightsProvider, cashAccountsProvider) resolves immediately instead of
/// hanging on a real network call with no server to answer it.
class _InstantEmptyAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"data": []}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

class _FakeAuthenticatedNotifier extends AuthNotifier {
  _FakeAuthenticatedNotifier(this.experienceMode);
  final String experienceMode;

  @override
  Future<AuthState> build() async => AuthState(
        isAuthenticated: true,
        accessToken: 'test-token',
        user: UserModel(
          id: 'test-user',
          email: 'test@zentri.tech',
          fullName: 'Test User',
          currency: 'HNL',
          payCycle: 'monthly',
          experienceMode: experienceMode,
        ),
      );
}

/// Counts how many times its build() runs — this is the direct signal for
/// whether IndexedStack keeps a tab's provider alive across tab switches.
/// A StatefulShellRoute branch that stays mounted should never re-run this;
/// the old ShellRoute (which destroyed/recreated the screen widget on every
/// tab change) would have re-run it on every single revisit.
class _BuildCounter {
  int count = 0;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _FakePathProvider();
    // A dedicated subdirectory (not '.', which widget_test.dart also uses)
    // avoids a Hive file-lock collision when `flutter test` runs multiple
    // spec files concurrently in separate processes.
    await Hive.initFlutter('.router_tab_navigation_test');
    if (!Hive.isBoxOpen(StorageKeys.preferencesBox)) {
      await Hive.openBox<String>(StorageKeys.preferencesBox);
    }
  });

  tearDownAll(() async {
    await Hive.close();
  });

  Future<ProviderContainer> pumpAuthenticatedApp(
    WidgetTester tester, {
    required String experienceMode,
    required _BuildCounter dashboardBuilds,
    required _BuildCounter expensesBuilds,
  }) async {
    // Hive's Box.put does real (non-virtual-time) file I/O internally; called
    // directly inside a testWidgets body — which runs under a FakeAsync zone
    // — it hangs forever because nothing is pumping the virtual clock yet.
    // runAsync briefly steps outside FakeAsync so real I/O can complete.
    await tester.runAsync(() => markOnboardingDone(userId: 'test-user'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            () => _FakeAuthenticatedNotifier(experienceMode),
          ),
          dioProvider.overrideWithValue(
            Dio()..httpClientAdapter = _InstantEmptyAdapter(),
          ),
          dashboardProvider.overrideWith((ref) async {
            dashboardBuilds.count++;
            return const DashboardModel(
              periodStart: '2026-08-01',
              periodEnd: '2026-08-31',
              daysRemaining: 10,
              totalExpenses: 0,
              totalIncome: 0,
              totalBudgeted: 0,
              balance: 0,
              safeDailySpend: 0,
              riskLevel: 'green',
              cashRunoutDate: null,
              topCategories: [],
              recentExpenses: [],
              insights: [],
              creditCardTotal: 0,
              creditCardTotalUSD: 0,
            );
          }),
          expensesProvider.overrideWith((ref) async {
            expensesBuilds.count++;
            return <ExpenseModel>[];
          }),
        ],
        child: const FinanzasApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FinanzasApp)),
    );
    // SplashScreen waits 1500ms before redirecting — clear that plus margin.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  testWidgets(
    'switching tabs with IndexedStack does not re-fetch an already-visited tab',
    (tester) async {
      final dashboardBuilds = _BuildCounter();
      final expensesBuilds = _BuildCounter();

      await pumpAuthenticatedApp(
        tester,
        experienceMode: 'advanced',
        dashboardBuilds: dashboardBuilds,
        expensesBuilds: expensesBuilds,
      );

      // Home is the initial tab — its provider should have built exactly once.
      expect(dashboardBuilds.count, 1,
          reason: 'home tab should fetch once on first mount');

      // Switch to the Expenses tab via its NavigationBar destination.
      final expensesIcon = find.byIcon(Icons.receipt_long_outlined);
      expect(expensesIcon, findsWidgets);
      await tester.tap(expensesIcon.first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(expensesBuilds.count, 1,
          reason: 'expenses tab should fetch once on first visit');

      // Switch back to Home, then back to Expenses again — with the old
      // ShellRoute (destroy+recreate per tab), both counters would increment
      // again here because each revisit created a brand-new autoDispose
      // provider instance. With StatefulShellRoute.indexedStack, both tabs
      // stay mounted in the stack, so neither should re-fetch.
      final homeIcon = find.byIcon(Icons.home_outlined);
      await tester.tap(homeIcon.first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(expensesIcon.first);
      await tester.pump(const Duration(milliseconds: 500));

      expect(dashboardBuilds.count, 1,
          reason:
              'revisiting home should NOT re-run its provider — this is the '
              'exact "loading flash on every tab switch" bug being fixed');
      expect(expensesBuilds.count, 1,
          reason:
              'revisiting expenses should NOT re-run its provider either');
    },
  );

  testWidgets(
    'simple mode hides the budgets destination without crashing',
    (tester) async {
      final dashboardBuilds = _BuildCounter();
      final expensesBuilds = _BuildCounter();

      await pumpAuthenticatedApp(
        tester,
        experienceMode: 'simple',
        dashboardBuilds: dashboardBuilds,
        expensesBuilds: expensesBuilds,
      );

      expect(tester.takeException(), isNull);
      // Simple mode shows 5 nav destinations (no Presupuestos/budgets).
      expect(find.text('Presup.'), findsNothing);
      expect(find.text('Inicio'), findsWidgets);
      expect(find.text('Metas'), findsWidgets);
    },
  );

  testWidgets(
    'toggling from advanced to simple mode while on budgets redirects home '
    'without crashing',
    (tester) async {
      final dashboardBuilds = _BuildCounter();
      final expensesBuilds = _BuildCounter();

      final container = await pumpAuthenticatedApp(
        tester,
        experienceMode: 'advanced',
        dashboardBuilds: dashboardBuilds,
        expensesBuilds: expensesBuilds,
      );

      final budgetsIcon = find.byIcon(Icons.account_balance_wallet_outlined);
      expect(budgetsIcon, findsWidgets);
      await tester.tap(budgetsIcon.first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      // Flip to simple mode while parked on the budgets branch — AppShell's
      // guard should redirect to home instead of leaving a hidden/orphaned
      // destination selected.
      container.read(experienceModeNotifierProvider.notifier).state =
          'simple';
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Presup.'), findsNothing);
    },
  );
}
