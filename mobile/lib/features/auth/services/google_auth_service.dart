import 'package:google_sign_in/google_sign_in.dart';

/// Handles Google Sign-In flow on the device.
/// Responsible ONLY for getting the idToken from Google — backend does the rest.
///
/// IMPORTANT: [serverClientId] must be the **Web** OAuth 2.0 client ID from
/// Google Cloud Console (NOT the Android client ID). This is required so that
/// Google returns an idToken that the backend can verify with google-auth-library.
class GoogleAuthService {
  GoogleAuthService({String? serverClientId})
      : _googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId: serverClientId ?? const String.fromEnvironment(
            'GOOGLE_CLIENT_ID',
            defaultValue: '',
          ),
        );

  final GoogleSignIn _googleSignIn;

  /// Returns the Google idToken, or null if the user cancelled.
  /// Throws on unexpected error so the caller can surface a message.
  Future<String?> signIn() async {
    // Sign out first to always show account picker
    await _googleSignIn.signOut();
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // user cancelled

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception(
        'Google did not return an idToken. '
        'Ensure serverClientId is set to the Web OAuth client ID.',
      );
    }
    return idToken;
  }

  /// Signs out of Google silently (called on app logout).
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
