import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class TrendData {
  const TrendData({required this.categoryName, required this.current, required this.previous, required this.changePercent});
  final String categoryName;
  final double current;
  final double previous;
  final double changePercent;

  factory TrendData.fromJson(Map<String, dynamic> j) => TrendData(
        categoryName: j['categoryName'] as String? ?? '',
        current: ((j['current'] ?? j['currentAmount']) as num? ?? 0).toDouble(),
        previous: ((j['previous'] ?? j['previousAmount']) as num? ?? 0).toDouble(),
        changePercent: ((j['changePercent'] ?? j['change']) as num? ?? 0).toDouble(),
      );
}

class AnomalyData {
  const AnomalyData({required this.categoryName, required this.currentWeek, required this.avgWeek, required this.zScore});
  final String categoryName;
  final double currentWeek;
  final double avgWeek;
  final double zScore;

  factory AnomalyData.fromJson(Map<String, dynamic> j) => AnomalyData(
        categoryName: j['categoryName'] as String? ?? '',
        currentWeek: ((j['currentWeek'] ?? j['current']) as num? ?? 0).toDouble(),
        avgWeek: ((j['avgWeek'] ?? j['average']) as num? ?? 0).toDouble(),
        zScore: (j['zScore'] as num? ?? 0).toDouble(),
      );
}

class CategorySummary {
  const CategorySummary({required this.name, required this.amount, required this.percentage});
  final String name;
  final double amount;
  final double percentage;

  factory CategorySummary.fromJson(Map<String, dynamic> j) => CategorySummary(
        name: j['name'] as String? ?? j['categoryName'] as String? ?? '',
        amount: double.parse((j['amount'] ?? j['total'] ?? 0).toString()),
        percentage: (j['percentage'] as num? ?? 0).toDouble(),
      );
}

class MethodSummaryItem {
  const MethodSummaryItem({required this.method, required this.amount, required this.percentage});
  final String method;
  final double amount;
  final double percentage;

  factory MethodSummaryItem.fromJson(Map<String, dynamic> j) => MethodSummaryItem(
        method: j['method'] as String? ?? '',
        amount: (j['amount'] as num? ?? 0).toDouble(),
        percentage: (j['percentage'] as num? ?? 0).toDouble(),
      );
}

class PaymentTrendMonth {
  const PaymentTrendMonth({
    required this.month,
    required this.cash,
    required this.cardDebit,
    required this.cardCredit,
  });
  final String month;
  final double cash;
  final double cardDebit;
  final double cardCredit;

  factory PaymentTrendMonth.fromJson(Map<String, dynamic> j) => PaymentTrendMonth(
        month: j['month'] as String? ?? '',
        cash: (j['cash'] as num? ?? 0).toDouble(),
        cardDebit: (j['card_debit'] as num? ?? 0).toDouble(),
        cardCredit: (j['card_credit'] as num? ?? 0).toDouble(),
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────
final trendsProvider = FutureProvider.autoDispose<List<TrendData>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.spendingTrends);
  final raw = resp.data;
  final items = (raw is List ? raw : (raw as Map<String, dynamic>?)?['items'] as List?) ?? [];
  return items.map((e) => TrendData.fromJson(e as Map<String, dynamic>)).toList();
});

final anomaliesProvider = FutureProvider.autoDispose<List<AnomalyData>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final resp = await dio.get('/analytics/anomalies');
    final items = resp.data as List<dynamic>? ?? [];
    return items.map((e) => AnomalyData.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

final expenseSummaryProvider = FutureProvider.autoDispose<List<CategorySummary>>((ref) async {
  final dio = ref.watch(dioProvider);
  // Default to current month
  final now = DateTime.now();
  final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  final lastDay = DateTime(now.year, now.month + 1, 0);
  final end =
      '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
  final resp = await dio.get(ApiConstants.expensesSummary,
      queryParameters: {'startDate': start, 'endDate': end});
  final data = resp.data as Map<String, dynamic>?;
  final cats = data?['categories'] as List<dynamic>? ?? [];
  final total = (data?['grandTotal'] as num? ?? 0).toDouble();
  return cats.map((e) {
    final m = e as Map<String, dynamic>;
    final amount = double.parse((m['amount'] ?? m['total'] ?? 0).toString());
    return CategorySummary(
      name: m['name'] as String? ?? m['categoryName'] as String? ?? '',
      amount: amount,
      percentage: total > 0 ? (amount / total * 100) : 0,
    );
  }).toList();
});

final methodSummaryProvider = FutureProvider.autoDispose<List<MethodSummaryItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final now = DateTime.now();
  final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  final lastDay = DateTime(now.year, now.month + 1, 0);
  final end =
      '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
  final resp = await dio.get(ApiConstants.expensesSummaryByMethod,
      queryParameters: {'startDate': start, 'endDate': end});
  final data = resp.data as Map<String, dynamic>?;
  final items = data?['breakdown'] as List<dynamic>? ?? [];
  return items
      .map((e) => MethodSummaryItem.fromJson(e as Map<String, dynamic>))
      .where((e) => e.amount > 0)
      .toList();
});

