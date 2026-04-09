import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../expenses/providers/expenses_provider.dart';

class BudgetModel {
  const BudgetModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.spent,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.periodType,
    required this.periodStart,
    required this.percentage,
  });

  final String id;
  final String name;
  final double amount;
  final double spent;
  final String? categoryId;
  final String categoryName;
  final String categoryIcon;
  final String periodType;
  final DateTime periodStart;
  final double percentage;

  double get usedPct => amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => spent > amount;

  static double _d(dynamic v) =>
      v == null ? 0.0 : v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

  factory BudgetModel.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    final psRaw = j['periodStart'] as String?;
    return BudgetModel(
      id: j['id'] as String,
      name: j['name'] as String,
      amount: _d(j['amount'] ?? j['limitAmount']),
      spent: _d(j['spent']),
      categoryId: cat?['id'] as String?,
      categoryName: cat?['name'] as String? ?? j['categoryName'] as String? ?? '',
      categoryIcon: cat?['icon'] as String? ?? j['categoryIcon'] as String? ?? 'category',
      periodType: j['periodType'] as String? ?? j['period'] as String? ?? 'monthly',
      periodStart: psRaw != null ? DateTime.parse(psRaw) : DateTime.now(),
      percentage: _d(j['percentage']),
    );
  }
}

final budgetsProvider = FutureProvider.autoDispose<List<BudgetModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.budgets);
  final items = resp.data as List<dynamic>? ?? [];
  return items.map((e) => BudgetModel.fromJson(e as Map<String, dynamic>)).toList();
});

