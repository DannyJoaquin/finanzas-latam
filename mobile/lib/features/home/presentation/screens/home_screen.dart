import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../providers/dashboard_provider.dart';
import '../../models/dashboard_model.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../cash/providers/cash_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/currency_format.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);
    final insightsAsync = ref.watch(insightsProvider);
    final monthRaw = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    final monthTitle = monthRaw[0].toUpperCase() + monthRaw.substring(1);
    final unreadCount = insightsAsync.valueOrNull
            ?.where((i) => !i.isRead && !i.isDismissed)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          _TopActionButton(
            icon: Icons.bar_chart_outlined,
            tooltip: 'Análisis',
            onPressed: () => context.go(AppRoutes.analytics),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _TopActionButton(
                icon: Icons.notifications_outlined,
                tooltip: 'Alertas',
                onPressed: () => _showNotificationsPanel(context, ref),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          _TopActionButton(
            icon: Icons.settings_outlined,
            tooltip: 'Ajustes',
            onPressed: () => context.go(AppRoutes.settings),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(error: e, onRetry: () => ref.invalidate(dashboardProvider)),
        data: (dash) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(insightsProvider);
            ref.invalidate(cashAccountsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Inicio',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$monthTitle · Resumen general',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              _BalanceCard(dash: dash),
              const SizedBox(height: 12),
              _CashPreviewCard(),
              if (dash.creditCardTotal > 0) ...[
                const SizedBox(height: 12),
                _CreditCardDebtCard(amount: dash.creditCardTotal, amountUSD: dash.creditCardTotalUSD, periodStart: dash.periodStart, periodEnd: dash.periodEnd),
              ],
              const SizedBox(height: 16),
              _QuickActions(),
              const SizedBox(height: 16),
              _InsightsSection(),
              const SizedBox(height: 16),
              _TopCategories(categories: dash.topCategories),
              const SizedBox(height: 16),
              _RecentExpenses(expenses: dash.recentExpenses),
            ],
          ),
        ),
      ),
    );
  }
}

// �"?�"? Notifications panel �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
void _showNotificationsPanel(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _NotificationsPanel(),
  );
}

