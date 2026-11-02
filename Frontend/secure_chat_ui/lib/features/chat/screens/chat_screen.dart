import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatProvider.notifier).connect(widget.currentUsername);
      }
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recipientUsername),
            Text(
              chat.status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: connected ? AppTheme.cyan : AppTheme.muted,
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
          IconButton(
            tooltip: 'Reconnect',
            icon: const Icon(Icons.refresh),
            onPressed: connected
                ? null
                : () => ref
                      .read(chatProvider.notifier)
                      .connect(widget.currentUsername),
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

            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: connected,
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
                    onPressed: connected ? _send : null,
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

    // Still demo sending. Python crypto has not yet been integrated
    // into the outgoing chat-message pipeline.
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
