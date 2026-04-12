import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/providers/dashboard_provider.dart';
import '../../../../core/constants/currency_format.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';

class IncomeModel {
  const IncomeModel({
    required this.id,
    required this.sourceName,
    required this.amount,
    required this.type,
    required this.cycle,
    required this.isActive,
    this.nextExpectedAt,
  });

  final String id;
  final String sourceName;
  final double amount;
  final String type;
  final String cycle;
  final bool isActive;
  final String? nextExpectedAt;

  factory IncomeModel.fromJson(Map<String, dynamic> j) => IncomeModel(
        id: j['id'] as String,
        sourceName: j['sourceName'] as String? ?? j['name'] as String? ?? '',
        // Backend may return numeric fields as strings (e.g. "5000.00")
        amount: double.parse((j['amount'] ?? j['estimatedAmount'] ?? 0).toString()),
        type: j['type'] as String? ?? 'salary',
        cycle: j['cycle'] as String? ?? 'monthly',
        isActive: j['isActive'] as bool? ?? true,
        nextExpectedAt: (j['nextExpectedAt'] as String?)?.substring(0, 10),
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
    final fmt = ref.watch(currencyFmtProvider);
    final monthRaw = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    final monthTitle = monthRaw[0].toUpperCase() + monthRaw.substring(1);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIncomeSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: incomesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(error: e, onRetry: () => ref.invalidate(incomesProvider)),
        data: (incomes) => incomes.isEmpty
            ? const Center(child: Text('No tienes ingresos configurados.\nToca + para agregar uno.', textAlign: TextAlign.center))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(incomesProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: incomes.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final total = incomes.fold<double>(0, (s, e) => s + e.amount);
                      final active = incomes.where((e) => e.isActive).length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ingresos',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$monthTitle · ${incomes.length} ${incomes.length == 1 ? 'fuente' : 'fuentes'}',
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
                                    'Ingresos configurados',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    fmt.format(total),
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          color: AppColors.income,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$active activos · ${incomes.length} fuentes',
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

                    final inc = incomes[i - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
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
                        child: _AnimatedCardEntry(
                          index: i,
                          child: Material(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => _showIncomeActionsSheet(context, ref, inc),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppColors.income.withAlpha(24),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.attach_money, color: AppColors.income),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            inc.sourceName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_typeLabels[inc.type] ?? inc.type} · ${_cycleLabels[inc.cycle] ?? inc.cycle}${inc.nextExpectedAt != null ? ' · Próximo: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(inc.nextExpectedAt!))}' : ''}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          fmt.format(inc.amount),
                                          style: const TextStyle(
                                            color: AppColors.income,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Icon(Icons.chevron_right,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ],
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

  void _showIncomeActionsSheet(BuildContext context, WidgetRef ref, IncomeModel inc) {
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
              title: const Text('Editar ingreso'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditIncomeSheet(context, ref, inc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: const Text('Eliminar ingreso', style: TextStyle(color: AppColors.expense)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, inc);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
      // Regenerate insights since income change affects risk projections
      dio.post(ApiConstants.insightsRegenerate).ignore();
      ref.invalidate(insightsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
  DateTime? _nextExpectedAt;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  static const _types = ['salary', 'variable', 'remittance', 'freelance', 'other'];
  static const _typeLabels = ['Salario', 'Variable', 'Remesa', 'Freelance', 'Otro'];
  static const _cycles = ['weekly', 'biweekly', 'monthly', 'one_time'];
  static const _cycleLabels = ['Semanal', 'Quincenal', 'Mensual', 'Único'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.sourceName ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _type = e?.type ?? 'salary';
    _cycle = e?.cycle ?? 'monthly';
    _nextExpectedAt = e?.nextExpectedAt != null ? DateTime.parse(e!.nextExpectedAt!) : null;
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
        'nextExpectedAt': _nextExpectedAt?.toIso8601String().substring(0, 10),
      };
      if (_isEditing) {
        await dio.patch('${ApiConstants.incomes}/${widget.existing!.id}', data: body);
      } else {
        await dio.post(ApiConstants.incomes, data: body);
      }
      widget.onSaved();
      // Regenerate insights since income change affects risk projections
      dio.post(ApiConstants.insightsRegenerate).ignore();
      ref.invalidate(insightsProvider);
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
    final nextDateLabel = _nextExpectedAt == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy').format(_nextExpectedAt!);
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
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: List.generate(_types.length,
                  (i) => DropdownMenuItem(value: _types[i], child: Text(_typeLabels[i]))),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _cycle,
              decoration: const InputDecoration(labelText: 'Frecuencia'),
              items: List.generate(_cycles.length,
                  (i) => DropdownMenuItem(value: _cycles[i], child: Text(_cycleLabels[i]))),
              onChanged: (v) => setState(() => _cycle = v!),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextExpectedAt ?? now,
                  firstDate: DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 5),
                );
                if (picked != null) {
                  setState(() => _nextExpectedAt = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Próxima fecha de pago (opcional)',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(nextDateLabel)),
                    if (_nextExpectedAt != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Quitar fecha',
                        onPressed: () => setState(() => _nextExpectedAt = null),
                      ),
                  ],
                ),
              ),
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
