import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';

class GoalModel {
  const GoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.status,
    required this.icon,
  });

  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? targetDate;
  final String status;
  final String icon;

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remaining => (targetAmount - currentAmount).clamp(0.0, double.infinity);

  factory GoalModel.fromJson(Map<String, dynamic> j) => GoalModel(
        id: j['id'] as String,
        name: j['name'] as String,
        // Backend may return numeric fields as strings (e.g. "5000.00")
        targetAmount: double.parse((j['targetAmount'] ?? 0).toString()),
        currentAmount: double.parse((j['currentAmount'] ?? 0).toString()),
        // backend uses 'targetDate', fallback 'deadline'
        targetDate: j['targetDate'] as String? ?? j['deadline'] as String?,
        status: j['status'] as String? ?? 'active',
        icon: j['icon'] as String? ?? '🎯',
      );
}

final goalsProvider = FutureProvider.autoDispose<List<GoalModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.goals);
  final items = resp.data as List<dynamic>? ?? [];
  return items.map((e) => GoalModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ');

    return Scaffold(
      appBar: AppBar(title: const Text('Metas de ahorro')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) => goals.isEmpty
            ? const Center(
                child: Text(
                  'No tienes metas de ahorro.\nToca + para crear una.',
                  textAlign: TextAlign.center,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(goalsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: goals.length,
                  itemBuilder: (_, i) {
                    final g = goals[i];
                    final pctLabel = '${(g.progress * 100).toStringAsFixed(0)}%';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(g.icon == '' || g.icon.isEmpty ? '🎯' : g.icon,
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      if (g.targetDate != null && g.targetDate!.isNotEmpty)
                                        Text(
                                          'Meta: ${g.targetDate}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  pctLabel,
                                  style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditGoalSheet(context, ref, g);
                                    } else if (value == 'delete') {
                                      _confirmDeleteGoal(context, ref, g);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')])),
                                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.expense), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: AppColors.expense))])),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: g.progress,
                                minHeight: 10,
                                color: AppColors.secondary,
                                backgroundColor:
                                    Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Ahorrado: ${fmt.format(g.currentAmount)}',
                                    style: const TextStyle(fontSize: 12)),
                                Text('Falta: ${fmt.format(g.remaining)}',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => _showContributeDialog(context, ref, g),
                                icon: const Icon(Icons.savings_outlined, size: 16),
                                label: const Text('Abonar'),
                              ),
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

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(onSaved: () => ref.invalidate(goalsProvider)),
    );
  }

  void _showEditGoalSheet(BuildContext context, WidgetRef ref, GoalModel g) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(
        existing: g,
        onSaved: () => ref.invalidate(goalsProvider),
      ),
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, WidgetRef ref, GoalModel g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: Text('¿Eliminar "${g.name}"? Los abonos registrados se perderán.'),
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
      await dio.delete('${ApiConstants.goals}/${g.id}');
      ref.invalidate(goalsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showContributeDialog(BuildContext context, WidgetRef ref, GoalModel goal) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abonar a "${goal.name}"'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto', prefixText: 'L '),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (amount == null || amount <= 0) return;
              try {
                final dio = ref.read(dioProvider);
                await dio.post('${ApiConstants.goals}/${goal.id}/contribute',
                    data: {'amount': amount});
                ref.invalidate(goalsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Abonar'),
          ),
        ],
      ),
    );
  }
}

// ─── Goal Sheet (Add + Edit) ─────────────────────────────────────────────────

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({required this.onSaved, this.existing});
  final VoidCallback onSaved;
  final GoalModel? existing;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _iconCtrl;
  DateTime? _targetDate;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.targetAmount.toStringAsFixed(2) : '');
    _iconCtrl = TextEditingController(text: e?.icon ?? '🎯');
    if (e?.targetDate != null && e!.targetDate!.isNotEmpty) {
      _targetDate = DateTime.tryParse(e.targetDate!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'targetAmount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
      };
      if (_iconCtrl.text.trim().isNotEmpty) body['icon'] = _iconCtrl.text.trim();
      if (_targetDate != null) body['targetDate'] = _targetDate!.toIso8601String().split('T')[0];
      if (_isEditing) {
        await dio.patch('${ApiConstants.goals}/${widget.existing!.id}', data: body);
      } else {
        await dio.post(ApiConstants.goals, data: body);
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
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditing ? 'Editar meta' : 'Nueva meta de ahorro',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de la meta'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto objetivo', prefixText: 'L '),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _iconCtrl,
              decoration: const InputDecoration(labelText: 'Ícono (emoji)', hintText: '🎯'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_targetDate == null
                  ? 'Fecha límite (opcional)'
                  : 'Fecha límite: ${dateFmt.format(_targetDate!)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Guardar cambios' : 'Crear meta'),
            ),
          ],
        ),
      ),
    );
  }
}
