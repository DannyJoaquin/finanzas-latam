import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/shared_groups_provider.dart';
import '../../providers/shared_expenses_provider.dart';
import '../../models/shared_group_model.dart';
import '../../models/shared_expense_model.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class AddSharedExpenseScreen extends ConsumerStatefulWidget {
  const AddSharedExpenseScreen({
    super.key,
    required this.groupId,
    this.initialExpense, // non-null = edit mode
  });
  final String groupId;
  final SharedExpenseModel? initialExpense;

  @override
  ConsumerState<AddSharedExpenseScreen> createState() =>
      _AddSharedExpenseScreenState();
}

class _AddSharedExpenseScreenState extends ConsumerState<AddSharedExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  String? _payerId;
  List<String> _selectedParticipants = [];

  // Split mode: 'equal' | 'amount' | 'percent'
  String _splitMode = 'equal';
  final Map<String, TextEditingController> _customAmounts = {};
  final Map<String, TextEditingController> _percentAmounts = {};
  final Set<String> _lockedParticipants = {};
  final Set<String> _lockedPercents = {};

  // Recurring
  bool _isRecurring = false;
  String? _recurringInterval; // 'monthly' | 'weekly'
  int _recurringDay = 1;

  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _totalCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _customAmounts.values) c.dispose();
    for (final c in _percentAmounts.values) c.dispose();
    super.dispose();
  }

  void _initParticipants(List<SharedMemberModel> members) {
    if (_initialized) return;
    _initialized = true;

    final exp = widget.initialExpense;

    // Ensure controllers exist for all current members
    for (final m in members) {
      _customAmounts.putIfAbsent(m.userId, () => TextEditingController());
      _percentAmounts.putIfAbsent(m.userId, () => TextEditingController());
    }

    if (exp != null) {
      // Edit mode — pre-populate
      _descCtrl.text = exp.description;
      _totalCtrl.text = exp.totalAmount.toStringAsFixed(2);
      _noteCtrl.text = exp.note ?? '';
      _date = exp.date;
      _payerId = exp.payerId;
      _selectedParticipants = exp.participants.map((p) => p.userId).toList();
      _isRecurring = exp.isRecurring;
      _recurringInterval = exp.recurringInterval;

      // B4 fix: detect if all shares are equal → use 'equal' mode
      final n = exp.participants.length;
      if (n > 0) {
        final allEqual = exp.participants.every(
          (p) => (p.shareAmount - exp.totalAmount / n).abs() < 0.01,
        );
        _splitMode = allEqual ? 'equal' : 'amount';
      }

      // B5 fix: ensure controllers exist for participants before assigning
      for (final p in exp.participants) {
        _customAmounts.putIfAbsent(p.userId, () => TextEditingController());
        _percentAmounts.putIfAbsent(p.userId, () => TextEditingController());
        _customAmounts[p.userId]!.text = p.shareAmount.toStringAsFixed(2);
        if (exp.totalAmount > 0) {
          final pct = (p.shareAmount / exp.totalAmount) * 100;
          _percentAmounts[p.userId]!.text = pct.toStringAsFixed(1);
        }
      }
    } else {
      _selectedParticipants = members.map((m) => m.userId).toList();
      final currentUserId = ref.read(authStateProvider).valueOrNull?.user?.id;
      _payerId = members.any((m) => m.userId == currentUserId)
          ? currentUserId
          : members.first.userId;
    }
  }

  /// Called each time a custom amount input changes.
  /// Locks [userId] and auto-distributes the remainder among unlocked participants.
  void _onCustomAmountChanged(String userId, List<SharedMemberModel> members) {
    _lockedParticipants.add(userId);

    final total = double.tryParse(_totalCtrl.text) ?? 0;
    final selected = members.where((m) => _selectedParticipants.contains(m.userId)).toList();
    final unlocked = selected.where((m) => !_lockedParticipants.contains(m.userId)).toList();

    if (unlocked.isEmpty) {
      setState(() {});
      return;
    }

    // B1 fix: also filter locked participants by _selectedParticipants
    final lockedSum = _lockedParticipants
        .where((id) => _customAmounts.containsKey(id) && _selectedParticipants.contains(id))
        .fold(0.0, (sum, id) => sum + (double.tryParse(_customAmounts[id]!.text) ?? 0));

    final remaining = total - lockedSum;
    final share = remaining / unlocked.length;

    for (final m in unlocked) {
      _customAmounts[m.userId]?.text =
          share > 0 ? share.toStringAsFixed(2) : '0.00';
    }
    setState(() {});
  }

  /// Called each time a percent input changes.
  /// Locks [userId] and auto-distributes the remaining % among unlocked participants.
  void _onPercentChanged(String userId, List<SharedMemberModel> members) {
    _lockedPercents.add(userId);

    final selected = members.where((m) => _selectedParticipants.contains(m.userId)).toList();
    final unlocked = selected.where((m) => !_lockedPercents.contains(m.userId)).toList();

    if (unlocked.isEmpty) {
      setState(() {});
      return;
    }

    final lockedPct = _lockedPercents
        .where((id) => _percentAmounts.containsKey(id) && _selectedParticipants.contains(id))
        .fold(0.0, (sum, id) => sum + (double.tryParse(_percentAmounts[id]!.text) ?? 0));

    final remaining = 100.0 - lockedPct;
    final share = remaining / unlocked.length;

    for (final m in unlocked) {
      _percentAmounts[m.userId]?.text =
          share > 0 ? share.toStringAsFixed(1) : '0.0';
    }
    setState(() {});
  }

  List<Map<String, dynamic>> _buildParticipants(List<SharedMemberModel> members) {
    final selected = members.where((m) => _selectedParticipants.contains(m.userId)).toList();
    if (selected.isEmpty) return [];

    final total = double.tryParse(_totalCtrl.text) ?? 0;

    if (_splitMode == 'equal') {
      final share = selected.isEmpty ? 0.0 : total / selected.length;
      return selected
          .map((m) => {'userId': m.userId, 'shareAmount': double.parse(share.toStringAsFixed(2))})
          .toList();
    } else if (_splitMode == 'percent') {
      return selected.map((m) {
        final pct = double.tryParse(_percentAmounts[m.userId]?.text ?? '0') ?? 0;
        final amt = total * pct / 100;
        return {'userId': m.userId, 'shareAmount': double.parse(amt.toStringAsFixed(2))};
      }).toList();
    } else {
      // 'amount'
      return selected.map((m) {
        final amt = double.tryParse(_customAmounts[m.userId]?.text ?? '0') ?? 0;
        return {'userId': m.userId, 'shareAmount': amt};
      }).toList();
    }
  }

  double _previewSum(List<SharedMemberModel> members) {
    final participants = _buildParticipants(members);
    return participants.fold(0.0, (acc, p) => acc + (p['shareAmount'] as double));
  }

  Future<void> _submit(List<SharedMemberModel> members) async {
    if (!_formKey.currentState!.validate()) return;
    if (_payerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona quién pagó')),
      );
      return;
    }
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un participante')),
      );
      return;
    }

    final participants = _buildParticipants(members);
    final total = double.parse(_totalCtrl.text);
    final sum = participants.fold(0.0, (a, p) => a + (p['shareAmount'] as double));
    if ((sum - total).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'La suma de los montos (L ${sum.toStringAsFixed(2)}) no coincide con el total (L ${total.toStringAsFixed(2)})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final repo = ref.read(sharedExpensesRepositoryProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    try {
      if (widget.initialExpense != null) {
        // Edit mode
        await repo.updateExpense(
          groupId: widget.groupId,
          expenseId: widget.initialExpense!.id,
          totalAmount: total,
          description: _descCtrl.text.trim(),
          date: dateStr,
          participants: participants,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          isRecurring: _isRecurring,
          recurringInterval: _isRecurring ? _recurringInterval : null,
          recurringDay: _isRecurring ? _recurringDay : null,
        );
      } else {
        // Create mode
        await repo.createExpense(
          groupId: widget.groupId,
          payerId: _payerId!,
          totalAmount: total,
          description: _descCtrl.text.trim(),
          date: dateStr,
          participants: participants,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          isRecurring: _isRecurring,
          recurringInterval: _isRecurring ? _recurringInterval : null,
          recurringDay: _isRecurring ? _recurringDay : null,
        );
      }
      ref.invalidate(sharedGroupExpensesProvider(widget.groupId));
      ref.invalidate(sharedGroupBalancesProvider(widget.groupId));
      ref.invalidate(sharedWidgetSummaryProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(sharedGroupDetailProvider(widget.groupId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialExpense != null ? 'Editar gasto' : 'Agregar gasto compartido'),
        centerTitle: false,
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(error: e, onRetry: () {}),
        data: (group) {
          final members = group.members
              .where((m) => m.status == 'active')
              .toList();
          _initParticipants(members);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Description ──
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.receipt_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Ingresa una descripción' : null,
                ),
                const SizedBox(height: 12),
                // ── Total Amount ──
                TextFormField(
                  controller: _totalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Monto total (L)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {
                    _lockedParticipants.clear();
                  }),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa el monto';
                    final parsed = double.tryParse(v);
                    if (parsed == null || parsed <= 0) return 'Monto inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // ── Date ──
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(DateFormat('dd/MM/yyyy').format(_date)),
                  subtitle: const Text('Fecha del gasto'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const Divider(),
                // ── Payer Selector ──
                Text('¿Quién pagó?',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: members.map((m) {
                    final selected = _payerId == m.userId;
                    return ChoiceChip(
                      label: Text(m.fullName),
                      selected: selected,
                      onSelected: (_) => setState(() => _payerId = m.userId),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // ── Participants ──
                Row(
                  children: [
                    Text('Participantes',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        if (_selectedParticipants.length == members.length) {
                          _selectedParticipants = [];
                        } else {
                          _selectedParticipants = members.map((m) => m.userId).toList();
                        }
                      }),
                      child: Text(
                        _selectedParticipants.length == members.length
                            ? 'Desmarcar todos'
                            : 'Seleccionar todos',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: members.map((m) {
                    final selected = _selectedParticipants.contains(m.userId);
                    return FilterChip(
                      label: Text(m.fullName),
                      selected: selected,
                      onSelected: (on) => setState(() {
                        if (on) {
                          _selectedParticipants.add(m.userId);
                        } else {
                          _selectedParticipants.remove(m.userId);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // ── Split mode ──
                Row(
                  children: [
                    Text('División',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'equal', label: Text('Por igual')),
                        ButtonSegment(value: 'percent', label: Text('%')),
                        ButtonSegment(value: 'amount', label: Text('Monto')),
                      ],
                      selected: {_splitMode},
                      onSelectionChanged: (s) => setState(() {
                        _splitMode = s.first;
                        _lockedParticipants.clear();
                        _lockedPercents.clear();
                        if (_splitMode == 'amount') {
                          for (final c in _customAmounts.values) c.clear();
                        } else if (_splitMode == 'percent') {
                          for (final c in _percentAmounts.values) c.clear();
                        }
                      }),
                    ),
                  ],
                ),
                // ── Percent split inputs ──
                if (_splitMode == 'percent') ...[
                  const SizedBox(height: 12),
                  ...members
                      .where((m) => _selectedParticipants.contains(m.userId))
                      .map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextFormField(
                              controller: _percentAmounts[m.userId],
                              decoration: InputDecoration(
                                labelText: m.fullName,
                                suffixText: '%',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => _onPercentChanged(m.userId, members),
                            ),
                          ))
                      .toList(),
                ],
                // ── Custom amount split inputs ──
                if (_splitMode == 'amount') ...[
                  const SizedBox(height: 12),
                  ...members
                      .where((m) => _selectedParticipants.contains(m.userId))
                      .map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextFormField(
                              controller: _customAmounts[m.userId],
                              decoration: InputDecoration(
                                labelText: m.fullName,
                                prefixText: 'L ',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => _onCustomAmountChanged(m.userId, members),
                            ),
                          ))
                      .toList(),
                ],
                // ── Preview live ──
                if (_selectedParticipants.isNotEmpty && (_totalCtrl.text.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  _SplitPreview(
                    members: members
                        .where((m) => _selectedParticipants.contains(m.userId))
                        .toList(),
                    participants: _buildParticipants(members),
                    payerId: _payerId,
                    total: double.tryParse(_totalCtrl.text) ?? 0,
                    sum: _previewSum(members),
                  ),
                ],
                const SizedBox(height: 12),
                // ── Note ──
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // ── Recurring expense ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Gasto recurrente'),
                          subtitle: const Text('Se creará automáticamente'),
                          value: _isRecurring,
                          onChanged: (v) => setState(() {
                            _isRecurring = v;
                            if (!v) _recurringInterval = null;
                          }),
                        ),
                        if (_isRecurring) ...[
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'monthly', label: Text('Mensual')),
                              ButtonSegment(value: 'weekly', label: Text('Semanal')),
                            ],
                            selected: {_recurringInterval ?? 'monthly'},
                            onSelectionChanged: (s) => setState(
                              () => _recurringInterval = s.first,
                            ),
                          ),
                          if (_recurringInterval == 'monthly') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Día del mes: '),
                                const SizedBox(width: 8),
                                DropdownButton<int>(
                                  value: _recurringDay.clamp(1, 28),
                                  items: List.generate(
                                    28,
                                    (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text('${i + 1}'),
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _recurringDay = v ?? 1),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : () => _submit(members),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.initialExpense != null ? 'Guardar cambios' : 'Guardar gasto'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Split Preview ─────────────────────────────────────────────────────────────

class _SplitPreview extends StatelessWidget {
  const _SplitPreview({
    required this.members,
    required this.participants,
    required this.payerId,
    required this.total,
    required this.sum,
  });
  final List<SharedMemberModel> members;
  final List<Map<String, dynamic>> participants;
  final String? payerId;
  final double total;
  final double sum;

  @override
  Widget build(BuildContext context) {
    final diff = (sum - total).abs();
    final isValid = diff <= 0.01;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isValid
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                size: 16,
                color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Vista previa de la división',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isValid ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...participants.map((p) {
            final member = members.where((m) => m.userId == p['userId']).firstOrNull;
            final name = member?.fullName ?? p['userId'];
            final isPayer = p['userId'] == payerId;
            final shareAmt = (p['shareAmount'] as double);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isPayer ? '$name (pagador)' : name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    'L ${shareAmt.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(
                'L ${sum.toStringAsFixed(2)} / L ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isValid ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