// â”€â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ');

    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _showAddBudgetSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (budgets) => budgets.isEmpty
            ? const Center(
                child: Text(
                  'No tienes presupuestos.\nToca + para crear uno.',
                  textAlign: TextAlign.center,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(budgetsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: budgets.length,
                  itemBuilder: (_, i) {
                    final b = budgets[i];
                    final pctLabel = '${(b.usedPct * 100).toStringAsFixed(0)}%';
                    final barColor = b.isOverBudget
                        ? AppColors.riskRed
                        : b.usedPct > 0.8
                            ? AppColors.riskYellow
                            : AppColors.riskGreen;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _busy ? null : () => _showEditBudgetSheet(context, b),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(materialIconFromString(b.categoryIcon), size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(b.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  Text(
                                    pctLabel,
                                    style: TextStyle(
                                        color: barColor, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade500),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: b.usedPct,
                                  minHeight: 8,
                                  color: barColor,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surfaceContainerHighest,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Gastado: ${fmt.format(b.spent)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Límite: ${fmt.format(b.amount)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _showAddBudgetSheet(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddBudgetSheet(onSaved: () => ref.invalidate(budgetsProvider)),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _showEditBudgetSheet(BuildContext context, BudgetModel budget) async {
    if (_busy) return;
    setState(() => _busy = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditBudgetSheet(
        budget: budget,
        onSaved: () => ref.invalidate(budgetsProvider),
      ),
    );
    if (mounted) setState(() => _busy = false);
  }
}

// â”€â”€â”€ Add Budget Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AddBudgetSheet extends ConsumerStatefulWidget {
  const _AddBudgetSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _periodType = 'monthly';
  String? _categoryId;
  DateTime _periodStart = DateTime.now();
  bool _saving = false;

  static const _errorTranslations = <String, String>{
    'A budget for this category and period type already exists':
        'Ya existe un presupuesto para esta categoría y período',
    'budget already exists': 'Ya existe un presupuesto para esta categoría y período',
  };

  static String _extractErrorMessage(Object e) {
    try {
      // DioException with response data
      final dynamic err = (e as dynamic).response?.data;
      if (err is Map) {
        final msg = err['message'];
        String? raw;
        if (msg is Map) raw = msg['message']?.toString();
        if (msg is String) raw = msg;
        final nested = err['error'];
        if (raw == null && nested is String) raw = nested;
        if (raw != null) {
          return _errorTranslations[raw] ?? raw;
        }
      }
    } catch (_) {}
    return e.toString();
  }

  static const _periods = ['weekly', 'biweekly', 'monthly'];
  static const _periodLabels = ['Semanal', 'Quincenal', 'Mensual'];

  DateTime get _periodEnd {
    return switch (_periodType) {
      'weekly' => _periodStart.add(const Duration(days: 7)),
      'biweekly' => _periodStart.add(const Duration(days: 14)),
      _ => DateTime(_periodStart.year, _periodStart.month + 1, _periodStart.day),
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _periodStart = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una categoría')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiConstants.budgets, data: {
        'name': _nameCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
        'periodType': _periodType,
        'periodStart': _periodStart.toIso8601String().split('T')[0],
        'periodEnd': _periodEnd.toIso8601String().split('T')[0],
        'categoryId': _categoryId,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final msg = _extractErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final categoriesAsync = ref.watch(categoriesProvider);
    final fmt = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nuevo presupuesto', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del presupuesto'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Límite', prefixText: 'L '),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const SizedBox.shrink(),
                data: (cats) => DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  isExpanded: true,
                  items: cats.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(c.iconData, size: 18),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _periodType,
                decoration: const InputDecoration(labelText: 'Período'),
                items: List.generate(_periods.length,
                    (i) => DropdownMenuItem(value: _periods[i], child: Text(_periodLabels[i]))),
                onChanged: (v) => setState(() => _periodType = v!),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Inicio: ${fmt.format(_periodStart)}'),
                subtitle: Text('Fin: ${fmt.format(_periodEnd)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ── Edit Budget Sheet ─────────────────────────────────────────────────────────

class _EditBudgetSheet extends ConsumerStatefulWidget {
  const _EditBudgetSheet({required this.budget, required this.onSaved});
  final BudgetModel budget;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends ConsumerState<_EditBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.budget.name);
  late final _amountCtrl = TextEditingController(
    text: widget.budget.amount.toStringAsFixed(2),
  );
  late String _periodType = widget.budget.periodType;
  late String? _categoryId = widget.budget.categoryId;
  late DateTime _periodStart = widget.budget.periodStart;
  bool _saving = false;
  bool _deleting = false;

  static const _errorTranslations = <String, String>{
    'A budget for this category and period type already exists':
        'Ya existe un presupuesto para esta categoría y período',
    'budget already exists': 'Ya existe un presupuesto para esta categoría y período',
  };

  static String _extractErrorMessage(Object e) {
    try {
      final dynamic err = (e as dynamic).response?.data;
      if (err is Map) {
        final msg = err['message'];
        String? raw;
        if (msg is Map) raw = msg['message']?.toString();
        if (msg is String) raw = msg;
        final nested = err['error'];
        if (raw == null && nested is String) raw = nested;
        if (raw != null) return _errorTranslations[raw] ?? raw;
      }
    } catch (_) {}
    return e.toString();
  }

  static const _periods = ['weekly', 'biweekly', 'monthly'];
  static const _periodLabels = ['Semanal', 'Quincenal', 'Mensual'];

  DateTime get _periodEnd {
    return switch (_periodType) {
      'weekly' => _periodStart.add(const Duration(days: 7)),
      'biweekly' => _periodStart.add(const Duration(days: 14)),
      _ => DateTime(_periodStart.year, _periodStart.month + 1, _periodStart.day),
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) setState(() => _periodStart = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoría')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('${ApiConstants.budgets}/${widget.budget.id}', data: {
        'name': _nameCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
        'periodType': _periodType,
        'periodStart': _periodStart.toIso8601String().split('T')[0],
        'periodEnd': _periodEnd.toIso8601String().split('T')[0],
        'categoryId': _categoryId,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_extractErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar presupuesto'),
        content: Text('¿Deseas eliminar "${widget.budget.name}"? Esta acción no se puede deshacer.'),
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
      await dio.delete('${ApiConstants.budgets}/${widget.budget.id}');
      widget.onSaved();
      if (mounted) Navigator.pop(context);
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final categoriesAsync = ref.watch(categoriesProvider);
    final fmt = DateFormat('dd/MM/yyyy');
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
                  Text('Editar presupuesto', style: Theme.of(context).textTheme.titleLarge),
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
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del presupuesto'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Límite', prefixText: 'L '),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const SizedBox.shrink(),
                data: (cats) {
                  final validId = cats.any((c) => c.id == _categoryId) ? _categoryId : null;
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
                          Text(c.name),
                        ],
                      ),
                    )).toList(),
                    onChanged: busy ? null : (v) => setState(() => _categoryId = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _periodType,
                decoration: const InputDecoration(labelText: 'Período'),
                items: List.generate(_periods.length,
                    (i) => DropdownMenuItem(value: _periods[i], child: Text(_periodLabels[i]))),
                onChanged: busy ? null : (v) => setState(() => _periodType = v!),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Inicio: ${fmt.format(_periodStart)}'),
                subtitle: Text('Fin: ${fmt.format(_periodEnd)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: busy ? null : _pickDate,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}