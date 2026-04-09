import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';

// Maps Material icon name strings (from backend) to IconData
IconData materialIconFromString(String name) {
  const map = <String, IconData>{
    'restaurant': Icons.restaurant,
    'local_restaurant': Icons.restaurant,
    'local_cafe': Icons.local_cafe,
    'coffee': Icons.coffee,
    'delivery_dining': Icons.delivery_dining,
    'shopping_cart': Icons.shopping_cart,
    'directions_car': Icons.directions_car,
    'local_gas_station': Icons.local_gas_station,
    'directions_bus': Icons.directions_bus,
    'home': Icons.home,
    'house': Icons.house,
    'local_hospital': Icons.local_hospital,
    'healing': Icons.healing,
    'medical_services': Icons.medical_services,
    'school': Icons.school,
    'sports_esports': Icons.sports_esports,
    'movie': Icons.movie,
    'music_note': Icons.music_note,
    'smartphone': Icons.smartphone,
    'laptop': Icons.laptop,
    'wifi': Icons.wifi,
    'flight': Icons.flight,
    'hotel': Icons.hotel,
    'fitness_center': Icons.fitness_center,
    'pets': Icons.pets,
    'checkroom': Icons.checkroom,
    'shopping_bag': Icons.shopping_bag,
    'savings': Icons.savings,
    'trending_up': Icons.trending_up,
    'attach_money': Icons.attach_money,
    'work': Icons.work,
    'business': Icons.business,
    'celebration': Icons.celebration,
    'card_giftcard': Icons.card_giftcard,
    'volunteer_activism': Icons.volunteer_activism,
    'more_horiz': Icons.more_horiz,
    'category': Icons.category,
    'receipt': Icons.receipt,
    'payment': Icons.payment,
    'account_balance': Icons.account_balance,
    'water_drop': Icons.water_drop,
    'bolt': Icons.bolt,
    'phone': Icons.phone,
    'child_care': Icons.child_care,
    'local_pharmacy': Icons.local_pharmacy,
    'spa': Icons.spa,
  };
  return map[name] ?? Icons.label_outline;
}

// ── Model ─────────────────────────────────────────────────────────────────────
class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.paymentMethod,
  });

  final String id;
  final double amount;
  final String description;
  final String date;
  final String? categoryId;
  final String categoryName;
  final String categoryIcon;
  final String paymentMethod;

  factory ExpenseModel.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    return ExpenseModel(
      id: j['id'] as String,
      amount: double.parse((j['amount'] ?? 0).toString()),
      description: j['description'] as String? ?? '',
      date: (j['date'] as String).substring(0, 10),
      categoryId: cat?['id'] as String?,
      categoryName: cat?['name'] as String? ?? '',
      categoryIcon: cat?['icon'] as String? ?? '💰',
      paymentMethod: j['paymentMethod'] as String? ?? 'cash',
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final expensesProvider = FutureProvider.autoDispose<List<ExpenseModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.expenses, queryParameters: {'limit': 50});
  final items = resp.data['items'] as List<dynamic>? ?? [];
  return items.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Category provider (for the add expense form) ─────────────────────────────
class CategoryOption {
  const CategoryOption({required this.id, required this.name, required this.iconName, this.parentName});
  final String id;
  final String name;
  final String iconName; // Material icon name string from backend
  final String? parentName;

  IconData get iconData => materialIconFromString(iconName);

  factory CategoryOption.fromJson(Map<String, dynamic> j, {String? parentName}) => CategoryOption(
        id: j['id'] as String,
        name: j['name'] as String,
        iconName: j['icon'] as String? ?? 'category',
        parentName: parentName,
      );
}

final categoriesProvider = FutureProvider.autoDispose<List<CategoryOption>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.categories);
  final raw = resp.data as List<dynamic>? ?? [];
  final result = <CategoryOption>[];
  // Backend returns hierarchical categories (parent + children).
  // Flatten: include parents + children of type 'expense'.
  for (final item in raw) {
    final m = item as Map<String, dynamic>;
    final parentName = m['name'] as String;
    final children = m['children'] as List<dynamic>? ?? [];
    if (children.isEmpty) {
      // leaf node with no children — include if expense type
      if ((m['type'] as String?) == 'expense') {
        result.add(CategoryOption.fromJson(m));
      }
    } else {
      // add subcategories (children)
      for (final child in children) {
        final c = child as Map<String, dynamic>;
        if ((c['type'] as String?) == 'expense') {
          result.add(CategoryOption.fromJson(c, parentName: parentName));
        }
      }
    }
  }
  return result;
});
