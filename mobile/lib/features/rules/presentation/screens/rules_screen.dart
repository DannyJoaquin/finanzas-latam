import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class RuleModel {
  const RuleModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.triggerType,
    required this.conditions,
    required this.actions,
    required this.priority,
  });
  final String id;
  final String name;
  final bool isActive;
  final String triggerType;
  final List<Map<String, dynamic>> conditions;
  final List<Map<String, dynamic>> actions;
  final int priority;

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  factory RuleModel.fromJson(Map<String, dynamic> j) => RuleModel(
        id: j['id'] as String,
        name: j['name'] as String,
        isActive: j['isActive'] as bool? ?? true,
        triggerType: j['triggerType'] as String? ?? '',
        conditions: _mapList(j['conditions']),
        actions: _mapList(j['actions']),
        priority: j['priority'] as int? ?? 1,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final rulesProvider = FutureProvider.autoDispose<List<RuleModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.rules);
  final raw = resp.data as List<dynamic>? ?? [];
  return raw.map((e) => RuleModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Human-readable labels ─────────────────────────────────────────────────────

const _triggerLabels = {
  'expense_added': 'Al agregar un gasto',
  'budget_threshold': 'Al superar presupuesto',
  'income_received': 'Al recibir ingreso',
  'goal_milestone': 'Al alcanzar meta',
  'periodic': 'Periódico',
};

// Only 'expense_added' actually evaluates rules today — the backend has no
// evaluator wired up for the others (see RulesEvaluatorService). The create
// form only offers this one so users don't build rules that silently never
// fire; existing rules with another trigger still show their real label
// via _triggerLabels above.
const _supportedTrigger = 'expense_added';

const _actionLabels = {
  'notify': 'Notificar',
  'tag': 'Etiquetar',
  'auto_categorize': 'Auto-categorizar',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider);
    final monthRaw = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    final monthTitle = monthRaw[0].toUpperCase() + monthRaw.substring(1);
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: isMobile
            ? IconButton(
                tooltip: 'Volver a configuración',
                onPressed: () => context.go(AppRoutes.settings),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: isMobile
            ? const Text('Reglas automáticas')
            : const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva regla',
            onPressed: () => _showCreateSheet(context, ref),
          ),
        ],
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rule_outlined, size: 56, color: AppColors.neutral),
              const SizedBox(height: 12),
              Text('Error cargando reglas: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
        data: (rules) => rules.isEmpty
            ? _EmptyState(onAdd: () => _showCreateSheet(context, ref))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                children: [
                  Text(
                    'Reglas',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$monthTitle · ${rules.length} automatizaciones',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ...rules.map((rule) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RuleTile(
                          rule: rule,
                          onToggle: () => _toggleRule(context, ref, rule),
                          onDelete: () => _deleteRule(context, ref, rule),
                        ),
                      )),
                ],
              ),
      ),
    );
  }

  Future<void> _toggleRule(BuildContext context, WidgetRef ref, RuleModel rule) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('${ApiConstants.rules}/${rule.id}', data: {
        'isActive': !rule.isActive,
      });
      ref.invalidate(rulesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar la regla')),
        );
      }
    }
  }

  Future<void> _deleteRule(BuildContext context, WidgetRef ref, RuleModel rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar regla'),
        content: Text('¿Eliminar "${rule.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('${ApiConstants.rules}/${rule.id}');
      ref.invalidate(rulesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar la regla')),
        );
      }
    }
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateRuleSheet(onSaved: () => ref.invalidate(rulesProvider)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rule_outlined, size: 72, color: AppColors.neutral),
            const SizedBox(height: 16),
            Text('Sin reglas configuradas',
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Crea reglas para automatizar acciones basadas en tus gastos e ingresos.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Crear primera regla'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
  });
  final RuleModel rule;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final triggerLabel = _triggerLabels[rule.triggerType] ?? rule.triggerType;
    final actionTypes = rule.actions.map((a) => a['type'] as String? ?? '').toList();
    final actionLabel = actionTypes.map((t) => _actionLabels[t] ?? t).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          rule.name,
          style: theme.textTheme.titleSmall?.copyWith(
            color: rule.isActive ? null : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.arrow_right_alt, size: 14, color: AppColors.neutral),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$triggerLabel → $actionLabel',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Prioridad ${rule.priority}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Switch(
              value: rule.isActive,
              onChanged: (_) => onToggle(),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CreateRuleSheet extends ConsumerStatefulWidget {
  const _CreateRuleSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_CreateRuleSheet> createState() => _CreateRuleSheetState();
}

