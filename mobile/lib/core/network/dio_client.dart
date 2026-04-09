import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final tokenStorage = ref.watch(tokenStorageProvider);

  dio.interceptors.addAll([
    // Unwrap backend TransformInterceptor: {data: <payload>} → <payload>
    InterceptorsWrapper(
      onResponse: (response, handler) {
        final body = response.data;
        if (body is Map && body.containsKey('data')) {
          response.data = body['data'];
        }
        return handler.next(response);
      },
    ),
    // Attach access token to every request
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try token refresh
          final refreshToken = await tokenStorage.getRefreshToken();
          if (refreshToken == null) return handler.next(error);

          try {
            final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
            final resp = await refreshDio.post(
              ApiConstants.refresh,
              data: {'refreshToken': refreshToken},
            );
            // Backend wraps response in {data: <payload>}
            final payload = resp.data is Map && resp.data['data'] != null
                ? resp.data['data'] as Map<String, dynamic>
                : resp.data as Map<String, dynamic>;
            final newAccess = payload['accessToken'] as String;
            final newRefresh = payload['refreshToken'] as String;
            await tokenStorage.saveTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
            );
            // Retry original request
            error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
            final retryResp = await dio.fetch(error.requestOptions);
            return handler.resolve(retryResp);
          } catch (_) {
            await tokenStorage.clearTokens();
          }
        }
        return handler.next(error);
      },
    ),
    // Logging (debug only)
    PrettyDioLogger(
      requestHeader: false,
      requestBody: true,
      responseBody: true,
      error: true,
      compact: true,
    ),
  ]);

  return dio;
});
