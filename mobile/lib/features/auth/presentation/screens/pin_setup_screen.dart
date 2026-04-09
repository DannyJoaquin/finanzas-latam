import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/constants/storage_keys.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final List<String> _pin = [];
  List<String>? _firstPin;
  bool _confirming = false;

  void _onKey(String digit) {
    if (_pin.length >= 6) return;
    setState(() => _pin.add(digit));
    if (_pin.length == 6) _onComplete();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  Future<void> _onComplete() async {
    if (!_confirming) {
      setState(() {
        _firstPin = List.from(_pin);
        _pin.clear();
        _confirming = true;
      });
    } else {
      if (_pin.join() == _firstPin!.join()) {
        final storage = ref.read(secureStorageProvider);
        await storage.write(key: StorageKeys.pinCode, value: _pin.join());
        if (mounted) context.go(AppRoutes.home);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Los PINs no coinciden. Intenta nuevamente.')));
        setState(() {
          _pin.clear();
          _firstPin = null;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !_confirming,
        title: Text(_confirming ? 'Confirmar PIN' : 'Crear PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _confirming ? 'Confirma tu PIN de 6 dígitos' : 'Elige un PIN de 6 dígitos',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            // Number pad
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.4,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                if (i == 9) return const SizedBox.shrink();
                if (i == 11) {
                  return IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 28),
                    onPressed: _onDelete,
                  );
                }
                final digit = i == 10 ? '0' : '${i + 1}';
                return TextButton(
                  onPressed: () => _onKey(digit),
                  child: Text(
                    digit,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
