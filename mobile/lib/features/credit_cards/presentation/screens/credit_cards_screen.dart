import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../models/credit_card_model.dart';
import '../../providers/credit_cards_provider.dart';

// ── Provider: expenses for a specific card ────────────────────────────────────

final _cardExpensesProvider =
    FutureProvider.autoDispose.family<List<ExpenseModel>, String>((ref, cardId) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(
    ApiConstants.expenses,
    queryParameters: {'creditCardId': cardId, 'limit': 100},
  );
  final items = resp.data['items'] as List<dynamic>? ?? [];
  return items.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Currency formatter ────────────────────────────────────────────────────────

NumberFormat _cardFmt(String currency) => NumberFormat.currency(
      locale: 'en_US',
      symbol: currency == 'USD' ? '\$ ' : 'L ',
      decimalDigits: currency == 'USD' ? 2 : 0,
    );

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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(creditCardsSummaryProvider);
    final monthRaw = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    final monthTitle = monthRaw[0].toUpperCase() + monthRaw.substring(1);

    // Re-schedule notifications whenever card data updates
    ref.listen<AsyncValue<List<CreditCardSummary>>>(
      creditCardsSummaryProvider,
      (_, next) {
        next.whenData((cards) =>
            NotificationService.instance.rescheduleAll(cards));
      },
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withAlpha(12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () => ref.invalidate(creditCardsSummaryProvider),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8, right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withAlpha(12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Agregar tarjeta',
              onPressed: () => _showAddCardSheet(context),
            ),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(creditCardsSummaryProvider),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return _EmptyState(onAdd: () => _showAddCardSheet(context));
          }
          final card = cards[_selectedIndex.clamp(0, cards.length - 1)];
          // CustomScrollView solves the infinite-width constraint issue.
          // Each SliverToBoxAdapter gives children TIGHT width = viewport width.
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tarjetas',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$monthTitle · ${cards.length} registradas',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Card carousel ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 210,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: cards.length,
                      onPageChanged: (i) => setState(() => _selectedIndex = i),
                      itemBuilder: (_, i) => _CreditCardWidget(
                        card: cards[i],
                        isSelected: i == _selectedIndex,
                      ),
                    ),
                  ),
                ),
              ),
              // ── Page dots ─────────────────────────────────────────
              if (cards.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
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
                  ),
                ),
              // ── Billing cycle ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _BillingCycleDetail(card: card),
                ),
              ),
              // ── Utilization ────────────────────────────────────────
              if (card.creditLimit != null && card.creditLimit! > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _UtilizationCard(card: card),
                  ),
                ),
              // ── Payment status card ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _PaymentStatusCard(
                    card: card,
                  ),
                ),
              ),
              // ── Overdue warning ────────────────────────────────────
              if (card.overdueBalance > 0 && card.paymentStatus != 'paid')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _OverdueWarningCard(card: card),
                  ),
                ),
              // ── Card expenses list ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _CardExpensesSection(
                    card: card,
                    cycleStart: card.currentCycleStart,
                    cycleEnd: card.currentCycleEnd,
                  ),
                ),
              ),
              // ── Card actions ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 80),
                  child: _CardActions(
                    card: card,
                    onEdit: () => _showEditCardSheet(context, card),
                    onDelete: () => _confirmDelete(context, card),
                    onPay: () => _showRegisterPaymentSheet(context, card),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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

  Future<void> _showRegisterPaymentSheet(
      BuildContext context, CreditCardSummary card) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RegisterPaymentSheet(
        card: card,
        onSaved: () {
          ref.invalidate(creditCardsSummaryProvider);
        },
      ),
    );
  }
}

// ── Credit card visual widget ─────────────────────────────────────────────────

