import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/dashboard_model.dart';

class DashboardRepository {
  const DashboardRepository(this._dio);
  final Dio _dio;

  Future<DashboardModel> getDashboard() async {
    // Fetch dashboard first to get the current period dates
    final dashResp = await _dio.get(ApiConstants.dashboard);
    final dashData = dashResp.data as Map<String, dynamic>;
    final period = dashData['currentPeriod'] as Map<String, dynamic>? ?? {};
    final periodStart = period['start'] as String?;
    final periodEnd = period['end'] as String?;

    // Build query params from the current period
    final summaryParams = <String, String>{
      if (periodStart != null) 'startDate': periodStart,
      if (periodEnd != null) 'endDate': periodEnd,
    };

    // Then fetch summary (with period dates) and recent expenses in parallel
    final results = await Future.wait([
      _dio.get(ApiConstants.expensesSummary, queryParameters: summaryParams),
      _dio.get(ApiConstants.expenses, queryParameters: {'limit': 5, 'page': 1}),
    ]);

    final summaryData = results[0].data as Map<String, dynamic>? ?? {};
    final expensesData = results[1].data as Map<String, dynamic>? ?? {};

    return DashboardModel.fromJson(dashData, summaryData: summaryData, expensesData: expensesData);
  }

  /// Regenerate insights in the background (fire-and-forget).
  /// Called once when the dashboard loads so that stale insights get auto-dismissed
  /// without blocking the insights fetch or interfering with dismiss-all.
  void triggerRegenerate() {
    _dio.post(ApiConstants.insightsRegenerate).ignore();
  }

  Future<List<InsightModel>> getInsights() async {
    final resp = await _dio.get(ApiConstants.insights);
    final items = resp.data as List<dynamic>? ?? [];
    return items
        .map((e) => InsightModel.fromJson(e as Map<String, dynamic>))
        .where((i) => !i.isDismissed)
        .toList();
  }

  /// Fetches ALL achievements and streaks, including those already dismissed.
  /// Used by the achievements trophy-case screen.
  Future<List<InsightModel>> getAchievements() async {
    final resp = await _dio.get(ApiConstants.insightsAchievements);
    final items = resp.data as List<dynamic>? ?? [];
    return items
        .map((e) => InsightModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markInsightRead(String id) async {
    await _dio.patch('${ApiConstants.insights}/$id/read');
  }

  Future<void> dismissInsight(String id) async {
    await _dio.delete('${ApiConstants.insights}/$id');
  }

  Future<void> dismissAllInsights() async {
    await _dio.delete('${ApiConstants.insights}/dismiss-all');
  }
}

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository(ref.watch(dioProvider)));

/// Throttle: only call triggerRegenerate() once every 4 hours across navigations.
DateTime? _lastRegenerateAt;

final dashboardProvider = FutureProvider.autoDispose<DashboardModel>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  // Trigger background regeneration at most once every 4 hours so that a
  // dismiss-all is not immediately undone when the user navigates back to home.
  final now = DateTime.now();
  if (_lastRegenerateAt == null ||
      now.difference(_lastRegenerateAt!) > const Duration(hours: 4)) {
    _lastRegenerateAt = now;
    repo.triggerRegenerate();
  }
  return repo.getDashboard();
});

final insightsProvider = FutureProvider.autoDispose<List<InsightModel>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getInsights();
});

/// All achievements + streaks including dismissed ones — for the trophy-case screen.
final achievementsProvider = FutureProvider.autoDispose<List<InsightModel>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getAchievements();
});
