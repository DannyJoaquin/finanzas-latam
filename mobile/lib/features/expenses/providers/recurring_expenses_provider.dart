import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';

String _dateOnly(dynamic value) {
  final raw = value?.toString() ?? '';
  return raw.length >= 10 ? raw.substring(0, 10) : raw;
}

class RecurringExpenseModel {
  const RecurringExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.paymentMethod,
    required this.frequency,
    required this.executionDay,
    required this.startDate,
    required this.nextRunDate,
    required this.isActive,
    this.cashAccountId,
    this.cashAccountName,
    this.creditCardId,
    this.creditCardName,
    this.notes,
    this.lastGeneratedDate,
    this.lastGenerationError,
  });

  final String id;
  final String name;
  final double amount;
  final String currency;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String paymentMethod;
  final String? cashAccountId;
  final String? cashAccountName;
  final String? creditCardId;
  final String? creditCardName;
  final String? notes;
  final String frequency;
  final int executionDay;
  final String startDate;
  final String nextRunDate;
  final String? lastGeneratedDate;
  final bool isActive;
  final String? lastGenerationError;

  String get accountName =>
      cashAccountName ?? creditCardName ?? paymentMethodLabel(paymentMethod);

  factory RecurringExpenseModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final cashAccount = json['cashAccount'] as Map<String, dynamic>?;
    final creditCard = json['creditCard'] as Map<String, dynamic>?;

    return RecurringExpenseModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      currency: json['currency'] as String? ?? 'HNL',
      categoryId:
          json['categoryId'] as String? ?? category?['id'] as String? ?? '',
      categoryName: category?['name'] as String? ?? 'Sin categoría',
      categoryIcon: category?['icon'] as String? ?? 'category',
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      cashAccountId: json['cashAccountId'] as String?,
      cashAccountName: cashAccount?['name'] as String?,
      creditCardId: json['creditCardId'] as String?,
      creditCardName: creditCard?['name'] as String?,
      notes: json['notes'] as String?,
      frequency: json['frequency'] as String? ?? 'monthly',
      executionDay: (json['executionDay'] as num?)?.toInt() ?? 1,
      startDate: _dateOnly(json['startDate']),
      nextRunDate: _dateOnly(json['nextRunDate']),
      lastGeneratedDate: json['lastGeneratedDate'] == null
          ? null
          : _dateOnly(json['lastGeneratedDate']),
      isActive: json['isActive'] as bool? ?? true,
      lastGenerationError: json['lastGenerationError'] as String?,
    );
  }
}

String frequencyLabel(String value) {
  switch (value) {
    case 'daily':
      return 'Diario';
    case 'weekly':
      return 'Semanal';
    case 'biweekly':
      return 'Quincenal';
    case 'monthly':
      return 'Mensual';
    case 'bimonthly':
      return 'Cada 2 meses';
    case 'quarterly':
      return 'Trimestral';
    case 'semiannual':
      return 'Semestral';
    case 'annual':
      return 'Anual';
    default:
      return value;
  }
}

String paymentMethodLabel(String value) {
  switch (value) {
    case 'cash':
      return 'Efectivo';
    case 'card_debit':
      return 'Tarjeta débito';
    case 'card_credit':
      return 'Tarjeta crédito';
    case 'transfer':
      return 'Transferencia';
    case 'other':
      return 'Otro';
    default:
      return value;
  }
}

class RecurringExpensesRepository {
  RecurringExpensesRepository(this._dio);
  final Dio _dio;

  Future<List<RecurringExpenseModel>> getAll() async {
    final response = await _dio.get(ApiConstants.recurringExpenses);
    final items = response.data as List<dynamic>? ?? [];
    return items
        .map((item) =>
            RecurringExpenseModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _dio.post(ApiConstants.recurringExpenses, data: data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _dio.patch(ApiConstants.recurringExpense(id), data: data);
  }

  Future<void> delete(String id) async {
    await _dio.delete(ApiConstants.recurringExpense(id));
  }
}

final recurringExpensesRepositoryProvider =
    Provider<RecurringExpensesRepository>((ref) {
  return RecurringExpensesRepository(ref.watch(dioProvider));
});

final recurringExpensesProvider =
    FutureProvider.autoDispose<List<RecurringExpenseModel>>((ref) async {
  return ref.watch(recurringExpensesRepositoryProvider).getAll();
});
