import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/secure_message_packet.dart';
import '../services/session_service.dart';
import '../services/websocket_service.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final sessionServiceProvider = Provider<SessionService>((ref) {
  final service = SessionService();
  ref.onDispose(service.dispose);
  return service;
});

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.senderUsername,
    required this.recipientUsername,
    required this.sessionId,
    required this.text,
    required this.timestamp,
    required this.isOutgoing,
    this.isDemo = true,
  });

  final String messageId;
  final String senderUsername;
  final String recipientUsername;
  final String sessionId;
  final String text;
  final DateTime timestamp;
  final bool isOutgoing;
  final bool isDemo;
}

class ChatState {
  const ChatState({
    this.status = SocketStatus.disconnected,
    this.messages = const [],
    this.notice,
  });

  final SocketStatus status;
  final List<ChatMessage> messages;
  final String? notice;
}

class ChatController extends Notifier<ChatState> {
  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;

  String? _activeSessionId;
  String? _currentUsername;
  String? _currentRecipientUsername;

  String? get activeSessionId => _activeSessionId;

  @override
  ChatState build() {
    final service = ref.read(webSocketServiceProvider);

    _eventsSubscription = service.events.listen(_handleEvent);

    ref.onDispose(() {
      _eventsSubscription?.cancel();
    });

    return const ChatState();
  }

  Future<void> connect(
    String username, {
    required String recipientUsername,
    required String authorizationHeader,
  }) async {
    final sameConversation =
        _currentUsername == username &&
        _currentRecipientUsername == recipientUsername;

    // Do not carry messages from another conversation into this one.
    final previousMessages = sameConversation
        ? state.messages
        : <ChatMessage>[];

    _currentUsername = username;
    _currentRecipientUsername = recipientUsername;
    _activeSessionId = null;

    state = ChatState(
      status: SocketStatus.connecting,
      messages: previousMessages,
      notice: 'Retrieving or creating chat session...',
    );

    try {
      final session = await ref
          .read(sessionServiceProvider)
          .getOrCreateActiveSession(
            currentUsername: username,
            recipientUsername: recipientUsername,
            authorizationHeader: authorizationHeader,
          );

      if (!session.isActive) {
        throw Exception('The retrieved chat session is not ACTIVE.');
      }

      // Establish the authenticated WebSocket connection.
      await ref
          .read(webSocketServiceProvider)
          .connect(username, authorizationHeader: authorizationHeader);

      _activeSessionId = session.sessionId;

      state = ChatState(
        status: SocketStatus.connected,
        messages: previousMessages,
        notice: 'Connected. Active chat session loaded.',
      );
    } catch (error) {
      _activeSessionId = null;

      state = ChatState(
        status: SocketStatus.disconnected,
        messages: previousMessages,
        notice: 'Chat initialization failed: $error',
      );
    }
  }

  Future<void> sendDemoMessage({
    required String senderUsername,
    required String recipientUsername,
    required String text,
  }) async {
    final sessionId = _activeSessionId;

    if (sessionId == null) {
      _setNotice('No active chat session. Reconnect and try again.');
      return;
    }

    if (senderUsername != _currentUsername ||
        recipientUsername != _currentRecipientUsername) {
      _setNotice('Message does not belong to the current conversation.');
      return;
    }

    if (text.trim().isEmpty) return;

    if (state.status != SocketStatus.connected) {
      _setNotice('Not connected to the chat relay.');
      return;
    }

    final messageId = DateTime.now().microsecondsSinceEpoch.toString();

    final timestamp = DateTime.now().toUtc().toIso8601String();

    // DEMO ONLY: Base64 is encoding, NOT encryption.
    final demoCiphertext = base64Encode(utf8.encode(text));

    final packet = SecureMessagePacket(
      messageId: messageId,
      senderUsername: senderUsername,
      recipientUsername: recipientUsername,
      sessionId: sessionId,
      timestamp: timestamp,
      nonce: 'demo-nonce-$messageId',
      ciphertext: demoCiphertext,
      hmac: 'DEMO-NOT-A-REAL-HMAC',
      signature: 'DEMO-NOT-A-REAL-SIGNATURE',
    );

    try {
      ref.read(webSocketServiceProvider).send(packet.toJson());

      final message = ChatMessage(
        messageId: messageId,
        senderUsername: senderUsername,
        recipientUsername: recipientUsername,
        sessionId: sessionId,
        text: text,
        timestamp: DateTime.now(),
        isOutgoing: true,
      );

      state = ChatState(
        status: SocketStatus.connected,
        messages: [...state.messages, message],
        notice: 'Packet sent. Waiting for backend confirmation.',
      );
    } catch (error) {
      _setNotice('Could not send packet: $error');
    }
  }

