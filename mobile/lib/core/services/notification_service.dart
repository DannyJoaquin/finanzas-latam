import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../../../features/credit_cards/models/credit_card_model.dart';
import '../../../features/settings/providers/notification_prefs_provider.dart'
    show NotificationPreferencesModel;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'credit_alerts';
  static const _channelName = 'Alertas de tarjetas';
  static const _channelDesc =
      'Notificaciones de corte y pago de tarjetas de crédito';

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: ios,
    ));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      _details(importance: Importance.max, priority: Priority.high),
      payload: payload,
    );
  }

  /// Call on app startup and whenever the cards list changes.
  /// Pass [prefs] to respect the user's local notification toggles.
  Future<void> rescheduleAll(
    List<CreditCardSummary> cards, [
    NotificationPreferencesModel? prefs,
  ]) async {
    // Cancel previous credit card notifications (ids 100–599, supports up to 50 cards)
    for (int i = 100; i < 600; i++) {
      await _plugin.cancel(i);
    }

    int base = 100;
    for (final card in cards) {
      if (prefs == null || prefs.localCardCutoffAlerts) {
        await _scheduleCutOffWarning(card, base);
      }
      // Skip payment reminder if status is already fully paid
      if (card.paymentStatus != 'paid') {
        if (prefs == null || prefs.localCardDue5d || prefs.localCardDue1d) {
          await _schedulePaymentReminders(card, base + 1, prefs: prefs);
        }
      }
      // Overdue reminder only if there is unpaid closed-cycle debt
      if (card.overdueBalance > 0 && card.paymentStatus != 'paid') {
        if (prefs == null || prefs.localCardPendingBalance) {
          await _scheduleOverdueReminder(card, base + 3);
        }
      }
      base += 10;
    }
  }

  // ── private helpers ───────────────────────────────────────────────────────

  Future<void> _scheduleCutOffWarning(CreditCardSummary card, int id) async {
    if (card.daysUntilCutOff > 5 || card.currentBalance <= 0) return;
    final cutOff = DateTime.parse(card.nextCutOffDate);
    final notify = cutOff.subtract(const Duration(days: 3));
    if (notify.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id,
      '✂️ ${card.name} corta en 3 días',
      'Tienes L ${card.currentBalance.toStringAsFixed(0)} cargados. Corte: ${card.nextCutOffDate}',
      _tzDateTime(notify, 9, 0),
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _schedulePaymentReminders(
    CreditCardSummary card,
    int id, {
    NotificationPreferencesModel? prefs,
  }) async {
    final payDate = DateTime.parse(card.paymentDueDate);
    final now = DateTime.now();

    final fiveDaysBefore = payDate.subtract(const Duration(days: 5));
    if ((prefs == null || prefs.localCardDue5d) && fiveDaysBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        id,
        '💳 Pago de ${card.name} vence en 5 días',
        'Debes pagar antes del ${card.paymentDueDate}',
        _tzDateTime(fiveDaysBefore, 9, 0),
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    final oneDayBefore = payDate.subtract(const Duration(days: 1));
    if ((prefs == null || prefs.localCardDue1d) && oneDayBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        id + 1,
        '🔴 ¡Mañana vence tu pago de ${card.name}!',
        'Evita mora. Paga antes del ${card.paymentDueDate}',
        _tzDateTime(oneDayBefore, 9, 0),
        _details(importance: Importance.max, priority: Priority.high),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _scheduleOverdueReminder(CreditCardSummary card, int id) async {
    if (card.closedCyclePaymentDue == null) return;
    if ((card.daysUntilClosedPayment ?? 99) > 7) return;
    final payDate = DateTime.parse(card.closedCyclePaymentDue!);
    final notify = payDate.subtract(const Duration(days: 2));
    if (notify.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id,
      '⚠️ Pago pendiente ${card.name} — ${card.daysUntilClosedPayment}d restantes',
      'L ${card.overdueBalance.toStringAsFixed(0)} del ciclo anterior. Paga antes del ${card.closedCyclePaymentDue}',
      _tzDateTime(notify, 9, 0),
      _details(importance: Importance.max, priority: Priority.high),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _tzDateTime(DateTime dt, int hour, int minute) {
    final scheduled = DateTime(dt.year, dt.month, dt.day, hour, minute);
    return tz.TZDateTime.from(scheduled, tz.local);
  }

  NotificationDetails _details({
    Importance importance = Importance.high,
    Priority priority = Priority.defaultPriority,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: importance,
        priority: priority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }
}
