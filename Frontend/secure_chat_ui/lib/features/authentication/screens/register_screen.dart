import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/app_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final success = await ref
        .read(authProvider.notifier)
        .register(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      final user = ref.read(authProvider).user;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created for ${user?.username ?? 'user'}.'),
        ),
      );

      context.go('/contacts');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
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
                    const Icon(Icons.person_add_alt_1_outlined, size: 56),
                    const SizedBox(height: 20),
                    const Text(
                      'Join SecureChat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _usernameController,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        final username = value?.trim() ?? '';

                        if (username.isEmpty) {
                          return 'Choose a username.';
                        }

                        if (!RegExp(
                          r'^[a-zA-Z0-9_]{3,50}$',
                        ).hasMatch(username)) {
                          return 'Use 3–50 letters, numbers or underscores.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
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
                          return 'Choose a password.';
                        }

                        if (value.length < 8) {
                          return 'Use at least 8 characters.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match.';
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
                      label: auth.isLoading
                          ? 'Creating account...'
                          : 'Register',
                      onPressed: auth.isLoading ? () {} : _register,
                    ),
                    if (auth.isLoading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already registered? Sign in'),
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
