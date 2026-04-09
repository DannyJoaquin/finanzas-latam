import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  ),
);

/// Persists and reads auth tokens securely
class TokenStorage {
  const TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: StorageKeys.accessToken, value: accessToken),
      _storage.write(key: StorageKeys.refreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: StorageKeys.accessToken);

  Future<String?> getRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);

  Future<void> saveUser(Map<String, dynamic> userJson) =>
      _storage.write(key: StorageKeys.cachedUser, value: jsonEncode(userJson));

  Future<Map<String, dynamic>?> getCachedUser() async {
    final raw = await _storage.read(key: StorageKeys.cachedUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.refreshToken),
      _storage.delete(key: StorageKeys.userId),
      _storage.delete(key: StorageKeys.cachedUser),
    ]);
  }

  /// Removes only the refresh token so the session expires with the access token.
  Future<void> deleteRefreshToken() =>
      _storage.delete(key: StorageKeys.refreshToken);
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);
