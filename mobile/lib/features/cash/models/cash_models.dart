class CashAccountModel {
  const CashAccountModel({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
    required this.color,
    required this.icon,
    required this.isDefault,
  });

  final String id;
  final String name;
  final double balance;
  final String currency;
  final String color;
  final String icon;
  final bool isDefault;

  factory CashAccountModel.fromJson(Map<String, dynamic> j) => CashAccountModel(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Cartera',
        balance: double.parse((j['balance'] ?? 0).toString()),
        currency: j['currency'] as String? ?? 'HNL',
        color: j['color'] as String? ?? '#34A853',
        icon: j['icon'] as String? ?? 'account_balance_wallet',
        isDefault: j['isDefault'] as bool? ?? false,
      );
}

class CashTransactionModel {
  const CashTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
  });

  final String id;
  final String type; // deposit | withdraw | spend | receive_transfer | send_transfer
  final double amount;
  final String description;
  final String date;

  factory CashTransactionModel.fromJson(Map<String, dynamic> j) =>
      CashTransactionModel(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'deposit',
        amount: double.parse((j['amount'] ?? 0).toString()),
        description: j['description'] as String? ?? '',
        date: (j['date'] as String? ?? '').substring(
            0, (j['date'] as String? ?? '').length.clamp(0, 10)),
      );
}
