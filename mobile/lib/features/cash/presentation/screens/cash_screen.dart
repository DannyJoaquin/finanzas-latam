import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/currency_format.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../models/cash_models.dart';
import '../../providers/cash_provider.dart';
import '../../../../core/formatters/money_input_formatter.dart';

class CashScreen extends ConsumerWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(cashAccountsProvider);
    final monthRaw = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    final monthTitle = monthRaw[0].toUpperCase() + monthRaw.substring(1);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(
            error: e, onRetry: () => ref.invalidate(cashAccountsProvider)),
        data: (accounts) {
          if (accounts.isEmpty) {
            return _EmptyState(
                onCreated: () => ref.invalidate(cashAccountsProvider));
          }
          // Show the default account, or the first one
          final account = accounts.firstWhere((a) => a.isDefault,
              orElse: () => accounts.first);
          return _AccountView(
              account: account, allAccounts: accounts, monthTitle: monthTitle);
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends ConsumerStatefulWidget {
  const _EmptyState({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends ConsumerState<_EmptyState> {
  bool _creating = false;

  Future<void> _createDefault() async {
    setState(() => _creating = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiConstants.cashAccounts, data: {
        'name': 'Mi cartera',
        'currency': ref.read(currencyProvider),
      });
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withAlpha(120),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin cartera de efectivo',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una cartera para rastrear tu dinero en efectivo de forma separada al banco.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _creating ? null : _createDefault,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add),
              label: const Text('Crear cartera de efectivo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Account view ──────────────────────────────────────────────────────────────

class _AccountView extends ConsumerWidget {
  const _AccountView(
      {required this.account,
      required this.allAccounts,
      required this.monthTitle});
  final CashAccountModel account;
  final List<CashAccountModel> allAccounts;
  final String monthTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(cashTransactionsProvider(account.id));
    final fmt = currencyFmt(account.currency);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(cashAccountsProvider);
        ref.invalidate(cashTransactionsProvider(account.id));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Text(
            'Efectivo',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '$monthTitle · Cuenta principal',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // ── Wallet card ──
          _WalletCard(account: account, fmt: fmt),
          const SizedBox(height: 20),

          // ── Action buttons ──
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _showOperationSheet(context, ref, account, 'deposit'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Depositar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showOperationSheet(context, ref, account, 'withdraw'),
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Retirar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Transactions ──
          Text(
            'Movimientos',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          txAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('Error cargando movimientos: $e'),
            data: (transactions) {
              if (transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Sin movimientos aún',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: transactions.take(50).map((tx) {
                  final canEdit = tx.type == 'deposit' || tx.type == 'withdraw';
                  return _TransactionTile(
                    tx: tx,
                    currency: account.currency,
                    onTap: tx.type == 'spend'
                        ? () => context.go(AppRoutes.expenses)
                        : canEdit
                            ? () => _showTransactionEditor(
                                context, ref, account, tx)
                            : null,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showOperationSheet(
    BuildContext context,
    WidgetRef ref,
    CashAccountModel account,
    String operation,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OperationSheet(
        account: account,
        operation: operation,
        onDone: () {
          ref.invalidate(cashAccountsProvider);
          ref.invalidate(cashTransactionsProvider(account.id));
        },
      ),
    );
  }

  void _showTransactionEditor(
    BuildContext context,
    WidgetRef ref,
    CashAccountModel account,
    CashTransactionModel transaction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditTransactionSheet(
        account: account,
        transaction: transaction,
        onDone: () {
          ref.invalidate(cashAccountsProvider);
          ref.invalidate(cashTransactionsProvider(account.id));
        },
      ),
    );
  }
}

// ── Wallet card ───────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.account, required this.fmt});
  final CashAccountModel account;
  final NumberFormat fmt;

  Color _parseColor() {
    try {
      final hex = account.color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountColor = _parseColor();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accountColor, accountColor.withAlpha(200)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                account.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Saldo disponible',
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            fmt.format(account.balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(
      {required this.tx, required this.currency, this.onTap});
  final CashTransactionModel tx;
  final String currency;
  final VoidCallback? onTap;

  bool get _isCredit => tx.type == 'deposit' || tx.type == 'receive_transfer';

  IconData get _icon {
    return switch (tx.type) {
      'deposit' => Icons.arrow_downward_rounded,
      'withdraw' => Icons.arrow_upward_rounded,
      'spend' => Icons.shopping_bag_outlined,
      'receive_transfer' => Icons.swap_horiz_rounded,
      'send_transfer' => Icons.swap_horiz_rounded,
      _ => Icons.circle_outlined,
    };
  }

  String get _label {
    return switch (tx.type) {
      'deposit' => 'Depósito',
      'withdraw' => 'Retiro',
      'spend' => 'Gasto',
      'receive_transfer' => 'Transferencia recibida',
      'send_transfer' => 'Transferencia enviada',
      _ => tx.type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _isCredit ? AppColors.income : AppColors.expense;
    final fmt = currencyFmt(currency);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.description.isNotEmpty ? tx.description : _label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tx.date,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_isCredit ? '+' : '-'}${fmt.format(tx.amount)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Operation sheet (deposit / withdraw) ──────────────────────────────────────

class _OperationSheet extends ConsumerStatefulWidget {
  const _OperationSheet({
    required this.account,
    required this.operation,
    required this.onDone,
  });
  final CashAccountModel account;
  final String operation; // 'deposit' | 'withdraw'
  final VoidCallback onDone;

  @override
  ConsumerState<_OperationSheet> createState() => _OperationSheetState();
}

class _OperationSheetState extends ConsumerState<_OperationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  bool get _isDeposit => widget.operation == 'deposit';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final endpoint =
          '${ApiConstants.cashAccounts}/${widget.account.id}/${widget.operation}';
      await dio.post(endpoint, data: {
        'amount': parseMoneyInput(_amountCtrl.text),
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
      });
      widget.onDone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isDeposit ? 'Depósito registrado' : 'Retiro registrado'),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final title = _isDeposit ? 'Depositar efectivo' : 'Retirar efectivo';
    final icon = _isDeposit ? Icons.add : Icons.remove;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [MoneyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Monto (${currencySymbol(widget.account.currency)})',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                prefixText: '${currencySymbol(widget.account.currency)} ',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final n = parseMoneyInput(v);
                if (n == null || n <= 0) return 'Monto inválido';
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(title),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditTransactionSheet extends ConsumerStatefulWidget {
  const _EditTransactionSheet({
    required this.account,
    required this.transaction,
    required this.onDone,
  });

  final CashAccountModel account;
  final CashTransactionModel transaction;
  final VoidCallback onDone;

  @override
  ConsumerState<_EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<_EditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descriptionCtrl;
  late DateTime _date;
  bool _saving = false;
  bool _deleting = false;

  bool get _isDeposit => widget.transaction.type == 'deposit';

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: formatMoneyInputValue(widget.transaction.amount),
    );
    _descriptionCtrl =
        TextEditingController(text: widget.transaction.description);
    _date = DateTime.tryParse(widget.transaction.date) ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Fecha del movimiento',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        ApiConstants.cashTransaction(widget.account.id, widget.transaction.id),
        data: {
          'amount': parseMoneyInput(_amountCtrl.text),
          'description': _descriptionCtrl.text.trim(),
          'date': _date.toIso8601String().split('T').first,
        },
      );
      widget.onDone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimiento actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isDeposit ? 'Eliminar depósito' : 'Eliminar retiro'),
        content: const Text('El saldo de efectivo se recalculará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.delete(
        ApiConstants.cashTransaction(widget.account.id, widget.transaction.id),
      );
      widget.onDone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimiento eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final busy = _saving || _deleting;
    final title = _isDeposit ? 'Editar depósito' : 'Editar retiro';
    final dateLabel = DateFormat('dd/MM/yyyy').format(_date);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Eliminar movimiento',
                    onPressed: busy ? null : _delete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText:
                      'Monto (${currencySymbol(widget.account.currency)})',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  prefixText: '${currencySymbol(widget.account.currency)} ',
                ),
                validator: (value) {
                  final amount = parseMoneyInput(value ?? '');

                  if (amount == null || amount <= 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLength: 255,
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(dateLabel),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