class _CreateRuleSheetState extends ConsumerState<_CreateRuleSheet> {
  final _nameCtrl = TextEditingController();
  final _actionValueCtrl = TextEditingController();
  final _trigger = _supportedTrigger;
  String _action = 'notify';
  String _condField = 'amount';
  String _condOp = 'gt';
  final _condValueCtrl = TextEditingController(text: '0');
  String? _condCategoryId;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _actionValueCtrl.dispose();
    _condValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final actionParams = switch (_action) {
      'tag' => {
          'tag': _actionValueCtrl.text.trim().isEmpty
              ? name
              : _actionValueCtrl.text.trim(),
        },
      'auto_categorize' => {
          'categoryId': _actionValueCtrl.text.trim(),
        },
      _ => {'message': 'Regla "$name" activada'},
    };
    if (_action == 'auto_categorize' && _actionValueCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría')),
      );
      return;
    }
    if (_condField == 'category' && _condCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría para la condición')),
      );
      return;
    }

    final condition = _condField == 'category'
        ? {'field': 'categoryId', 'op': 'eq', 'value': _condCategoryId}
        : {
            'field': _condField,
            'op': _condOp,
            'value': double.tryParse(_condValueCtrl.text) ?? 0,
          };

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiConstants.rules, data: {
        'name': name,
        'triggerType': _trigger,
        'conditions': [condition],
        'actions': [
          {
            'type': _action,
            'params': actionParams,
          }
        ],
        'priority': 1,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear la regla')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nueva Regla', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),

          // Name
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre de la regla',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Trigger — only expense_added currently evaluates rules, so it's
          // shown as a fixed label rather than a choice that could silently
          // never fire.
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Disparador',
              border: OutlineInputBorder(),
            ),
            child: Text(_triggerLabels[_trigger] ?? _trigger),
          ),
          const SizedBox(height: 16),

          // Condition
          DropdownButtonFormField<String>(
            initialValue: _condField,
            decoration: const InputDecoration(
              labelText: 'Campo',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'amount', child: Text('Monto')),
              DropdownMenuItem(value: 'category', child: Text('Categoría')),
            ],
            onChanged: (v) => setState(() => _condField = v!),
          ),
          const SizedBox(height: 10),
          if (_condField == 'category')
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                'No se pudieron cargar las categorías: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (categories) => DropdownButtonFormField<String>(
                initialValue: categories.any((c) => c.id == _condCategoryId)
                    ? _condCategoryId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Es la categoría',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map((category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _condCategoryId = v),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final operatorDropdown = DropdownButtonFormField<String>(
                  initialValue: _condOp,
                  decoration: const InputDecoration(
                    labelText: 'Operador',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'gt', child: Text('Mayor que')),
                    DropdownMenuItem(value: 'lt', child: Text('Menor que')),
                    DropdownMenuItem(value: 'eq', child: Text('Igual a')),
                  ],
                  onChanged: (v) => setState(() => _condOp = v!),
                );
                final valueField = TextField(
                  controller: _condValueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor de condición',
                    border: OutlineInputBorder(),
                  ),
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    children: [
                      operatorDropdown,
                      const SizedBox(height: 12),
                      valueField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: operatorDropdown),
                    const SizedBox(width: 8),
                    Expanded(child: valueField),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),

          // Action
          DropdownButtonFormField<String>(
            initialValue: _action,
            decoration: const InputDecoration(
              labelText: 'Acción',
              border: OutlineInputBorder(),
            ),
            items: _actionLabels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _action = v!),
          ),
          if (_action == 'tag') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _actionValueCtrl,
              decoration: const InputDecoration(
                labelText: 'Etiqueta',
                hintText: 'Ej: revisar',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_action == 'auto_categorize') ...[
            const SizedBox(height: 12),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                'No se pudieron cargar las categorías: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (categories) => DropdownButtonFormField<String>(
                initialValue: categories.any((c) => c.id == _actionValueCtrl.text)
                    ? _actionValueCtrl.text
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Categoría destino',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map((category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(
                  () => _actionValueCtrl.text = value ?? '',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando...' : 'Guardar Regla'),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
