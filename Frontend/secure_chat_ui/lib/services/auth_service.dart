import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_config.dart';
import '../models/auth_user.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthUser> register({
    required String username,
    required String password,
  }) async {
    final response = await _post(
      ApiConfig.registerEndpoint,
      username: username,
      password: password,
    );

    if (response.statusCode != 201) {
      throw ApiException(_errorMessage(response));
    }

    return _parseUser(response);
  }

  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final response = await _post(
      ApiConfig.loginEndpoint,
      username: username,
      password: password,
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return _parseUser(response);
  }

  Future<http.Response> _post(
    String endpoint, {
    required String username,
    required String password,
  }) async {
    try {
      return await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
            }),
          )
          .timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Could not connect to the server. Check that Spring Boot is running.',
      );
    }
  }

  AuthUser _parseUser(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      return AuthUser.fromJson(decoded);
    } on FormatException {
      throw const ApiException('The server returned an unexpected response.');
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];

        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      // The backend may return an empty or non-JSON error response.
    }

    switch (response.statusCode) {
      case 400:
        return 'Invalid input or registration details.';
      case 401:
      case 403:
        return 'The request was rejected. Check backend security settings.';
      case 409:
        return 'This username may already be registered.';
      default:
        return 'Server error (${response.statusCode}). Please try again.';
    }
  }

  void dispose() {
    _client.close();
  }
}
