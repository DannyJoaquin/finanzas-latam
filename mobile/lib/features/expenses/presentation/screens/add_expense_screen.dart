import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../providers/expenses_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../features/credit_cards/providers/credit_cards_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/home/providers/dashboard_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _selectedCategoryId;
  String _paymentMethod = 'cash';
  String? _selectedCreditCardId;
  String? _currency;
  DateTime _date = DateTime.now();

  String _localCurrency(WidgetRef ref) {
    _currency ??= ref.read(currencyProvider);
    return _currency!;
  }
  bool _saving = false;

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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
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
      await dio.post(ApiConstants.expenses, data: {
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
        'currency': _currency!,
        if (desc.isNotEmpty) 'description': desc,
        'categoryId': _selectedCategoryId,
        'paymentMethod': _paymentMethod,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        if (_paymentMethod == 'card_credit' && _selectedCreditCardId != null)
          'creditCardId': _selectedCreditCardId,
      });
      ref.invalidate(expensesProvider);
      if (_paymentMethod == 'card_credit') {
        ref.invalidate(creditCardsSummaryProvider);
      }
      ref.invalidate(dashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gasto guardado')));
        context.go(AppRoutes.expenses);
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

  Widget _sectionCard(Widget child) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize _currency from user preferences on first build
    _localCurrency(ref);
    final catAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const SizedBox.shrink()),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Agregar gasto',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Registra tu movimiento y mantenlo bajo control',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Monto',
                            prefixText: _currency! == 'USD' ? '\$ ' : 'L ',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            final n = double.tryParse(v.replaceAll(',', '.'));
                            if (n == null || n <= 0) return 'Monto inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'HNL', label: Text('L')),
                            ButtonSegment(value: 'USD', label: Text('\$')),
                          ],
                          selected: {_currency!},
                          onSelectionChanged: (s) => setState(() => _currency = s.first),
                          style: SegmentedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              Column(
                children: [
                  catAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error al cargar categorías'),
                    data: (cats) => DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      isExpanded: true,
                      items: cats
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Icon(c.iconData, size: 18),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        c.parentName != null ? '${c.parentName} › ${c.name}' : c.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Método de pago'),
                    items: _payMethods.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _paymentMethod = v ?? 'cash';
                      _selectedCreditCardId = null;
                    }),
                  ),
                  if (_paymentMethod == 'card_credit') ...[
                    const SizedBox(height: 16),
                    ref.watch(creditCardsProvider).when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (cards) => cards.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800).withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFF9800).withAlpha(80)),
                                  ),
                                  child: const Text(
                                    'No tienes tarjetas registradas. Agrégalas en la sección de Tarjetas.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  initialValue: _selectedCreditCardId,
                                  decoration: const InputDecoration(
                                    labelText: 'Tarjeta de crédito',
                                    prefixIcon: Icon(Icons.credit_card_outlined),
                                  ),
                                  items: cards
                                      .map((c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(c.name),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _selectedCreditCardId = v;
                                    if (v != null) {
                                      final card = cards.firstWhere((c) => c.id == v);
                                      _currency = card.limitCurrency;
                                    }
                                  }),
                                ),
                        ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Guardar gasto'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
