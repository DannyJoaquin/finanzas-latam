import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_models.dart';
import '../services/google_auth_service.dart';

class AuthRepository {
  const AuthRepository(this._dio, this._tokens);
  final Dio _dio;
  final TokenStorage _tokens;

  Future<AuthState> login({
    required String email,
    required String password,
  }) async {
    final resp = await _dio.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
    final data = resp.data as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    await _tokens.saveTokens(
      accessToken: accessToken,
      refreshToken: data['refreshToken'] as String,
    );
    final meResp = await _dio.get(ApiConstants.me);
    final user = UserModel.fromJson(meResp.data as Map<String, dynamic>);
    await _tokens.saveUser(user.toJson());
    return AuthState(isAuthenticated: true, user: user, accessToken: accessToken);
  }

  Future<AuthState> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final resp = await _dio.post(ApiConstants.register, data: {
      'fullName': fullName,
      'email': email,
      'password': password,
    });
    final data = resp.data as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    await _tokens.saveTokens(
      accessToken: accessToken,
      refreshToken: data['refreshToken'] as String,
    );
    final meResp = await _dio.get(ApiConstants.me);
    final user = UserModel.fromJson(meResp.data as Map<String, dynamic>);
    await _tokens.saveUser(user.toJson());
    return AuthState(isAuthenticated: true, user: user, accessToken: accessToken);
  }

  Future<void> logout() async {
    final refreshToken = await _tokens.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _dio.post(ApiConstants.logout, data: {'refreshToken': refreshToken});
      } catch (_) {}
    }
    await _tokens.clearTokens();
    // Sign out from Google if the user logged in via Google
    try {
      await GoogleAuthService().signOut();
    } catch (_) {}
  }

  /// Sign in with Google. Returns null if user cancelled.
  Future<AuthState?> loginWithGoogle() async {
    final idToken = await GoogleAuthService().signIn();
    if (idToken == null) return null; // user cancelled

    final resp = await _dio.post(ApiConstants.googleAuth, data: {'idToken': idToken});
    final data = resp.data as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    await _tokens.saveTokens(
      accessToken: accessToken,
      refreshToken: data['refreshToken'] as String,
    );
    final userJson = data['user'] as Map<String, dynamic>;
    // Fetch full user profile (includes currency, payCycle, etc.)
    try {
      final meResp = await _dio.get(ApiConstants.me);
      final user = UserModel.fromJson(meResp.data as Map<String, dynamic>);
      await _tokens.saveUser(user.toJson());
      return AuthState(isAuthenticated: true, user: user, accessToken: accessToken);
    } catch (_) {
      // Fallback: build user from Google response payload
      final user = UserModel(
        id: userJson['id'] as String,
        email: userJson['email'] as String,
        fullName: userJson['fullName'] as String? ?? '',
        currency: 'HNL',
        payCycle: 'monthly',
        avatarUrl: userJson['avatarUrl'] as String?,
      );
      await _tokens.saveUser(user.toJson());
      return AuthState(isAuthenticated: true, user: user, accessToken: accessToken);
    }
  }

  Future<AuthState?> tryRestoreSession() async {
    final token = await _tokens.getAccessToken();
    if (token == null) return null;
    try {
      final resp = await _dio.get(ApiConstants.me);
      final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
      await _tokens.saveUser(user.toJson());
      return AuthState(isAuthenticated: true, user: user, accessToken: token);
    } on DioException catch (e) {
      // If the server is unreachable (network error), restore from cached user
      final isNetworkError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      if (isNetworkError) {
        final cached = await _tokens.getCachedUser();
        if (cached != null) {
          return AuthState(
            isAuthenticated: true,
            user: UserModel.fromJson(cached),
            accessToken: token,
          );
        }
      }
      // 401/403 or no cache — force re-login
      return null;
    } catch (_) {
      return null;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider));
});
