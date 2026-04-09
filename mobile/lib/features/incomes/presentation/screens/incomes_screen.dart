import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';

class IncomeModel {
  const IncomeModel({
    required this.id,
    required this.sourceName,
    required this.amount,
    required this.type,
    required this.cycle,
    required this.isActive,
  });

  final String id;
  final String sourceName;
  final double amount;
  final String type;
  final String cycle;
  final bool isActive;

  factory IncomeModel.fromJson(Map<String, dynamic> j) => IncomeModel(
        id: j['id'] as String,
        sourceName: j['sourceName'] as String? ?? j['name'] as String? ?? '',
        // Backend may return numeric fields as strings (e.g. "5000.00")
        amount: double.parse((j['amount'] ?? j['estimatedAmount'] ?? 0).toString()),
        type: j['type'] as String? ?? 'salary',
        cycle: j['cycle'] as String? ?? 'monthly',
        isActive: j['isActive'] as bool? ?? true,
      );
}

final incomesProvider = FutureProvider.autoDispose<List<IncomeModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.incomes);
  final items = resp.data as List<dynamic>? ?? [];
  return items.map((e) => IncomeModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class IncomesScreen extends ConsumerWidget {
  const IncomesScreen({super.key});

  static const _cycleLabels = {
    'weekly': 'Semanal',
    'biweekly': 'Quincenal',
    'monthly': 'Mensual',
    'one_time': 'Único',
  };

  static const _typeLabels = {
    'salary': 'Salario',
    'variable': 'Variable',
    'remittance': 'Remesa',
    'freelance': 'Freelance',
    'other': 'Otro',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomesAsync = ref.watch(incomesProvider);
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ');

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Ingresos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIncomeSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: incomesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (incomes) => incomes.isEmpty
            ? const Center(child: Text('No tienes ingresos configurados.\nToca + para agregar uno.', textAlign: TextAlign.center))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(incomesProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: incomes.length,
                  itemBuilder: (_, i) {
                    final inc = incomes[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          child: Icon(Icons.attach_money,
                              color: Theme.of(context).colorScheme.onSecondaryContainer),
                        ),
                        title: Text(inc.sourceName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${_typeLabels[inc.type] ?? inc.type} · ${_cycleLabels[inc.cycle] ?? inc.cycle}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fmt.format(inc.amount),
                              style: const TextStyle(
                                  color: AppColors.income, fontWeight: FontWeight.bold),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditIncomeSheet(context, ref, inc);
                                } else if (value == 'delete') {
                                  _confirmDelete(context, ref, inc);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')])),
                                PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.expense), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: AppColors.expense))])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _showAddIncomeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IncomeSheet(onSaved: () => ref.invalidate(incomesProvider)),
    );
  }

  void _showEditIncomeSheet(BuildContext context, WidgetRef ref, IncomeModel inc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IncomeSheet(
        existing: inc,
        onSaved: () => ref.invalidate(incomesProvider),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, IncomeModel inc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ingreso'),
        content: Text('¿Eliminar "${inc.sourceName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('${ApiConstants.incomes}/${inc.id}');
      ref.invalidate(incomesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─── Income Sheet (Add + Edit) ────────────────────────────────────────────────

class _IncomeSheet extends ConsumerStatefulWidget {
  const _IncomeSheet({required this.onSaved, this.existing});
  final VoidCallback onSaved;
  final IncomeModel? existing;

  @override
  ConsumerState<_IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends ConsumerState<_IncomeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late String _type;
  late String _cycle;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  static const _types = ['salary', 'variable', 'remittance', 'freelance', 'other'];
  static const _typeLabels = ['Salario', 'Variable', 'Remesa', 'Freelance', 'Otro'];
  static const _cycles = ['weekly', 'biweekly', 'monthly'];
  static const _cycleLabels = ['Semanal', 'Quincenal', 'Mensual'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.sourceName ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _type = e?.type ?? 'salary';
    _cycle = e?.cycle ?? 'monthly';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final body = {
        'sourceName': _nameCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
        'type': _type,
        'cycle': _cycle,
      };
      if (_isEditing) {
        await dio.patch('${ApiConstants.incomes}/${widget.existing!.id}', data: body);
      } else {
        await dio.post(ApiConstants.incomes, data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditing ? 'Editar ingreso' : 'Nuevo ingreso',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Fuente de ingreso', prefixIcon: Icon(Icons.work_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto estimado', prefixText: 'L '),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: List.generate(_types.length,
                  (i) => DropdownMenuItem(value: _types[i], child: Text(_typeLabels[i]))),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _cycle,
              decoration: const InputDecoration(labelText: 'Frecuencia'),
              items: List.generate(_cycles.length,
                  (i) => DropdownMenuItem(value: _cycles[i], child: Text(_cycleLabels[i]))),
              onChanged: (v) => setState(() => _cycle = v!),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
