import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:finanzas_latam/main.dart';
import 'package:finanzas_latam/core/constants/storage_keys.dart';
import 'package:finanzas_latam/features/auth/providers/auth_provider.dart';
import 'package:finanzas_latam/features/auth/models/auth_models.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
  @override
  Future<String?> getTemporaryPath() async => '.';
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _FakePathProvider();
    await Hive.initFlutter('.');
    if (!Hive.isBoxOpen(StorageKeys.preferencesBox)) {
      await Hive.openBox<String>(StorageKeys.preferencesBox);
    }
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets(
    'App smoke test - MaterialApp renders when unauthenticated',
    (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(() => _FakeAuthNotifier()),
            ],
            child: const FinanzasApp(),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    },
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}
