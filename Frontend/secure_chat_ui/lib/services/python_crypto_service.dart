import 'dart:convert';
import 'package:flutter/services.dart';

class PythonCryptoService {
  static const MethodChannel _channel = MethodChannel(
    'securechat/python_crypto',
  );

  Future<Map<String, dynamic>> handle(
    String operation, {
    Map<String, dynamic> payload = const {},
  }) async {
    final raw = await _channel.invokeMethod<String>('handle', {
      'operation': operation,
      'payload': jsonEncode(payload),
    });

    if (raw == null) {
      throw StateError('Python bridge returned no result');
    }

    final result = jsonDecode(raw) as Map<String, dynamic>;

    if (result['ok'] != true) {
      throw StateError(
        result['error']?.toString() ?? 'Crypto operation failed',
      );
    }

    return result;
  }

  Future<String> aesSmokeTest([String text = 'Chaquopy works!']) async {
    final result = await handle('aes_roundtrip', payload: {'text': text});
    return result['plaintext'] as String;
  }
}
