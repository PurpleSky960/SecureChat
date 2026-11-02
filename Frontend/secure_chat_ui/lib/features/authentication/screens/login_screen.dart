import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/app_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final success = await ref
        .read(authProvider.notifier)
        .login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      context.go('/contacts');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_moon_outlined,
                      size: 68,
                      color: AppTheme.cyan,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SecureChat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Private communication. Verified integrity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your username.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password.';
                        }
                        return null;
                      },
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        auth.error!,
                        style: const TextStyle(color: Color(0xFFFF6B81)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label: auth.isLoading ? 'Signing in...' : 'Sign in',
                      icon: auth.isLoading ? null : Icons.arrow_forward,
                      onPressed: auth.isLoading ? () {} : _login,
                    ),
                    if (auth.isLoading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Create account',
                      outlined: true,
                      onPressed: () => context.go('/register'),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'CONNECTED AUTHENTICATION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.muted,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
