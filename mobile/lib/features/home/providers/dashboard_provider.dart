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

  Future<List<InsightModel>> getInsights() async {
    final resp = await _dio.get(ApiConstants.insights);
    final items = resp.data as List<dynamic>? ?? [];
    return items
        .map((e) => InsightModel.fromJson(e as Map<String, dynamic>))
        .where((i) => !i.isDismissed)
        .toList();
  }

  Future<void> markInsightRead(String id) async {
    await _dio.patch('${ApiConstants.insights}/$id/read');
  }

  Future<void> dismissInsight(String id) async {
    await _dio.delete('${ApiConstants.insights}/$id');
  }
}

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository(ref.watch(dioProvider)));

final dashboardProvider = FutureProvider.autoDispose<DashboardModel>((ref) {
  return ref.watch(dashboardRepositoryProvider).getDashboard();
});

final insightsProvider = FutureProvider.autoDispose<List<InsightModel>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getInsights();
});
