import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_latam/features/home/models/dashboard_model.dart';

void main() {
  // ──────────────────────────────────────────────────────────────
  // InsightModel
  // ──────────────────────────────────────────────────────────────
  group('InsightModel', () {
    final baseJson = {
      'id': 'insight-1',
      'title': 'Gasto inusual en Restaurantes',
      'body': 'Gastaste 2.5x más que la semana pasada.',
      'type': 'anomaly',
      'priority': 'high',
      'isRead': false,
      'isDismissed': false,
      'generatedAt': '2026-04-09T10:00:00Z',
    };

    test('fromJson parses all fields correctly', () {
      final model = InsightModel.fromJson(baseJson);

      expect(model.id, 'insight-1');
      expect(model.title, 'Gasto inusual en Restaurantes');
      expect(model.body, 'Gastaste 2.5x más que la semana pasada.');
      expect(model.type, 'anomaly');
      expect(model.priority, 'high');
      expect(model.isRead, false);
      expect(model.isDismissed, false);
      expect(model.generatedAt, '2026-04-09T10:00:00Z');
    });

    test('fromJson uses default values for nullable fields', () {
      final model = InsightModel.fromJson({'id': 'x'});

      expect(model.title, '');
      expect(model.body, '');
      expect(model.type, 'projection');
      expect(model.priority, 'medium');
      expect(model.isRead, false);
      expect(model.isDismissed, false);
      expect(model.generatedAt, isNull);
    });

    test('copyWith updates isRead only', () {
      final original = InsightModel.fromJson(baseJson);
      final updated = original.copyWith(isRead: true);

      expect(updated.isRead, true);
      expect(updated.id, original.id);
      expect(updated.title, original.title);
      expect(updated.isDismissed, original.isDismissed);
    });

    test('copyWith without argument keeps original isRead', () {
      final original = InsightModel.fromJson(baseJson);
      final copy = original.copyWith();

      expect(copy.isRead, original.isRead);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // DashboardModel
  // ──────────────────────────────────────────────────────────────
  group('DashboardModel', () {
    final dashboardJson = {
      'currentPeriod': {'start': '2026-04-01', 'end': '2026-04-30'},
      'daysRemaining': 21,
      'totalSpentThisPeriod': 5000,
      'totalIncomeThisPeriod': 20000,
      'availableBalance': 15000,
      'safeDailySpend': 714.28,
      'riskLevel': 'green',
      'cashRunoutDate': null,
    };

    final summaryJson = {
      'categories': [
        {
          'categoryName': 'Comida',
          'amount': 3000,
          'total': '3000',
          'icon': '🍔',
        },
        {
          'categoryName': 'Transporte',
          'amount': 2000,
          'total': '2000',
          'icon': '🚗',
        },
      ],
      'grandTotal': 5000,
    };

    test('fromJson parses dashboard fields correctly', () {
      final model = DashboardModel.fromJson(dashboardJson);

      expect(model.periodStart, '2026-04-01');
      expect(model.periodEnd, '2026-04-30');
      expect(model.daysRemaining, 21);
      expect(model.totalExpenses, 5000.0);
      expect(model.totalIncome, 20000.0);
      expect(model.balance, 15000.0);
      expect(model.safeDailySpend, closeTo(714.28, 0.01));
      expect(model.riskLevel, 'green');
      expect(model.cashRunoutDate, isNull);
    });

    test('fromJson parses topCategories from summaryData', () {
      final model = DashboardModel.fromJson(dashboardJson, summaryData: summaryJson);

      expect(model.topCategories.length, 2);
      expect(model.topCategories.first.name, 'Comida');
      expect(model.topCategories.first.amount, 3000.0);
      expect(model.topCategories.first.percentage, closeTo(0.6, 0.001));
    });

    test('category percentage sums to 1.0', () {
      final model = DashboardModel.fromJson(dashboardJson, summaryData: summaryJson);
      final totalPct = model.topCategories.fold<double>(0, (s, c) => s + c.percentage);
      expect(totalPct, closeTo(1.0, 0.001));
    });

    test('fromJson handles missing summaryData gracefully', () {
      final model = DashboardModel.fromJson(dashboardJson);

      expect(model.topCategories, isEmpty);
      expect(model.recentExpenses, isEmpty);
    });

    test('fromJson starts with empty insights list', () {
      final model = DashboardModel.fromJson(dashboardJson);
      expect(model.insights, isEmpty);
    });

    test('riskLevel correctly mapped as red', () {
      final redJson = Map<String, dynamic>.from(dashboardJson)
        ..['riskLevel'] = 'red';
      final model = DashboardModel.fromJson(redJson);
      expect(model.riskLevel, 'red');
    });

    test('cashRunoutDate populated when backend sets it', () {
      final withRunout = Map<String, dynamic>.from(dashboardJson)
        ..['cashRunoutDate'] = '2026-04-20';
      final model = DashboardModel.fromJson(withRunout);
      expect(model.cashRunoutDate, '2026-04-20');
    });

    test('fromJson defaults when json is empty', () {
      final model = DashboardModel.fromJson({});

      expect(model.periodStart, '');
      expect(model.periodEnd, '');
      expect(model.daysRemaining, 0);
      expect(model.totalExpenses, 0.0);
      expect(model.riskLevel, 'green');
    });
  });
}
