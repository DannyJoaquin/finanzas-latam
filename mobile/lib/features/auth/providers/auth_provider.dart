import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/services/fcm_service.dart';
import '../models/auth_models.dart';
import '../repositories/auth_repository.dart';

/// Async notifier that holds the current authentication state
class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repo = ref.read(authRepositoryProvider);
    final restored = await repo.tryRestoreSession();
    if (restored != null && restored.isAuthenticated) {
      unawaited(_tryRegisterFcmToken(restored));
    }
    return restored ?? const AuthState.unauthenticated();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email: email, password: password),
    );
    unawaited(_tryRegisterFcmToken());
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).register(
            fullName: fullName,
            email: email,
            password: password,
          ),
    );
    unawaited(_tryRegisterFcmToken());
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () async {
        final repo = ref.read(authRepositoryProvider);
        final authState = await repo.loginWithGoogle();
        // null means user cancelled — restore previous state (unauthenticated)
        return authState ?? const AuthState.unauthenticated();
      },
    );
    state = result;
    unawaited(_tryRegisterFcmToken());
  }

  Future<void> _tryRegisterFcmToken([AuthState? auth]) async {
    final currentAuth = auth ?? state.valueOrNull;
    if (currentAuth == null || !currentAuth.isAuthenticated) return;
    try {
      final dio = ref.read(dioProvider);
      await FcmService.instance.registerToken(dio);
    } catch (_) {
      // Non-fatal: login must not fail when push is unavailable.
    }
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// The user's configured local currency (e.g. 'HNL', 'USD', 'GTQ').
/// Falls back to 'HNL' when not authenticated yet.
final currencyProvider = Provider<String>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.user?.currency ?? 'HNL';
});
