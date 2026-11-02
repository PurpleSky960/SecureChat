import 'dart:async';
import 'dart:convert';

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

  Future<void> connect(String username) async {
    await disconnect();

    _status = SocketStatus.connecting;

    final uri = Uri.parse(
      '${ApiConfig.baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://')}'
      '/ws',
    ).replace(queryParameters: {'username': username});

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      await channel.ready.timeout(const Duration(seconds: 10));

      _status = SocketStatus.connected;

      _subscription = channel.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String);

            if (decoded is Map<String, dynamic>) {
              _events.add(decoded);
            } else {
              _events.add({
                'type': 'ERROR',
                'message': 'Received an unexpected WebSocket message.',
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
            'message': 'WebSocket connection failed.',
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
    } catch (_) {
      _status = SocketStatus.disconnected;
      _events.add({
        'type': 'CONNECTION_ERROR',
        'message': 'Could not connect to the chat server.',
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
