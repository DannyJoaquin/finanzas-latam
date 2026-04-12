import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// StreamProvider that emits `true` when the device has network connectivity.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  return (() async* {
    final initial = await connectivity.checkConnectivity();
    yield initial.any((r) => r != ConnectivityResult.none);
    yield* connectivity.onConnectivityChanged
        .map((results) => results.any((r) => r != ConnectivityResult.none))
        .distinct();
  })();
});

/// Convenience provider: current connectivity status (sync, defaults to true).
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).valueOrNull ?? true;
});
