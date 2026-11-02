import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/key_provider.dart';
import '../../../providers/auth_provider.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    await ref.read(keyLookupProvider.notifier).lookup(_usernameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(keyLookupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureChat'),
        actions: [
          IconButton(
            tooltip: 'Security status',
            onPressed: () => context.push('/security'),
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Find a recipient',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search by username and check their public-key status '
              'before starting a secure conversation.',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _usernameController,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Recipient username',
                  hintText: 'e.g. bob',
                  prefixIcon: const Icon(Icons.person_search_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: lookup.isLoading ? null : _search,
                    icon: const Icon(Icons.search),
                  ),
                ),
                validator: (value) {
                  final username = value?.trim() ?? '';

                  if (!RegExp(r'^[a-zA-Z0-9_]{3,50}$').hasMatch(username)) {
                    return 'Use 3–50 letters, numbers or underscores.';
                  }

                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),

            Consumer(
              builder: (context, ref, child) {
                final currentUser = ref.watch(authProvider).user;

                return OutlinedButton.icon(
                  onPressed: currentUser == null
                      ? null
                      : () {
                          final recipient = _usernameController.text
                              .trim()
                              .toLowerCase();

                          if (!RegExp(
                            r'^[a-z0-9_]{3,50}$',
                          ).hasMatch(recipient)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter a valid recipient username.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (recipient == currentUser.username) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Choose another username for the demo chat.',
                                ),
                              ),
                            );
                            return;
                          }

                          context.push(
                            '/chat',
                            extra: {
                              'currentUsername': currentUser.username,
                              'recipientUsername': recipient,
                            },
                          );
                        },
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Open demo chat (key lookup skipped)'),
                );
              },
            ),
            const SizedBox(height: 12),

            if (lookup.isLoading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              const Text(
                'Looking up public key...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted),
              ),
            ],

            if (!lookup.isLoading && lookup.error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.key_off_outlined,
                        size: 36,
                        color: Color(0xFFFF6B81),
                      ),
                      const SizedBox(height: 12),
                      Text(lookup.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      const Text(
                        'Check the username or ask the recipient '
                        'to register a public key.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
              ),

            if (!lookup.isLoading && lookup.keyInfo != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppTheme.cyan,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Public key available',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        lookup.keyInfo!.username,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Algorithm',
                        value: lookup.keyInfo!.algorithm,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Status', value: lookup.keyInfo!.status),
                      const SizedBox(height: 10),
                      const Text(
                        'SHA-256 fingerprint',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        lookup.keyInfo!.fingerprint,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            final key = lookup.keyInfo!;

                            context.push('/recipient', extra: key);
                          },
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Start conversation'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A server-provided key is not automatically '
                        'a trusted identity. Verify its fingerprint '
                        'through a trusted channel.',
                        style: TextStyle(color: AppTheme.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            if (!lookup.isLoading &&
                lookup.error == null &&
                lookup.keyInfo == null)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text('Search for a recipient'),
                  subtitle: Text(
                    'Enter a username to check public-key availability.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppTheme.muted)),
        ),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    );
  }
}
