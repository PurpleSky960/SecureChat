import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/public_key_info.dart';
import 'key_service.dart';
import 'python_crypto_service.dart';

class KeyManagementService {
  KeyManagementService({
    PythonCryptoService? crypto,
    KeyService? keys,
    FlutterSecureStorage? storage,
  }) : _crypto = crypto ?? PythonCryptoService(),
       _keys = keys ?? KeyService(),
       _storage = storage ?? const FlutterSecureStorage();

  final PythonCryptoService _crypto;
  final KeyService _keys;
  final FlutterSecureStorage _storage;

  String _privateKeyName(String username) =>
      'securechat_private_${username.toLowerCase()}';

  String _publicPemName(String username) =>
      'securechat_public_pem_${username.toLowerCase()}';

  String _publicDerName(String username) =>
      'securechat_public_der_${username.toLowerCase()}';

  Future<PublicKeyInfo> initializeKeys(
    String username, {
    required String authorizationHeader,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();

    if (!RegExp(r'^[a-z0-9_]{3,50}$').hasMatch(normalizedUsername)) {
      throw const KeyLookupException('Invalid username.');
    }

    if (authorizationHeader.trim().isEmpty) {
      throw const KeyLookupException(
        'Authentication token is missing. Please log in again.',
      );
    }

    final privateKey = await _storage.read(
      key: _privateKeyName(normalizedUsername),
    );

    final publicPem = await _storage.read(
      key: _publicPemName(normalizedUsername),
    );

    final publicDer = await _storage.read(
      key: _publicDerName(normalizedUsername),
    );

    late final String privateKeyToUse;
    late final String publicPemToUse;
    late final String publicDerToUpload;

    if (privateKey != null || publicPem != null || publicDer != null) {
      // Never silently replace an incomplete identity.
      if (privateKey == null || publicPem == null || publicDer == null) {
        throw const KeyLookupException(
          'Your locally stored key pair is incomplete. '
          'Do not generate a replacement automatically.',
        );
      }

      privateKeyToUse = privateKey;
      publicPemToUse = publicPem;
      publicDerToUpload = publicDer;
    } else {
      // Generate a new RSA identity only when none exists.
      final generated = await _crypto.handle('generate_keypair');

      final generatedPrivate = generated['privateKey'];
      final generatedPublic = generated['publicKey'];

      if (generatedPrivate is! String || generatedPublic is! String) {
        throw const KeyLookupException(
          'Python did not return a valid RSA key pair.',
        );
      }

      final derBase64 = _convertPublicPemToDer(generatedPublic);

      // Store the complete identity before contacting the server.
      await _storage.write(
        key: _privateKeyName(normalizedUsername),
        value: generatedPrivate,
      );

      try {
        await _storage.write(
          key: _publicPemName(normalizedUsername),
          value: generatedPublic,
        );

        await _storage.write(
          key: _publicDerName(normalizedUsername),
          value: derBase64,
        );
      } catch (_) {
        // Avoid leaving a partially stored identity.
        await _storage.delete(key: _privateKeyName(normalizedUsername));
        await _storage.delete(key: _publicPemName(normalizedUsername));
        await _storage.delete(key: _publicDerName(normalizedUsername));
        rethrow;
      }

      privateKeyToUse = generatedPrivate;
      publicPemToUse = generatedPublic;
      publicDerToUpload = derBase64;
    }

    // The private key never leaves the client.
    assert(privateKeyToUse.isNotEmpty);
    assert(publicPemToUse.isNotEmpty);

    // IMPORTANT: Pass the authenticated user's JWT to the backend.
    await _keys.registerPublicKey(
      username: normalizedUsername,
      publicKey: publicDerToUpload,
      authorizationHeader: authorizationHeader,
    );

    // Verify that the server stored the expected public key.
    final registered = await _keys.getPublicKey(normalizedUsername);

    if (!registered.isActive || registered.publicKey != publicDerToUpload) {
      throw const KeyLookupException(
        'Public-key registration could not be verified.',
      );
    }

    return registered;
  }

  String _convertPublicPemToDer(String publicPemBase64) {
    try {
      // bridge.py returns Base64-encoded PEM bytes.
      final pemBytes = base64Decode(publicPemBase64);
      final pem = ascii.decode(pemBytes);

      if (!pem.contains('-----BEGIN PUBLIC KEY-----') ||
          !pem.contains('-----END PUBLIC KEY-----')) {
        throw const FormatException('Unexpected PEM format.');
      }

      final body = pem
          .replaceAll('-----BEGIN PUBLIC KEY-----', '')
          .replaceAll('-----END PUBLIC KEY-----', '')
          .replaceAll(RegExp(r'\s'), '');

      final derBytes = base64Decode(body);

      if (derBytes.isEmpty) {
        throw const FormatException('Empty DER key.');
      }

      // Spring Boot expects Base64(X.509 DER).
      return base64Encode(derBytes);
    } on FormatException {
      throw const KeyLookupException(
        'Could not convert the generated RSA public key.',
      );
    }
  }

  Future<String> getPrivateKey(String username) async {
    final value = await _storage.read(
      key: _privateKeyName(username.trim().toLowerCase()),
    );

    if (value == null) {
      throw const KeyLookupException(
        'No local private key exists for this account.',
      );
    }

    return value;
  }

  Future<String> getPublicPem(String username) async {
    final value = await _storage.read(
      key: _publicPemName(username.trim().toLowerCase()),
    );

    if (value == null) {
      throw const KeyLookupException(
        'No local public key exists for this account.',
      );
    }

    return value;
  }

  void dispose() {
    _keys.dispose();
  }
}
