import 'dart:async';
import 'dart:convert';
import '../models/secure_message_packet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/websocket_service.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.senderUsername,
    required this.text,
    required this.timestamp,
    required this.isOutgoing,
    this.isDemo = true,
  });

  final String messageId;
  final String senderUsername;
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

  Future<void> sendDemoMessage({
    required String senderUsername,
    required String recipientUsername,
    required String text,
  }) async {
    final messageId = DateTime.now().microsecondsSinceEpoch.toString();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    // DEMO ONLY: Base64 is encoding, NOT encryption.
    // This payload is deliberately not a secure message.
    final demoCiphertext = base64Encode(utf8.encode(text));

    final packet = SecureMessagePacket(
      messageId: messageId,
      senderUsername: senderUsername,
      recipientUsername: recipientUsername,
      sessionId: 'demo-$senderUsername-$recipientUsername',
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
        text: text,
        timestamp: DateTime.now(),
        isOutgoing: true,
      );

      state = ChatState(
        status: SocketStatus.connected,
        messages: [...state.messages, message],
        notice: 'Demo packet sent to the relay; delivery is not confirmed.',
      );
    } catch (_) {
      state = ChatState(
        status: state.status,
        messages: state.messages,
        notice: 'Could not send packet. Check the connection.',
      );
    }
  }

  @override
  ChatState build() {
    final service = ref.read(webSocketServiceProvider);

    _eventsSubscription = service.events.listen(_handleEvent);

    ref.onDispose(() {
      _eventsSubscription?.cancel();
    });

    return const ChatState();
  }

  Future<void> connect(String username) async {
    state = ChatState(
      status: SocketStatus.connecting,
      messages: state.messages,
    );

    try {
      await ref.read(webSocketServiceProvider).connect(username);

      state = ChatState(
        status: SocketStatus.connected,
        messages: state.messages,
        notice: 'Connected to chat relay.',
      );
    } catch (_) {
      state = ChatState(
        status: SocketStatus.disconnected,
        messages: state.messages,
        notice: 'Could not connect to the chat server.',
      );
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
      state = ChatState(
        status: state.status,
        messages: state.messages,
        notice: event['message']?.toString() ?? 'Relay error.',
      );
      return;
    }

    if (event.containsKey('ciphertext') &&
        event.containsKey('senderUsername')) {
      final sender = event['senderUsername'].toString();
      final ciphertext = event['ciphertext'].toString();

      // TODO Phase 5: send the received packet to the Python bridge
      // for signature/integrity verification and local decryption.
      // This is only a transport demonstration, not secure decryption.

      final message = ChatMessage(
        messageId:
            event['messageId']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        senderUsername: sender,
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

      // Keep the variable explicitly referenced during the demo.
      assert(ciphertext.isNotEmpty || ciphertext.isEmpty);
    }
  }

  void addDemoMessage({
    required String messageId,
    required String senderUsername,
    required String text,
  }) {
    final message = ChatMessage(
      messageId: messageId,
      senderUsername: senderUsername,
      text: text,
      timestamp: DateTime.now(),
      isOutgoing: true,
    );

    state = ChatState(
      status: state.status,
      messages: [...state.messages, message],
      notice: 'Local demo message added.',
    );
  }

  void setNotice(String? notice) {
    state = ChatState(
      status: state.status,
      messages: state.messages,
      notice: notice,
    );
  }

  Future<void> disconnect() async {
    await ref.read(webSocketServiceProvider).disconnect();

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
