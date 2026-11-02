import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_config.dart';
import '../models/public_key_info.dart';

class KeyLookupException implements Exception {
  const KeyLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KeyService {
  KeyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> registerPublicKey({
    required String username,
    required String publicKey,
    required String authorizationHeader,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();

    if (!RegExp(r'^[a-z0-9_]{3,50}$').hasMatch(normalizedUsername)) {
      throw const KeyLookupException('Invalid username.');
    }

    if (publicKey.isEmpty || authorizationHeader.isEmpty) {
      throw const KeyLookupException(
        'Public key or authentication token is missing.',
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/keys'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': authorizationHeader,
            },
            body: jsonEncode({
              'username': normalizedUsername,
              'publicKey': publicKey,
            }),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 204) {
        throw KeyLookupException(
          'Public-key registration failed (HTTP ${response.statusCode}): '
          '${_errorMessage(response)}',
        );
      }
    } on TimeoutException {
      throw const KeyLookupException('Public-key registration timed out.');
    } on http.ClientException {
      throw const KeyLookupException('Could not connect to Spring Boot.');
    }
  }

  Future<PublicKeyInfo> getPublicKey(String username) async {
    final normalizedUsername = username.trim().toLowerCase();

    if (!RegExp(r'^[a-z0-9_]{3,50}$').hasMatch(normalizedUsername)) {
      throw const KeyLookupException('Invalid username.');
    }

    try {
      final response = await _client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/keys/'
              '${Uri.encodeComponent(normalizedUsername)}',
            ),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode != 200) {
        if (response.statusCode == 404 || response.statusCode == 400) {
          throw const KeyLookupException(
            'No usable public key was found for this username.',
          );
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const KeyLookupException(
            'The server rejected the key lookup request.',
          );
        }

        throw KeyLookupException(
          'Key lookup failed (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      final key = PublicKeyInfo.fromJson(decoded);

      if (key.username.toLowerCase() != normalizedUsername) {
        throw const KeyLookupException(
          'The server returned a key for a different username.',
        );
      }

      return key;
    } on TimeoutException {
      throw const KeyLookupException('Key lookup timed out.');
    } on http.ClientException {
      throw const KeyLookupException('Could not reach Spring Boot.');
    } on FormatException {
      throw const KeyLookupException(
        'The server returned an invalid public-key response.',
      );
    } on TypeError {
      throw const KeyLookupException(
        'The public-key response has unexpected fields.',
      );
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
    } catch (_) {
      // Keep the HTTP status as the fallback.
    }

    return 'The server rejected the public key.';
  }

  void dispose() {
    _client.close();
  }
}
