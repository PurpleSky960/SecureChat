import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/register_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/contacts/screens/contacts_screen.dart';
import '../../features/contacts/screens/recipient_screen.dart';
import '../../features/security/screens/security_screen.dart';
import '../../models/public_key_info.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const ContactsScreen(),
    ),
    GoRoute(
      path: '/security',
      builder: (context, state) => const SecurityScreen(),
    ),
    GoRoute(
      path: '/recipient',
      builder: (context, state) {
        final recipient = state.extra;

        if (recipient is! PublicKeyInfo) {
          return const Scaffold(
            body: Center(child: Text('Recipient details are unavailable.')),
          );
        }

        return RecipientScreen(recipient: recipient);
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final extra = state.extra;

        if (extra is! Map<String, String>) {
          return const Scaffold(
            body: Center(child: Text('Chat details are unavailable.')),
          );
        }

        final currentUsername = extra['currentUsername'];
        final recipientUsername = extra['recipientUsername'];

        if (currentUsername == null || recipientUsername == null) {
          return const Scaffold(
            body: Center(child: Text('Missing chat participant information.')),
          );
        }

        return ChatScreen(
          currentUsername: currentUsername,
          recipientUsername: recipientUsername,
        );
      },
    ),
  ],
);
