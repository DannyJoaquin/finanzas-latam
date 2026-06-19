class SharedSettlementModel {
  final String id;
  final String groupId;
  final String payerId;
  final String payerName;
  final String receiverId;
  final String receiverName;
  final double amount;
  final String paymentMethod;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  const SharedSettlementModel({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.payerName,
    required this.receiverId,
    required this.receiverName,
    required this.amount,
    required this.paymentMethod,
    this.note,
    required this.date,
    required this.createdAt,
  });

  factory SharedSettlementModel.fromJson(Map<String, dynamic> json) {
    final payer = json['payer'] as Map<String, dynamic>? ?? {};
    final receiver = json['receiver'] as Map<String, dynamic>? ?? {};
    return SharedSettlementModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String? ?? '',
      payerId: json['payerId'] as String? ?? payer['id'] as String? ?? '',
      payerName: payer['fullName'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? receiver['id'] as String? ?? '',
      receiverName: receiver['fullName'] as String? ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      note: json['note'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
