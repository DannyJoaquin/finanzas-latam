import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:io';

/// Friendly error widget used across all async screens.
/// Shows a localized Spanish message and an optional retry button.
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.message,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Override the auto-detected message.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = message ?? _message(error);
    final icon = _icon(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.error.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _message(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'La conexión tardó demasiado. Verifica tu red e intenta de nuevo.';
        case DioExceptionType.connectionError:
          return 'No se pudo conectar al servidor. Revisa tu conexión a internet.';
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          if (code == 401) return 'Tu sesión expiró. Por favor inicia sesión de nuevo.';
          if (code == 403) return 'No tienes permiso para ver este contenido.';
          if (code == 404) return 'No se encontró la información solicitada.';
          if (code != null && code >= 500) {
            return 'El servidor encontró un error. Intenta más tarde.';
          }
          return 'Ocurrió un error inesperado (código $code).';
        case DioExceptionType.cancel:
          return 'La solicitud fue cancelada.';
        default:
          return 'Error de red desconocido.';
      }
    }
    if (error is SocketException) {
      return 'Sin conexión a internet. Revisa tu red.';
    }
    return 'Algo salió mal. Por favor intenta de nuevo.';
  }

  static IconData _icon(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return Icons.wifi_off_outlined;
      }
      if (error.type == DioExceptionType.badResponse) {
        final code = error.response?.statusCode ?? 0;
        if (code == 401 || code == 403) return Icons.lock_outline;
        if (code >= 500) return Icons.cloud_off_outlined;
      }
    }
    if (error is SocketException) return Icons.wifi_off_outlined;
    return Icons.error_outline;
  }
}
