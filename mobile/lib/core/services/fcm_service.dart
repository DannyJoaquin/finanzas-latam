import 'dart:async';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../constants/api_constants.dart';
import 'notification_service.dart';

/// Service responsible for:
/// 1. Obtaining the device FCM token (when firebase_messaging is configured).
/// 2. Registering/updating the token with the backend so push notifications work.
///
/// ## How to activate full FCM support
/// 1. Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
///    to the respective platform folders.
/// 2. In pubspec.yaml, uncomment:
///      firebase_core: ^3.3.0
///      firebase_messaging: ^15.1.2
/// 3. Run `flutter pub get`.
/// 4. That's it — this service will automatically pick up the token on next launch.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      _initialized = true;
      dev.log('[FCM] Messaging initialized');
    } catch (e) {
      dev.log('[FCM] Messaging init skipped: $e');
    }
  }

  /// Call once after the user is authenticated.
  /// Attempts to get an FCM token and registers it with the backend.
  /// Fails silently if Firebase is not configured.
  Future<void> registerToken(Dio dio) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      await dio.patch(ApiConstants.me, data: {'fcmToken': token});
      dev.log('[FCM] Token registered: ${token.substring(0, 10)}...');
    } catch (e) {
      dev.log('[FCM] Token registration skipped: $e');
    }
  }

  /// Returns null when Firebase is not configured.
  Future<String?> _getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      // Firebase not configured or unavailable in current runtime.
      return null;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Nueva alerta';
    final body = message.notification?.body ?? 'Tienes una nueva notificacion';

    unawaited(NotificationService.instance.showInstant(
      id: _notificationId(message),
      title: title,
      body: body,
      payload: _routePayload(message),
    ));
  }

  void _handleOpenedMessage(RemoteMessage message) {
    // Routing on tap can be centralized later in app shell/router listener.
    dev.log('[FCM] Notification opened with data: ${message.data}');
  }

  int _notificationId(RemoteMessage message) {
    final source = message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
    return source.hashCode & 0x7fffffff;
  }

  String? _routePayload(RemoteMessage message) {
    final type = message.data['type']?.toString();
    switch (type) {
      case 'budget_alert':
        return '/budgets';
      case 'weekly_summary':
        return '/analytics';
      case 'insight':
        return '/home';
      default:
        return null;
    }
  }
}
