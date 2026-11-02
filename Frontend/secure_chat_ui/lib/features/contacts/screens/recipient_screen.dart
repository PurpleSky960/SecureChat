import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/public_key_info.dart';
import '../../../providers/auth_provider.dart';

class RecipientScreen extends ConsumerWidget {
  const RecipientScreen({super.key, required this.recipient});

  final PublicKeyInfo recipient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Recipient details')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 72,
              color: AppTheme.cyan,
            ),
            const SizedBox(height: 16),
            Text(
              recipient.username,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: AppTheme.cyan,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Public key available',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Algorithm', style: TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 4),
                    Text(
                      recipient.algorithm,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Text('Status', style: TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 4),
                    Text(
                      recipient.status,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: currentUser == null
                  ? null
                  : () {
                      if (currentUser.username == recipient.username) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'You cannot start a conversation with yourself.',
                            ),
                          ),
                        );
                        return;
                      }

                      context.push(
                        '/chat',
                        extra: {
                          'currentUsername': currentUser.username,
                          'recipientUsername': recipient.username,
                        },
                      );
                    },
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Start conversation'),
            ),
          ],
        ),
      ),
    );
  }
}
