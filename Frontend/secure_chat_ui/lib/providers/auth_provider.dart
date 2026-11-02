import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(service.dispose);
  return service;
});

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.error});

  final AuthUser? user;
  final bool isLoading;
  final String? error;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  AuthService get _service => ref.read(authServiceProvider);

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
      state = AuthState(user: user);
      return true;
    } on ApiException catch (e) {
      state = AuthState(error: e.message);
      return false;
    } catch (_) {
      state = const AuthState(error: 'Something went wrong. Please try again.');
      return false;
    }
  }

  void clearError() {
    state = AuthState(user: state.user);
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
