import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_latam/features/cash/models/cash_models.dart';

void main() {
  // ──────────────────────────────────────────────────────────────
  // CashAccountModel
  // ──────────────────────────────────────────────────────────────
  group('CashAccountModel', () {
    final fullJson = {
      'id': 'acc-1',
      'name': 'Mi cartera',
      'balance': 34000.50,
      'currency': 'HNL',
      'color': '#1976D2',
      'icon': 'wallet',
      'isDefault': true,
    };

    test('fromJson parses all fields correctly', () {
      final model = CashAccountModel.fromJson(fullJson);

      expect(model.id, 'acc-1');
      expect(model.name, 'Mi cartera');
      expect(model.balance, 34000.50);
      expect(model.currency, 'HNL');
      expect(model.color, '#1976D2');
      expect(model.icon, 'wallet');
      expect(model.isDefault, true);
    });

    test('fromJson uses defaults for missing fields', () {
      final model = CashAccountModel.fromJson({'id': 'acc-2'});

      expect(model.name, 'Cartera');
      expect(model.balance, 0.0);
      expect(model.currency, 'HNL');
      expect(model.color, '#34A853');
      expect(model.icon, 'account_balance_wallet');
      expect(model.isDefault, false);
    });

    test('fromJson parses balance from string', () {
      final model = CashAccountModel.fromJson({'id': 'acc-3', 'balance': '12500.75'});
      expect(model.balance, 12500.75);
    });

    test('fromJson parses balance from int', () {
      final model = CashAccountModel.fromJson({'id': 'acc-4', 'balance': 10000});
      expect(model.balance, 10000.0);
    });

    test('fromJson parses isDefault=false correctly', () {
      final model = CashAccountModel.fromJson({'id': 'acc-5', 'isDefault': false});
      expect(model.isDefault, false);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // CashTransactionModel
  // ──────────────────────────────────────────────────────────────
  group('CashTransactionModel', () {
    final fullJson = {
      'id': 'tx-1',
      'type': 'deposit',
      'amount': 5000.0,
      'description': 'Depósito en efectivo',
      'date': '2026-04-09T14:30:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final model = CashTransactionModel.fromJson(fullJson);

      expect(model.id, 'tx-1');
      expect(model.type, 'deposit');
      expect(model.amount, 5000.0);
      expect(model.description, 'Depósito en efectivo');
      expect(model.date, '2026-04-09'); // truncated to 10 chars
    });

    test('truncates date to YYYY-MM-DD format', () {
      final model = CashTransactionModel.fromJson({
        'id': 'tx-2',
        'date': '2026-12-25T00:00:00.000Z',
      });
      expect(model.date, '2026-12-25');
    });

    test('handles short date string (no truncation needed)', () {
      final model = CashTransactionModel.fromJson({
        'id': 'tx-3',
        'date': '2026-04-09',
      });
      expect(model.date, '2026-04-09');
    });

    test('fromJson uses defaults for missing fields', () {
      final model = CashTransactionModel.fromJson({'id': 'tx-4'});

      expect(model.type, 'deposit');
      expect(model.amount, 0.0);
      expect(model.description, '');
      expect(model.date, '');
    });

    test('parses withdraw type', () {
      final model = CashTransactionModel.fromJson({
        'id': 'tx-5',
        'type': 'withdraw',
        'amount': 1000,
        'date': '2026-04-01',
      });
      expect(model.type, 'withdraw');
    });

    test('fromJson parses amount from string', () {
      final model = CashTransactionModel.fromJson({
        'id': 'tx-6',
        'amount': '750.25',
        'date': '2026-04-01',
      });
      expect(model.amount, 750.25);
    });
  });
}
