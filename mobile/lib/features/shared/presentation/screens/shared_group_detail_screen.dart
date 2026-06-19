import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/constants/currency_format.dart';
import '../../../../core/presentation/widgets/app_error_widget.dart';
import '../../providers/shared_groups_provider.dart';
import '../../providers/shared_expenses_provider.dart';
import '../../providers/shared_settlements_provider.dart';
import '../../models/shared_expense_model.dart';
import '../../models/shared_balance_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../screens/add_shared_expense_screen.dart';

class SharedGroupDetailScreen extends ConsumerStatefulWidget {
  const SharedGroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<SharedGroupDetailScreen> createState() => _SharedGroupDetailScreenState();
}

class _SharedGroupDetailScreenState extends ConsumerState<SharedGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(sharedGroupDetailProvider(widget.groupId));
    final balancesAsync = ref.watch(sharedGroupBalancesProvider(widget.groupId));
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.user?.id ?? '';
    final fmt = ref.watch(currencyFmtProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: groupAsync.when(
          data: (g) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.name, style: const TextStyle(fontSize: 17)),
              Text(
                '${g.members.length} miembro${g.members.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          loading: () => const Text('Cargando...'),
          error: (_, __) => const Text('Detalle del grupo'),
        ),
        actions: [
          groupAsync.when(
            data: (g) => IconButton(
              icon: const Icon(Icons.vpn_key_outlined),
              tooltip: 'Código de invitación',
              onPressed: () => _showInviteCode(context, g.inviteCode),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'export_csv') await _exportCsv(context);
              if (val == 'export_pdf') await _exportPdf(context);
              if (val == 'import') _showImportDialog(context);
              if (val == 'settings') _showSettingsDialog(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export_csv',
                child: ListTile(
                  leading: Icon(Icons.table_chart_outlined),
                  title: Text('Exportar CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'export_pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Exportar PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.upload_file_outlined),
                  title: Text('Importar CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Configuración'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Gastos'),
            Tab(text: 'Balances'),
            Tab(text: 'Stats'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.sharedAddExpense(widget.groupId)),
        icon: const Icon(Icons.add),
        label: const Text('Agregar gasto'),
      ),
      body: Column(
        children: [
          // Balance header
          balancesAsync.when(
            data: (b) => _BalanceHeader(
              youAreOwed: b.youAreOwed,
              youOwe: b.youOwe,
              fmt: fmt,
            ),
            loading: () => const SizedBox(height: 4, child: LinearProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Tabs content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _ExpensesTab(groupId: widget.groupId, currentUserId: currentUserId),
                _BalancesTab(
                  groupId: widget.groupId,
                  currentUserId: currentUserId,
                  balancesAsync: balancesAsync,
                ),
                _StatsTab(groupId: widget.groupId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final repo = ProviderScope.containerOf(context, listen: false)
        .read(sharedExpensesRepositoryProvider);
    try {
      final csv = await repo.exportGroupCsv(widget.groupId);
      await SharePlus.instance.share(ShareParams(
        text: csv,
        subject: 'Gastos del grupo',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    try {
      final expenses =
          ref.read(sharedGroupExpensesProvider(widget.groupId)).value ?? [];
      final groupName =
          ref.read(sharedGroupDetailProvider(widget.groupId)).value?.name ?? 'Grupo';

      final doc = pw.Document();
      final dateFmt = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();
      final totalAmount = expenses.fold(0.0, (s, e) => s + e.totalAmount);

      const primary = PdfColor.fromInt(0xFF6750A4);
      const primaryLight = PdfColor.fromInt(0xFFEADDFF);
      const surface = PdfColor.fromInt(0xFFF4EFF4);
      const onSurface = PdfColor.fromInt(0xFF1C1B1F);
      const muted = PdfColor.fromInt(0xFF6A6374);

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GASTOS COMPARTIDOS',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.2,
                          )),
                      pw.SizedBox(height: 4),
                      pw.Text(groupName,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                          )),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generado: ${dateFmt.format(now)}',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 9)),
                      pw.SizedBox(height: 4),
                      pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],
        ),
        build: (ctx) => [
          // ── Summary row ──────────────────────────
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: surface,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: primaryLight, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total gastos',
                          style: const pw.TextStyle(fontSize: 9, color: muted)),
                      pw.SizedBox(height: 4),
                      pw.Text('${expenses.length}',
                          style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: onSurface)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: surface,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: primaryLight, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Monto total',
                          style: const pw.TextStyle(fontSize: 9, color: muted)),
                      pw.SizedBox(height: 4),
                      pw.Text('L ${totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // ── Expenses table ───────────────────────
          pw.Text('DETALLE DE GASTOS',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: onSurface,
                letterSpacing: 0.8,
              )),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Fecha', 'Descripción', 'Pagó', 'Monto (L)', 'Partes'],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: primary),
            rowDecoration:
                const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration:
                const pw.BoxDecoration(color: surface),
            cellStyle: const pw.TextStyle(fontSize: 7.5, color: onSurface),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerLeft,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(56),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FixedColumnWidth(64),
              4: const pw.FlexColumnWidth(2.2),
            },
            data: expenses.map((e) {
              final parts = e.participants
                  .map((p) =>
                      '${p.fullName.split(' ').first}: L${p.shareAmount.toStringAsFixed(0)}')
                  .join('  ');
              return [
                dateFmt.format(e.date),
                e.description,
                e.payerName.split(' ').first,
                e.totalAmount.toStringAsFixed(2),
                parts,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 24),
          // ── Footer watermark ─────────────────────
          pw.Divider(color: primaryLight),
          pw.SizedBox(height: 6),
          pw.Text('Generado por Zentri – Finanzas Personales',
              style: const pw.TextStyle(fontSize: 8, color: muted)),
        ],
      ));

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gastos_${widget.groupId}.pdf');
      await file.writeAsBytes(await doc.save());

      if (context.mounted) {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Gastos del grupo – $groupName',
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al generar PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImportDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Importar CSV: próximamente')),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final repo = ProviderScope.containerOf(context, listen: false)
        .read(sharedExpensesRepositoryProvider);
    bool requiresApproval = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Configuración del grupo'),
          content: SwitchListTile(
            title: const Text('Requerir aprobación'),
            subtitle: const Text('Los gastos deben ser aprobados por el admin'),
            value: requiresApproval,
            onChanged: (v) => setS(() => requiresApproval = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                await repo.updateGroupSettings(
                  groupId: widget.groupId,
                  requiresApproval: requiresApproval,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      }),
    );
  }

  void _showInviteCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de invitación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Comparte este código con quien quieras invitar:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado')),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// ── Balance Header ─────────────────────────────────────────────────────────────

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.youAreOwed,
    required this.youOwe,
    required this.fmt,
  });
  final double youAreOwed;
  final double youOwe;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final net = youAreOwed - youOwe;
    final isPositive = net >= 0;
    final color = isPositive ? Colors.green.shade700 : Colors.orange.shade700;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        border: Border(bottom: BorderSide(color: color.withAlpha(60))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BalanceChip(
            label: 'Te deben',
            amount: fmt.format(youAreOwed),
            color: Colors.green.shade700,
          ),
          Container(width: 1, height: 36, color: theme.dividerColor),
          _BalanceChip(
            label: 'Debes',
            amount: fmt.format(youOwe),
            color: Colors.orange.shade700,
          ),
          Container(width: 1, height: 36, color: theme.dividerColor),
          _BalanceChip(
            label: 'Balance neto',
            amount: '${isPositive ? '+' : ''}${fmt.format(net)}',
            color: color,
          ),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Expenses Tab ───────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.groupId, required this.currentUserId});
  final String groupId;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(sharedGroupExpensesProvider(groupId));
    final fmt = ref.watch(currencyFmtProvider);

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
        error: e,
        onRetry: () => ref.invalidate(sharedGroupExpensesProvider(groupId)),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text('Sin gastos todavía', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(sharedGroupExpensesProvider(groupId)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: expenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _ExpenseCard(
              expense: expenses[i],
              groupId: groupId,
              currentUserId: currentUserId,
              fmt: fmt,
            ),
          ),
        );
      },
    );
  }
}

