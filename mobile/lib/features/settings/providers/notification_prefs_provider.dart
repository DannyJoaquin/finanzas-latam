import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class NotificationPreferencesModel {
  final bool pushBudgetAlerts;
  final bool pushDailyReminder;
  final bool pushWeeklySummary;
  final bool pushImportantInsights;
  final bool pushCriticalFinancialAlerts;
  final bool pushMotivation;
  final bool localCardCutoffAlerts;
  final bool localCardDue5d;
  final bool localCardDue1d;
  final bool localCardPendingBalance;
  final bool inappSavingsOpportunities;
  final bool inappPatterns;
  final bool inappMotivation;

  const NotificationPreferencesModel({
    required this.pushBudgetAlerts,
    required this.pushDailyReminder,
    required this.pushWeeklySummary,
    required this.pushImportantInsights,
    required this.pushCriticalFinancialAlerts,
    required this.pushMotivation,
    required this.localCardCutoffAlerts,
    required this.localCardDue5d,
    required this.localCardDue1d,
    required this.localCardPendingBalance,
    required this.inappSavingsOpportunities,
    required this.inappPatterns,
    required this.inappMotivation,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    bool b(String key, {bool def = true}) =>
        json[key] == null ? def : json[key] as bool;
    return NotificationPreferencesModel(
      pushBudgetAlerts: b('pushBudgetAlerts'),
      pushDailyReminder: b('pushDailyReminder'),
      pushWeeklySummary: b('pushWeeklySummary'),
      pushImportantInsights: b('pushImportantInsights'),
      pushCriticalFinancialAlerts: b('pushCriticalFinancialAlerts'),
      pushMotivation: b('pushMotivation', def: false),
      localCardCutoffAlerts: b('localCardCutoffAlerts'),
      localCardDue5d: b('localCardDue5d'),
      localCardDue1d: b('localCardDue1d'),
      localCardPendingBalance: b('localCardPendingBalance'),
      inappSavingsOpportunities: b('inappSavingsOpportunities'),
      inappPatterns: b('inappPatterns'),
      inappMotivation: b('inappMotivation'),
    );
  }

  NotificationPreferencesModel copyWith({
    bool? pushBudgetAlerts,
    bool? pushDailyReminder,
    bool? pushWeeklySummary,
    bool? pushImportantInsights,
    bool? pushCriticalFinancialAlerts,
    bool? pushMotivation,
    bool? localCardCutoffAlerts,
    bool? localCardDue5d,
    bool? localCardDue1d,
    bool? localCardPendingBalance,
    bool? inappSavingsOpportunities,
    bool? inappPatterns,
    bool? inappMotivation,
  }) {
    return NotificationPreferencesModel(
      pushBudgetAlerts: pushBudgetAlerts ?? this.pushBudgetAlerts,
      pushDailyReminder: pushDailyReminder ?? this.pushDailyReminder,
      pushWeeklySummary: pushWeeklySummary ?? this.pushWeeklySummary,
      pushImportantInsights:
          pushImportantInsights ?? this.pushImportantInsights,
      pushCriticalFinancialAlerts:
          pushCriticalFinancialAlerts ?? this.pushCriticalFinancialAlerts,
      pushMotivation: pushMotivation ?? this.pushMotivation,
      localCardCutoffAlerts:
          localCardCutoffAlerts ?? this.localCardCutoffAlerts,
      localCardDue5d: localCardDue5d ?? this.localCardDue5d,
      localCardDue1d: localCardDue1d ?? this.localCardDue1d,
      localCardPendingBalance:
          localCardPendingBalance ?? this.localCardPendingBalance,
      inappSavingsOpportunities:
          inappSavingsOpportunities ?? this.inappSavingsOpportunities,
      inappPatterns: inappPatterns ?? this.inappPatterns,
      inappMotivation: inappMotivation ?? this.inappMotivation,
    );
  }

  Map<String, dynamic> toJsonPatch() => {
        'pushBudgetAlerts': pushBudgetAlerts,
        'pushDailyReminder': pushDailyReminder,
        'pushWeeklySummary': pushWeeklySummary,
        'pushImportantInsights': pushImportantInsights,
        'pushCriticalFinancialAlerts': pushCriticalFinancialAlerts,
        'pushMotivation': pushMotivation,
        'localCardCutoffAlerts': localCardCutoffAlerts,
        'localCardDue5d': localCardDue5d,
        'localCardDue1d': localCardDue1d,
        'localCardPendingBalance': localCardPendingBalance,
        'inappSavingsOpportunities': inappSavingsOpportunities,
        'inappPatterns': inappPatterns,
        'inappMotivation': inappMotivation,
      };
}

// ── State notifier ─────────────────────────────────────────────────────────

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferencesModel> {
  @override
  Future<NotificationPreferencesModel> build() async {
    final dio = ref.watch(dioProvider);
    final resp = await dio.get(ApiConstants.notificationPreferences);
    return NotificationPreferencesModel.fromJson(
      resp.data as Map<String, dynamic>,
    );
  }

  Future<void> toggle(Map<String, dynamic> patch) async {
    final prev = state.valueOrNull;
    if (prev == null) return;
    final dio = ref.read(dioProvider);
    try {
      final resp = await dio.patch(
        ApiConstants.notificationPreferences,
        data: patch,
      );
      state = AsyncData(
        NotificationPreferencesModel.fromJson(
          resp.data as Map<String, dynamic>,
        ),
      );
    } on DioException {
      // Restore previous state on failure
      state = AsyncData(prev);
      rethrow;
    }
  }
}

final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPreferencesNotifier,
        NotificationPreferencesModel>(
  NotificationPreferencesNotifier.new,
);
