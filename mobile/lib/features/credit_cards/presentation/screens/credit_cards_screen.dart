import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../models/credit_card_model.dart';
import '../../providers/credit_cards_provider.dart';

// ── Gradient per network ──────────────────────────────────────────────────────

LinearGradient _networkGradient(String network) {
  return switch (network) {
    'visa' => const LinearGradient(
        colors: [Color(0xFF1A237E), Color(0xFF1565C0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    'mastercard' => const LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF2D1B69)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    'amex' => const LinearGradient(
        colors: [Color(0xFF006241), Color(0xFF1A3A5C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    _ => const LinearGradient(
        colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CreditCardsScreen extends ConsumerStatefulWidget {
  const CreditCardsScreen({super.key});

  @override
  ConsumerState<CreditCardsScreen> createState() => _CreditCardsScreenState();
}

class _CreditCardsScreenState extends ConsumerState<CreditCardsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(creditCardsSummaryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F1117)
          : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Tarjetas de crédito'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => ref.invalidate(creditCardsSummaryProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar tarjeta',
            onPressed: () => _showAddCardSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(creditCardsSummaryProvider.future),
              child: summaryAsync.when(
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 300),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 200),
                    Center(child: Text('Error: $e')),
                  ],
                ),
                data: (cards) {
                  if (cards.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.75,
                          child: _EmptyState(onAdd: () => _showAddCardSheet(context)),
                        ),
                      ],
                    );
                  }

                  final card = cards[_selectedIndex.clamp(0, cards.length - 1)];

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 8),
                      // ── Card carousel ─────────────────────────────────────────
                      SizedBox(
                        height: 210,
                        child: PageView.builder(
                          controller: PageController(
                            viewportFraction: cards.length == 1 ? 0.92 : 0.86,
                            initialPage: _selectedIndex,
                          ),
                          itemCount: cards.length,
                          onPageChanged: (i) => setState(() => _selectedIndex = i),
                          itemBuilder: (_, i) => _CreditCardWidget(
                            card: cards[i],
                            isSelected: i == _selectedIndex,
                          ),
                        ),
                      ),
                      // ── Page dots ─────────────────────────────────────────────
                      if (cards.length > 1) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            cards.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _selectedIndex ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _selectedIndex
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // ── Billing cycle detail ──────────────────────────────────
                      _BillingCycleDetail(card: card),
                      const SizedBox(height: 16),
                      // ── Utilization ───────────────────────────────────────────
                      if (card.creditLimit != null && card.creditLimit! > 0) ...[
                        _UtilizationCard(card: card),
                        const SizedBox(height: 16),
                      ],
                      // ── Overdue payment warning ───────────────────────────────
                      if (card.overdueBalance > 0) ...[
                        _OverdueWarningCard(card: card),
                        const SizedBox(height: 16),
                      ],
                      // ── Actions ───────────────────────────────────────────────
                      _CardActions(
                        card: card,
                        onEdit: () => _showEditCardSheet(context, card),
                        onDelete: () => _confirmDelete(context, card),
                      ),
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ),  // RefreshIndicator
          ),  // Expanded
        ],  // Column.children
      ),  // Column (body)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCardSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarjeta'),
      ),
    );
  }

  Future<void> _showAddCardSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddCardSheet(
        onSaved: () {
          ref.invalidate(creditCardsSummaryProvider);
          ref.invalidate(creditCardsProvider);
        },
      ),
    );
  }

  Future<void> _showEditCardSheet(BuildContext context, CreditCardSummary card) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddCardSheet(
        editCard: card,
        onSaved: () {
          ref.invalidate(creditCardsSummaryProvider);
          ref.invalidate(creditCardsProvider);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CreditCardSummary card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: Text('¿Eliminar ${card.name}? Los gastos existentes no se borrarán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('${ApiConstants.creditCards}/${card.id}');
        ref.invalidate(creditCardsSummaryProvider);
        ref.invalidate(creditCardsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarjeta eliminada')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

// ── Credit card visual widget ─────────────────────────────────────────────────

class _CreditCardWidget extends StatelessWidget {
  const _CreditCardWidget({required this.card, required this.isSelected});
  final CreditCardSummary card;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);
    final gradient = _networkGradient(card.network);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: isSelected ? 0 : 10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withAlpha(isSelected ? 110 : 45),
            blurRadius: isSelected ? 30 : 12,
            spreadRadius: isSelected ? 2 : 0,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(10),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -55,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(7),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: chip + network logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ChipIcon(),
                      _NetworkLogo(network: card.network),
                    ],
                  ),
                  const Spacer(),
                  // Balance
                  Text(
                    fmt.format(card.currentBalance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gastado este ciclo',
                    style: TextStyle(
                      color: Colors.white.withAlpha(160),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Bottom row: card name + cut-off badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          card.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CutOffBadge(days: card.daysUntilCutOff),
                    ],
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

// ── Chip icon ─────────────────────────────────────────────────────────────────

class _ChipIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFF5C842)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: CustomPaint(painter: _ChipPainter()),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8960C).withAlpha(120)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(size.width / 2, 2), Offset(size.width / 2, size.height - 2), paint);
    canvas.drawLine(
        Offset(2, size.height / 2), Offset(size.width - 2, size.height / 2), paint);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.2,
        size.width * 0.6,
        size.height * 0.6,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Network logo ──────────────────────────────────────────────────────────────

class _NetworkLogo extends StatelessWidget {
  const _NetworkLogo({required this.network});
  final String network;

  @override
  Widget build(BuildContext context) {
    return switch (network) {
      'visa' => const Text(
          'VISA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
          ),
        ),
      'mastercard' => SizedBox(
          width: 50,
          height: 32,
          child: CustomPaint(painter: _MastercardPainter()),
        ),
      'amex' => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withAlpha(200), width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'AMEX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
      _ => Icon(Icons.credit_card, color: Colors.white.withAlpha(200), size: 28),
    };
  }
}

