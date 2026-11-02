import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/public_key_info.dart';
import '../services/key_service.dart';

final keyServiceProvider = Provider<KeyService>((ref) {
  final service = KeyService();
  ref.onDispose(service.dispose);
  return service;
});

class KeyLookupState {
  const KeyLookupState({this.keyInfo, this.isLoading = false, this.error});

  final PublicKeyInfo? keyInfo;
  final bool isLoading;
  final String? error;
}

class KeyLookupController extends Notifier<KeyLookupState> {
  @override
  KeyLookupState build() => const KeyLookupState();

  Future<void> lookup(String username) async {
    state = const KeyLookupState(isLoading: true);

    try {
      final key = await ref.read(keyServiceProvider).getPublicKey(username);

      if (key.isActive) {
        state = KeyLookupState(keyInfo: key);
      } else {
        state = const KeyLookupState(
          error: 'This user does not have an active public key.',
        );
      }
    } on KeyLookupException catch (e) {
      state = KeyLookupState(error: e.message);
    } catch (_) {
      state = const KeyLookupState(
        error: 'An unexpected error occurred during key lookup.',
      );
    }
  }

  void clear() {
    state = const KeyLookupState();
  }
}

final keyLookupProvider = NotifierProvider<KeyLookupController, KeyLookupState>(
  KeyLookupController.new,
);
