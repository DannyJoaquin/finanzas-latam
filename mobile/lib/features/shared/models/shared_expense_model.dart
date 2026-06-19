class SharedParticipantModel {
  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final double shareAmount;
  final bool isSettled;

  const SharedParticipantModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.shareAmount,
    required this.isSettled,
  });

  factory SharedParticipantModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return SharedParticipantModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? user['id'] as String? ?? '',
      fullName: user['fullName'] as String? ?? '',
      avatarUrl: user['avatarUrl'] as String?,
      shareAmount: double.tryParse(json['shareAmount'].toString()) ?? 0,
      isSettled: json['isSettled'] as bool? ?? false,
    );
  }
}

class SharedExpenseModel {
  final String id;
  final String groupId;
  final String payerId;
  final String payerName;
  final double totalAmount;
  final String currency;
  final String description;
  final String? categoryLabel;
  final String paymentMethod;
  final String? note;
  final DateTime date;
  final List<SharedParticipantModel> participants;
  final DateTime createdAt;
  // New fields
  final String? receiptUrl;
  final String status; // 'approved' | 'pending'
  final bool isRecurring;
  final String? recurringInterval; // 'monthly' | 'weekly'
  final int? recurringDay;

  const SharedExpenseModel({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.payerName,
    required this.totalAmount,
    required this.currency,
    required this.description,
    this.categoryLabel,
    required this.paymentMethod,
    this.note,
    required this.date,
    required this.participants,
    required this.createdAt,
    this.receiptUrl,
    this.status = 'approved',
    this.isRecurring = false,
    this.recurringInterval,
    this.recurringDay,
  });

  factory SharedExpenseModel.fromJson(Map<String, dynamic> json) {
    final payer = json['payer'] as Map<String, dynamic>? ?? {};
    return SharedExpenseModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String? ?? '',
      payerId: json['payerId'] as String? ?? payer['id'] as String? ?? '',
      payerName: payer['fullName'] as String? ?? '',
      totalAmount: double.tryParse(json['totalAmount'].toString()) ?? 0,
      currency: json['currency'] as String? ?? 'HNL',
      description: json['description'] as String? ?? '',
      categoryLabel: json['categoryLabel'] as String?,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      note: json['note'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((p) => SharedParticipantModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      receiptUrl: json['receiptUrl'] as String?,
      status: json['status'] as String? ?? 'approved',
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringInterval: json['recurringInterval'] as String?,
      recurringDay: json['recurringDay'] as int?,
    );
  }
}
