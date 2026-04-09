import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../providers/expenses_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';

// ── Filter state ──────────────────────────────────────────────────────────────

class _ExpenseFilter {
  const _ExpenseFilter({this.startDate, this.endDate});
  final DateTime? startDate;
  final DateTime? endDate;
  bool get isActive => startDate != null || endDate != null;
  _ExpenseFilter copyWith({DateTime? startDate, DateTime? endDate, bool clearStart = false, bool clearEnd = false}) {
    return _ExpenseFilter(
      startDate: clearStart ? null : (startDate ?? this.startDate),
      endDate: clearEnd ? null : (endDate ?? this.endDate),
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

  @override
  Widget build(BuildContext context) {
    final expAsync = ref.watch(expensesProvider);
    final filter = ref.watch(_expensesFilterProvider);
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ');
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _busy ? null : () => _showFilterSheet(context),
                tooltip: 'Filtrar',
              ),
              if (filter.isActive)
                Positioned(
                  top: 8,
                  right: 8,
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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          // Apply filter
          var filtered = expenses;
          if (filter.startDate != null) {
            filtered = filtered
                .where((e) =>
                    !DateTime.parse(e.date)
                        .isBefore(filter.startDate!))
                .toList();
          }
          if (filter.endDate != null) {
            filtered = filtered
                .where((e) =>
                    !DateTime.parse(e.date)
                        .isAfter(filter.endDate!.add(const Duration(days: 1))))
                .toList();
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = filtered[i];
                final isEmoji = e.categoryIcon.runes.any((r) => r > 127);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.expense.withAlpha(20),
                    child: isEmoji
                        ? Text(e.categoryIcon)
                        : Icon(
                            materialIconFromString(e.categoryIcon),
                            size: 20,
                            color: AppColors.expense,
                          ),
                  ),
                  title: Text(
                    e.description.isEmpty ? e.categoryName : e.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${e.categoryName} · ${DateFormat('dd MMM', 'en_US').format(DateTime.parse(e.date))}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '-${fmt.format(e.amount)}',
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _busy ? null : () => _showEditSheet(context, e),
                );
              },
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

  Future<void> _showFilterSheet(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    final dFmt = DateFormat('dd/MM/yyyy', 'en_US');
    DateTime? tmpStart = ref.read(_expensesFilterProvider).startDate;
    DateTime? tmpEnd = ref.read(_expensesFilterProvider).endDate;

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
                      });
                    },
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  if (picked != null) setState(() => tmpStart = picked);
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
                  if (picked != null) setState(() => tmpEnd = picked);
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  ref.read(_expensesFilterProvider.notifier).state =
                      _ExpenseFilter(startDate: tmpStart, endDate: tmpEnd);
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
                    value: validId,
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
                value: _paymentMethod,
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
