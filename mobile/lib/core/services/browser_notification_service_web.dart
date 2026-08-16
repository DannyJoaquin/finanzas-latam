import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> showBrowserNotification({
  required String title,
  required String body,
  required int id,
  String? payload,
}) async {
  try {
    if (web.Notification.permission != 'granted') return;

    final notification = web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        icon: '/icons/Icon-192.png',
        tag: 'zentri-$id',
      ),
    );

    if (payload != null && payload.isNotEmpty) {
      final route = payload.startsWith('/') ? payload : '/home';
      notification.onclick = ((web.Event _) {
        web.window.location.hash = route;
        notification.close();
      }).toJS;
    }
  } catch (_) {
    // Browser notifications are optional and can be unavailable or blocked.
  }
}

Future<bool> requestBrowserNotificationPermission() async {
  try {
    if (web.Notification.permission == 'granted') return true;
    if (web.Notification.permission == 'denied') return false;

    final permission =
        await web.Notification.requestPermission().toDart;
    return permission.toDart == 'granted';
  } catch (_) {
    return false;
  }
}
