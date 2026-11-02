import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/key_management_service.dart';
import '../services/key_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(service.dispose);
  return service;
});

final keyManagementServiceProvider = Provider<KeyManagementService>((ref) {
  final service = KeyManagementService();
  ref.onDispose(service.dispose);
  return service;
});

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.error});

  final AuthUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user?.hasAccessToken ?? false;

  String? get accessToken => user?.accessToken;

  String? get authorizationHeader {
    if (!isAuthenticated) return null;
    return user!.authorizationHeader;
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  AuthService get _service => ref.read(authServiceProvider);

  KeyManagementService get _keyService =>
      ref.read(keyManagementServiceProvider);

  Future<bool> login({required String username, required String password}) {
    return _authenticate(
      () => _service.login(username: username, password: password),
    );
  }

  Future<bool> register({required String username, required String password}) {
    return _authenticate(
      () => _service.register(username: username, password: password),
    );
  }

  Future<bool> _authenticate(Future<AuthUser> Function() request) async {
    state = const AuthState(isLoading: true);

    try {
      final user = await request();

      // A JWT is required before registering a public key.
      if (!user.hasAccessToken) {
        throw const ApiException(
          'The server did not provide an access token. '
          'Please log in again.',
        );
      }

      // Initialize or reuse this account's RSA identity.
      // Pass the JWT through to public-key registration.
      await _keyService.initializeKeys(
        user.username,
        authorizationHeader: user.authorizationHeader,
      );

      state = AuthState(user: user);
      return true;
    } on ApiException catch (e) {
      state = AuthState(error: e.message);
      return false;
    } on KeyLookupException catch (e) {
      state = AuthState(error: e.message);
      return false;
    } catch (e) {
      state = AuthState(
        error: 'Something went wrong while initializing your account: $e',
      );
      return false;
    }
  }

  void clearError() {
    state = AuthState(user: state.user);
  }

  void logout() {
    // Do not delete the RSA private key on logout.
    // It must remain available for future conversations.
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