  Future<void> terminateActiveSession({
    required String authorizationHeader,
  }) async {
    final sessionId = _activeSessionId;

    if (sessionId == null) {
      _setNotice('There is no active session to terminate.');
      return;
    }

    try {
      await ref
          .read(sessionServiceProvider)
          .terminateSession(
            sessionId: sessionId,
            authorizationHeader: authorizationHeader,
          );

      _activeSessionId = null;

      state = ChatState(
        status: state.status,
        messages: state.messages,
        notice: 'Chat session terminated.',
      );
    } catch (error) {
      _setNotice('Could not terminate session: $error');
      rethrow;
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? event['status'] ?? '')
        .toString()
        .toUpperCase();

    if (type == 'CONNECTED') {
      state = ChatState(
        status: SocketStatus.connected,
        messages: state.messages,
        notice: event['message']?.toString() ?? 'Connected.',
      );
      return;
    }

    if (type == 'DISCONNECTED' || type == 'CONNECTION_ERROR') {
      state = ChatState(
        status: SocketStatus.disconnected,
        messages: state.messages,
        notice: event['message']?.toString() ?? 'Disconnected.',
      );
      return;
    }

    if (type == 'ERROR') {
      _setNotice(
        'Backend rejected packet: '
        '${event['message']?.toString() ?? 'Unknown error'}',
      );
      return;
    }

    if (type == 'RELAYED') {
      _setNotice(
        event['message']?.toString() ??
            'Backend accepted and relayed the packet.',
      );
      return;
    }

    if (!event.containsKey('ciphertext') ||
        !event.containsKey('senderUsername')) {
      return;
    }

    final currentUser = _currentUsername;
    final currentRecipient = _currentRecipientUsername;
    final currentSession = _activeSessionId;

    if (currentUser == null ||
        currentRecipient == null ||
        currentSession == null) {
      return;
    }

    final sender = event['senderUsername']?.toString();
    final recipient = event['recipientUsername']?.toString();
    final sessionId = event['sessionId']?.toString();

    // Accept only packets belonging to this exact conversation.
    final belongsToConversation =
        sender == currentRecipient &&
        recipient == currentUser &&
        sessionId == currentSession;

    if (!belongsToConversation) {
      return;
    }

    final messageId =
        event['messageId']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();

    // Prevent duplicate insertion if the relay delivers the same event twice.
    if (state.messages.any((message) => message.messageId == messageId)) {
      return;
    }

    final message = ChatMessage(
      messageId: messageId,
      senderUsername: sender!,
      recipientUsername: recipient!,
      sessionId: sessionId!,
      text: '[Encrypted packet received]',
      timestamp:
          DateTime.tryParse(event['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      isOutgoing: false,
    );

    state = ChatState(
      status: state.status,
      messages: [...state.messages, message],
      notice: 'Packet received. Verification is not implemented yet.',
    );
  }

  void _setNotice(String? notice) {
    state = ChatState(
      status: state.status,
      messages: state.messages,
      notice: notice,
    );
  }

  Future<void> disconnect() async {
    await ref.read(webSocketServiceProvider).disconnect();

    _activeSessionId = null;
    _currentUsername = null;
    _currentRecipientUsername = null;

    state = ChatState(
      status: SocketStatus.disconnected,
      messages: state.messages,
      notice: 'Disconnected from chat relay.',
    );
  }

  void clearMessages() {
    state = ChatState(status: state.status, messages: const []);
  }
}

final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
