import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_sign_in_web;

Widget buildGoogleSignInWebButton({
  required bool isLoading,
  required bool isDark,
  required bool isSignUp,
}) {
  return IgnorePointer(
    ignoring: isLoading,
    child: SizedBox(
      width: double.infinity,
      height: 52,
      child: google_sign_in_web.renderButton(
        configuration: google_sign_in_web.GSIButtonConfiguration(
            theme: isDark
              ? google_sign_in_web.GSIButtonTheme.filledBlack
              : google_sign_in_web.GSIButtonTheme.outline,
          size: google_sign_in_web.GSIButtonSize.large,
            text: isSignUp
              ? google_sign_in_web.GSIButtonText.signupWith
              : google_sign_in_web.GSIButtonText.signinWith,
          shape: google_sign_in_web.GSIButtonShape.rectangular,
          logoAlignment: google_sign_in_web.GSIButtonLogoAlignment.center,
          minimumWidth: 320,
          locale: 'es',
        ),
      ),
    ),
  );
}