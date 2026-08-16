import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'google_sign_in_button.dart';

class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({
    required this.isLoading,
    required this.onPressed,
    this.isSignUp = false,
    super.key,
  });

  final bool isLoading;
  final VoidCallback onPressed;
  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (kIsWeb) {
      return KeyedSubtree(
        key: ValueKey('google-auth-button-$isDark-$isSignUp'),
        child: buildGoogleSignInWebButton(
          isLoading: isLoading,
          isDark: isDark,
          isSignUp: isSignUp,
        ),
      );
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'G',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isSignUp ? 'Registrarse con Google' : 'Continuar con Google',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
    );
  }
}
