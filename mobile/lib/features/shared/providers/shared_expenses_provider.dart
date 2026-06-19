import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/shared_expense_model.dart';

class SharedExpensesRepository {
  SharedExpensesRepository(this._dio);
  final Dio _dio;

  Future<List<SharedExpenseModel>> getGroupExpenses(String groupId) async {
    final resp = await _dio.get(ApiConstants.sharedGroupExpenses(groupId));
    final data = resp.data as List<dynamic>;
    return data.map((e) => SharedExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SharedExpenseModel> createExpense({
    required String groupId,
    required String payerId,
    required double totalAmount,
    required String description,
    required String date,
    required List<Map<String, dynamic>> participants,
    String? paymentMethod,
    String? categoryLabel,
    String? note,
    String? cashAccountId,
    String? receiptUrl,
    bool? isRecurring,
    String? recurringInterval,
    int? recurringDay,
  }) async {
    final resp = await _dio.post(ApiConstants.sharedGroupExpenses(groupId), data: {
      'payerId': payerId,
      'totalAmount': totalAmount,
      'description': description,
      'date': date,
      'participants': participants,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (categoryLabel != null) 'categoryLabel': categoryLabel,
      if (note != null) 'note': note,
      if (cashAccountId != null) 'cashAccountId': cashAccountId,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
      if (isRecurring != null) 'isRecurring': isRecurring,
      if (recurringInterval != null) 'recurringInterval': recurringInterval,
      if (recurringDay != null) 'recurringDay': recurringDay,
    });
    return SharedExpenseModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<SharedExpenseModel> updateExpense({
    required String groupId,
    required String expenseId,
    double? totalAmount,
    String? description,
    String? date,
    List<Map<String, dynamic>>? participants,
    String? paymentMethod,
    String? categoryLabel,
    String? note,
    String? receiptUrl,
    bool? isRecurring,
    String? recurringInterval,
    int? recurringDay,
  }) async {
    final resp = await _dio.patch(
      ApiConstants.sharedGroupExpense(groupId, expenseId),
      data: {
        if (totalAmount != null) 'totalAmount': totalAmount,
        if (description != null) 'description': description,
        if (date != null) 'date': date,
        if (participants != null) 'participants': participants,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (categoryLabel != null) 'categoryLabel': categoryLabel,
        if (note != null) 'note': note,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
        if (isRecurring != null) 'isRecurring': isRecurring,
        if (recurringInterval != null) 'recurringInterval': recurringInterval,
        if (recurringDay != null) 'recurringDay': recurringDay,
      },
    );
    return SharedExpenseModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
  }) async {
    await _dio.delete(ApiConstants.sharedGroupExpense(groupId, expenseId));
  }

  Future<SharedExpenseModel> approveExpense({
    required String groupId,
    required String expenseId,
    String? note,
  }) async {
    final resp = await _dio.patch(
      ApiConstants.sharedGroupExpenseApprove(groupId, expenseId),
      data: {if (note != null) 'note': note},
    );
    return SharedExpenseModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<SharedExpenseModel> rejectExpense({
    required String groupId,
    required String expenseId,
    String? note,
  }) async {
    final resp = await _dio.patch(
      ApiConstants.sharedGroupExpenseReject(groupId, expenseId),
      data: {if (note != null) 'note': note},
    );
    return SharedExpenseModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getGroupStats(String groupId) async {
    final resp = await _dio.get(ApiConstants.sharedGroupStats(groupId));
    return resp.data as Map<String, dynamic>;
  }

  Future<String> exportGroupCsv(String groupId) async {
    // Do NOT use ResponseType.plain — let Dio's unwrap interceptor handle the {data: "..."} wrapper
    final resp = await _dio.get(ApiConstants.sharedGroupExportCsv(groupId));
    final raw = resp.data;
    if (raw is String) return raw;
    if (raw is Map && raw['data'] is String) return raw['data'] as String;
    return raw.toString();
  }

  Future<Map<String, dynamic>> importExpenses({
    required String groupId,
    required List<Map<String, dynamic>> rows,
  }) async {
    final resp = await _dio.post(
      ApiConstants.sharedGroupImport(groupId),
      data: {'rows': rows},
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGroupSettings(String groupId) async {
    final resp = await _dio.get(ApiConstants.sharedGroupSettings(groupId));
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGroupSettings({
    required String groupId,
    bool? requiresApproval,
  }) async {
    final resp = await _dio.patch(
      ApiConstants.sharedGroupSettings(groupId),
      data: {
        if (requiresApproval != null) 'requiresApproval': requiresApproval,
      },
    );
    return resp.data as Map<String, dynamic>;
  }
}

final sharedExpensesRepositoryProvider = Provider<SharedExpensesRepository>((ref) {
  return SharedExpensesRepository(ref.watch(dioProvider));
});

final sharedGroupExpensesProvider =
    FutureProvider.autoDispose.family<List<SharedExpenseModel>, String>((ref, groupId) {
  return ref.watch(sharedExpensesRepositoryProvider).getGroupExpenses(groupId);
});
