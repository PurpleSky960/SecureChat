class AuthUser {
  const AuthUser({
    required this.userId,
    required this.username,
    required this.message,
  });

  final int userId;
  final String username;
  final String message;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['userId'];

    if (rawId is! num || json['username'] is! String) {
      throw const FormatException(
        'Unexpected authentication response from server.',
      );
    }

    return AuthUser(
      userId: rawId.toInt(),
      username: json['username'] as String,
      message: json['message'] as String? ?? 'Success',
    );
  }
}
