import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zentri/features/credit_cards/models/credit_card_model.dart';
import 'package:zentri/features/credit_cards/presentation/screens/credit_cards_screen.dart';

/// Regression test for the "Utilización del crédito" widget always rendering
/// a "$" for both currencies. Root cause: it always computed/formatted the
/// HNL-denominated total, but used `_cardFmt(card.limitCurrency)` — so a
/// USD-limit card showed the HNL figure prefixed with "$".
void main() {
  testWidgets(
    'shows the limit currency amount under its own symbol, not the HNL total',
    (tester) async {
      // USD-limit card with mixed-currency spend: 13,039.28 HNL + 85.24 USD.
      const card = CreditCardSummary(
        id: 'card-1',
        name: 'Tarjeta USD',
        network: 'visa',
        cutOffDay: 15,
        paymentDueDays: 20,
        currentCycleStart: '2026-08-01',
        currentCycleEnd: '2026-08-15',
        nextCutOffDate: '2026-08-15',
        paymentDueDate: '2026-09-04',
        daysUntilCutOff: 5,
        daysUntilPayment: 10,
        currentBalance: 13124.52,
        overdueBalance: 0,
        currentBalanceHNL: 13039.28,
        currentBalanceUSD: 85.24,
        overdueBalanceHNL: 0,
        overdueBalanceUSD: 0,
        paymentStatus: 'no_debt',
        creditLimit: 8000,
        limitCurrency: 'USD',
        utilizationPct: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 700, child: buildUtilizationCardForTest(card)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The USD figure (the limit's own currency) must be shown with "$",
      // and the HNL figure must be shown with its own "L." symbol — never
      // the HNL amount prefixed with "$".
      expect(find.textContaining('\$ 85.24'), findsOneWidget);
      expect(find.textContaining('L. 13,039'), findsOneWidget);
      expect(find.textContaining('\$ 13,039'), findsNothing);
    },
  );
}
