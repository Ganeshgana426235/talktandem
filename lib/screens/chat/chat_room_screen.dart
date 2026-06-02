import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/auth_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/report_bottom_sheet.dart';

class ChatRoomScreen extends StatefulWidget {
  final String conversationId;
  final String friendName;
  final String friendId;
  final String? friendAvatar;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.friendName,
    required this.friendId,
    this.friendAvatar,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) {
      context.read<AuthProvider>().firestore.markConversationRead(
            widget.conversationId,
            uid,
          );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    if (uid == null) return;

    _messageController.clear();
    await auth.firestore.sendMessage(
      conversationId: widget.conversationId,
      senderId: uid,
      text: text,
      otherUserId: widget.friendId,
    );
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportBottomSheet(
        onSubmit: () async {
          final uid = context.read<AuthProvider>().uid;
          if (uid != null) {
            await context.read<AuthProvider>().firestore.submitReport(
                  reporterId: uid,
                  reportedUserId: widget.friendId,
                  reason: 'User report from chat',
                  context: 'chat',
                );
          }
          if (!context.mounted) return;
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myUid = auth.uid ?? '';
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName,
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: surfaceColor,
        elevation: 1,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.flag, color: AppTheme.errorRed),
            onPressed: _showReportSheet,
            tooltip: 'Report / Block',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: auth.firestore.watchMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.tealAccent,
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hello to ${widget.friendName}!',
                      style: TextStyle(color: textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myUid;
                    final hasError = msg.hasError;

                    return Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(bottom: hasError ? 4 : 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMe ? AppTheme.tealAccent : surfaceColor,
                            borderRadius: BorderRadius.circular(20).copyWith(
                              bottomRight: isMe
                                  ? const Radius.circular(4)
                                  : const Radius.circular(20),
                              bottomLeft: !isMe
                                  ? const Radius.circular(4)
                                  : const Radius.circular(20),
                            ),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: isMe ? Colors.white : textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (hasError && msg.correction != null)
                          Container(
                            margin: const EdgeInsets.only(
                                bottom: 12, right: 8, left: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.emeraldGreen
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.sparkles,
                                        color: AppTheme.emeraldGreen,
                                        size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'AI Correction',
                                      style: TextStyle(
                                        color: AppTheme.emeraldGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  msg.text,
                                  style: const TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 14,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  msg.correction!,
                                  style: const TextStyle(
                                    color: AppTheme.emeraldGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: surfaceColor,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                            color: textSecondary.withValues(alpha: 0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: scaffoldBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.tealAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
