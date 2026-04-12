import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../providers/expenses_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/currency_format.dart';

// ── Filter state ──────────────────────────────────────────────────────────────

class _ExpenseFilter {
  const _ExpenseFilter({
    this.startDate,
    this.endDate,
    this.paymentMethod,
    this.selectedMonth,
    this.selectedCategoryId,
  });
  final DateTime? startDate;
  final DateTime? endDate;
  final String? paymentMethod;
  /// When set, filters the entire calendar month (overrides start/end).
  final DateTime? selectedMonth;
  final String? selectedCategoryId;

  bool get isActive =>
      startDate != null ||
      endDate != null ||
      paymentMethod != null ||
      selectedMonth != null ||
      selectedCategoryId != null;

  _ExpenseFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    DateTime? selectedMonth,
    String? selectedCategoryId,
    bool clearStart = false,
    bool clearEnd = false,
    bool clearMethod = false,
    bool clearMonth = false,
    bool clearCategory = false,
  }) {
    return _ExpenseFilter(
      startDate: clearStart ? null : (startDate ?? this.startDate),
      endDate: clearEnd ? null : (endDate ?? this.endDate),
      paymentMethod: clearMethod ? null : (paymentMethod ?? this.paymentMethod),
      selectedMonth: clearMonth ? null : (selectedMonth ?? this.selectedMonth),
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
    );
  }
}

final _expensesFilterProvider =
    StateProvider.autoDispose<_ExpenseFilter>((ref) => const _ExpenseFilter());

// ── Screen ────────────────────────────────────────────────────────────────────

class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  ConsumerState<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen> {
  bool _busy = false;

  String _formatMixedTotal(_CurrencyTotals totals) {
    if (totals.hnl > 0 && totals.usd > 0) {
      return '${currencyFmt('HNL').format(totals.hnl)} + ${currencyFmt('USD').format(totals.usd)}';
    }
    if (totals.usd > 0) {
      return currencyFmt('USD').format(totals.usd);
    }
    return currencyFmt('HNL').format(totals.hnl);
  }

