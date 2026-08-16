import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/currency_format.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/cash/providers/cash_provider.dart';
import '../../../../features/credit_cards/providers/credit_cards_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/recurring_expenses_provider.dart';

class RecurringExpensesScreen extends ConsumerStatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  ConsumerState<RecurringExpensesScreen> createState() =>
      _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState
    extends ConsumerState<RecurringExpensesScreen> {
  final _busyIds = <String>{};

  Future<void> _showForm({RecurringExpenseModel? recurring}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringExpenseForm(initial: recurring),
    );
    if (!mounted) return;
    ref.invalidate(recurringExpensesProvider);
    ref.invalidate(expensesProvider);
  }

  Future<void> _toggle(RecurringExpenseModel recurring) async {
    if (_busyIds.contains(recurring.id)) return;
    setState(() => _busyIds.add(recurring.id));
    try {
      await ref.read(recurringExpensesRepositoryProvider).update(
        recurring.id,
        {'isActive': !recurring.isActive},
      );
      ref.invalidate(recurringExpensesProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(recurring.id));
    }
  }

  Future<void> _delete(RecurringExpenseModel recurring) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar gasto recurrente'),
        content: Text(
          'Se eliminará la configuración de "${recurring.name}". Los gastos ya generados conservarán su historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(recurring.id));
    try {
      await ref.read(recurringExpensesRepositoryProvider).delete(recurring.id);
      ref.invalidate(recurringExpensesProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(recurring.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final recurringAsync = ref.watch(recurringExpensesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const SizedBox.shrink(),
      ),
      floatingActionButton: recurringAsync.maybeWhen(
        data: (items) => items.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo gasto'),
              ),
        orElse: () => null,
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(recurringExpensesProvider),
        ),
        data: (items) {
          final active = items.where((item) => item.isActive).toList();
          final upcoming = [...active]
            ..sort((a, b) => a.nextRunDate.compareTo(b.nextRunDate));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recurringExpensesProvider);
              await ref.read(recurringExpensesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                Text(
                  'Gastos recurrentes',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${active.length} activos · ${items.length} configurados',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                if (upcoming.isNotEmpty)
                  _UpcomingSection(items: upcoming.take(3).toList()),
                if (upcoming.isNotEmpty) const SizedBox(height: 18),
                if (items.isEmpty)
                  _EmptyRecurringState(onCreate: () => _showForm())
                else ...[
                  Text(
                    'Todas las configuraciones',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecurringCard(
                        recurring: item,
                        busy: _busyIds.contains(item.id),
                        onEdit: () => _showForm(recurring: item),
                        onToggle: () => _toggle(item),
                        onDelete: () => _delete(item),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.items});
  final List<RecurringExpenseModel> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Próximos gastos',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currencyFmt(item.currency).format(item.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatShortDate(item.nextRunDate),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.recurring,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final RecurringExpenseModel recurring;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor =
        recurring.isActive ? Colors.teal : theme.colorScheme.outline;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: busy ? null : onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(16),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.autorenew_rounded,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recurring.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StatusPill(
                          label: recurring.isActive ? 'Activo' : 'Pausado',
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      currencyFmt(recurring.currency).format(recurring.amount),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${recurring.categoryName} · ${recurring.accountName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${frequencyLabel(recurring.frequency)} · ${recurring.isActive ? 'Próximo' : 'Se reanudará desde'}: ${_formatDate(recurring.nextRunDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (recurring.lastGeneratedDate != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Último generado: ${_formatDate(recurring.lastGeneratedDate!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (recurring.lastGenerationError != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Pendiente de generar',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: !busy,
                tooltip: 'Acciones',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'toggle') onToggle();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.pause_circle_outline,
                      ),
                      title: Text(recurring.isActive ? 'Pausar' : 'Reactivar'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyRecurringState extends StatelessWidget {
  const _EmptyRecurringState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.autorenew_rounded,
            size: 58,
            color: theme.colorScheme.primary.withAlpha(110),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes gastos recurrentes',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Configura pagos que se crearán automáticamente en Gastos.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Configurar gasto'),
          ),
        ],
      ),
    );
  }
}

class _RecurringExpenseForm extends ConsumerStatefulWidget {
  const _RecurringExpenseForm({this.initial});
  final RecurringExpenseModel? initial;

  @override
  ConsumerState<_RecurringExpenseForm> createState() =>
      _RecurringExpenseFormState();
}

class _RecurringExpenseFormState extends ConsumerState<_RecurringExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;

  late DateTime _startDate;
  late String _configuredCurrency;
  late String _currency;
  late String _paymentMethod;
  late String _frequency;
  late int _executionDay;
  String? _categoryId;
  String? _cashAccountId;
  String? _creditCardId;
  bool _saving = false;

  static const _paymentMethods = {
    'cash': 'Efectivo',
    'card_debit': 'Tarjeta débito',
    'card_credit': 'Tarjeta crédito',
    'transfer': 'Transferencia',
    'other': 'Otro',
  };

  static const _frequencies = [
    'daily',
    'weekly',
    'biweekly',
    'monthly',
    'bimonthly',
    'quarterly',
    'semiannual',
    'annual',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.initial;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _amountCtrl = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    _notesCtrl = TextEditingController(text: existing?.notes ?? '');
    _startDate = existing == null
        ? DateTime.now()
        : DateTime.tryParse(existing.startDate) ?? DateTime.now();
    _configuredCurrency = ref.read(currencyProvider);
    _currency = existing?.currency ?? _configuredCurrency;
    _paymentMethod = existing?.paymentMethod ?? 'cash';
    _frequency = existing?.frequency ?? 'monthly';
    _executionDay = existing?.executionDay ?? _startDate.day;
    _categoryId = existing?.categoryId;
    _cashAccountId = existing?.cashAccountId;
    _creditCardId = existing?.creditCardId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _weekly => _frequency == 'weekly' || _frequency == 'biweekly';

  List<String> get _currencyOptions => {
        _configuredCurrency,
        _currency,
        'USD',
      }.toList();

  String _currencyLabel(String code) => code == 'HNL' ? 'L.' : code;

  List<int> get _dayOptions => _weekly
      ? List<int>.generate(7, (index) => index + 1)
      : List<int>.generate(31, (index) => index + 1);

  String _dayName(int day) {
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return names[day - 1];
  }

  void _changeFrequency(String? value) {
    if (value == null) return;
    setState(() {
      _frequency = value;
      if (_frequency == 'weekly' || _frequency == 'biweekly') {
        _executionDay = _isoWeekday(_startDate);
      } else {
        _executionDay = _startDate.day;
      }
    });
  }

  int _isoWeekday(DateTime date) => date.weekday;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _executionDay = _weekly ? _isoWeekday(picked) : picked.day;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    if (_paymentMethod == 'card_credit' && _creditCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una tarjeta de crédito')),
      );
      return;
    }

    setState(() => _saving = true);
    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'amount': amount,
      'currency': _currency,
      'categoryId': _categoryId,
      'paymentMethod': _paymentMethod,
      'frequency': _frequency,
      'executionDay': _executionDay,
      'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
      if (_paymentMethod == 'cash' && _cashAccountId != null)
        'cashAccountId': _cashAccountId,
      if (_paymentMethod == 'card_credit' && _creditCardId != null)
        'creditCardId': _creditCardId,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    try {
      final repository = ref.read(recurringExpensesRepositoryProvider);
      if (widget.initial == null) {
        await repository.create(data);
      } else {
        await repository.update(widget.initial!.id, data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cashAsync = ref.watch(cashAccountsProvider);
    final cardsAsync = ref.watch(creditCardsProvider);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.initial == null
                    ? 'Nuevo gasto recurrente'
                    : 'Editar gasto recurrente',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe un nombre'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Monto',
                        prefixText: '${currencySymbol(_currency)} ',
                      ),
                      validator: (value) {
                        final amount =
                            double.tryParse(value?.replaceAll(',', '.') ?? '');
                        return amount == null || amount <= 0
                            ? 'Monto inválido'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 108,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: _currencyOptions
                          .map(
                            (code) => DropdownMenuItem(
                              value: code,
                              child: Text(_currencyLabel(code)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _currency = value ?? _currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) =>
                    const Text('No se pudieron cargar las categorías'),
                data: (categories) => DropdownButtonFormField<String>(
                  value:
                      categories.any((category) => category.id == _categoryId)
                          ? _categoryId
                          : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(
                            category.parentName == null
                                ? category.name
                                : '${category.parentName} › ${category.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Selecciona una categoría' : null,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Método de pago',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: _paymentMethods.entries
                    .map((entry) => DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _paymentMethod = value;
                    if (value != 'cash') _cashAccountId = null;
                    if (value != 'card_credit') _creditCardId = null;
                  });
                },
              ),
              if (_paymentMethod == 'cash') ...[
                const SizedBox(height: 12),
                cashAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text(
                      'No se pudieron cargar las cuentas de efectivo'),
                  data: (accounts) => DropdownButtonFormField<String?>(
                    value: _cashAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta utilizada',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Cuenta predeterminada'),
                      ),
                      ...accounts.map(
                        (account) => DropdownMenuItem<String?>(
                          value: account.id,
                          child: Text(account.name,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _cashAccountId = value),
                  ),
                ),
              ],
              if (_paymentMethod == 'card_credit') ...[
                const SizedBox(height: 12),
                cardsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) =>
                      const Text('No se pudieron cargar las tarjetas'),
                  data: (cards) => DropdownButtonFormField<String?>(
                    value: cards.any((card) => card.id == _creditCardId)
                        ? _creditCardId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta utilizada',
                      prefixIcon: Icon(Icons.credit_card_outlined),
                    ),
                    items: cards
                        .map(
                          (card) => DropdownMenuItem<String?>(
                            value: card.id,
                            child: Text(card.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final card =
                          cards.where((item) => item.id == value).firstOrNull;
                      setState(() {
                        _creditCardId = value;
                        if (card != null) _currency = card.limitCurrency;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Selecciona una tarjeta' : null,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia',
                  prefixIcon: Icon(Icons.repeat_outlined),
                ),
                items: _frequencies
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(frequencyLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: _changeFrequency,
              ),
              if (_frequency != 'daily') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _dayOptions.contains(_executionDay)
                      ? _executionDay
                      : _dayOptions.first,
                  decoration: InputDecoration(
                    labelText:
                        _weekly ? 'Día de la semana' : 'Día de ejecución',
                    prefixIcon: const Icon(Icons.today_outlined),
                  ),
                  items: _dayOptions
                      .map(
                        (day) => DropdownMenuItem(
                          value: day,
                          child: Text(_weekly ? _dayName(day) : 'Día $day'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _executionDay = value ?? _executionDay),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Primera ejecución'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(widget.initial == null
                    ? 'Crear gasto recurrente'
                    : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd/MM/yyyy').format(parsed);
}

String _formatShortDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final raw = DateFormat('d MMM', 'es').format(parsed);
  return raw[0].toUpperCase() + raw.substring(1);
}