class _ExpenseCard extends ConsumerWidget {
  const _ExpenseCard({
    required this.expense,
    required this.groupId,
    required this.currentUserId,
    required this.fmt,
  });
  final SharedExpenseModel expense;
  final String groupId;
  final String currentUserId;
  final NumberFormat fmt;

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(sharedExpensesRepositoryProvider).approveExpense(
            groupId: groupId,
            expenseId: expense.id,
          );
      ref.invalidate(sharedGroupExpensesProvider(groupId));
      ref.invalidate(sharedGroupBalancesProvider(groupId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al aprobar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(sharedExpensesRepositoryProvider).rejectExpense(
            groupId: groupId,
            expenseId: expense.id,
          );
      ref.invalidate(sharedGroupExpensesProvider(groupId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al rechazar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddSharedExpenseScreen(
          groupId: groupId,
          initialExpense: expense,
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Text(
            '¿Eliminar "${expense.description}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(sharedExpensesRepositoryProvider).deleteExpense(
            groupId: groupId,
            expenseId: expense.id,
          );
      ref.invalidate(sharedGroupExpensesProvider(groupId));
      ref.invalidate(sharedGroupBalancesProvider(groupId));
      ref.invalidate(sharedWidgetSummaryProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myParticipation = expense.participants
        .where((p) => p.userId == currentUserId)
        .firstOrNull;
    final isPayer = expense.payerId == currentUserId;
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd/MM/yy').format(expense.date);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          expense.description,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (expense.isRecurring) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: expense.recurringInterval == 'weekly'
                              ? 'Semanal'
                              : 'Mensual',
                          child: Icon(Icons.repeat,
                              size: 14, color: theme.colorScheme.primary),
                        ),
                      ],
                      if (expense.status == 'pending') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Text(
                            'Pendiente',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  fmt.format(expense.totalAmount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') _handleEdit(context);
                    if (value == 'delete') _handleDelete(context, ref);
                    if (value == 'approve') _handleApprove(context, ref);
                    if (value == 'reject') _handleReject(context, ref);
                  },
                  itemBuilder: (_) => [
                    if (expense.status == 'pending') ...[
                      const PopupMenuItem(
                          value: 'approve',
                          child: ListTile(
                            leading: Icon(Icons.check_circle_outline, color: Colors.green),
                            title: Text('Aprobar'),
                            contentPadding: EdgeInsets.zero,
                          )),
                      const PopupMenuItem(
                          value: 'reject',
                          child: ListTile(
                            leading: Icon(Icons.cancel_outlined, color: Colors.orange),
                            title: Text('Rechazar'),
                            contentPadding: EdgeInsets.zero,
                          )),
                    ],
                    const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        )),
                    const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  isPayer ? 'Tú pagaste' : 'Pagó ${expense.payerName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (myParticipation != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPayer
                      ? Colors.green.shade700.withAlpha(20)
                      : Colors.orange.shade700.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPayer
                      ? 'Tu parte: ${fmt.format(myParticipation.shareAmount)} (de ${fmt.format(expense.totalAmount)})'
                      : 'Tu parte: ${fmt.format(myParticipation.shareAmount)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPayer ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Balances Tab ───────────────────────────────────────────────────────────────

class _BalancesTab extends ConsumerWidget {
  const _BalancesTab({
    required this.groupId,
    required this.currentUserId,
    required this.balancesAsync,
  });
  final String groupId;
  final String currentUserId;
  final AsyncValue<GroupBalanceSummaryModel> balancesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFmtProvider);

    return balancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
        error: e,
        onRetry: () => ref.invalidate(sharedGroupBalancesProvider(groupId)),
      ),
      data: (b) {
        if (b.balances.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                SizedBox(height: 12),
                Text('¡Todo saldado!', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('No hay deudas pendientes en este grupo.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(sharedGroupBalancesProvider(groupId)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: b.balances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final entry = b.balances[i];
              final isMyDebt = entry.fromUserId == currentUserId;
              final isOwedToMe = entry.toUserId == currentUserId;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMyDebt
                        ? Colors.orange.shade700.withAlpha(30)
                        : (isOwedToMe
                            ? Colors.green.shade700.withAlpha(30)
                            : Colors.grey.shade200),
                    child: Icon(
                      Icons.person_outline,
                      color: isMyDebt
                          ? Colors.orange.shade700
                          : (isOwedToMe ? Colors.green.shade700 : Colors.grey),
                    ),
                  ),
                  title: Text(
                    '${entry.fromUserName} → ${entry.toUserName}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isMyDebt ? 'Tú debes' : (isOwedToMe ? 'Te deben' : ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: isMyDebt ? Colors.orange.shade700 : Colors.green.shade700,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt.format(entry.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isMyDebt ? Colors.orange.shade700 : Colors.green.shade700,
                        ),
                      ),
                      if (isMyDebt)
                        GestureDetector(
                          onTap: () => _showSettlementSheet(ctx, ref, entry),
                          child: Text(
                            'Registrar pago',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(ctx).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showSettlementSheet(BuildContext context, WidgetRef ref, entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SettlementSheet(
        groupId: groupId,
        receiverId: entry.toUserId,
        receiverName: entry.toUserName,
        suggestedAmount: entry.amount,
        ref: ref,
      ),
    );
  }
}

// ── Settlement Sheet ──────────────────────────────────────────────────────────

class _SettlementSheet extends StatefulWidget {
  const _SettlementSheet({
    required this.groupId,
    required this.receiverId,
    required this.receiverName,
    required this.suggestedAmount,
    required this.ref,
  });
  final String groupId;
  final String receiverId;
  final String receiverName;
  final double suggestedAmount;
  final WidgetRef ref;

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amtCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController(text: widget.suggestedAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.ref.read(sharedSettlementsRepositoryProvider).createSettlement(
            groupId: widget.groupId,
            receiverId: widget.receiverId,
            amount: double.parse(_amtCtrl.text),
            date: DateTime.now().toIso8601String().split('T').first,
          );
      widget.ref.invalidate(sharedGroupBalancesProvider(widget.groupId));
      widget.ref.invalidate(sharedGroupSettlementsProvider(widget.groupId));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago registrado')),
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
              'Registrar pago a ${widget.receiverName}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amtCtrl,
              decoration: const InputDecoration(
                labelText: 'Monto (L)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa un monto';
                final parsed = double.tryParse(v);
                if (parsed == null || parsed <= 0) return 'Monto inválido';
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmar pago'),
            ),
          ],
        ),
      ),
    );
  }
}
// ── Stats Tab ──────────────────────────────────────────────────────────────────

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_groupStatsProvider(groupId));
    final theme = Theme.of(context);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 8),
            Text('No se pudieron cargar las estadísticas',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            TextButton(
              onPressed: () => ref.invalidate(_groupStatsProvider(groupId)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (stats) {
        final byPayer = (stats['byPayer'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final byMonth = (stats['byMonth'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final totalAmount = (stats['totalAmount'] as num? ?? 0).toDouble();

        // Find highest single expense amount across all payers
        final maxPayer = byPayer.isEmpty
            ? 0.0
            : byPayer
                .map((p) => (p['amount'] as num? ?? 0).toDouble())
                .reduce((a, b) => a > b ? a : b);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Resumen ────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total gastos',
                    value: '${stats['totalExpenses'] ?? 0}',
                    icon: Icons.receipt_long_outlined,
                    color: theme.colorScheme.primaryContainer,
                    iconColor: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Monto total',
                    value: 'L ${totalAmount.toStringAsFixed(0)}',
                    icon: Icons.attach_money,
                    color: theme.colorScheme.secondaryContainer,
                    iconColor: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            // ── Por pagador ────────────────────
            if (byPayer.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Quién pagó más',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...byPayer.map((p) {
                final name = p['name'] as String? ?? '—';
                final amount = (p['amount'] as num? ?? 0).toDouble();
                final pct =
                    totalAmount > 0 ? (amount / totalAmount).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PayerRow(
                    name: name,
                    amount: amount,
                    pct: pct,
                    isTopPayer: amount == maxPayer && byPayer.length > 1,
                  ),
                );
              }),
            ],
            // ── Por mes ───────────────────────
            if (byMonth.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Por mes',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...byMonth.reversed.take(6).map((m) {
                final month = m['month'] as String? ?? '';
                final amount = (m['amount'] as num? ?? 0).toDouble();
                final maxMonth = byMonth.isEmpty
                    ? 1.0
                    : byMonth
                        .map((x) => (x['amount'] as num? ?? 0).toDouble())
                        .reduce((a, b) => a > b ? a : b);
                final pct =
                    maxMonth > 0 ? (amount / maxMonth).clamp(0.0, 1.0) : 0.0;
                // Parse "2026-04" → "Abr 2026"
                final parts = month.split('-');
                final label = parts.length == 2
                    ? DateFormat('MMM yyyy')
                        .format(DateTime(int.parse(parts[0]), int.parse(parts[1])))
                    : month;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MonthRow(label: label, amount: amount, pct: pct),
                );
              }),
            ],
            if (byPayer.isEmpty && byMonth.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_outlined,
                          size: 56, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      Text('Sin datos todavía',
                          style:
                              TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 10),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _PayerRow extends StatelessWidget {
  const _PayerRow({
    required this.name,
    required this.amount,
    required this.pct,
    required this.isTopPayer,
  });
  final String name;
  final double amount;
  final double pct;
  final bool isTopPayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if (isTopPayer) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('El que más pagó',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary)),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              'L ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 36,
              child: Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: theme.colorScheme.surfaceVariant,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.label,
    required this.amount,
    required this.pct,
  });
  final String label;
  final double amount;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            Text(
              'L ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.secondary),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: theme.colorScheme.surfaceVariant,
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

final _groupStatsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, groupId) {
  return ref.watch(sharedExpensesRepositoryProvider).getGroupStats(groupId);
});
