import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/tutorial_service.dart';
import '../../../auth/providers/auth_provider.dart';

import '../../providers/dashboard_provider.dart';
import '../../models/dashboard_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../cash/providers/cash_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/currency_format.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../../../core/providers/experience_provider.dart';
import '../../../settings/providers/notification_prefs_provider.dart';
import '../../../shared/providers/shared_groups_provider.dart';

/// Reusable "glow card" decoration shared by the dashboard cards for a
/// consistent modern look: rounded corners, a soft color-tinted ambient
/// shadow plus a tight contact shadow, and a subtle hairline border in
/// both light and dark mode.
/// [subtle] drops the tinted ambient glow for plain list containers that
/// carry no semantic color (e.g. "Top gastos"), so the colored glow stays
/// reserved for cards where the color actually means something (risk,
/// cash, debt, shared balance) — see ARCHITECTURE_KNOWLEDGE.md notes on
/// keeping visual emphasis intentional rather than uniform.
BoxDecoration _glowCardDecoration(
  BuildContext context, {
  List<Color>? gradient,
  Color? glowColor,
  double radius = 24,
  bool subtle = false,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final shadowTint = glowColor ?? theme.colorScheme.primary;
  return BoxDecoration(
    color: isDark
        ? const Color(0xFF141826)
        : theme.colorScheme.surfaceContainerLow,
    gradient: gradient != null
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient)
        : null,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: shadowTint
            .withAlpha(subtle ? (isDark ? 16 : 6) : (isDark ? 46 : 16)),
        blurRadius: subtle ? 22 : 30,
        offset: Offset(0, subtle ? 8 : 12),
      ),
      BoxShadow(
        color: Colors.black.withAlpha(isDark ? 60 : 8),
        blurRadius: 12,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

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
            color: Theme.of(context).shadowColor.withAlpha(24),
            blurRadius: 26,
            offset: const Offset(0, 8),
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return;
      final userId = auth.valueOrNull?.user?.id;
      if (userId == null) return;
      if (!TutorialService().isOnboardingDone(userId: userId)) {
        context.go(AppRoutes.onboarding);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(dashboardProvider);
    final insightsAsync = ref.watch(insightsProvider);
    final isSimple =
        ref.watch(isSimpleModeProvider); // top-level watch — always subscribed
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
          if (!isSimple)
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
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
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
        error: (e, _) => AppErrorWidget(
            error: e, onRetry: () => ref.invalidate(dashboardProvider)),
        data: (dash) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(insightsProvider);
            ref.invalidate(cashAccountsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 26,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withAlpha(50),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(
                    'Inicio',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(
                  '$monthTitle · Resumen general',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              _BalanceCard(dash: dash, isSimple: isSimple),
              if (!isSimple) ...[
                const SizedBox(height: 12),
                const _SharedSummaryCard()
              ],
              if (!isSimple) ...[
                const SizedBox(height: 12),
                _CashPreviewCard()
              ],
              if (!isSimple && dash.creditCardTotal > 0) ...[
                const SizedBox(height: 12),
                _CreditCardDebtCard(
                    amount: dash.creditCardTotal,
                    amountUSD: dash.creditCardTotalUSD,
                    periodStart: dash.periodStart,
                    periodEnd: dash.periodEnd),
              ],
              const SizedBox(height: 16),
              if (isSimple)
                const _SimplePrimaryButton()
              else
                const _QuickActions(),
              const SizedBox(height: 16),
              if (!isSimple) ...[
                _InsightsSection(),
                const SizedBox(height: 16)
              ],
              _TopCategories(
                  categories: dash.topCategories, isSimple: isSimple),
              if (!isSimple) ...[
                const SizedBox(height: 16),
                _RecentExpenses(expenses: dash.recentExpenses),
              ],
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
  static const _priorityOrder = {
    'critical': 4,
    'high': 3,
    'medium': 2,
    'low': 1
  };
  static const _motivationTypes = {'streak', 'achievement'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final prefsAsync = ref.watch(notificationPrefsProvider);
    final repo = ref.read(dashboardRepositoryProvider);

    final showMotivation = prefsAsync.valueOrNull?.inappMotivation ?? true;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
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
                const Icon(Icons.notifications_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notificaciones',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              foregroundColor: Colors.grey,
                            ),
                            child: const Text('Limpiar todo',
                                style: TextStyle(fontSize: 12)),
                          ),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
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
              error: (e, _) => AppErrorWidget(
                  error: e, onRetry: () => ref.invalidate(insightsProvider)),
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

                // Sort by priority desc, then date desc
                final sorted = [...insights]..sort((a, b) {
                    final pa = _priorityOrder[a.priority] ?? 1;
                    final pb = _priorityOrder[b.priority] ?? 1;
                    if (pb != pa) return pb.compareTo(pa);
                    return (b.generatedAt ?? '').compareTo(a.generatedAt ?? '');
                  });

                final alerts = sorted
                    .where((i) =>
                        !_motivationTypes.contains(i.type) &&
                        (i.priority == 'critical' || i.priority == 'high'))
                    .toList();
                final suggestions = sorted
                    .where((i) =>
                        !_motivationTypes.contains(i.type) &&
                        (i.priority == 'medium' || i.priority == 'low'))
                    .toList();
                final achievements = sorted
                    .where((i) => _motivationTypes.contains(i.type))
                    .toList();

                final sections = <Widget>[];

                void addSection(String label, List<InsightModel> items) {
                  if (items.isEmpty) return;
                  sections.add(_PanelSectionHeader(label: label));
                  for (final ins in items) {
                    sections.add(_InsightListTile(
                      insight: ins,
                      onMarkRead: () async {
                        await repo.markInsightRead(ins.id);
                        ref.invalidate(insightsProvider);
                      },
                      onDismiss: () async {
                        await repo.dismissInsight(ins.id);
                        ref.invalidate(insightsProvider);
                      },
                    ));
                    sections.add(const Divider(height: 1));
                  }
                }

                addSection('Alertas', alerts);
                addSection('Sugerencias', suggestions);
                if (showMotivation) addSection('Logros', achievements);

                if (sections.isEmpty) {
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

                return ListView(
                  controller: scrollCtrl,
                  children: sections,
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

class _PanelSectionHeader extends StatelessWidget {
  const _PanelSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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

  Color _borderColor(BuildContext context) {
    return switch (insight.priority) {
      'critical' => AppColors.error,
      'high' => AppColors.warning,
      'medium' => Theme.of(context).colorScheme.primary,
      _ => Colors.green.shade600,
    };
  }

  Color _iconColor(BuildContext context) => _borderColor(context);

  String _normalizeNotificationText(String input) {
    if (input.isEmpty) return input;

    var text = input;

    // Common UTF-8/Latin-1 mojibake (e.g. "podrÃ­a" -> "podría").
    try {
      text = utf8.decode(latin1.encode(text));
    } catch (_) {
      // Keep original text when conversion is not possible.
    }

    const replacements = {
      'Ã¡': 'á',
      'Ã©': 'é',
      'Ã­': 'í',
      'Ã³': 'ó',
      'Ãº': 'ú',
      'Ã±': 'ñ',
      'Ã': 'Á',
      'Ã‰': 'É',
      'Ã': 'Í',
      'Ã“': 'Ó',
      'Ãš': 'Ú',
      'Ã‘': 'Ñ',
      'Â¿': '¿',
      'Â¡': '¡',
      // CP437-like artifacts seen on some malformed payloads.
      '├í': 'á',
      '├⌐': 'é',
      '├¡': 'í',
      '├│': 'ó',
      '├║': 'ú',
      '├▒': 'ñ',
      '├ü': 'Á',
      '├ë': 'É',
      '├ì': 'Í',
      '├ô': 'Ó',
      '├Ü': 'Ú',
      '├æ': 'Ñ',
    };

    replacements.forEach((broken, fixed) {
      text = text.replaceAll(broken, fixed);
    });

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor(context);
    final iconColor = _iconColor(context);
    return Opacity(
      opacity: insight.isRead ? 0.55 : 1.0,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left color border strip
            Container(width: 3, color: borderColor),
            Expanded(
              child: ListTile(
                leading: Icon(_insightIcon(insight.type),
                    color: iconColor, size: 22),
                title: Text(_normalizeNotificationText(insight.title),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(_normalizeNotificationText(insight.body),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  color: Colors.grey,
                  tooltip: 'Descartar',
                ),
                onTap: insight.isRead ? null : onMarkRead,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Decorative "ticket stub" motifs ──────────────────────────────────────
// Signature element for the Home dashboard: the balance reads like a pay
// stub for la quincena (the pay cycle Hondurans actually think in terms
// of, not "the month") — a torn, perforated card stamped at the corner.

/// A hand-cut dashed rule faking the perforated tear-line of a paper
/// ticket. No custom painter needed — just spaced containers.
class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashSpace = 5.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          children: List.generate(
            count < 0 ? 0 : count,
            (_) => Container(
              width: dashWidth,
              height: 1.4,
              margin: const EdgeInsets.only(right: dashSpace),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(1)),
            ),
          ),
        );
      },
    );
  }
}

/// The perforation separating the ticket's "amount" stub from its
/// "details" stub — a dashed rule with a row of punched-out dots.
class _PunchDivider extends StatelessWidget {
  const _PunchDivider({required this.lineColor, required this.dotColor});
  final Color lineColor;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: Center(child: _DashedLine(color: lineColor))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (_) => Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pay-cycle indicator reimagined as a stamped seal — a rotated
/// double-ring circle, the way a boarding pass gets stamped at the gate.
/// Replaces the old pill badge.
class _CycleStamp extends StatelessWidget {
  const _CycleStamp(
      {required this.days, required this.color, required this.bg});
  final int days;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.16,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(150), width: 1),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$days',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1,
                      )),
                  Text('DÍAS',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 1.1,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Balance card ──────────────────────────────────────────────────────────
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.dash, required this.isSimple});
  final DashboardModel dash;
  final bool isSimple;

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
    final isDark = theme.brightness == Brightness.dark;
    final riskColor = _readableRiskColor(context);
    final riskAccent = (!isSimple && dash.riskLevel == 'yellow')
        ? (isDark ? const Color(0xFFFFC94D) : const Color(0xFF9A5600))
        : riskColor;
    final primaryTextColor =
        isDark ? const Color(0xFFF2F5FB) : theme.colorScheme.onSurface;
    final secondaryTextColor =
        isDark ? const Color(0xFFAEB6C7) : theme.colorScheme.onSurfaceVariant;
    final cycleBadgeBg =
        isDark ? const Color(0xFF1A4C39) : riskAccent.withAlpha(62);
    final cycleBadgeColor = isDark ? const Color(0xFF89F5B6) : riskAccent;
    final bgGradient = isDark
        ? const [Color(0xFF1B2333), Color(0xFF10151F)]
        : [
            Colors.white,
            Color.alphaBlend(
                theme.colorScheme.primary.withAlpha(12), Colors.white)
          ];

    final dividerLine =
        (isDark ? Colors.white : Colors.black).withAlpha(isDark ? 32 : 20);
    final dividerDot =
        (isDark ? Colors.white : Colors.black).withAlpha(isDark ? 24 : 14);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: _glowCardDecoration(
            context,
            gradient: bgGradient,
            glowColor: riskAccent,
            radius: 26,
          ),
          child: Padding(
            padding: EdgeInsets.all(isSimple ? 24 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        size: 13, color: secondaryTextColor),
                    const SizedBox(width: 6),
                    Text(
                      'BALANCE DEL PERÍODO',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  fmt.format(dash.balance),
                  style: (isSimple
                          ? theme.textTheme.displayMedium
                          : theme.textTheme.displaySmall)
                      ?.copyWith(
                    fontWeight: isSimple ? FontWeight.w900 : FontWeight.bold,
                    color: primaryTextColor,
                    letterSpacing: -0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (!isSimple) ...[
                  const SizedBox(height: 4),
                  // ── Prediction / safe-spend row ──
                  _PredictionRow(
                    dash: dash,
                    riskColor: riskAccent,
                    fmt: fmt,
                    neutralTextColor: secondaryTextColor,
                  ),
                ],
                const SizedBox(height: 18),
                _PunchDivider(lineColor: dividerLine, dotColor: dividerDot),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatChip(
                      label: 'Ingresos',
                      value: fmt.format(dash.totalIncome),
                      color: AppColors.income,
                      isSimple: isSimple,
                      onTap: () => context.go(AppRoutes.incomes),
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Gastos',
                      value: fmt.format(dash.totalExpenses),
                      color: AppColors.expense,
                      isSimple: isSimple,
                      onTap: () => context.go(AppRoutes.expenses),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isSimple)
          Positioned(
            top: -10,
            right: 18,
            child: _CycleStamp(
                days: dash.daysRemaining,
                color: cycleBadgeColor,
                bg: cycleBadgeBg),
          ),
      ],
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow(
      {required this.dash,
      required this.riskColor,
      required this.fmt,
      this.neutralTextColor});
  final DashboardModel dash;
  final Color riskColor;
  final NumberFormat fmt;
  final Color? neutralTextColor;

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
                  fontSize: 12, color: riskColor, fontWeight: FontWeight.w600),
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
              style: TextStyle(
                  fontSize: 12, color: riskColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    return Text(
      'Gasto diario seguro: ${fmt.format(dash.safeDailySpend)}',
      style: theme.textTheme.bodySmall?.copyWith(
          color: neutralTextColor ?? theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label,
      required this.value,
      required this.color,
      required this.onTap,
      this.isSimple = false});
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final bool isSimple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tone = isDark ? Color.lerp(color, Colors.white, 0.08)! : color;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12, vertical: isSimple ? 14 : 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x2A1B2333) : color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: isDark
                  ? Border.all(color: tone.withAlpha(54), width: 1)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      label == 'Ingresos'
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: tone,
                    ),
                    const SizedBox(width: 4),
                    Text(label.toUpperCase(),
                        style: TextStyle(
                            fontSize: isSimple ? 12 : 10,
                            color: tone,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: isSimple ? 17 : 14,
                        color: tone,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
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
    final isDark = theme.brightness == Brightness.dark;
    final cardBg =
        isDark ? const Color(0xFF123228) : theme.colorScheme.secondaryContainer;
    final cardBg2 =
        isDark ? const Color(0xFF0E2C23) : theme.colorScheme.secondaryContainer;
    final textColor = isDark
        ? const Color(0xFFD2F5E7)
        : theme.colorScheme.onSecondaryContainer;
    final bgGradient = isDark
        ? [cardBg, cardBg2]
        : [
            theme.colorScheme.secondaryContainer,
            Color.alphaBlend(AppColors.secondary.withAlpha(20),
                theme.colorScheme.secondaryContainer),
          ];

    return GestureDetector(
      onTap: () => context.go(AppRoutes.cash),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: _glowCardDecoration(
          context,
          gradient: bgGradient,
          glowColor: AppColors.secondary,
          radius: 20,
          subtle: true,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: textColor.withAlpha(isDark ? 30 : 36),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: textColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: accountsAsync.when(
                loading: () => const _ShimmerText(),
                error: (_, __) => Text('Efectivo disponible',
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.w500)),
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return Text(
                      'Configurar cartera de efectivo \u2192',
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14),
                    );
                  }
                  final total = accounts.fold(0.0, (s, a) => s + a.balance);
                  final currency = accounts.first.currency;
                  final fmt = currencyFmt(currency);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Efectivo disponible',
                          style: TextStyle(
                              fontSize: 11, color: textColor.withAlpha(190))),
                      Text(
                        fmt.format(total),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor),
                      ),
                    ],
                  );
                },
              ),
            ),
            Icon(Icons.chevron_right, color: textColor.withAlpha(170)),
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
      other is _CreditExpensesParams &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

final _creditExpensesProvider = FutureProvider.autoDispose
    .family<List<ExpenseModel>, _CreditExpensesParams>(
  (ref, params) async {
    final dio = ref.watch(dioProvider);
    final resp = await dio.get(ApiConstants.expenses, queryParameters: {
      'paymentMethod': 'card_credit',
      'startDate': params.start,
      'endDate': params.end,
      'limit': 100,
    });
    final items = resp.data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

class _CreditCardDebtCard extends ConsumerWidget {
  const _CreditCardDebtCard(
      {required this.amount,
      required this.amountUSD,
      required this.periodStart,
      required this.periodEnd});
  final double amount;
  final double amountUSD;
  final String periodStart;
  final String periodEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFmtProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor =
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFC96A00);
    final titleColor =
        isDark ? theme.colorScheme.onSurface : const Color(0xFFA45700);
    final bodyColor =
        isDark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF8C4A00);
    final bgGradient = isDark
        ? const [Color(0xFF1C2231), Color(0xFF131925)]
        : [
            const Color(0xFFFFF4E5),
            Color.alphaBlend(
                accentColor.withAlpha(16), const Color(0xFFFFF4E5)),
          ];

    return GestureDetector(
      onTap: () =>
          _showCreditDetail(context, periodStart, periodEnd, amount, amountUSD),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: _glowCardDecoration(
          context,
          gradient: bgGradient,
          glowColor: accentColor,
          radius: 20,
          subtle: true,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(isDark ? 30 : 34),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.credit_card_rounded, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gastos con tarjeta de crédito',
                    style: TextStyle(
                        fontSize: 13,
                        color: titleColor,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  if (amountUSD > 0) ...[
                    Text(
                      fmt.format(amount),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: accentColor),
                    ),
                    Text(
                      '+ ${currencyFmt('USD').format(amountUSD)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: bodyColor),
                    ),
                  ] else
                    Text(
                      fmt.format(amount),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: accentColor),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Cargado a crédito este período',
                    style: TextStyle(fontSize: 11, color: bodyColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.info_outline, color: titleColor, size: 20),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor =
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFC96A00);
    final titleColor =
        isDark ? theme.colorScheme.onSurface : const Color(0xFFA45700);
    final bodyColor =
        isDark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF8C4A00);
    final infoBgColor = isDark
        ? theme.colorScheme.surfaceContainerHigh.withAlpha(210)
        : const Color(0xFFFFF4E5);
    final infoBorderColor =
        isDark ? Colors.white.withAlpha(12) : const Color(0xFFF2D2A2);

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
                Icon(Icons.credit_card_outlined, color: accentColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gastos del período con crédito',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                      ),
                      Text(
                        'Del $periodStart al $periodEnd',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        '+ ${currencyFmt('USD').format(totalUSD)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: bodyColor,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    fmt.format(total),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: infoBgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: infoBorderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: titleColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total de gastos registrados con tarjeta de crédito durante este período presupuestario.',
                    style: TextStyle(fontSize: 12, color: bodyColor),
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
                  return const Center(
                      child: Text('Sin gastos de crédito en este período'));
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final e = expenses[i];
                    final isEmoji = e.categoryIcon.runes.any((r) => r > 127);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: infoBgColor,
                        child: isEmoji
                            ? Text(e.categoryIcon)
                            : Icon(
                                materialIconFromString(e.categoryIcon),
                                size: 18,
                                color: accentColor,
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
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: accentColor),
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
/// Full-width single action button for Simple mode.
class _SimplePrimaryButton extends StatelessWidget {
  const _SimplePrimaryButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.go(AppRoutes.addExpense),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withAlpha(80),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline,
                size: 36, color: theme.colorScheme.onPrimary),
            const SizedBox(height: 8),
            Text(
              'Registrar gasto',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creditAccent =
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFC96A00);
    return Row(
      children: [
        _ActionButton(
          icon: Icons.add_circle_rounded,
          label: 'Gasto',
          color: AppColors.expense,
          onTap: () => context.go(AppRoutes.addExpense),
        ),
        const SizedBox(width: 10),
        _ActionButton(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Efectivo',
          color: AppColors.secondary,
          onTap: () => context.go(AppRoutes.cash),
        ),
        const SizedBox(width: 10),
        _ActionButton(
          icon: Icons.bar_chart_rounded,
          label: 'Análisis',
          color: Theme.of(context).colorScheme.primary,
          onTap: () => context.go(AppRoutes.analytics),
        ),
        const SizedBox(width: 10),
        _ActionButton(
          icon: Icons.credit_card_rounded,
          label: 'Tarjetas',
          color: creditAccent,
          onTap: () => context.go(AppRoutes.creditCards),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 28 : 18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: color.withAlpha(isDark ? 50 : 30), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(isDark ? 40 : 22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface),
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
        final active = insights.where((i) => !i.isDismissed).toList();
        if (active.isEmpty) return const SizedBox.shrink();

        final shown = _expanded ? active : active.take(_initialMax).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Alertas e indicadores',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
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
                        child: const Text('Descartar todo',
                            style: TextStyle(fontSize: 12)),
                      ),
                    if (active.length > _initialMax)
                      TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(_expanded
                            ? 'Ver menos'
                            : 'Ver más (${active.length - _initialMax})'),
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
Widget _categoryIconWidget(
  String icon, {
  bool isSimple = false,
  Color? accent,
}) {
  final iconData = materialIconFromString(icon);
  final iconColor = accent ?? AppColors.warning;
  return Container(
    width: isSimple ? 36 : 30,
    height: isSimple ? 36 : 30,
    decoration: BoxDecoration(
      color: iconColor.withAlpha(28),
      shape: BoxShape.circle,
    ),
    child: Icon(iconData, size: isSimple ? 20 : 17, color: iconColor),
  );
}

class _TopCategories extends ConsumerWidget {
  const _TopCategories({required this.categories, required this.isSimple});
  final List<CategorySpend> categories;
  final bool isSimple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final visible = categories.take(5).toList();
    final total = categories.fold(0.0, (s, c) => s + c.amount);
    final maxAmount = visible.fold<double>(
      0,
      (max, category) => category.amount > max ? category.amount : max,
    );
    final fmt = ref.watch(currencyFmtProvider);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, isSimple ? 16 : 14),
      decoration: _glowCardDecoration(context, radius: 20, subtle: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(22),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.insights_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top gastos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Categorías con mayor impacto',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.go(AppRoutes.expenses),
                tooltip: 'Ver todos los gastos',
                icon: const Icon(Icons.arrow_forward_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...visible.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final accent = AppColors
                .categoryPalette[index % AppColors.categoryPalette.length];
            final share = category.percentage > 0
                ? category.percentage
                : total > 0
                    ? category.amount / total
                    : 0.0;
            final barValue = maxAmount > 0 ? category.amount / maxAmount : 0.0;
            return Padding(
              padding: EdgeInsets.only(
                  bottom:
                      index == visible.length - 1 ? 0 : (isSimple ? 16 : 13)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isSimple ? 42 : 34,
                    height: isSimple ? 42 : 34,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(18),
                      borderRadius: BorderRadius.circular(isSimple ? 14 : 11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: TextStyle(
                        color: accent,
                        fontSize: isSimple ? 14 : 11,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  SizedBox(width: isSimple ? 12 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isSimple ? 20 : 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              fmt.format(category.amount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: isSimple ? 18 : 13,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: barValue.clamp(0.0, 1.0),
                                  minHeight: isSimple ? 8 : 6,
                                  color: accent,
                                  backgroundColor: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withAlpha(140),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(share * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          index == 0
                              ? 'Mayor gasto del período'
                              : 'Del gasto total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
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
      ),
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: _glowCardDecoration(context, radius: 20, subtle: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.expense.withAlpha(18),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: AppColors.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gastos recientes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${expenses.take(5).length} movimientos del período',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.expenses),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...expenses.take(5).toList().asMap().entries.map(
            (entry) {
              final index = entry.key;
              final expense = entry.value;
              final accent = AppColors.categoryPalette[
                  (index + 1) % AppColors.categoryPalette.length];
              return Column(
                children: [
                  InkWell(
                    onTap: () => context.go(AppRoutes.expenses),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          _categoryIconWidget(
                            expense.categoryIcon,
                            accent: accent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense.description.isEmpty
                                      ? expense.categoryName
                                      : expense.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        expense.categoryName.isEmpty
                                            ? 'Sin categoría'
                                            : expense.categoryName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: Text(
                                        '·',
                                        style: TextStyle(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDashboardDate(expense.date),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '-${currencyFmt(expense.currency).format(expense.amount)}',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.expense,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (index < expenses.take(5).length - 1)
                    Divider(
                      height: 1,
                      indent: 42,
                      color: theme.colorScheme.outlineVariant.withAlpha(55),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _formatDashboardDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final formatted = DateFormat('d MMM', 'es').format(parsed);
  return formatted[0].toUpperCase() + formatted.substring(1);
}

// ── Shared Groups Summary Card ───────────────────────────────────────────────

class _SharedSummaryCard extends ConsumerWidget {
  const _SharedSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(sharedWidgetSummaryProvider);
    final fmt = ref.watch(currencyFmtProvider);
    final theme = Theme.of(context);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (!summary.hasGroups) return const SizedBox.shrink();

        final isDark = theme.brightness == Brightness.dark;
        final oweColor =
            isDark ? const Color(0xFF6FE3A0) : Colors.green.shade700;
        final dueColor =
            isDark ? const Color(0xFFFFB37A) : Colors.orange.shade700;

        return GestureDetector(
          onTap: () => context.go(AppRoutes.shared),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _glowCardDecoration(
              context,
              glowColor: theme.colorScheme.primary,
              radius: 20,
              subtle: true,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary
                            .withAlpha(isDark ? 30 : 24),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.group_rounded,
                          color: theme.colorScheme.primary, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Gastos Compartidos',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      'Ver →',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryChip(
                        label: 'Te deben',
                        amount: fmt.format(summary.totalOwed),
                        color: oweColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Debes',
                        amount: fmt.format(summary.totalDue),
                        color: dueColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
