import 'dart:async';

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
import '../../../../core/providers/experience_provider.dart';

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

  // ── Auto-categorization state ──────────────────────────────────────────
  CategorySuggestion? _suggestion;
  bool _suggestionLoading = false;
  bool _rememberCategory = false;
  Timer? _debounce;

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
  void initState() {
    super.initState();
    _descCtrl.addListener(_onDescriptionChanged);
  }

  void _onDescriptionChanged() {
    _debounce?.cancel();
    final text = _descCtrl.text.trim();
    if (text.length < 3) {
      if (_suggestion != null) setState(() => _suggestion = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _fetchSuggestion(text));
  }

  Future<void> _fetchSuggestion(String description) async {
    setState(() => _suggestionLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final result = await suggestCategory(dio, description);
      if (!mounted) return;
      // Only auto-select if the returned categoryId is a leaf category in the
      // selectable dropdown list (backend may return a parent category ID).
      final availableIds = ref.read(categoriesProvider).valueOrNull
          ?.map((c) => c.id)
          .toSet() ?? {};
      setState(() {
        _suggestion = result;
        if (result != null &&
            result.isHighConfidence &&
            _selectedCategoryId == null &&
            result.categoryId != null &&
            availableIds.contains(result.categoryId)) {
          _selectedCategoryId = result.categoryId;
        }
      });
    } finally {
      if (mounted) setState(() => _suggestionLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _descCtrl.removeListener(_onDescriptionChanged);
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
      final isSimple = ref.read(isSimpleModeProvider);
      final paymentMethod = isSimple ? 'cash' : _paymentMethod;
      final desc = _descCtrl.text.trim();
      await dio.post(ApiConstants.expenses, data: {
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
        'currency': _currency!,
        if (desc.isNotEmpty) 'description': desc,
        'categoryId': _selectedCategoryId,
        'paymentMethod': paymentMethod,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        if (paymentMethod == 'card_credit' && _selectedCreditCardId != null)
          'creditCardId': _selectedCreditCardId,
      });
      // Send categorization feedback if user chose differently from suggestion
      if (desc.isNotEmpty && _selectedCategoryId != null) {
        final sugId = _suggestion?.categoryId;
        if (sugId != null && sugId != _selectedCategoryId) {
          sendCategorizationFeedback(
            dio,
            desc,
            _selectedCategoryId!,
            remember: _rememberCategory,
          );
        }
      }
      ref.invalidate(expensesProvider);
      if (paymentMethod == 'card_credit') {
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
    final isSimple = ref.watch(isSimpleModeProvider);

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
            // ── Suggestion chip ──────────────────────────────────────────
            if (_suggestionLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (_suggestion != null && _suggestion!.hasSuggestion)
              _SuggestionChip(
                suggestion: _suggestion!,
                selectedCategoryId: _selectedCategoryId,
                onApply: (id) => setState(() {
                  _selectedCategoryId = id;
                  _suggestion = null;
                }),
              ),
            const SizedBox(height: 14),
            _sectionCard(
              Column(
                children: [
                  catAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error al cargar categorías'),
                    data: (cats) {
                    // Guard: ensure value exists in list to avoid Flutter assertion error.
                    // Backend suggestion may return a parent category ID not in the flat list.
                    final validId = cats.any((c) => c.id == _selectedCategoryId)
                        ? _selectedCategoryId
                        : null;
                    return DropdownButtonFormField<String>(
                      value: validId,
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
                      onChanged: (v) => setState(() {
                        _selectedCategoryId = v;
                        // Show "remember" option when user overrides a suggestion
                        if (_suggestion != null &&
                            v != null &&
                            v != _suggestion!.categoryId) {
                          _rememberCategory = false;
                        }
                      }),
                      validator: (v) => v == null ? 'Requerido' : null,
                    );
                  },
                  ),
                  // "Remember" checkbox — only shown when user overrides suggestion
                  if (_suggestion != null &&
                      _selectedCategoryId != null &&
                      _selectedCategoryId != _suggestion!.categoryId)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _rememberCategory,
                      onChanged: (v) => setState(() => _rememberCategory = v ?? false),
                      title: Text(
                        'Recordar para descripciones similares',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  if (!isSimple) ...[
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
                  ],
                  if (!isSimple && _paymentMethod == 'card_credit') ...[
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
                  if (!isSimple) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha'),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 18),
                  ],
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

// ── Suggestion chip widget ──────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.suggestion,
    required this.selectedCategoryId,
    required this.onApply,
  });

  final CategorySuggestion suggestion;
  final String? selectedCategoryId;
  final void Function(String categoryId) onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alreadyApplied = selectedCategoryId == suggestion.categoryId;
    final color = alreadyApplied
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.tertiaryContainer;
    final textColor = alreadyApplied
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onTertiaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: alreadyApplied
            ? null
            : () => onApply(suggestion.categoryId!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                alreadyApplied
                    ? Icons.check_circle_outline_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  alreadyApplied
                      ? 'Auto-detectado: ${suggestion.categoryName}'
                      : 'Sugerida: ${suggestion.categoryName}',
                  style: theme.textTheme.labelMedium?.copyWith(color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suggestion.matchedKeyword != null && !alreadyApplied) ...[
                const SizedBox(width: 6),
                Text(
                  '· "${suggestion.matchedKeyword}"',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor.withAlpha(160),
                  ),
                ),
              ],
              if (!alreadyApplied) ...[
                const SizedBox(width: 8),
                Text(
                  'Aplicar',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