class _NotificationsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final repo = ref.read(dashboardRepositoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined),
                const SizedBox(width: 10),
                Text(
                  'Notificaciones',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                insightsAsync.when(
                  data: (list) {
                    final unread = list.where((i) => !i.isRead).length;
                    final hasDismissible = list.isNotEmpty;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasDismissible)
                          TextButton(
                            onPressed: () async {
                              await repo.dismissAllInsights();
                              ref.invalidate(insightsProvider);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              foregroundColor: Colors.grey,
                            ),
                            child: const Text('Limpiar todo', style: TextStyle(fontSize: 12)),
                          ),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unread',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: insightsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorWidget(error: e, onRetry: () => ref.invalidate(insightsProvider)),
              data: (insights) {
                if (insights.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.green.shade400),
                        const SizedBox(height: 12),
                        const Text('Todo en orden',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('No hay alertas en este momento',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  itemCount: insights.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final ins = insights[i];
                    return _InsightListTile(
                      insight: ins,
                      onMarkRead: () async {
                        await repo.markInsightRead(ins.id);
                        ref.invalidate(insightsProvider);
                      },
                      onDismiss: () async {
                        await repo.dismissInsight(ins.id);
                        ref.invalidate(insightsProvider);
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InsightListTile extends StatelessWidget {
  const _InsightListTile({
    required this.insight,
    required this.onMarkRead,
    required this.onDismiss,
  });
  final InsightModel insight;
  final VoidCallback onMarkRead;
  final VoidCallback onDismiss;

  Color _color(BuildContext context) {
    return switch (insight.priority) {
      'critical' => AppColors.error,
      'high' => AppColors.warning,
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Opacity(
      opacity: insight.isRead ? 0.55 : 1.0,
      child: ListTile(
        leading: Icon(_insightIcon(insight.type), color: color, size: 22),
        title: Text(insight.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(insight.body,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: onDismiss,
          color: Colors.grey,
          tooltip: 'Descartar',
        ),
        onTap: insight.isRead ? null : onMarkRead,
        dense: true,
      ),
    );
  }
}

// �"?�"? Balance card �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.dash});
  final DashboardModel dash;

  Color _riskColor() {
    return switch (dash.riskLevel) {
      'red' => AppColors.riskRed,
      'yellow' => AppColors.riskYellow,
      _ => AppColors.riskGreen,
    };
  }

  Color _readableRiskColor(BuildContext context) {
    final base = _riskColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return base;

    // Increase contrast for warning tone in dark mode.
    if (dash.riskLevel == 'yellow') return const Color(0xFFFFD54F);
    return base;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFmtProvider);
    final theme = Theme.of(context);
    final riskColor = _readableRiskColor(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(14),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Balance del período', style: theme.textTheme.labelLarge),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withAlpha(42),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: riskColor),
                      const SizedBox(width: 4),
                      Text(
                        '${dash.daysRemaining}d del ciclo',
                        style: TextStyle(
                            fontSize: 12,
                            color: riskColor,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              fmt.format(dash.balance),
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // �"?�"? Prediction / safe-spend row �"?�"?
            _PredictionRow(dash: dash, riskColor: riskColor, fmt: fmt),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatChip(
                  label: 'Ingresos',
                  value: fmt.format(dash.totalIncome),
                  color: AppColors.income,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'Gastos',
                  value: fmt.format(dash.totalExpenses),
                  color: AppColors.expense,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow(
      {required this.dash, required this.riskColor, required this.fmt});
  final DashboardModel dash;
  final Color riskColor;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (dash.riskLevel == 'red' && dash.cashRunoutDate != null) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: riskColor, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Al ritmo actual, fondos se agotarían: ${dash.cashRunoutDate}',
              style: TextStyle(
                  fontSize: 12,
                  color: riskColor,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      );
    }

    if (dash.riskLevel == 'yellow' && dash.cashRunoutDate != null) {
      return Row(
        children: [
          Icon(Icons.info_outline_rounded, color: riskColor, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Al ritmo actual, fondos alcanzan hasta: ${dash.cashRunoutDate}',
              style: TextStyle(fontSize: 12, color: riskColor),
            ),
          ),
        ],
      );
    }

    return Text(
      'Gasto diario seguro: ${fmt.format(dash.safeDailySpend)}',
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// �"?�"? Cash preview card �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
class _CashPreviewCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(cashAccountsProvider);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.go(AppRoutes.cash),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: theme.colorScheme.onSecondaryContainer,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: accountsAsync.when(
                loading: () => const _ShimmerText(),
                error: (_, __) => Text('Efectivo disponible',
                    style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500)),
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return Text(
                      'Configurar cartera de efectivo \u2192',
                      style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                          fontSize: 14),
                    );
                  }
                  final total = accounts.fold(0.0, (s, a) => s + a.balance);
                  final currency = accounts.first.currency;
                  final fmt = NumberFormat.currency(
                      locale: 'en_US', symbol: '$currency ');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Efectivo disponible',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSecondaryContainer
                                  .withAlpha(180))),
                      Text(
                        fmt.format(total),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ],
                  );
                },
              ),
            ),
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSecondaryContainer.withAlpha(160)),
          ],
        ),
      ),
    );
  }
}

class _ShimmerText extends StatelessWidget {
  const _ShimmerText();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      width: 120,
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(60),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── Credit card debt card ─────────────────────────────────────────────────────

class _CreditExpensesParams {
  const _CreditExpensesParams({required this.start, required this.end});
  final String start;
  final String end;

  @override
  bool operator ==(Object other) =>
      other is _CreditExpensesParams && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

final _creditExpensesProvider =
    FutureProvider.autoDispose.family<List<ExpenseModel>, _CreditExpensesParams>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final resp = await dio.get(ApiConstants.expenses, queryParameters: {
      'paymentMethod': 'card_credit',
      'startDate': params.start,
      'endDate': params.end,
      'limit': 100,
    });
    final items = resp.data['items'] as List<dynamic>? ?? [];
    return items.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
  },
);

