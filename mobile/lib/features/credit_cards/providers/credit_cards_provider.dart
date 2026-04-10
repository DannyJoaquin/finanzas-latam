import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/credit_card_model.dart';

final creditCardsProvider = FutureProvider.autoDispose<List<CreditCardModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.creditCards);
  final items = resp.data as List<dynamic>? ?? [];
  return items
      .map((e) => CreditCardModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final creditCardsSummaryProvider =
    FutureProvider.autoDispose<List<CreditCardSummary>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.creditCardsSummary);
  final items = resp.data as List<dynamic>? ?? [];
  return items
      .map((e) => CreditCardSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});
