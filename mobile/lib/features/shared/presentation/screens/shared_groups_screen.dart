import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/constants/currency_format.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../providers/shared_groups_provider.dart';
import '../../models/shared_group_model.dart';

class SharedGroupsScreen extends ConsumerWidget {
  const SharedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(sharedGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join',
            onPressed: () => _showJoinGroupSheet(context, ref),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Unirse'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => _showCreateGroupSheet(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Crear grupo'),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(
          error: e,
          onRetry: () => ref.invalidate(sharedGroupsProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return _EmptyState(
              onCreateTap: () => _showCreateGroupSheet(context, ref),
              onJoinTap: () => _showJoinGroupSheet(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sharedGroupsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: groups.length + 1,
              separatorBuilder: (_, i) =>
                  i == 0 ? const SizedBox.shrink() : const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grupos',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${groups.length} ${groups.length == 1 ? 'grupo activo' : 'grupos activos'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return _GroupCard(group: groups[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});
  final SharedGroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = currencyFmt(group.currency);
    final balancesAsync = ref.watch(sharedGroupBalancesProvider(group.id));
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.sharedGroupDetail(group.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${group.members.length} miembro${group.members.length != 1 ? 's' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              balancesAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (_, __) => const SizedBox.shrink(),
                data: (b) => Row(
                  children: [
                    if (b.youAreOwed > 0)
                      _BalanceBadge(
                        label: 'Te deben',
                        amount: fmt.format(b.youAreOwed),
                        color: Colors.green.shade700,
                      ),
                    if (b.youAreOwed > 0 && b.youOwe > 0)
                      const SizedBox(width: 8),
                    if (b.youOwe > 0)
                      _BalanceBadge(
                        label: 'Debes',
                        amount: fmt.format(b.youOwe),
                        color: Colors.orange.shade700,
                      ),
                    if (b.youAreOwed == 0 && b.youOwe == 0)
                      _BalanceBadge(
                        label: 'Saldado',
                        amount: '',
                        color: Colors.grey,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        amount.isNotEmpty ? '$label $amount' : label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap, required this.onJoinTap});
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Sin grupos todavía',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea un grupo para dividir gastos con amigos o familiares, o únete con un código de invitación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Crear grupo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoinTap,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Unirse con código'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Group Sheet ────────────────────────────────────────────────────────

void _showCreateGroupSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CreateGroupSheet(ref: ref),
  );
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.ref.read(sharedGroupsRepositoryProvider).createGroup(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          );
      widget.ref.invalidate(sharedGroupsProvider);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Crear grupo',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo',
                prefixIcon: Icon(Icons.group_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa un nombre' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Crear grupo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Join Group Sheet ──────────────────────────────────────────────────────────

void _showJoinGroupSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _JoinGroupSheet(ref: ref),
  );
}

class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final group = await widget.ref
          .read(sharedGroupsRepositoryProvider)
          .joinGroup(_codeCtrl.text.trim().toUpperCase());
      widget.ref.invalidate(sharedGroupsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Te uniste a ${group.name}!')),
        );
      }
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unirse a un grupo',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa el código de 8 caracteres que te compartió el administrador del grupo.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Código de invitación',
                prefixIcon: Icon(Icons.vpn_key_outlined),
                hintText: 'Ej: A1B2C3D4',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  v == null || v.trim().length < 4 ? 'Código inválido' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Unirse'),
            ),
          ],
        ),
      ),
    );
  }
}
