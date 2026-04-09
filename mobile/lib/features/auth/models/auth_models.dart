class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.currency,
    required this.payCycle,
    this.payDay1,
    this.payDay2,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String fullName;
  final String currency;
  final String payCycle;
  final int? payDay1;
  final int? payDay2;
  final String? avatarUrl;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        currency: json['currency'] as String? ?? 'HNL',
        payCycle: json['payCycle'] as String? ?? 'monthly',
        payDay1: json['payDay1'] as int?,
        payDay2: json['payDay2'] as int?,
        avatarUrl: json['avatarUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'currency': currency,
        'payCycle': payCycle,
        if (payDay1 != null) 'payDay1': payDay1,
        if (payDay2 != null) 'payDay2': payDay2,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };
}

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.user,
    this.accessToken,
  });

  final bool isAuthenticated;
  final UserModel? user;
  final String? accessToken;

  const AuthState.unauthenticated()
      : isAuthenticated = false,
        user = null,
        accessToken = null;
}
