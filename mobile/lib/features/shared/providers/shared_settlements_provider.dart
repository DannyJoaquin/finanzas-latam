import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/shared_settlement_model.dart';

class SharedSettlementsRepository {
  SharedSettlementsRepository(this._dio);
  final Dio _dio;

  Future<List<SharedSettlementModel>> getGroupSettlements(String groupId) async {
    final resp = await _dio.get(ApiConstants.sharedGroupSettlements(groupId));
    final data = resp.data as List<dynamic>;
    return data.map((e) => SharedSettlementModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SharedSettlementModel> createSettlement({
    required String groupId,
    required String receiverId,
    required double amount,
    required String date,
    String? paymentMethod,
    String? note,
    String? payerCashAccountId,
  }) async {
    final resp = await _dio.post(ApiConstants.sharedGroupSettlements(groupId), data: {
      'receiverId': receiverId,
      'amount': amount,
      'date': date,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (note != null) 'note': note,
      if (payerCashAccountId != null) 'payerCashAccountId': payerCashAccountId,
    });
    return SharedSettlementModel.fromJson(resp.data as Map<String, dynamic>);
  }
}

final sharedSettlementsRepositoryProvider = Provider<SharedSettlementsRepository>((ref) {
  return SharedSettlementsRepository(ref.watch(dioProvider));
});

final sharedGroupSettlementsProvider =
    FutureProvider.autoDispose.family<List<SharedSettlementModel>, String>((ref, groupId) {
  return ref.watch(sharedSettlementsRepositoryProvider).getGroupSettlements(groupId);
});
