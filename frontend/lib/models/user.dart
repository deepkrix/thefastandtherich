class User {
  final String userId;
  final String email;
  final String status;
  final String kycStatus;
  final String role;
  final DateTime createdAt;

  User({
    required this.userId,
    required this.email,
    required this.status,
    required this.kycStatus,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'],
      email: json['email'],
      status: json['status'],
      kycStatus: json['kycStatus'],
      role: json['role'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      expiresIn: json['expiresIn'],
    );
  }
}
