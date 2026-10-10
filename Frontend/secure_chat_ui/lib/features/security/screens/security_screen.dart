import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security status')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline, color: AppTheme.cyan),
              title: Text('Encryption'),
              subtitle: Text('Not connected'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.verified_user_outlined,
                color: AppTheme.violet,
              ),
              title: Text('Message integrity'),
              subtitle: Text('No verification performed yet'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.key_outlined),
              title: Text('Public-key status'),
              subtitle: Text('No key loaded'),
            ),
          ),
        ],
      ),
    );
  }
}
