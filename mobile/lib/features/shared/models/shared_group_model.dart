class SharedMemberModel {
  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String status; // active | removed | left
  final DateTime joinedAt;

  const SharedMemberModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.status,
    required this.joinedAt,
  });

  factory SharedMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return SharedMemberModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? user['id'] as String? ?? '',
      fullName: user['fullName'] as String? ?? '',
      avatarUrl: user['avatarUrl'] as String?,
      status: json['status'] as String? ?? 'active',
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SharedGroupModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String currency;
  final String inviteCode;
  final bool isActive;
  final List<SharedMemberModel> members;
  final DateTime createdAt;

  const SharedGroupModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.currency,
    required this.inviteCode,
    required this.isActive,
    required this.members,
    required this.createdAt,
  });

  factory SharedGroupModel.fromJson(Map<String, dynamic> json) {
    return SharedGroupModel(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      currency: json['currency'] as String? ?? 'HNL',
      inviteCode: json['inviteCode'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((m) => SharedMemberModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
