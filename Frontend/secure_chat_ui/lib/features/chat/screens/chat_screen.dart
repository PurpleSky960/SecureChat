import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../services/websocket_service.dart';
import '../../../services/python_crypto_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.currentUsername,
    required this.recipientUsername,
  });

  final String currentUsername;
  final String recipientUsername;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();

  bool _testingPython = false;
  bool _terminatingSession = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _connect();
      }
    });
  }

  // Establish an authenticated WebSocket connection
  // and retrieve or create the active session.
  Future<void> _connect() async {
    final auth = ref.read(authProvider);
    final authorizationHeader = auth.authorizationHeader;

    if (authorizationHeader == null || authorizationHeader.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login session unavailable. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    await ref
        .read(chatProvider.notifier)
        .connect(
          widget.currentUsername,
          recipientUsername: widget.recipientUsername,
          authorizationHeader: authorizationHeader,
        );
  }

  // Terminate the current server-side chat session.
  Future<void> _terminateSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terminate session?'),
        content: Text(
          'This will end the current chat session with '
          '${widget.recipientUsername}.\n\n'
          'You will need to establish a new session before sending '
          'more messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Terminate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authorizationHeader = ref.read(authProvider).authorizationHeader;

    if (authorizationHeader == null || authorizationHeader.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication expired. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _terminatingSession = true);

    try {
      await ref
          .read(chatProvider.notifier)
          .terminateActiveSession(authorizationHeader: authorizationHeader);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat session terminated successfully.'),
          backgroundColor: AppTheme.cyan,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not terminate session: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _terminatingSession = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // Temporary smoke test: Flutter -> Kotlin -> Python -> PyCryptodome.
  Future<void> _testPythonBridge() async {
    if (_testingPython) return;

    setState(() => _testingPython = true);

    try {
      final crypto = PythonCryptoService();

      final result = await crypto.aesSmokeTest(
        'SecureChat Python bridge works!',
      );

      debugPrint('PYTHON BRIDGE SUCCESS: $result');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Python bridge works: $result'),
          backgroundColor: AppTheme.cyan,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('PYTHON BRIDGE FAILED: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Python bridge failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _testingPython = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    final connected = chat.status == SocketStatus.connected;

    // Read the active session ID from the controller.
    final activeSessionId = ref.read(chatProvider.notifier).activeSessionId;

    final hasActiveSession = activeSessionId != null;

    final canSendMessages = connected && hasActiveSession;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recipientUsername),
            Text(
              connected
                  ? (hasActiveSession ? 'CONNECTED' : 'NO ACTIVE SESSION')
                  : chat.status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: canSendMessages ? AppTheme.cyan : AppTheme.muted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Connection details',
            icon: const Icon(Icons.security_outlined),
            onPressed: () => _showSecurityDetails(context, chat.notice),
          ),

          // Terminate the current server-side session.
          IconButton(
            tooltip: 'Terminate session',
            icon: _terminatingSession
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.call_end, color: Colors.redAccent),
            onPressed: hasActiveSession && !_terminatingSession
                ? _terminateSession
                : null,
          ),

          // Reconnect also creates a new session if none is active.
          IconButton(
            tooltip: hasActiveSession ? 'Reconnect' : 'Start new session',
            icon: const Icon(Icons.refresh),
            onPressed: _terminatingSession ? null : _connect,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.surface,
              child: const Text(
                'DEMO MODE — messages are not end-to-end encrypted',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFFC857),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // TEMPORARY: remove after the bridge smoke test passes.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testingPython ? null : _testPythonBridge,
                  icon: _testingPython
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.memory),
                  label: Text(
                    _testingPython ? 'Testing Python...' : 'Test Python Bridge',
                  ),
                ),
              ),
            ),

            Expanded(
              child: chat.messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 48,
                              color: AppTheme.muted,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Connect to the relay and send a demo packet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: chat.messages.length,
                      itemBuilder: (context, index) {
                        final message = chat.messages[index];

                        return Align(
                          alignment: message.isOutgoing
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 300),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: message.isOutgoing
                                  ? const Color(0xFF183746)
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.elevatedSurface,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.isOutgoing
                                      ? 'You'
                                      : message.senderUsername,
                                  style: const TextStyle(
                                    color: AppTheme.cyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(message.text),
                                const SizedBox(height: 8),
                                Text(
                                  '${message.timestamp.toLocal().hour.toString().padLeft(2, '0')}:'
                                  '${message.timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            if (chat.notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  chat.notice!,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  textAlign: TextAlign.center,
                ),
              ),

            if (connected && !hasActiveSession)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'This session has ended. Start a new session to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFFFC857), fontSize: 11),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: canSendMessages,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Write a demo message...',
                        prefixIcon: Icon(Icons.message_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send demo packet',
                    onPressed: canSendMessages ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    ref
        .read(chatProvider.notifier)
        .sendDemoMessage(
          senderUsername: widget.currentUsername,
          recipientUsername: widget.recipientUsername,
          text: text,
        );

    _messageController.clear();
  }

  void _showSecurityDetails(BuildContext context, String? notice) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transport status',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('End-to-end encryption'),
                subtitle: Text('Not implemented yet — Phase 5'),
              ),
              const ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('Signature verification'),
                subtitle: Text('Not implemented yet — Phase 5'),
              ),
              ListTile(
                leading: const Icon(Icons.radio_button_checked),
                title: const Text('Latest connection event'),
                subtitle: Text(notice ?? 'No event reported'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
