import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  static Future<Box<String>>? _webBoxFuture;

  Future<Box<String>> _webBox() {
    return _webBoxFuture ??= Hive.openBox<String>(StorageKeys.authBox);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (kIsWeb) {
      final box = await _webBox();
      await box.put(StorageKeys.accessToken, accessToken);
      await box.put(StorageKeys.refreshToken, refreshToken);
      return;
    }

    await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    if (kIsWeb) return (await _webBox()).get(StorageKeys.accessToken);
    return _storage.read(key: StorageKeys.accessToken);
  }

  Future<String?> getRefreshToken() async {
    if (kIsWeb) return (await _webBox()).get(StorageKeys.refreshToken);
    return _storage.read(key: StorageKeys.refreshToken);
  }

  Future<void> saveUser(Map<String, dynamic> userJson) async {
    final value = jsonEncode(userJson);
    if (kIsWeb) {
      await (await _webBox()).put(StorageKeys.cachedUser, value);
      return;
    }
    await _storage.write(key: StorageKeys.cachedUser, value: value);
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    final raw = kIsWeb
        ? (await _webBox()).get(StorageKeys.cachedUser)
        : await _storage.read(key: StorageKeys.cachedUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTokens() async {
    if (kIsWeb) {
      await (await _webBox()).deleteAll([
        StorageKeys.accessToken,
        StorageKeys.refreshToken,
        StorageKeys.userId,
        StorageKeys.cachedUser,
      ]);
      return;
    }

    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.refreshToken),
      _storage.delete(key: StorageKeys.userId),
      _storage.delete(key: StorageKeys.cachedUser),
    ]);
  }

  /// Removes only the refresh token so the session expires with the access token.
  Future<void> deleteRefreshToken() async {
    if (kIsWeb) {
      await (await _webBox()).delete(StorageKeys.refreshToken);
      return;
    }
    await _storage.delete(key: StorageKeys.refreshToken);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);
