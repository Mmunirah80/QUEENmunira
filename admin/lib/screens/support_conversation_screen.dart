import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/loading_widget.dart';
import '../providers/admin_providers.dart';

class SupportConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String participantName;

  const SupportConversationScreen({super.key, required this.conversationId, required this.participantName});

  @override
  ConsumerState<SupportConversationScreen> createState() => _SupportConversationScreenState();
}

class _SupportConversationScreenState extends ConsumerState<SupportConversationScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await ref.read(adminFirebaseDataSourceProvider).sendSupportMessage(widget.conversationId, text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(supportMessagesStreamProvider(widget.conversationId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: NahamTheme.headerBackground,
          foregroundColor: Colors.white,
          title: Text(widget.participantName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) => messages.isEmpty
                    ? const Center(child: Text('لا توجد رسائل بعد'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppDesignSystem.space16),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final m = messages[i];
                          final isAdmin = m['isAdmin'] as bool? ?? false;
                          return Align(
                            alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isAdmin ? NahamTheme.primary.withValues(alpha: 0.2) : NahamTheme.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['text'] as String? ?? ''),
                                  Text(
                                    m['createdAt'] != null ? _formatTime(m['createdAt'] as String) : '',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: LoadingWidget()),
                error: (e, _) => Center(child: Text('خطأ: $e')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDesignSystem.space16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(backgroundColor: NahamTheme.primary, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
