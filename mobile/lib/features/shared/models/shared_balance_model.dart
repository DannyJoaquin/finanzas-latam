class BalanceEntryModel {
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;

  const BalanceEntryModel({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
  });

  factory BalanceEntryModel.fromJson(Map<String, dynamic> json) {
    return BalanceEntryModel(
      fromUserId: json['fromUserId'] as String? ?? '',
      fromUserName: json['fromUserName'] as String? ?? '',
      toUserId: json['toUserId'] as String? ?? '',
      toUserName: json['toUserName'] as String? ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0,
    );
  }
}

class GroupBalanceSummaryModel {
  final List<BalanceEntryModel> balances;
  final double youAreOwed;
  final double youOwe;

  const GroupBalanceSummaryModel({
    required this.balances,
    required this.youAreOwed,
    required this.youOwe,
  });

  factory GroupBalanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return GroupBalanceSummaryModel(
      balances: (json['balances'] as List<dynamic>? ?? [])
          .map((b) => BalanceEntryModel.fromJson(b as Map<String, dynamic>))
          .toList(),
      youAreOwed: double.tryParse(json['youAreOwed'].toString()) ?? 0,
      youOwe: double.tryParse(json['youOwe'].toString()) ?? 0,
    );
  }
}

class SharedWidgetSummaryModel {
  final double totalOwed;
  final double totalDue;
  final bool hasGroups;

  const SharedWidgetSummaryModel({
    required this.totalOwed,
    required this.totalDue,
    required this.hasGroups,
  });

  factory SharedWidgetSummaryModel.fromJson(Map<String, dynamic> json) {
    return SharedWidgetSummaryModel(
      totalOwed: double.tryParse(json['totalOwed'].toString()) ?? 0,
      totalDue: double.tryParse(json['totalDue'].toString()) ?? 0,
      hasGroups: json['hasGroups'] as bool? ?? false,
    );
  }
}
