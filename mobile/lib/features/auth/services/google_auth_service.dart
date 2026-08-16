import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Handles Google Sign-In flow on the device and Web.
/// Responsible ONLY for getting the idToken from Google — backend does the rest.
///
/// The Web OAuth client ID must be supplied with `GOOGLE_WEB_CLIENT_ID` at
/// build time. Native platforms use that same Web client as serverClientId so
/// that the backend can verify the returned idToken.
class GoogleAuthService {
  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static final GoogleAuthService instance = GoogleAuthService._();

  static String get _configuredClientId {
    if (_webClientId.isEmpty) {
      throw StateError(
        'Google OAuth Web client ID is missing. '
        'Build with --dart-define=GOOGLE_WEB_CLIENT_ID=...',
      );
    }
    return _webClientId;
  }

  factory GoogleAuthService({String? serverClientId}) => instance;

  GoogleAuthService._({String? serverClientId})
      : _googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          clientId: kIsWeb ? _configuredClientId : null,
          serverClientId: kIsWeb ? null : serverClientId ?? _configuredClientId,
        );

  final GoogleSignIn _googleSignIn;

  Stream<void> get onWebSignIn => _googleSignIn.onCurrentUserChanged
      .where((account) => account != null)
      .map((_) {});

  /// Returns the Google idToken, or null if the user cancelled.
  /// Throws on unexpected error so the caller can surface a message.
  Future<String?> signIn() async {
    if (kIsWeb) {
      final account = _googleSignIn.currentUser;
      if (account == null) {
        throw StateError(
          'Google Web sign-in must be started with the Google button.',
        );
      }
      return _idTokenFromAccount(account);
    }

    if (!kIsWeb) await _googleSignIn.signOut();
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // user cancelled

    return _idTokenFromAccount(account);
  }

  Future<String> _idTokenFromAccount(GoogleSignInAccount account) async {
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception(
        'Google did not return an idToken. '
        'Ensure the Google OAuth client ID is configured.',
      );
    }
    return idToken;
  }

  /// Signs out of Google silently (called on app logout).
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
