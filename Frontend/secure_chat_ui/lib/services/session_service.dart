import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_config.dart';

class ChatSession {
  const ChatSession({
    required this.sessionId,
    required this.username,
    required this.peerUsername,
    required this.status,
    this.createdAt,
    this.expiresAt,
  });

  final String sessionId;
  final String username;
  final String peerUsername;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['sessionId'] as String,
      username: json['username'] as String,
      peerUsername: json['peerUsername'] as String,
      status: json['status'] as String,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'].toString()),
    );
  }

  bool belongsToConversation(String firstUser, String secondUser) {
    final a = firstUser.toLowerCase();
    final b = secondUser.toLowerCase();

    final sessionUser = username.toLowerCase();
    final sessionPeer = peerUsername.toLowerCase();

    return (sessionUser == a && sessionPeer == b) ||
        (sessionUser == b && sessionPeer == a);
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

class SessionService {
  SessionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers(String authorizationHeader) {
    if (authorizationHeader.trim().isEmpty ||
        !authorizationHeader.startsWith('Bearer ')) {
      throw Exception('A valid Bearer token is required.');
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': authorizationHeader,
    };
  }

  Uri _sessionsUri([String? sessionId]) {
    final path = sessionId == null
        ? '/api/sessions'
        : '/api/sessions/$sessionId';

    return Uri.parse('${ApiConfig.baseUrl}$path');
  }

  Future<List<ChatSession>> getMySessions({
    required String authorizationHeader,
  }) async {
    try {
      final response = await _client
          .get(_sessionsUri(), headers: _headers(authorizationHeader))
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Could not retrieve sessions. '
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception('Unexpected session response format.');
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatSession.fromJson)
          .toList();
    } on TimeoutException {
      throw Exception('Session request timed out.');
    } on http.ClientException {
      throw Exception('Could not connect to the session API.');
    } on FormatException {
      throw Exception('The server returned invalid session JSON.');
    }
  }

  Future<ChatSession> createSession({
    required String peerUsername,
    required String authorizationHeader,
  }) async {
    try {
      final response = await _client
          .post(
            _sessionsUri(),
            headers: _headers(authorizationHeader),
            body: jsonEncode({'peerUsername': peerUsername.trim()}),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode != 201) {
        throw Exception(
          'Could not create chat session. '
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected session creation response.');
      }

      return ChatSession.fromJson(decoded);
    } on TimeoutException {
      throw Exception('Session creation timed out.');
    } on http.ClientException {
      throw Exception('Could not connect to the session API.');
    } on FormatException {
      throw Exception('The server returned invalid session JSON.');
    }
  }

  Future<ChatSession> getOrCreateActiveSession({
    required String currentUsername,
    required String recipientUsername,
    required String authorizationHeader,
  }) async {
    final sessions = await getMySessions(
      authorizationHeader: authorizationHeader,
    );

    final matchingSessions = sessions
        .where(
          (session) =>
              session.isActive &&
              session.belongsToConversation(currentUsername, recipientUsername),
        )
        .toList();

    if (matchingSessions.isNotEmpty) {
      matchingSessions.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return dateB.compareTo(dateA);
      });

      return matchingSessions.first;
    }

    // No ACTIVE session exists. Create one through the existing API.
    return createSession(
      peerUsername: recipientUsername,
      authorizationHeader: authorizationHeader,
    );
  }

  Future<void> terminateSession({
    required String sessionId,
    required String authorizationHeader,
  }) async {
    try {
      final response = await _client
          .delete(
            _sessionsUri(sessionId),
            headers: _headers(authorizationHeader),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode != 204) {
        throw Exception(
          'Could not terminate session. '
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on TimeoutException {
      throw Exception('Session termination timed out.');
    } on http.ClientException {
      throw Exception('Could not connect to the session API.');
    }
  }

  void dispose() {
    _client.close();
  }
}
