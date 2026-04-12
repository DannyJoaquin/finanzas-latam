import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/currency_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../expenses/providers/expenses_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _SimResult {
  const _SimResult({
    required this.currentMonthlyAvg,
    required this.projectedSavings,
    required this.annualSavings,
  });
  final double currentMonthlyAvg;
  final double projectedSavings;
  final double annualSavings;

  factory _SimResult.fromJson(Map<String, dynamic> j) => _SimResult(
        currentMonthlyAvg: (j['currentMonthlyAvg'] as num? ?? 0).toDouble(),
        projectedSavings: (j['projectedSavings'] as num? ?? 0).toDouble(),
        annualSavings: (j['annualSavings'] as num? ?? 0).toDouble(),
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SimulatorScreen extends ConsumerStatefulWidget {
  const SimulatorScreen({super.key});

  @override
  ConsumerState<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends ConsumerState<SimulatorScreen> {
  CategoryOption? _selectedCategory;
  double _reductionPct = 20;
  _SimResult? _result;
  bool _loading = false;
  String? _error;

  Future<void> _simulate() async {
    if (_selectedCategory == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get(
        ApiConstants.simulation,
        queryParameters: {
          'categoryId': _selectedCategory!.id,
          'reductionPct': _reductionPct.toStringAsFixed(0),
        },
      );
      setState(() {
        _result = _SimResult.fromJson(resp.data as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo calcular la simulación. Intenta más tarde.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catAsync = ref.watch(categoriesProvider);
    final fmt = ref.watch(currencyFmtProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de Ahorro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '¿Cuánto ahorrarías si redujeras tus gastos en una categoría?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Category selector
            Text('Categoría', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            catAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error cargando categorías: $e',
                  style: const TextStyle(color: AppColors.error)),
              data: (cats) => DropdownButtonFormField<CategoryOption>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  hintText: 'Selecciona una categoría',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: cats
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
            ),

            const SizedBox(height: 24),

            // Reduction slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reducción', style: theme.textTheme.labelLarge),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_reductionPct.toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _reductionPct,
              min: 5,
              max: 80,
              divisions: 15,
              label: '${_reductionPct.toInt()}%',
              onChanged: (v) => setState(() => _reductionPct = v),
            ),

            const SizedBox(height: 24),

            // Simulate button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedCategory == null || _loading ? null : _simulate,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.calculate_outlined),
                label: Text(_loading ? 'Calculando...' : 'Simular'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],

            // Results
            if (_result != null) ...[
              const SizedBox(height: 32),
              _ResultCard(result: _result!, fmt: fmt),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.fmt});
  final _SimResult result;
  final dynamic fmt; // NumberFormat

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resultados', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _MetricTile(
          icon: Icons.trending_down_outlined,
          iconColor: AppColors.expense,
          label: 'Gasto mensual actual',
          value: fmt.format(result.currentMonthlyAvg),
        ),
        const Divider(height: 1),
        _MetricTile(
          icon: Icons.savings_outlined,
          iconColor: AppColors.success,
          label: 'Ahorro mensual proyectado',
          value: fmt.format(result.projectedSavings),
          highlight: true,
        ),
        const Divider(height: 1),
        _MetricTile(
          icon: Icons.emoji_events_outlined,
          iconColor: const Color(0xFFFF9800),
          label: 'Ahorro anual estimado',
          value: fmt.format(result.annualSavings),
          highlight: true,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.success.withOpacity(0.06)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }
}
