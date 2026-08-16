import 'package:flutter/foundation.dart';

class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        kIsWeb ? 'http://localhost:3000/api/v1' : 'http://10.0.2.2:3000/api/v1',
  );

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String googleAuth = '/auth/google';
  static const String changePassword = '/auth/password';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String me = '/users/me';

  // Categories
  static const String categories = '/categories';

  // Expenses
  static const String expenses = '/expenses';
  static const String expensesSummary = '/expenses/summary';
  static const String recurringExpenses = '/recurring-expenses';
  static String recurringExpense(String id) => '$recurringExpenses/$id';

  // Incomes
  static const String incomes = '/incomes';
  static const String incomesProjection = '/incomes/projection';

  // Budgets
  static const String budgets = '/budgets';

  // Cash
  static const String cashAccounts = '/cash/accounts';
  static String cashTransaction(String accountId, String transactionId) =>
      '$cashAccounts/$accountId/transactions/$transactionId';

  // Goals
  static const String goals = '/goals';

  // Analytics
  static const String dashboard = '/analytics/dashboard';
  static const String spendingTrends = '/analytics/spending-trends';
  static const String paymentMethodTrends = '/analytics/payment-method-trends';
  static const String expensesSummary2 = '/expenses/summary';
  static const String expensesSummaryByMethod = '/expenses/summary-by-method';
  static const String simulation = '/analytics/simulation';

  // Insights
  static const String insights = '/insights';
  static const String insightsRegenerate = '/insights/regenerate';
  static const String insightsAchievements = '/insights/achievements';

  // Rules
  static const String rules = '/rules';

  // Credit Cards
  static const String creditCards = '/credit-cards';
  static const String creditCardsSummary = '/credit-cards/summary';
  static String creditCardPayments(String cardId) =>
      '/credit-cards/$cardId/payments';

  // Notification Preferences
  static const String notificationPreferences =
      '/users/me/notification-preferences';

  // Shared Groups
  static const String sharedGroups = '/shared-groups';
  static const String sharedGroupsJoin = '/shared-groups/join';
  static const String sharedGroupsWidgetSummary =
      '/shared-groups/widget-summary';
  static const String mySharedExpenses = '/shared-groups/my-shared-expenses';
  static String sharedGroupDetail(String id) => '/shared-groups/$id';
  static String sharedGroupLeave(String id) => '/shared-groups/$id/leave';
  static String sharedGroupMembers(String id) => '/shared-groups/$id/members';
  static String sharedGroupBalances(String id) => '/shared-groups/$id/balances';
  static String sharedGroupExpenses(String id) => '/shared-groups/$id/expenses';
  static String sharedGroupExpense(String groupId, String expenseId) =>
      '/shared-groups/$groupId/expenses/$expenseId';
  static String sharedGroupExpenseApprove(String groupId, String expenseId) =>
      '/shared-groups/$groupId/expenses/$expenseId/approve';
  static String sharedGroupExpenseReject(String groupId, String expenseId) =>
      '/shared-groups/$groupId/expenses/$expenseId/reject';
  static String sharedGroupSettlements(String id) =>
      '/shared-groups/$id/settlements';
  static String sharedGroupSettlement(String groupId, String settlementId) =>
      '/shared-groups/$groupId/settlements/$settlementId';
  static String sharedGroupStats(String id) => '/shared-groups/$id/stats';
  static String sharedGroupExportCsv(String id) =>
      '/shared-groups/$id/export/csv';
  static String sharedGroupImport(String id) => '/shared-groups/$id/import';
  static String sharedGroupSettings(String id) => '/shared-groups/$id/settings';
}