class _CreditCardDebtCard extends ConsumerWidget {
  const _CreditCardDebtCard({required this.amount, required this.amountUSD, required this.periodStart, required this.periodEnd});
  final double amount;
  final double amountUSD;
  final String periodStart;
  final String periodEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFmtProvider);
    const cardColor = Color(0xFFFF9800);

    return GestureDetector(
      onTap: () => _showCreditDetail(context, periodStart, periodEnd, amount, amountUSD),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(10),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.credit_card_outlined, color: cardColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gastos con tarjeta de crédito',
                    style: TextStyle(
                        fontSize: 13,
                        color: cardColor,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  if (amountUSD > 0) ...[
                    Text(
                      fmt.format(amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: cardColor),
                    ),
                    Text(
                      '+ ${NumberFormat.currency(locale: 'en_US', symbol: '\$ ').format(amountUSD)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: cardColor.withAlpha(200)),
                    ),
                  ] else
                    Text(
                      fmt.format(amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: cardColor),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Cargado a crédito este período',
                    style: TextStyle(fontSize: 11, color: cardColor.withAlpha(180)),
                  ),
                ],
              ),
            ),
            Icon(Icons.info_outline, color: cardColor.withAlpha(160), size: 20),
          ],
        ),
      ),
    );
  }
}

void _showCreditDetail(
  BuildContext context,
  String periodStart,
  String periodEnd,
  double total,
  double totalUSD,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CreditDetailSheet(
      periodStart: periodStart,
      periodEnd: periodEnd,
      total: total,
      totalUSD: totalUSD,
    ),
  );
}

