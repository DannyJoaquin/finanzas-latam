class ApiConstants {
  const ApiConstants._();

  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String googleAuth = '/auth/google';
  static const String me = '/users/me';

  // Categories
  static const String categories = '/categories';

  // Expenses
  static const String expenses = '/expenses';
  static const String expensesSummary = '/expenses/summary';

  // Incomes
  static const String incomes = '/incomes';
  static const String incomesProjection = '/incomes/projection';

  // Budgets
  static const String budgets = '/budgets';

  // Cash
  static const String cashAccounts = '/cash/accounts';

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
  static String creditCardPayments(String cardId) => '/credit-cards/$cardId/payments';

  // Notification Preferences
  static const String notificationPreferences = '/users/me/notification-preferences';
}
