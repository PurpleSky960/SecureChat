import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/api_config.dart';

enum SocketStatus { disconnected, connecting, connected, reconnecting }

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _events = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;

  SocketStatus _status = SocketStatus.disconnected;

  SocketStatus get status => _status;

  Future<void> connect(
    String username, {
    required String authorizationHeader,
  }) async {
    await disconnect();

    if (authorizationHeader.trim().isEmpty ||
        !authorizationHeader.startsWith('Bearer ')) {
      throw ArgumentError('A valid Bearer token is required.');
    }

    _status = SocketStatus.connecting;

    final baseUri = Uri.parse(ApiConfig.baseUrl);

    final uri = baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws',
      queryParameters: null,
    );

    try {
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': authorizationHeader},
      );

      _channel = channel;

      // Listen before waiting for readiness so early server events aren't lost.
      _subscription = channel.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String);

            if (decoded is Map<String, dynamic>) {
              _events.add(decoded);
            } else {
              _events.add({
                'type': 'ERROR',
                'message': 'Unexpected WebSocket message format.',
              });
            }
          } catch (_) {
            _events.add({
              'type': 'ERROR',
              'message': 'Could not parse a WebSocket message.',
            });
          }
        },
        onError: (Object error) {
          _status = SocketStatus.disconnected;

          _events.add({
            'type': 'CONNECTION_ERROR',
            'message': 'WebSocket connection failed: $error',
          });
        },
        onDone: () {
          _status = SocketStatus.disconnected;

          _events.add({
            'type': 'DISCONNECTED',
            'message': 'WebSocket connection closed.',
          });
        },
        cancelOnError: true,
      );

      await channel.ready.timeout(const Duration(seconds: 10));

      _status = SocketStatus.connected;
    } catch (error) {
      _status = SocketStatus.disconnected;

      await disconnect();

      _events.add({
        'type': 'CONNECTION_ERROR',
        'message': 'Could not connect to the chat server: $error',
      });

      rethrow;
    }
  }

  void send(Map<String, dynamic> packet) {
    if (_status != SocketStatus.connected || _channel == null) {
      throw StateError('WebSocket is not connected.');
    }

    _channel!.sink.add(jsonEncode(packet));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    final channel = _channel;
    _channel = null;

    _status = SocketStatus.disconnected;

    if (channel != null) {
      await channel.sink.close();
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
