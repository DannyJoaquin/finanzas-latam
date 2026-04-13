import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../features/auth/models/auth_models.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Notifier with immediate local state + background server sync.
class ExperienceModeNotifier extends Notifier<String> {
  @override
  String build() {
    // Seed from current auth (may be loading → null → 'advanced' initially).
    // ref.listen catches when auth finishes loading and corrects the value once,
    // WITHOUT causing a full rebuild loop.
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      final savedMode = next.valueOrNull?.user?.experienceMode;
      if (savedMode != null && savedMode != state) {
        state = savedMode;
      }
    });
    return ref.read(authStateProvider).valueOrNull?.user?.experienceMode ?? 'advanced';
  }

  Future<void> setMode(String mode) async {
    final previous = state;
    state = mode; // optimistic update — UI responds immediately
    debugPrint('[ExperienceMode] setMode called: $previous → $mode');
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.patch(ApiConstants.me, data: {'experienceMode': mode});
      debugPrint('[ExperienceMode] PATCH response: ${resp.statusCode}');
      // Do NOT invalidate authStateProvider — that would restart build()
      // and wipe the optimistic state back to 'advanced'.
    } catch (e) {
      debugPrint('[ExperienceMode] PATCH failed, reverting: $e');
      state = previous; // revert if server call fails
    }
  }
}

final experienceModeNotifierProvider =
    NotifierProvider<ExperienceModeNotifier, String>(ExperienceModeNotifier.new);

/// Returns the current experience mode string ('simple' or 'advanced').
final experienceModeProvider = Provider<String>((ref) {
  return ref.watch(experienceModeNotifierProvider);
});

/// Convenience boolean: true when the user is in Simple mode.
final isSimpleModeProvider = Provider<bool>((ref) {
  return ref.watch(experienceModeProvider) == 'simple';
});
