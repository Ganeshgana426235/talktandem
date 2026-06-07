import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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

  void _showMessageOptions(ChatMessage msg, bool isMe) {
    final surface = AppTheme.getSurfaceColor(context);
    final textPrimary = AppTheme.getTextColor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Message Options',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(LucideIcons.copy, color: AppTheme.tealAccent),
                  title: Text('Copy Text', style: TextStyle(color: textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: msg.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard.')),
                    );
                  },
                ),
                if (isMe) ...[
                  ListTile(
                    leading: const Icon(LucideIcons.edit3, color: AppTheme.tealAccent),
                    title: Text('Edit Message', style: TextStyle(color: textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditDialog(msg);
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.trash2, color: AppTheme.coralAction),
                    title: const Text('Delete Message', style: TextStyle(color: AppTheme.coralAction)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDelete(msg);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(ChatMessage msg) {
    final controller = TextEditingController(text: msg.text);
    final surface = AppTheme.getSurfaceColor(context);
    final textPrimary = AppTheme.getTextColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Message', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.tealAccent), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newText = controller.text.trim();
                if (newText.isNotEmpty && newText != msg.text) {
                  await context.read<AuthProvider>().firestore.editMessage(
                    conversationId: widget.conversationId,
                    messageId: msg.id,
                    newText: newText,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tealAccent),
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(ChatMessage msg) {
    final surface = AppTheme.getSurfaceColor(context);
    final textPrimary = AppTheme.getTextColor(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete Message', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<AuthProvider>().firestore.deleteMessage(
                  conversationId: widget.conversationId,
                  messageId: msg.id,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralAction),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showUnfriendConfirmDialog() {
    final surface = AppTheme.getSurfaceColor(context);
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Unfriend ${widget.friendName}',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to remove ${widget.friendName} from your friends list? You will no longer be able to message each other.',
            style: TextStyle(color: textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final myUid = auth.uid;
                if (myUid != null) {
                  try {
                    await auth.firestore.unfriend(
                      myUid: myUid,
                      otherUid: widget.friendId,
                    );
                    await auth.loadUserData(myUid);
                    
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed ${widget.friendName} from friends.')),
                    );
                    Navigator.of(context).pop(); // Go back to the chat list
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to unfriend: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralAction,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Unfriend',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myUid = auth.uid ?? '';
    final friendIds = List<String>.from(auth.userData?['friendIds'] ?? []);
    final isFriend = friendIds.contains(widget.friendId);
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
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.moreVertical, color: textPrimary),
            onSelected: (value) {
              if (value == 'unfriend') {
                _showUnfriendConfirmDialog();
              } else if (value == 'report') {
                _showReportSheet();
              }
            },
            itemBuilder: (context) {
              return [
                if (isFriend)
                  const PopupMenuItem<String>(
                    value: 'unfriend',
                    child: Row(
                      children: [
                        Icon(LucideIcons.userMinus, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('Unfriend', style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(LucideIcons.flag, color: AppTheme.errorRed, size: 18),
                      SizedBox(width: 8),
                      Text('Report / Block', style: TextStyle(color: AppTheme.errorRed)),
                    ],
                  ),
                ),
              ];
            },
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
                        GestureDetector(
                          onLongPress: () => _showMessageOptions(msg, isMe),
                          child: Container(
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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: 'talktandem',
            ).collection('conversations').doc(widget.conversationId).snapshots(),
            builder: (context, snapshot) {
              bool isPendingRequest = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  final isRequest = data['isRequest'] as bool? ?? false;
                  final senderId = data['requestSenderId'] as String?;
                  if (isRequest && senderId != myUid) {
                    isPendingRequest = true;
                  }
                }
              }

              if (isPendingRequest) {
                final borderColor = AppTheme.getBorderColor(context);
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Message Request',
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.friendName} wants to message you directly. Accept their request to start chatting.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await auth.firestore.declineChatRequest(widget.conversationId);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.errorRed),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Decline', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await auth.firestore.acceptChatRequest(widget.conversationId);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.tealAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
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
              );
            },
          ),
        ],
      ),
    );
  }
}