  @override
  Widget build(BuildContext context) {
    final expAsync = ref.watch(expensesProvider);
    final filter = ref.watch(_expensesFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withAlpha(14),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.filter_list),
                  onPressed: _busy ? null : () => _showFilterSheet(context),
                  tooltip: 'Filtrar',
                ),
              ),
              if (filter.isActive)
                Positioned(
                  top: 8,
                  right: 14,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: expAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(error: e, onRetry: () => ref.invalidate(expensesProvider)),
        data: (expenses) {
          // Apply filter
          var filtered = expenses;
          if (filter.selectedMonth != null) {
            final m = filter.selectedMonth!;
            filtered = filtered.where((e) {
              final d = DateTime.parse(e.date);
              return d.year == m.year && d.month == m.month;
            }).toList();
          } else {
            if (filter.startDate != null) {
              filtered = filtered
                  .where((e) => !DateTime.parse(e.date).isBefore(filter.startDate!))
                  .toList();
            }
            if (filter.endDate != null) {
              filtered = filtered
                  .where((e) => !DateTime.parse(e.date)
                      .isAfter(filter.endDate!.add(const Duration(days: 1))))
                  .toList();
            }
          }
          if (filter.paymentMethod != null) {
            filtered = filtered.where((e) => e.paymentMethod == filter.paymentMethod).toList();
          }

          final categorySource = [...filtered];
          if (filter.selectedCategoryId != null) {
            filtered = filtered
                .where((e) => e.categoryId == filter.selectedCategoryId)
                .toList();
          }

          // Sort descending
          final sorted = [...filtered]..sort((a, b) => b.date.compareTo(a.date));
          final totalFiltered = _CurrencyTotals.fromExpenses(sorted);
          final now = DateTime.now();
          final monthLabel = DateFormat('MMMM yyyy', 'es').format(now);
          final monthTitle = monthLabel[0].toUpperCase() + monthLabel.substring(1);

          final byCategory = <String, _CategoryChipData>{};
          for (final e in categorySource) {
            final id = e.categoryId ?? e.categoryName;
            final prev = byCategory[id];
            byCategory[id] = _CategoryChipData(
              id: id,
              name: e.categoryName,
              total: (prev?.total ?? 0) + e.amount,
            );
          }
          final categoryChips = byCategory.values.toList()
            ..sort((a, b) => b.total.compareTo(a.total));

          // Build interleaved list: String = month header, ExpenseModel = row
          final monthFmt = DateFormat('MMMM yyyy', 'es');
          final List<dynamic> listItems = [];
          // Pre-compute per-month subtotals
          final Map<String, _CurrencyTotals> monthTotals = {};
          for (final e in sorted) {
            final key = DateFormat('yyyy-MM').format(DateTime.parse(e.date));
            monthTotals[key] = (monthTotals[key] ?? const _CurrencyTotals()).addExpense(e);
          }
          String? lastMonthKey;
          for (final e in sorted) {
            final d = DateTime.parse(e.date);
            final key = DateFormat('yyyy-MM').format(d);
            if (key != lastMonthKey) {
              final raw = monthFmt.format(d);
              listItems.add(_MonthHeader(
                label: raw[0].toUpperCase() + raw.substring(1),
                totals: monthTotals[key] ?? const _CurrencyTotals(),
              ));
              lastMonthKey = key;
            }
            listItems.add(e);
          }
          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    filter.isActive ? 'Sin resultados para este filtro' : 'No hay gastos registrados',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (filter.isActive) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.read(_expensesFilterProvider.notifier).state = const _ExpenseFilter(),
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(expensesProvider.future),
            child: CustomScrollView(
              slivers: [
                // Hero header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gastos',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$monthTitle · ${sorted.length} ${sorted.length == 1 ? 'movimiento' : 'movimientos'}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).shadowColor.withAlpha(14),
                                blurRadius: 20,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total gastado',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatMixedTotal(totalFiltered),
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.expense,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: const Text('Todos'),
                                  showCheckmark: false,
                                  side: BorderSide.none,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                  selectedColor: colorScheme.primary.withAlpha(24),
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: filter.selectedCategoryId == null
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  selected: filter.selectedCategoryId == null,
                                  onSelected: (_) {
                                    ref.read(_expensesFilterProvider.notifier).state =
                                        filter.copyWith(clearCategory: true);
                                  },
                                ),
                              ),
                              ...categoryChips.take(6).map((cat) {
                                final selected = filter.selectedCategoryId == cat.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(cat.name),
                                    showCheckmark: false,
                                    side: BorderSide.none,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                    selectedColor: colorScheme.primary.withAlpha(24),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    selected: selected,
                                    onSelected: (_) {
                                      ref.read(_expensesFilterProvider.notifier).state =
                                          filter.copyWith(selectedCategoryId: cat.id);
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final item = listItems[i];

                      // ── Month header ──────────────────────────────
                      if (item is _MonthHeader) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                item.label,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Divider(
                                  thickness: 1,
                                  color: Theme.of(context).colorScheme.primary.withAlpha(50),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formatMixedTotal(item.totals),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.expense.withAlpha(180),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // ── Expense row ───────────────────────────────
                      final e = item as ExpenseModel;
                      final isEmoji = e.categoryIcon.runes.any((r) => r > 127);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).shadowColor.withAlpha(14),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: _AnimatedItemEntry(
                            index: i,
                            child: Material(
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(22),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: _busy ? null : () => _showExpenseActionsSheet(context, e),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: AppColors.expense.withAlpha(20),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        alignment: Alignment.center,
                                        child: isEmoji
                                            ? Text(e.categoryIcon, style: const TextStyle(fontSize: 24))
                                            : Icon(
                                                materialIconFromString(e.categoryIcon),
                                                size: 24,
                                                color: AppColors.expense,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.description.isEmpty ? e.categoryName : e.description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${e.categoryName} · ${DateFormat('dd MMM', 'es').format(DateTime.parse(e.date))}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '-${currencyFmt(e.currency).format(e.amount)}',
                                        style: const TextStyle(
                                          color: AppColors.expense,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: listItems.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : () => context.go(AppRoutes.addExpense),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEditSheet(BuildContext context, ExpenseModel expense) async {
    if (_busy) return;
    setState(() => _busy = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EditExpenseSheet(
        expense: expense,
        onSaved: () => ref.invalidate(expensesProvider),
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _showExpenseActionsSheet(BuildContext context, ExpenseModel expense) async {
    if (_busy) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar gasto'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditSheet(context, expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: const Text('Eliminar gasto', style: TextStyle(color: AppColors.expense)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteExpense(context, expense);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteExpense(BuildContext context, ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text('¿Deseas eliminar este gasto? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('${ApiConstants.expenses}/${expense.id}');
      ref.invalidate(expensesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto eliminado')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    final dFmt = DateFormat('dd/MM/yyyy', 'en_US');
    DateTime? tmpStart = ref.read(_expensesFilterProvider).startDate;
    DateTime? tmpEnd = ref.read(_expensesFilterProvider).endDate;
    String? tmpMethod = ref.read(_expensesFilterProvider).paymentMethod;
    DateTime? tmpMonth = ref.read(_expensesFilterProvider).selectedMonth;
    String? tmpCategoryId = ref.read(_expensesFilterProvider).selectedCategoryId;

    const payMethods = <String, String>{
      'cash': 'Efectivo',
      'card_debit': 'Débito',
      'card_credit': 'Crédito',
      'transfer': 'Transferencia',
      'other': 'Otro',
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Filtrar gastos', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        tmpStart = null;
                        tmpEnd = null;
                        tmpMethod = null;
                        tmpMonth = null;
                        tmpCategoryId = null;
                      });
                    },
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Month quick-select ──────────────────────────────────────
              Text('Mes', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final now = DateTime.now();
                final mFmt = DateFormat('MMM yyyy', 'es');
                final months = List.generate(6, (i) => DateTime(now.year, now.month - i, 1));
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: months.map((m) {
                    final selected = tmpMonth != null &&
                        tmpMonth!.year == m.year &&
                        tmpMonth!.month == m.month;
                    final raw = mFmt.format(m);
                    final label = raw[0].toUpperCase() + raw.substring(1);
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        tmpMonth = v ? m : null;
                        if (v) { tmpStart = null; tmpEnd = null; }
                      }),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 16),
              // ── Custom date range ───────────────────────────────────────
              Text('Rango personalizado', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(tmpStart != null ? 'Desde: ${dFmt.format(tmpStart!)}' : 'Desde (fecha inicial)'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: tmpStart ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() { tmpStart = picked; tmpMonth = null; });
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(tmpEnd != null ? 'Hasta: ${dFmt.format(tmpEnd!)}' : 'Hasta (fecha final)'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: tmpEnd ?? DateTime.now(),
                    firstDate: tmpStart ?? DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() { tmpEnd = picked; tmpMonth = null; });
                },
              ),
              const SizedBox(height: 16),
              Text('Método de pago', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: payMethods.entries.map((entry) {
                  final selected = tmpMethod == entry.key;
                  return FilterChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (v) => setState(() => tmpMethod = v ? entry.key : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  ref.read(_expensesFilterProvider.notifier).state = _ExpenseFilter(
                    startDate: tmpMonth != null ? null : tmpStart,
                    endDate: tmpMonth != null ? null : tmpEnd,
                    paymentMethod: tmpMethod,
                    selectedMonth: tmpMonth,
                    selectedCategoryId: tmpCategoryId,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Aplicar filtros'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _busy = false);
  }
}

class _CategoryChipData {
  const _CategoryChipData({
    required this.id,
    required this.name,
    required this.total,
  });

  final String id;
  final String name;
  final double total;
}

class _AnimatedItemEntry extends StatelessWidget {
  const _AnimatedItemEntry({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.04).clamp(0.0, 0.55);
    final end = (start + 0.32).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Interval(start, end, curve: Curves.easeOutCubic),
      builder: (context, value, child) {
        final y = (1 - value) * 10;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, y), child: child),
        );
      },
      child: child,
    );
  }
}

// ── Month header data class ───────────────────────────────────────────────────

class _MonthHeader {
  const _MonthHeader({required this.label, required this.totals});
  final String label;
  final _CurrencyTotals totals;
}

class _CurrencyTotals {
  const _CurrencyTotals({this.hnl = 0, this.usd = 0});

  final double hnl;
  final double usd;

  _CurrencyTotals addExpense(ExpenseModel e) {
    final currency = e.currency.toUpperCase();
    if (currency == 'USD') {
      return _CurrencyTotals(hnl: hnl, usd: usd + e.amount);
    }
    return _CurrencyTotals(hnl: hnl + e.amount, usd: usd);
  }

  static _CurrencyTotals fromExpenses(List<ExpenseModel> expenses) {
    var totals = const _CurrencyTotals();
    for (final e in expenses) {
      totals = totals.addExpense(e);
    }
    return totals;
  }
}

// ── Edit Expense Sheet ────────────────────────────────────────────────────────

class _EditExpenseSheet extends ConsumerStatefulWidget {
  const _EditExpenseSheet({required this.expense, required this.onSaved});

  final ExpenseModel expense;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends ConsumerState<_EditExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountCtrl = TextEditingController(
    text: widget.expense.amount.toStringAsFixed(2),
  );
  late final _descCtrl = TextEditingController(text: widget.expense.description);
  late String? _selectedCategoryId = widget.expense.categoryId;
  late String _paymentMethod = widget.expense.paymentMethod;
  late DateTime _date = DateTime.parse(widget.expense.date);

  bool _saving = false;
  bool _deleting = false;

  static const _payMethods = {
    'cash': 'Efectivo',
    'card_debit': 'Tarjeta débito',
    'card_credit': 'Tarjeta crédito',
    'transfer': 'Transferencia',
    'other': 'Otro',
  };

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona una categoría')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final desc = _descCtrl.text.trim();
      await dio.patch('${ApiConstants.expenses}/${widget.expense.id}', data: {
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
        if (desc.isNotEmpty) 'description': desc,
        'categoryId': _selectedCategoryId,
        'paymentMethod': _paymentMethod,
        'date': DateFormat('yyyy-MM-dd').format(_date),
      });
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gasto actualizado')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text('¿Deseas eliminar este gasto? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('${ApiConstants.expenses}/${widget.expense.id}');
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gasto eliminado')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catAsync = ref.watch(categoriesProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final busy = _saving || _deleting;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Editar gasto', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: _deleting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Eliminar',
                    onPressed: busy ? null : _delete,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Monto', prefixText: 'L '),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
              ),
              const SizedBox(height: 16),
              catAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error al cargar categorías'),
                data: (cats) {
                  // Ensure value exists in list to avoid Flutter assertion error
                  final validId = cats.any((c) => c.id == _selectedCategoryId)
                      ? _selectedCategoryId
                      : null;
                  return DropdownButtonFormField<String>(
                    initialValue: validId,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    isExpanded: true,
                    items: cats.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(c.iconData, size: 18),
                          const SizedBox(width: 8),
                          Flexible(child: Text(
                            c.parentName != null ? '${c.parentName} › ${c.name}' : c.name,
                            overflow: TextOverflow.ellipsis,
                          )),
                        ],
                      ),
                    )).toList(),
                    onChanged: busy ? null : (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) => v == null ? 'Requerido' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Método de pago'),
                items: _payMethods.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => _paymentMethod = v ?? 'cash'),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: busy ? null : _pickDate,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
