import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/shared_group_model.dart';
import '../models/shared_balance_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class SharedGroupsRepository {
  SharedGroupsRepository(this._dio);
  final Dio _dio;

  Future<List<SharedGroupModel>> getGroups() async {
    final resp = await _dio.get(ApiConstants.sharedGroups);
    final data = resp.data as List<dynamic>;
    return data.map((e) => SharedGroupModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SharedGroupModel> getGroup(String id) async {
    final resp = await _dio.get(ApiConstants.sharedGroupDetail(id));
    return SharedGroupModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<SharedGroupModel> createGroup({
    required String name,
    String? description,
    String currency = 'HNL',
  }) async {
    final resp = await _dio.post(ApiConstants.sharedGroups, data: {
      'name': name,
      if (description != null) 'description': description,
      'currency': currency,
    });
    return SharedGroupModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<SharedGroupModel> joinGroup(String code) async {
    final resp = await _dio.post(ApiConstants.sharedGroupsJoin, data: {'code': code});
    return SharedGroupModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> leaveGroup(String id) async {
    await _dio.delete(ApiConstants.sharedGroupLeave(id));
  }

  Future<void> deleteGroup(String id) async {
    await _dio.delete(ApiConstants.sharedGroupDetail(id));
  }

  Future<GroupBalanceSummaryModel> getGroupBalances(String id) async {
    final resp = await _dio.get(ApiConstants.sharedGroupBalances(id));
    return GroupBalanceSummaryModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<SharedWidgetSummaryModel> getWidgetSummary() async {
    final resp = await _dio.get(ApiConstants.sharedGroupsWidgetSummary);
    return SharedWidgetSummaryModel.fromJson(resp.data as Map<String, dynamic>);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final sharedGroupsRepositoryProvider = Provider<SharedGroupsRepository>((ref) {
  return SharedGroupsRepository(ref.watch(dioProvider));
});

final sharedGroupsProvider = FutureProvider.autoDispose<List<SharedGroupModel>>((ref) {
  return ref.watch(sharedGroupsRepositoryProvider).getGroups();
});

final sharedGroupDetailProvider =
    FutureProvider.autoDispose.family<SharedGroupModel, String>((ref, id) {
  return ref.watch(sharedGroupsRepositoryProvider).getGroup(id);
});

final sharedGroupBalancesProvider =
    FutureProvider.autoDispose.family<GroupBalanceSummaryModel, String>((ref, groupId) {
  return ref.watch(sharedGroupsRepositoryProvider).getGroupBalances(groupId);
});

final sharedWidgetSummaryProvider =
    FutureProvider.autoDispose<SharedWidgetSummaryModel>((ref) {
  return ref.watch(sharedGroupsRepositoryProvider).getWidgetSummary();
});