class _CreditCardWidget extends StatelessWidget {
  const _CreditCardWidget({required this.card, required this.isSelected});
  final CreditCardSummary card;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final fmt = _cardFmt(card.limitCurrency);
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
                  // Balance — show each currency separately when mixed
                  if (card.currentBalanceUSD > 0) ...[  
                    Text(
                      _cardFmt('HNL').format(card.currentBalanceHNL),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '+ ${_cardFmt('USD').format(card.currentBalanceUSD)}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else
                    Text(
                      fmt.format(card.currentBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Gastado este ciclo',
                        style: TextStyle(
                          color: Colors.white.withAlpha(160),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      _CardStatusBadge(status: card.paymentStatus),
                    ],
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
    final fmt = _cardFmt(card.limitCurrency);
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
            value: card.currentBalanceUSD > 0
                ? '${_cardFmt('HNL').format(card.currentBalanceHNL)}  +  ${_cardFmt('USD').format(card.currentBalanceUSD)}'
                : fmt.format(card.currentBalance),
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
    final fmt = _cardFmt(card.limitCurrency);
    final fmtLimit = fmt;
    final pct = card.utilizationPct ?? 0;
    // Utilization is based on HNL only (USD can't be added without exchange rate)
    final unpaidOverdueHNL = (card.overdueBalanceHNL - (card.closedCyclePaidAmount ?? 0)).clamp(0.0, double.infinity);
    final totalUsedHNL = card.currentBalanceHNL + unpaidOverdueHNL;
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
                  card.currentBalanceUSD > 0
                      ? 'Usado: ${fmt.format(totalUsedHNL)}  +  ${_cardFmt('USD').format(card.currentBalanceUSD)}'
                      : 'Usado: ${fmt.format(totalUsedHNL)}',
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

// ── Payment status badge (on card) ───────────────────────────────────────────

class _CardStatusBadge extends StatelessWidget {
  const _CardStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = switch (status) {
      'paid'    => ('Pagada',    const Color(0xFF34A853), Icons.check_circle_rounded),
      'partial' => ('Parcial',   const Color(0xFFFF9800), Icons.timelapse_rounded),
      'unpaid'  => ('Sin pagar', const Color(0xFFEA4335), Icons.cancel_rounded),
      _         => ('Al día',    const Color(0xFF34A853), Icons.thumb_up_alt_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(130)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 9),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment status card ───────────────────────────────────────────────────────

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({required this.card});
  final CreditCardSummary card;

  String _fmtDate(String d) {
    final parts = d.split('-');
    if (parts.length != 3) return d;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = _cardFmt(card.limitCurrency);
    final theme = Theme.of(context);

    final (label, subtitle, icon, color) = switch (card.paymentStatus) {
      'paid'    => ('Pagada',               'Ciclo anterior cubierto',             Icons.check_circle_rounded,  const Color(0xFF34A853)),
      'partial' => ('Pago parcial',         'Ciclo anterior cubierto parcialmente', Icons.timelapse_rounded,    const Color(0xFFFF9800)),
      'unpaid'  => ('Sin pagar',            'Ciclo anterior pendiente de pago',    Icons.cancel_rounded,        const Color(0xFFEA4335)),
      // no_debt: current cycle is active, nothing is overdue
      _         => card.currentBalance > 0
          ? ('Ciclo activo',    'Ciclo abierto · sin vencimiento aún',  Icons.radio_button_checked, const Color(0xFF5C6BC0))
          : ('Sin deuda',       'No hay gastos ni cobros pendientes',   Icons.thumb_up_alt_rounded,  const Color(0xFF34A853)),
    };

    final relevantDebt = card.overdueBalance > 0 ? card.overdueBalance : 0.0;
    final relevantPaid = card.closedCyclePaidAmount ?? 0.0;
    final coverage = card.paymentCoverage ?? 0;
    final showProgress = relevantDebt > 0 && card.paymentStatus != 'no_debt';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: color,
                              ),
                            ),
                            if (showProgress)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$coverage%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Progress bar + amounts ───────────────────────────────
            if (showProgress) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (coverage / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: color.withAlpha(30),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          relevantPaid > 0
                              ? 'Pagado: ${fmt.format(relevantPaid)}'
                              : 'Sin pagos registrados',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Deuda: ${fmt.format(relevantDebt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (card.lastPaymentDate != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Último pago: ${_fmtDate(card.lastPaymentDate!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: color.withAlpha(190),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (!showProgress) const SizedBox(height: 4),
            // ── Active-cycle payment info (no_debt + lastPayment) ────
            if (card.paymentStatus == 'no_debt' && card.lastPaymentAmount != null) ...[
              Divider(height: 1, color: color.withAlpha(40)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF34A853)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pago registrado en este ciclo: ${fmt.format(card.lastPaymentAmount!)}  ·  ${_fmtDate(card.lastPaymentDate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF34A853),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'El pago se aplicará como "ciclo anterior pagado" cuando este ciclo cierre el ${card.nextCutOffDate}.',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withAlpha(160),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
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
    final fmt = _cardFmt(card.limitCurrency);
    final urgent = (card.daysUntilClosedPayment ?? 99) <= 3;
    const color = Color(0xFFEA4335);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Row(
          children: [
            Icon(
              urgent ? Icons.error_outline : Icons.warning_amber_rounded,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urgent
                        ? '¡Pago urgente! Vence pronto'
                        : 'Ciclo anterior pendiente de pago',
                    style: const TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmt.format(card.overdueBalance)} · '
                    'Vence ${card.closedCyclePaymentDue} '
                    '(${card.daysUntilClosedPayment}d)',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xCFEA4335)),
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
    required this.onPay,
  });
  final CreditCardSummary card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final isPaid = card.paymentStatus == 'paid';
    final isPartial = card.paymentStatus == 'partial';
    final btnLabel = isPaid
        ? 'Registrar otro pago'
        : isPartial
            ? 'Completar pago'
            : 'Registrar pago de tarjeta';
    final btnIcon =
        isPaid || isPartial ? Icons.add_circle_outline : Icons.check_circle_outline;
    final btnColor = isPaid
        ? const Color(0xFF1E7E34)
        : isPartial
            ? const Color(0xFFE65100)
            : const Color(0xFF34A853);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onPay,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: btnColor,
            ),
            icon: Icon(btnIcon, size: 20),
            label: Text(
              btnLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card expenses section ─────────────────────────────────────────────────────

class _CardExpensesSection extends ConsumerWidget {
  const _CardExpensesSection({
    required this.card,
    required this.cycleStart,
    required this.cycleEnd,
  });
  final CreditCardSummary card;
  final String cycleStart;
  final String cycleEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expAsync = ref.watch(_cardExpensesProvider(card.id));
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gastos con esta tarjeta',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'Ciclo: $cycleStart – $cycleEnd',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            expAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error al cargar gastos',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
              data: (expenses) {
                // Current billing cycle
                final cycleExpenses = expenses.where((e) {
                  final d = e.date;
                  return d.compareTo(cycleStart) >= 0 &&
                      d.compareTo(cycleEnd) <= 0;
                }).toList();

                // Previous (closed) billing cycle
                final prevStart = card.closedCycleStart;
                final prevEnd = card.closedCycleEnd;
                final prevExpenses = (prevStart != null && prevEnd != null)
                    ? expenses.where((e) {
                        final d = e.date;
                        return d.compareTo(prevStart) >= 0 &&
                            d.compareTo(prevEnd) <= 0;
                      }).toList()
                    : <ExpenseModel>[];

                if (cycleExpenses.isEmpty && prevExpenses.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Sin gastos en este ciclo',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // ── Current cycle ──────────────────────────────────
                    _ExpenseCycleSection(
                      label: 'Ciclo actual',
                      dateRange: '$cycleStart → $cycleEnd',
                      expenses: cycleExpenses,
                      theme: theme,
                      cardCurrency: card.limitCurrency,
                    ),
                    // ── Previous (closed) cycle ────────────────────────
                    if (prevExpenses.isNotEmpty) ...[
                      const Divider(height: 1, thickness: 1),
                      _ExpenseCycleSection(
                        label: 'Ciclo anterior',
                        dateRange: '$prevStart → $prevEnd',
                        expenses: prevExpenses,
                        theme: theme,
                        cardCurrency: card.limitCurrency,
                        dimmed: true,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expense cycle section ─────────────────────────────────────────────────────

class _ExpenseCycleSection extends StatelessWidget {
  const _ExpenseCycleSection({
    required this.label,
    required this.dateRange,
    required this.expenses,
    required this.theme,
    required this.cardCurrency,
    this.dimmed = false,
  });

  final String label;
  final String dateRange;
  final List<ExpenseModel> expenses;
  final ThemeData theme;
  final String cardCurrency;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final fmt = _cardFmt(cardCurrency);
    final totalHNL = expenses.where((e) => e.currency == 'HNL').fold(0.0, (s, e) => s + e.amount);
    final totalUSD = expenses.where((e) => e.currency == 'USD').fold(0.0, (s, e) => s + e.amount);
    final total = totalHNL + totalUSD;
    final labelColor = dimmed
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;

    return Opacity(
      opacity: dimmed ? 0.75 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Icon(
                  dimmed ? Icons.history_outlined : Icons.credit_card_outlined,
                  size: 14,
                  color: labelColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  dateRange,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Sin gastos en este ciclo',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expenses.length > 5 ? 5 : expenses.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 56, endIndent: 16),
              itemBuilder: (_, i) {
                final e = expenses[i];
                final isEmoji = e.categoryIcon.runes.any((r) => r > 127);
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.expense.withAlpha(dimmed ? 10 : 20),
                    child: isEmoji
                        ? Text(e.categoryIcon,
                            style: const TextStyle(fontSize: 14))
                        : Icon(
                            materialIconFromString(e.categoryIcon),
                            size: 16,
                            color: AppColors.expense,
                          ),
                  ),
                  title: Text(
                    e.description.isEmpty ? e.categoryName : e.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${e.categoryName} · ${DateFormat('dd MMM', 'es').format(DateTime.parse(e.date))}',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: Text(
                    _cardFmt(e.currency).format(e.amount),
                    style: TextStyle(
                      color: dimmed
                          ? theme.colorScheme.onSurfaceVariant
                          : AppColors.expense,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
            if (expenses.length > 5) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '+ ${expenses.length - 5} gastos más',
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${expenses.length} ${expenses.length == 1 ? 'gasto' : 'gastos'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (totalHNL > 0 && totalUSD > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _cardFmt('HNL').format(totalHNL),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dimmed
                                ? theme.colorScheme.onSurfaceVariant
                                : AppColors.expense,
                          ),
                        ),
                        Text(
                          _cardFmt('USD').format(totalUSD),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dimmed
                                ? theme.colorScheme.onSurfaceVariant
                                : AppColors.expense,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Total: ${fmt.format(total)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: dimmed
                            ? theme.colorScheme.onSurfaceVariant
                            : AppColors.expense,
                      ),
                    ),
                ],
              ),
            ),
          ],
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

// ── Register payment sheet ────────────────────────────────────────────────────

class _RegisterPaymentSheet extends ConsumerStatefulWidget {
  const _RegisterPaymentSheet({required this.card, required this.onSaved});
  final CreditCardSummary card;
  final VoidCallback onSaved;

  @override
  ConsumerState<_RegisterPaymentSheet> createState() =>
      _RegisterPaymentSheetState();
}

class _RegisterPaymentSheetState
    extends ConsumerState<_RegisterPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  bool _saving = false;

  CreditCardSummary get card => widget.card;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the remaining HNL amount to pay in the closed cycle.
    // When there's mixed currency debt, only pre-fill the HNL portion.
    final double defaultAmount;
    if (card.overdueBalanceHNL > 0) {
      final paid = card.closedCyclePaidAmount ?? 0;
      final remaining = card.overdueBalanceHNL - paid;
      defaultAmount = remaining > 0 ? remaining : card.overdueBalanceHNL;
    } else {
      defaultAmount = card.currentBalanceHNL;
    }
    if (defaultAmount > 0) {
      _amountCtrl.text = defaultAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _cycleStart =>
      card.closedCycleStart ?? card.currentCycleStart;
  String get _cycleEnd =>
      card.closedCycleEnd ?? card.currentCycleEnd;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Fecha de pago',
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _save() async {
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        ApiConstants.creditCardPayments(card.id),
        data: {
          'amount': amount,
          'paymentDate': _paymentDate.toIso8601String().split('T')[0],
          'cycleStart': _cycleStart,
          'cycleEnd': _cycleEnd,
          if (_notesCtrl.text.trim().isNotEmpty)
            'notes': _notesCtrl.text.trim(),
        },
      );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Pago registrado exitosamente'),
              ],
            ),
            backgroundColor: Color(0xFF34A853),
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
    final fmt = _cardFmt(card.limitCurrency);
    final theme = Theme.of(context);
    final dateStr =
        '${_paymentDate.day.toString().padLeft(2, '0')}/${_paymentDate.month.toString().padLeft(2, '0')}/${_paymentDate.year}';

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
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
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34A853).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF34A853),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registrar pago',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        card.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Cycle info banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withAlpha(120),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 15, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Ciclo: $_cycleStart  →  $_cycleEnd',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (card.overdueBalance > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA4335).withAlpha(14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFEA4335).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 15, color: Color(0xFFEA4335)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        card.overdueBalanceUSD > 0
                            ? 'Deuda: ${fmt.format(card.overdueBalanceHNL)}  +  \$ ${card.overdueBalanceUSD.toStringAsFixed(2)}'
                            : 'Deuda del ciclo cerrado: ${fmt.format(card.overdueBalance)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEA4335),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Amount field (always in HNL — bank payments are in lempiras)
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monto pagado (HNL)',
                hintText: '0',
                prefixIcon: const Icon(Icons.payments_outlined),
                prefixText: 'L ',
                helperText: card.overdueBalanceUSD > 0
                    ? 'Los \$ ${card.overdueBalanceUSD.toStringAsFixed(2)} USD se registran por separado'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de pago',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(dateStr),
              ),
            ),
            const SizedBox(height: 16),
            // Notes (optional)
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Ej: Pago completo vía transferencia',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: const Color(0xFF34A853),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_saving ? 'Guardando…' : 'Confirmar pago'),
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
                initialValue: _network,
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
