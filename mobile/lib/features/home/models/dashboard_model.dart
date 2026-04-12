class InsightModel {
  const InsightModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    required this.isRead,
    required this.isDismissed,
    this.generatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;     // anomaly | projection | pattern | savings_opportunity | budget_warning
  final String priority; // low | medium | high | critical
  final bool isRead;
  final bool isDismissed;
  final String? generatedAt;

  factory InsightModel.fromJson(Map<String, dynamic> j) => InsightModel(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        type: j['type'] as String? ?? 'projection',
        priority: j['priority'] as String? ?? 'medium',
        isRead: j['isRead'] as bool? ?? false,
        isDismissed: j['isDismissed'] as bool? ?? false,
        generatedAt: j['generatedAt'] as String?,
      );

  InsightModel copyWith({bool? isRead}) => InsightModel(
        id: id,
        title: title,
        body: body,
        type: type,
        priority: priority,
        isRead: isRead ?? this.isRead,
        isDismissed: isDismissed,
        generatedAt: generatedAt,
      );
}

class DashboardModel {
  const DashboardModel({
    required this.periodStart,
    required this.periodEnd,
    required this.daysRemaining,
    required this.totalExpenses,
    required this.totalIncome,
    required this.totalBudgeted,
    required this.balance,
    required this.safeDailySpend,
    required this.riskLevel,
    required this.cashRunoutDate,
    required this.topCategories,
    required this.recentExpenses,
    required this.insights,
    this.creditCardTotal = 0,
    this.creditCardTotalUSD = 0,
  });

  final String periodStart;
  final String periodEnd;
  final int daysRemaining;
  final double totalExpenses;
  final double totalIncome;
  final double totalBudgeted;
  final double balance;
  final double safeDailySpend;
  final String riskLevel; // green | yellow | red
  final String? cashRunoutDate;
  final List<CategorySpend> topCategories;
  final List<RecentExpense> recentExpenses;
  final List<InsightModel> insights;
  final double creditCardTotal;
  final double creditCardTotalUSD;

  factory DashboardModel.fromJson(
    Map<String, dynamic> j, {
    Map<String, dynamic>? summaryData,
    Map<String, dynamic>? expensesData,
  }) {
    final period = j['currentPeriod'] as Map<String, dynamic>? ?? {};

    // Parse topCategories from expenses/summary
    final cats = summaryData?['categories'] as List<dynamic>? ?? [];
    final grandTotal = (summaryData?['grandTotal'] as num? ?? 0).toDouble();
    final topCategories = cats.map((e) {
      final m = e as Map<String, dynamic>;
      final amount = double.parse((m['amount'] ?? m['total'] ?? 0).toString());
      return CategorySpend(
        name: m['name'] as String? ?? m['categoryName'] as String? ?? '',
        amount: amount,
        icon: m['icon'] as String? ?? '💰',
        percentage: grandTotal > 0 ? amount / grandTotal : 0,
      );
    }).toList();

    // Parse recentExpenses from expenses list
    final expItems = (expensesData?['items'] as List<dynamic>?) ?? [];
    final recentExpenses = expItems.map((e) {
      final m = e as Map<String, dynamic>;
      final cat = m['category'] as Map<String, dynamic>?;
      return RecentExpense(
        id: m['id'] as String,
        description: m['description'] as String? ?? '',
        amount: double.parse((m['amount'] ?? 0).toString()),
        date: (m['date'] as String? ?? '').substring(0, 10.clamp(0, (m['date'] as String? ?? '').length)),
        categoryName: cat?['name'] as String? ?? '',
        categoryIcon: cat?['icon'] as String? ?? '💰',
        categoryIconIsEmoji: false,
      );
    }).toList();

    return DashboardModel(
      periodStart: period['start'] as String? ?? '',
      periodEnd: period['end'] as String? ?? '',
      daysRemaining: j['daysRemaining'] as int? ?? 0,
      totalExpenses: double.parse((j['totalSpentThisPeriod'] ?? 0).toString()),
      totalIncome: double.parse((j['totalIncomeThisPeriod'] ?? 0).toString()),
      totalBudgeted: 0,
      balance: double.parse((j['availableBalance'] ?? 0).toString()),
      safeDailySpend: double.parse((j['safeDailySpend'] ?? 0).toString()),
      riskLevel: j['riskLevel'] as String? ?? 'green',
      cashRunoutDate: j['cashRunoutDate'] as String?,
      topCategories: topCategories,
      recentExpenses: recentExpenses,
      insights: const <InsightModel>[],
      creditCardTotal: double.parse((j['creditCardTotal'] ?? 0).toString()),
      creditCardTotalUSD: double.parse((j['creditCardTotalUSD'] ?? 0).toString()),
    );
  }
}

class CategorySpend {
  const CategorySpend({required this.name, required this.amount, required this.icon, this.percentage = 0});
  final String name;
  final double amount;
  final String icon; // Material icon name OR emoji
  final double percentage;

  factory CategorySpend.fromJson(Map<String, dynamic> j) => CategorySpend(
        name: j['name'] as String,
        amount: double.parse((j['amount'] ?? j['total'] ?? 0).toString()),
        icon: j['icon'] as String? ?? '💰',
      );
}

class RecentExpense {
  const RecentExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.categoryName,
    required this.categoryIcon,
    this.categoryIconIsEmoji = true,
  });
  final String id;
  final String description;
  final double amount;
  final String date;
  final String categoryName;
  final String categoryIcon;
  final bool categoryIconIsEmoji; // false = Material icon name

  factory RecentExpense.fromJson(Map<String, dynamic> j) => RecentExpense(
        id: j['id'] as String,
        description: j['description'] as String? ?? '',
        amount: double.parse((j['amount'] ?? 0).toString()),
        date: j['date'] as String,
        categoryName: j['categoryName'] as String? ?? '',
        categoryIcon: j['categoryIcon'] as String? ?? '💰',
      );
}
