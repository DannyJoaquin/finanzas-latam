import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/cash_models.dart';

final cashAccountsProvider =
    FutureProvider.autoDispose<List<CashAccountModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.cashAccounts);
  final items = resp.data as List<dynamic>? ?? [];
  return items
      .map((e) => CashAccountModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final cashTransactionsProvider = FutureProvider.autoDispose
    .family<List<CashTransactionModel>, String>((ref, accountId) async {
  final dio = ref.watch(dioProvider);
  final resp =
      await dio.get('${ApiConstants.cashAccounts}/$accountId/transactions');
  final items = resp.data as List<dynamic>? ?? [];
  return items
      .map((e) => CashTransactionModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
