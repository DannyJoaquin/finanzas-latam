import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/connectivity_provider.dart';

/// Animated banner that slides down when the device is offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: child,
      ),
      child: isOnline
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('offline'),
              color: Colors.red.shade700,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: const SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Sin conexión a internet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
