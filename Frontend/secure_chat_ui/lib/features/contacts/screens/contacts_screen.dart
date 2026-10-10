import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your contacts',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your secure conversations will appear here.',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 24),
            const Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text('No contacts yet'),
                subtitle: Text('Contacts will load from the backend.'),
              ),
            ),
            const Spacer(),
            AppButton(
              label: 'View security status',
              icon: Icons.verified_user_outlined,
              onPressed: () => context.push('/security'),
            ),
          ],
        ),
      ),
    );
  }
}
