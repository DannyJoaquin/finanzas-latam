import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/cash_models.dart';
import '../../providers/cash_provider.dart';

class CashScreen extends ConsumerWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(cashAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Efectivo')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return _EmptyState(onCreated: () => ref.invalidate(cashAccountsProvider));
          }
          // Show the default account, or the first one
          final account =
              accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
          return _AccountView(account: account, allAccounts: accounts);
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
        'currency': 'HNL',
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
  const _AccountView({required this.account, required this.allAccounts});
  final CashAccountModel account;
  final List<CashAccountModel> allAccounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(cashTransactionsProvider(account.id));
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: '${account.currency} ');
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(cashAccountsProvider);
        ref.invalidate(cashTransactionsProvider(account.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Wallet card ──
          _WalletCard(account: account, fmt: fmt),
          const SizedBox(height: 20),

          // ── Action buttons ──
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showOperationSheet(context, ref, account, 'deposit'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Depositar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showOperationSheet(context, ref, account, 'withdraw'),
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
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                      Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
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
                  return _TransactionTile(tx: tx, currency: account.currency);
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
  const _TransactionTile({required this.tx, required this.currency});
  final CashTransactionModel tx;
  final String currency;

  bool get _isCredit =>
      tx.type == 'deposit' || tx.type == 'receive_transfer';

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
    final fmt =
        NumberFormat.currency(locale: 'en_US', symbol: '$currency ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tx.date,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
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
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      });
      widget.onDone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isDeposit ? 'Depósito registrado' : 'Retiro registrado'),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monto (${widget.account.currency})',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final n = double.tryParse(v.replaceAll(',', '.'));
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(title),
            ),
          ],
        ),
      ),
    );
  }
}
