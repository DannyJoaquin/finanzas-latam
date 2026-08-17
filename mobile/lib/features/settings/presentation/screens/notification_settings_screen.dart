import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/services/browser_notification_service.dart';
import '../../../../core/services/fcm_service.dart';
import '../../providers/notification_prefs_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error cargando preferencias: $e',
              style: const TextStyle(color: Colors.red)),
        ),
        data: (prefs) => ListView(
          children: [
            if (kIsWeb) ...[
              const _SubHeader(label: 'Navegador'),
              const _BrowserNotificationTile(),
            ],
            // ── Push ────────────────────────────────────────────────────────
            const _SubHeader(label: 'Notificaciones push'),
            _NotifTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Alertas de presupuesto',
              subtitle: 'Cuando tu presupuesto llega al 50%, 80% o 100%',
              value: prefs.pushBudgetAlerts,
              onChanged: (v) => _toggle(ref, context, {'pushBudgetAlerts': v}),
            ),
            _NotifTile(
              icon: Icons.today_outlined,
              title: 'Recordatorio diario',
              subtitle: 'Solo si hay algo que revisar hoy',
              value: prefs.pushDailyReminder,
              onChanged: (v) => _toggle(ref, context, {'pushDailyReminder': v}),
            ),
            _NotifTile(
              icon: Icons.calendar_month_outlined,
              title: 'Resumen semanal',
              subtitle: 'Total y comparación vs semana anterior',
              value: prefs.pushWeeklySummary,
              onChanged: (v) => _toggle(ref, context, {'pushWeeklySummary': v}),
            ),
            _NotifTile(
              icon: Icons.insights_outlined,
              title: 'Insights importantes',
              subtitle: 'Anomalías y oportunidades de ahorro',
              value: prefs.pushImportantInsights,
              onChanged: (v) =>
                  _toggle(ref, context, {'pushImportantInsights': v}),
            ),
            _NotifTile(
              icon: Icons.warning_amber_outlined,
              title: 'Alertas financieras críticas',
              subtitle: 'Riesgo de quedarse sin fondos',
              value: prefs.pushCriticalFinancialAlerts,
              onChanged: (v) =>
                  _toggle(ref, context, {'pushCriticalFinancialAlerts': v}),
            ),
            _NotifTile(
              icon: Icons.emoji_events_outlined,
              title: 'Motivación y logros',
              subtitle: 'Rachas, hitos y medallas (desactivado por defecto)',
              value: prefs.pushMotivation,
              onChanged: (v) => _toggle(ref, context, {'pushMotivation': v}),
            ),
            _NotifTile(
              icon: Icons.group_outlined,
              title: 'Gastos compartidos',
              subtitle: 'Cuando alguien agrega, edita o elimina un gasto del grupo',
              value: prefs.pushSharedExpenseChanges,
              onChanged: (v) => _toggle(
                ref,
                context,
                {'pushSharedExpenseChanges': v},
              ),
            ),
            const SizedBox(height: 8),

            // ── Tarjetas de crédito ─────────────────────────────────────────
            const _SubHeader(label: 'Tarjetas de crédito (locales)'),
            _NotifTile(
              icon: Icons.content_cut_outlined,
              title: 'Aviso de corte',
              subtitle: '3 días antes de la fecha de corte',
              value: prefs.localCardCutoffAlerts,
              onChanged: (v) =>
                  _toggle(ref, context, {'localCardCutoffAlerts': v}),
            ),
            _NotifTile(
              icon: Icons.event_outlined,
              title: 'Vencimiento 5 días antes',
              subtitle: 'Recuerda que tu pago vence pronto',
              value: prefs.localCardDue5d,
              onChanged: (v) => _toggle(ref, context, {'localCardDue5d': v}),
            ),
            _NotifTile(
              icon: Icons.event_available_outlined,
              title: 'Vencimiento 1 día antes',
              subtitle: 'Alerta final antes del corte',
              value: prefs.localCardDue1d,
              onChanged: (v) => _toggle(ref, context, {'localCardDue1d': v}),
            ),
            _NotifTile(
              icon: Icons.credit_card_outlined,
              title: 'Saldo pendiente de ciclo anterior',
              subtitle: 'Cuando queda deuda sin pagar del ciclo previo',
              value: prefs.localCardPendingBalance,
              onChanged: (v) =>
                  _toggle(ref, context, {'localCardPendingBalance': v}),
            ),
            const SizedBox(height: 8),

            // ── In-app ──────────────────────────────────────────────────────
            const _SubHeader(label: 'Centro de notificaciones (in-app)'),
            _NotifTile(
              icon: Icons.savings_outlined,
              title: 'Oportunidades de ahorro',
              subtitle: 'Sugerencias para reducir gastos',
              value: prefs.inappSavingsOpportunities,
              onChanged: (v) =>
                  _toggle(ref, context, {'inappSavingsOpportunities': v}),
            ),
            _NotifTile(
              icon: Icons.pattern_outlined,
              title: 'Patrones de gasto',
              subtitle: 'Día más caro de la semana y tendencias',
              value: prefs.inappPatterns,
              onChanged: (v) => _toggle(ref, context, {'inappPatterns': v}),
            ),
            _NotifTile(
              icon: Icons.local_fire_department_outlined,
              title: 'Logros y rachas',
              subtitle: 'Hitos gamificados en tu centro de notificaciones',
              value: prefs.inappMotivation,
              onChanged: (v) => _toggle(ref, context, {'inappMotivation': v}),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(
    WidgetRef ref,
    BuildContext context,
    Map<String, dynamic> patch,
  ) async {
    try {
      await ref.read(notificationPrefsProvider.notifier).toggle(patch);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la preferencia')),
        );
      }
    }
  }
}

class _BrowserNotificationTile extends ConsumerStatefulWidget {
  const _BrowserNotificationTile();

  @override
  ConsumerState<_BrowserNotificationTile> createState() =>
      _BrowserNotificationTileState();
}

class _BrowserNotificationTileState
    extends ConsumerState<_BrowserNotificationTile> {
  bool _requesting = false;

  Future<void> _enable() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    final granted = await requestBrowserNotificationPermission();
    if (granted) {
      await FcmService.instance.registerToken(ref.read(dioProvider));
    }

    if (!mounted) return;
    setState(() => _requesting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Notificaciones del navegador activadas.'
              : 'No se concedió el permiso de notificaciones.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 320),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 16),
                Text(
                  'Notificaciones del navegador',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Permite alertas cuando Zentri esté abierta o instalada'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _requesting ? null : _enable,
                icon: _requesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_outlined),
                label: Text(_requesting ? 'Activando' : 'Activar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section sub-header ───────────────────────────────────────────────────────

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Switch tile ──────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }
}