class _CreditDetailSheet extends ConsumerWidget {
  const _CreditDetailSheet({
    required this.periodStart,
    required this.periodEnd,
    required this.total,
    required this.totalUSD,
  });
  final String periodStart;
  final String periodEnd;
  final double total;
  final double totalUSD;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFmtProvider);
    const cardColor = Color(0xFFFF9800);

    // Fetch credit card expenses for the current period
    final creditExpensesAsync = ref.watch(_creditExpensesProvider(
      _CreditExpensesParams(start: periodStart, end: periodEnd),
    ));

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.credit_card_outlined, color: cardColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gastos del período con crédito',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cardColor,
                            ),
                      ),
                      Text(
                        'Del $periodStart al $periodEnd',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (totalUSD > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt.format(total),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cardColor,
                        ),
                      ),
                      Text(
                        '+ ${NumberFormat.currency(locale: 'en_US', symbol: '\$ ').format(totalUSD)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cardColor.withAlpha(200),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    fmt.format(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardColor.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cardColor.withAlpha(200)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total de gastos registrados con tarjeta de crédito durante este período presupuestario.',
                    style: TextStyle(fontSize: 12, color: cardColor.withAlpha(200)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: creditExpensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorWidget(error: e),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(child: Text('Sin gastos de crédito en este período'));
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final e = expenses[i];
                    final isEmoji = e.categoryIcon.runes.any((r) => r > 127);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cardColor.withAlpha(20),
                        child: isEmoji
                            ? Text(e.categoryIcon)
                            : Icon(
                                materialIconFromString(e.categoryIcon),
                                size: 18,
                                color: cardColor,
                              ),
                      ),
                      title: Text(
                        e.description.isEmpty ? e.categoryName : e.description,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${e.categoryName} · ${e.date}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        currencyFmt(e.currency).format(e.amount),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: cardColor),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// �"?�"? Quick actions �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: Icons.add_circle_outline,
          label: 'Gasto',
          onTap: () => context.go(AppRoutes.addExpense),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Efectivo',
          onTap: () => context.go(AppRoutes.cash),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.bar_chart_outlined,
          label: 'Análisis',
          onTap: () => context.go(AppRoutes.analytics),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.credit_card_outlined,
          label: 'Tarjetas',
          onTap: () => context.go(AppRoutes.creditCards),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withAlpha(12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// �"?�"? Insights section �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
class _InsightsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_InsightsSection> createState() => _InsightsSectionState();
}

class _InsightsSectionState extends ConsumerState<_InsightsSection> {
  bool _expanded = false;
  static const _initialMax = 3;

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(insightsProvider);
    final repo = ref.read(dashboardRepositoryProvider);

    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insights) {
        final active =
            insights.where((i) => !i.isDismissed).toList();
        if (active.isEmpty) return const SizedBox.shrink();

        final shown = _expanded ? active : active.take(_initialMax).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alertas e indicadores',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          await repo.dismissAllInsights();
                          ref.invalidate(insightsProvider);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: Colors.grey,
                        ),
                        child: const Text('Descartar todo', style: TextStyle(fontSize: 12)),
                      ),
                    if (active.length > _initialMax)
                      TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(_expanded ? 'Ver menos' : 'Ver más (${active.length - _initialMax})'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...shown.map((ins) => _InsightCard(
                  key: ValueKey(ins.id),
                  insight: ins,
                  onMarkRead: () async {
                    await repo.markInsightRead(ins.id);
                    ref.invalidate(insightsProvider);
                  },
                  onDismiss: () async {
                    await repo.dismissInsight(ins.id);
                    ref.invalidate(insightsProvider);
                  },
                )),
          ],
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    super.key,
    required this.insight,
    required this.onMarkRead,
    required this.onDismiss,
  });
  final InsightModel insight;
  final VoidCallback onMarkRead;
  final VoidCallback onDismiss;

  Color _color(BuildContext context) {
    return switch (insight.priority) {
      'critical' => AppColors.error,
      'high' => AppColors.warning,
      'low' => Theme.of(context).colorScheme.onSurfaceVariant,
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);

    return Opacity(
      opacity: insight.isRead ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: insight.isRead ? null : onMarkRead,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(_insightIcon(insight.type), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      insight.body,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 16),
                color: Colors.grey,
                tooltip: 'Descartar',
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _insightIcon(String type) {
  return switch (type) {
    'anomaly' => Icons.trending_up_rounded,
    'projection' => Icons.warning_amber_rounded,
    'pattern' => Icons.insights_rounded,
    'savings_opportunity' => Icons.savings_outlined,
    'budget_warning' => Icons.account_balance_wallet_outlined,
    _ => Icons.lightbulb_outline,
  };
}

// �"?�"? Top categories �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
Widget _categoryIconWidget(String icon) {
  final iconData = materialIconFromString(icon);
  return Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: AppColors.warning.withAlpha(28),
      shape: BoxShape.circle,
    ),
    child: Icon(iconData, size: 17, color: AppColors.warning),
  );
}

class _TopCategories extends ConsumerWidget {
  const _TopCategories({required this.categories});
  final List<CategorySpend> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final total = categories.fold(0.0, (s, c) => s + c.amount);
    final fmt = ref.watch(currencyFmtProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top gastos',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...categories.take(5).toList().asMap().entries.map((e) {
          final pct = total > 0 ? e.value.amount / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _categoryIconWidget(e.value.icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.value.name,
                              style: const TextStyle(fontSize: 13)),
                          Text(fmt.format(e.value.amount),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          color: AppColors.categoryPalette[
                              e.key % AppColors.categoryPalette.length],
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// �"?�"? Recent expenses �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
class _RecentExpenses extends ConsumerWidget {
  const _RecentExpenses({required this.expenses});
  final List<RecentExpense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expenses.isEmpty) return const SizedBox.shrink();
    final fmt = ref.watch(currencyFmtProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gastos recientes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.go(AppRoutes.expenses),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        ...expenses.take(5).map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _categoryIconWidget(e.categoryIcon),
                title: Text(
                    e.description.isEmpty ? e.categoryName : e.description),
                subtitle: Text(e.categoryName),
                trailing: Text(
                  '-${fmt.format(e.amount)}',
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => context.go(AppRoutes.expenses),
              ),
            ),
      ],
    );
  }
}

