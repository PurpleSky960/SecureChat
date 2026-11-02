class AuthUser {
  const AuthUser({
    required this.userId,
    required this.username,
    required this.message,
    this.accessToken,
    this.tokenType = 'Bearer',
  });

  final int userId;
  final String username;
  final String message;

  // Null is permitted for registration responses that don't issue a token.
  final String? accessToken;
  final String tokenType;

  bool get hasAccessToken => accessToken != null && accessToken!.isNotEmpty;

  String get authorizationHeader {
    if (!hasAccessToken) {
      throw StateError('No access token is available.');
    }

    return '$tokenType $accessToken';
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['userId'];
    final rawUsername = json['username'];

    if (rawId is! num || rawUsername is! String) {
      throw const FormatException(
        'Unexpected authentication response from server.',
      );
    }

    final rawToken = json['accessToken'];
    final rawTokenType = json['tokenType'];

    if (rawToken != null && rawToken is! String) {
      throw const FormatException('Invalid access token.');
    }

    if (rawTokenType != null && rawTokenType is! String) {
      throw const FormatException('Invalid token type.');
    }

    return AuthUser(
      userId: rawId.toInt(),
      username: rawUsername,
      message: json['message'] as String? ?? 'Success',
      accessToken: rawToken as String?,
      tokenType: rawTokenType as String? ?? 'Bearer',
    );
  }
}
