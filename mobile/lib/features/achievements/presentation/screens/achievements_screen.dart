import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../../home/models/dashboard_model.dart';
import '../../../home/providers/dashboard_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider);
    final monthRaw = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    final monthTitle = monthRaw[0].toUpperCase() + monthRaw.substring(1);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: achievementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(
          error: e,
          onRetry: () => ref.invalidate(achievementsProvider),
        ),
        data: (all) {
          if (all.isEmpty) {
            return _EmptyState();
          }

          final active = all.where((i) => !i.isDismissed).toList();
          final dismissed = all.where((i) => i.isDismissed).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                'Logros',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$monthTitle · ${all.length} medallas',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (active.isNotEmpty) ...[
                _SectionHeader(title: 'Activos', count: active.length),
                const SizedBox(height: 8),
                ...active.map((i) => _AchievementCard(insight: i)),
                const SizedBox(height: 20),
              ],
              if (dismissed.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Obtenidos anteriormente',
                  count: dismissed.length,
                ),
                const SizedBox(height: 8),
                ...dismissed.map((i) => _AchievementCard(insight: i, dimmed: true)),
              ],
              if (active.isEmpty && dismissed.isEmpty) _EmptyState(),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.insight, this.dimmed = false});
  final InsightModel insight;
  final bool dimmed;

  IconData get _icon => insight.type == 'streak'
      ? Icons.local_fire_department_rounded
      : Icons.emoji_events_rounded;

  Color _color(BuildContext context) {
    if (insight.type == 'streak') return Colors.deepOrange;
    return switch (insight.priority) {
      'critical' => const Color(0xFFFFD700), // gold
      'high' => const Color(0xFFC0C0C0),     // silver
      _ => const Color(0xFFCD7F32),           // bronze
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final theme = Theme.of(context);

    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(dimmed ? 10 : 20),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(dimmed ? 6 : 14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(30),
                border: Border.all(color: color.withAlpha(100), width: 1.5),
              ),
              child: Icon(_icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: dimmed ? theme.colorScheme.onSurface : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (insight.generatedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(insight.generatedAt!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color.withAlpha(160),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso.substring(0, 10.clamp(0, iso.length));
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Colors.amber.withAlpha(120),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin logros todavía',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sigue registrando tus gastos y manteniendo\ntus metas para desbloquear logros.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
