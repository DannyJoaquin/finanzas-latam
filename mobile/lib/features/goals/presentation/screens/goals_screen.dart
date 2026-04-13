import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/currency_format.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../../../core/providers/experience_provider.dart';

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
    final fmt = ref.watch(currencyFmtProvider);
    final isSimple = ref.watch(isSimpleModeProvider);
    final monthRaw = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    final monthTitle = monthRaw[0].toUpperCase() + monthRaw.substring(1);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(error: e, onRetry: () => ref.invalidate(goalsProvider)),
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
                  itemCount: goals.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final totalTarget = goals.fold<double>(0, (s, g) => s + g.targetAmount);
                      final totalSaved = goals.fold<double>(0, (s, g) => s + g.currentAmount);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metas',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$monthTitle · ${goals.length} ${goals.length == 1 ? 'meta' : 'metas'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Container(
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
                                    'Ahorro acumulado',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${fmt.format(totalSaved)} / ${fmt.format(totalTarget)}',
                                    style: (isSimple
                                            ? Theme.of(context).textTheme.headlineMedium
                                            : Theme.of(context).textTheme.headlineSmall)
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${goals.length} metas activas',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final g = goals[i - 1];
                    final pctLabel = '${(g.progress * 100).toStringAsFixed(0)}%';
                    final itemRadius = isSimple ? 24.0 : 22.0;
                    final iconSize = isSimple ? 60.0 : 50.0;

                    return Padding(
                      padding: EdgeInsets.only(bottom: isSimple ? 16 : 14),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(itemRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor.withAlpha(14),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _AnimatedCardEntry(
                          index: i,
                          child: Material(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(itemRadius),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(itemRadius),
                              onTap: () => _showGoalActionsSheet(context, ref, g),
                              child: Padding(
                                padding: EdgeInsets.all(isSimple ? 20 : 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: iconSize,
                                          height: iconSize,
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary.withAlpha(18),
                                            borderRadius: BorderRadius.circular(isSimple ? 18 : 16),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            g.icon == '' || g.icon.isEmpty ? '🎯' : g.icon,
                                            style: TextStyle(fontSize: isSimple ? 32 : 26),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(g.name,
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: isSimple ? 22 : 18)),
                                              if (g.targetDate != null && g.targetDate!.isNotEmpty)
                                                Text(
                                                  'Meta: ${g.targetDate}',
                                                  style: TextStyle(
                                                    fontSize: isSimple ? 13 : 11,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          pctLabel,
                                          style: TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: isSimple ? 22 : 18,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.chevron_right, size: 18,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: g.progress,
                                        minHeight: isSimple ? 12 : 10,
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
                                            style: TextStyle(
                                                fontSize: isSimple ? 14 : 12,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                        Text('Falta: ${fmt.format(g.remaining)}',
                                            style: TextStyle(
                                                fontSize: isSimple ? 14 : 12,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                            ),
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

  void _showGoalActionsSheet(BuildContext context, WidgetRef ref, GoalModel g) {
    showModalBottomSheet(
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
              title: const Text('Editar meta'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditGoalSheet(context, ref, g);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: const Text('Eliminar meta', style: TextStyle(color: AppColors.expense)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteGoal(context, ref, g);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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

class _AnimatedCardEntry extends StatelessWidget {
  const _AnimatedCardEntry({required this.index, required this.child});

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
  late String _selectedIcon;
  DateTime? _targetDate;
  bool _saving = false;

  static const _emojiOptions = [
    '🎯',
    '💰',
    '🏠',
    '🚗',
    '✈️',
    '🎓',
    '💍',
    '🧰',
    '🛡️',
    '📱',
    '💻',
    '👶',
    '🐶',
    '🏖️',
    '🎁',
    '🧳',
    '🏍️',
    '📷',
    '🎮',
    '🩺',
    '🛠️',
    '🏆',
    '🌟',
    '📚',
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.targetAmount.toStringAsFixed(2) : '');
    _selectedIcon = (e?.icon != null && e!.icon.isNotEmpty) ? e.icon : '🎯';
    if (e?.targetDate != null && e!.targetDate!.isNotEmpty) {
      _targetDate = DateTime.tryParse(e.targetDate!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _showEmojiPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecciona un emoji', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                itemCount: _emojiOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (_, i) {
                  final emoji = _emojiOptions[i];
                  final isSelected = emoji == _selectedIcon;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(ctx, emoji),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _selectedIcon = selected);
    }
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
      body['icon'] = _selectedIcon;
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
            Text('Ícono', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _emojiOptions.take(8).map((emoji) {
                      final selected = emoji == _selectedIcon;
                      return ChoiceChip(
                        label: Text(emoji, style: const TextStyle(fontSize: 18)),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedIcon = emoji),
                      );
                    }).toList(),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showEmojiPicker,
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 18),
                  label: const Text('Ver más'),
                ),
              ],
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