final paymentTrendsProvider = FutureProvider.autoDispose<List<PaymentTrendMonth>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.paymentMethodTrends);
  final items = resp.data as List<dynamic>? ?? [];
  return items.map((e) => PaymentTrendMonth.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Tendencias'),
            Tab(text: 'Anomalías'),
            Tab(text: 'Métodos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SummaryTab(),
          _TrendsTab(),
          _AnomaliesTab(),
          _MethodsTab(),
        ],
      ),
    );
  }
}

// ── Summary tab ───────────────────────────────────────────────────────────────
class _SummaryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(expenseSummaryProvider);
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cats) {
        if (cats.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aún no hay gastos este período',
                    style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('Agrega un gasto para ver el análisis', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }
        final total = cats.fold(0.0, (s, c) => s + c.amount);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(expenseSummaryProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Pie chart
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: cats.take(6).toList().asMap().entries.map((e) {
                      final color = AppColors.categoryPalette[e.key % AppColors.categoryPalette.length];
                      return PieChartSectionData(
                        color: color,
                        value: e.value.amount,
                        title: '${e.value.percentage.toStringAsFixed(0)}%',
                        radius: 60,
                        titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Total: ${fmt.format(total)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              // Category list
              ...cats.asMap().entries.map((e) {
                final color = AppColors.categoryPalette[e.key % AppColors.categoryPalette.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value.name, style: const TextStyle(fontSize: 13))),
                      Text(fmt.format(e.value.amount),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('${e.value.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ── Trends tab ────────────────────────────────────────────────────────────────
class _TrendsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(trendsProvider);
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);

    return trendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (trends) {
        if (trends.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Sin datos de tendencias',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Las tendencias comparan cuánto gastaste en cada categoría en el período actual vs el anterior. Registra gastos durante dos períodos para verlas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        final hasPreviousData = trends.any((t) => t.previous > 0);

        // Build bar chart data
        final items = trends.take(6).toList();
        final maxVal = items.fold(0.0, (m, t) => [m, t.current, t.previous].reduce((a, b) => a > b ? a : b));

        final barGroups = items.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.previous,
                color: AppColors.neutral.withAlpha(120),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: e.value.current,
                color: AppColors.primary,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList();

        // Truncate labels to 10 chars max for readability
        final labels = items
            .map((t) => t.categoryName.length > 10
                ? '${t.categoryName.substring(0, 9)}…'
                : t.categoryName)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Explanation banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasPreviousData
                          ? 'Comparación de gastos por categoría: período actual (azul) vs el período anterior (gris).'
                          : 'Aún no hay datos del período anterior. Cuando empiece el próximo período, verás la comparación aquí.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Período actual vs. previo',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal * 1.25 : 100,
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= labels.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[i],
                              style: const TextStyle(fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (v, _) => Text(
                          'L ${v.toInt()}',
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Legend(color: AppColors.neutral.withAlpha(120), label: 'Período anterior'),
                const SizedBox(width: 16),
                _Legend(color: AppColors.primary, label: 'Período actual'),
              ],
            ),
            const SizedBox(height: 24),
            Text('Detalle por categoría',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...trends.map((t) {
              final isUp = t.changePercent > 0;
              final isNew = t.previous == 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.categoryName,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              isNew
                                  ? 'Actual: ${fmt.format(t.current)}  ·  Sin período anterior'
                                  : 'Actual: ${fmt.format(t.current)}  ·  Anterior: ${fmt.format(t.previous)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Nuevo',
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUp ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isUp ? AppColors.expense : AppColors.income,
                              size: 16,
                            ),
                            Text(
                              '${t.changePercent.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: isUp ? AppColors.expense : AppColors.income,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}

// ── Anomalies tab ─────────────────────────────────────────────────────────────
class _AnomaliesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anomAsync = ref.watch(anomaliesProvider);
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);

    return anomAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Sin datos de anomalías')),
      data: (anomalies) => anomalies.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: AppColors.riskGreen),
                  SizedBox(height: 16),
                  Text('¡Sin anomalías detectadas!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Las anomalías aparecen cuando un gasto en una categoría sube mucho respecto a tu promedio semanal. A medida que registres más gastos, este análisis se vuelve más preciso.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: anomalies.length,
              itemBuilder: (_, i) {
                final a = anomalies[i];
                final severity = a.zScore > 2.5 ? 'Alta' : 'Media';
                final color = a.zScore > 2.5 ? AppColors.error : AppColors.warning;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            severity,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.categoryName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                'Esta semana: ${fmt.format(a.currentWeek)} · Promedio: ${fmt.format(a.avgWeek)}',
                                style: TextStyle(
                                    fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Methods tab ───────────────────────────────────────────────────────────────

const _methodLabels = <String, String>{
  'cash': 'Efectivo',
  'card_debit': 'Débito',
  'card_credit': 'Crédito',
  'transfer': 'Transf.',
  'other': 'Otro',
};

const _methodColors = <String, Color>{
  'cash': Color(0xFF4CAF50),
  'card_debit': Color(0xFF2196F3),
  'card_credit': Color(0xFFFF9800),
  'transfer': Color(0xFF9C27B0),
  'other': Color(0xFF9E9E9E),
};

class _MethodsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodAsync = ref.watch(methodSummaryProvider);
    final trendsAsync = ref.watch(paymentTrendsProvider);
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(methodSummaryProvider.future);
        ref.refresh(paymentTrendsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Section 1: Distribution this month ──
          Text('Distribución este mes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          methodAsync.when(
            loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.credit_card_off_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Sin gastos este mes', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }
              final total = items.fold(0.0, (s, i) => s + i.amount);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 45,
                        sections: items.asMap().entries.map((e) {
                          final color = _methodColors[e.value.method] ?? const Color(0xFF9E9E9E);
                          return PieChartSectionData(
                            color: color,
                            value: e.value.amount,
                            title: '${e.value.percentage.toStringAsFixed(0)}%',
                            radius: 65,
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Total: ${fmt.format(total)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...items.map((item) {
                    final color = _methodColors[item.method] ?? const Color(0xFF9E9E9E);
                    final label = _methodLabels[item.method] ?? item.method;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(label, style: const TextStyle(fontSize: 13))),
                          Text(fmt.format(item.amount),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(
                            '${item.percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          // ── Section 2: 6-month trend ──
          Text('Últimos 6 meses',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          trendsAsync.when(
            loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (months) {
              if (months.isEmpty) return const SizedBox.shrink();

              final maxVal = months.fold(0.0, (m, t) {
                final v = [t.cash, t.cardDebit, t.cardCredit].reduce((a, b) => a > b ? a : b);
                return v > m ? v : m;
              });

              final barGroups = months.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.cash,
                      color: _methodColors['cash']!,
                      width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                    BarChartRodData(
                      toY: e.value.cardDebit,
                      color: _methodColors['card_debit']!,
                      width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                    BarChartRodData(
                      toY: e.value.cardCredit,
                      color: _methodColors['card_credit']!,
                      width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ],
                );
              }).toList();

              // Short month labels: "Jan", "Feb", etc.
              final labels = months.map((m) {
                final parts = m.month.split('-');
                if (parts.length < 2) return m.month;
                final monthNum = int.tryParse(parts[1]) ?? 1;
                const abbr = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                return abbr[monthNum];
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxVal > 0 ? maxVal * 1.3 : 100,
                        barGroups: barGroups,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= labels.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(labels[i], style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (v, _) => Text(
                                'L ${v.toInt()}',
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Legend(color: _methodColors['cash']!, label: 'Efectivo'),
                      const SizedBox(width: 14),
                      _Legend(color: _methodColors['card_debit']!, label: 'Débito'),
                      const SizedBox(width: 14),
                      _Legend(color: _methodColors['card_credit']!, label: 'Crédito'),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
