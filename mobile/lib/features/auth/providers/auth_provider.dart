import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_models.dart';
import '../repositories/auth_repository.dart';

/// Async notifier that holds the current authentication state
class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repo = ref.read(authRepositoryProvider);
    final restored = await repo.tryRestoreSession();
    return restored ?? const AuthState.unauthenticated();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email: email, password: password),
    );
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
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState.unauthenticated());
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