class _MastercardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = 13.0;
    final cy = size.height / 2;
    final cx = size.width / 2;

    canvas.drawCircle(
      Offset(cx - 9, cy),
      r,
      Paint()..color = const Color(0xFFEB001B).withAlpha(220),
    );
    canvas.drawCircle(
      Offset(cx + 9, cy),
      r,
      Paint()..color = const Color(0xFFF79E1B).withAlpha(220),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Cut-off badge ─────────────────────────────────────────────────────────────

class _CutOffBadge extends StatelessWidget {
  const _CutOffBadge({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final urgent = days <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: urgent
            ? const Color(0xFFFF5252).withAlpha(210)
            : Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent ? Icons.warning_amber_rounded : Icons.content_cut_rounded,
            color: Colors.white,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            days == 0 ? 'Corta hoy' : 'Corte ${days}d',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Billing cycle detail ──────────────────────────────────────────────────────

class _BillingCycleDetail extends StatelessWidget {
  const _BillingCycleDetail({required this.card});
  final CreditCardSummary card;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);
    final theme = Theme.of(context);
    final payUrgent = card.daysUntilPayment <= 5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ciclo actual',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.calendar_month_outlined,
            label: 'Período',
            value: '${card.currentCycleStart}  →  ${card.currentCycleEnd}',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.content_cut_rounded,
                  label: 'Próximo corte',
                  value: '${card.nextCutOffDate}\n${card.daysUntilCutOff}d restantes',
                  color: card.daysUntilCutOff <= 3
                      ? const Color(0xFFFF5252)
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  icon: Icons.payment_outlined,
                  label: 'Fecha de pago',
                  value: '${card.paymentDueDate}\n${card.daysUntilPayment}d restantes',
                  color: payUrgent ? const Color(0xFFFF5252) : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Deuda actual del ciclo',
            value: fmt.format(card.currentBalance),
            large: true,
            color: card.currentBalance > 0
                ? const Color(0xFFFF9800)
                : const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: large ? 20 : 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: large ? 16 : 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Utilization card ──────────────────────────────────────────────────────────

class _UtilizationCard extends StatelessWidget {
  const _UtilizationCard({required this.card});
  final CreditCardSummary card;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);
    final fmtLimit = NumberFormat.currency(
      locale: 'en_US',
      symbol: card.limitCurrency == 'USD' ? '\$ ' : 'L ',
      decimalDigits: card.limitCurrency == 'USD' ? 2 : 0,
    );
    final pct = card.utilizationPct ?? 0;
    final color = pct > 80
        ? const Color(0xFFEA4335)
        : pct > 50
            ? const Color(0xFFFF9800)
            : const Color(0xFF34A853);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Utilización del crédito',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.outlineVariant.withAlpha(60),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Usado: ${fmt.format(card.currentBalance)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Límite: ${fmtLimit.format(card.creditLimit!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overdue warning ───────────────────────────────────────────────────────────

class _OverdueWarningCard extends StatelessWidget {
  const _OverdueWarningCard({required this.card});
  final CreditCardSummary card;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: 'L ', decimalDigits: 0);
    final urgent = (card.daysUntilClosedPayment ?? 99) <= 3;
    const color = Color(0xFFEA4335);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Row(
          children: [
            Icon(
              urgent ? Icons.error_outline : Icons.warning_amber_rounded,
              color: color,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urgent ? '¡Pago urgente!' : 'Pago del ciclo anterior',
                    style: const TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${fmt.format(card.overdueBalance)} · '
                    'Vence ${card.closedCyclePaymentDue} '
                    '(${card.daysUntilClosedPayment}d)',
                    style: TextStyle(fontSize: 12, color: color.withAlpha(210)),
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

// ── Card actions ──────────────────────────────────────────────────────────────

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });
  final CreditCardSummary card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar tarjeta'),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEA4335),
              side: const BorderSide(color: Color(0xFFEA4335)),
            ),
            child: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: _networkGradient('other'),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D3748).withAlpha(90),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.credit_card, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin tarjetas registradas',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Agrega tus tarjetas de crédito para llevar control de ciclos de corte y fechas de pago.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Agregar tarjeta'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / edit card sheet ─────────────────────────────────────────────────────

class _AddCardSheet extends ConsumerStatefulWidget {
  const _AddCardSheet({required this.onSaved, this.editCard});
  final VoidCallback onSaved;
  final CreditCardSummary? editCard;

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  String _network = 'other';
  int _cutOffDay = 15;
  int _paymentDueDays = 20;
  bool _saving = false;
  String _limitCurrency = 'HNL';

  static const _networks = {
    'visa': 'Visa',
    'mastercard': 'Mastercard',
    'amex': 'American Express',
    'other': 'Otra red',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.editCard;
    if (e != null) {
      _nameCtrl.text = e.name;
      _network = e.network;
      _cutOffDay = e.cutOffDay;
      _paymentDueDays = e.paymentDueDays;
      if (e.creditLimit != null) {
        _limitCtrl.text = e.creditLimit!.toStringAsFixed(0);
      }
      _limitCurrency = e.limitCurrency;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'network': _network,
        'cutOffDay': _cutOffDay,
        'paymentDueDays': _paymentDueDays,
        if (_limitCtrl.text.isNotEmpty)
          'creditLimit': double.parse(_limitCtrl.text.replaceAll(',', '.')),
        if (_limitCtrl.text.isNotEmpty) 'limitCurrency': _limitCurrency,
      };
      if (widget.editCard != null) {
        await dio.patch(
            '${ApiConstants.creditCards}/${widget.editCard!.id}', data: data);
      } else {
        await dio.post(ApiConstants.creditCards, data: data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
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
    final isEdit = widget.editCard != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Live card preview
              _MiniCardPreview(
                name: _nameCtrl.text.isEmpty ? 'Mi tarjeta' : _nameCtrl.text,
                network: _network,
              ),
              const SizedBox(height: 20),
              Text(
                isEdit ? 'Editar tarjeta' : 'Nueva tarjeta',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la tarjeta',
                  hintText: 'Ej: VISA Atlántida',
                  prefixIcon: Icon(Icons.credit_card_outlined),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _network,
                decoration: const InputDecoration(
                  labelText: 'Red de pago',
                  prefixIcon: Icon(Icons.contactless_outlined),
                ),
                items: _networks.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _network = v ?? 'other'),
              ),
              const SizedBox(height: 20),
              // Día de corte slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Día de corte',
                          style: Theme.of(context).textTheme.labelLarge),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Día $_cutOffDay',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _cutOffDay.toDouble(),
                    min: 1,
                    max: 28,
                    divisions: 27,
                    label: '$_cutOffDay',
                    onChanged: (v) =>
                        setState(() => _cutOffDay = v.round()),
                  ),
                ],
              ),
              // Días para pagar slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Días para pagar',
                          style: Theme.of(context).textTheme.labelLarge),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_paymentDueDays días',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _paymentDueDays.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 25,
                    label: '$_paymentDueDays',
                    onChanged: (v) =>
                        setState(() => _paymentDueDays = v.round()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _limitCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Límite de crédito (opcional)',
                        prefixText: _limitCurrency == 'USD' ? '\$ ' : 'L ',
                        prefixIcon: const Icon(Icons.show_chart),
                        helperText: 'Para mostrar % de utilización',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'HNL', label: Text('L')),
                        ButtonSegment(value: 'USD', label: Text('\$')),
                      ],
                      selected: {_limitCurrency},
                      onSelectionChanged: (v) =>
                          setState(() => _limitCurrency = v.first),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? 'Guardar cambios' : 'Agregar tarjeta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini card preview (inside add sheet) ─────────────────────────────────────

class _MiniCardPreview extends StatelessWidget {
  const _MiniCardPreview({required this.name, required this.network});
  final String name;
  final String network;

  @override
  Widget build(BuildContext context) {
    final gradient = _networkGradient(network);
    return Container(
      height: 84,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withAlpha(90),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            _NetworkLogo(network: network),
          ],
        ),
      ),
    );
  }
}
