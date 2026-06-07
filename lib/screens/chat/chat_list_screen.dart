import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../models/auth_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'chat_room_screen.dart';
import '../premium/premium_plans_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_call_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Lounge',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
          TabBar(
            labelColor: AppTheme.tealAccent,
            unselectedLabelColor: textSecondary,
            indicatorColor: AppTheme.tealAccent,
            tabs: const [
              Tab(text: 'Practice'),
              Tab(text: 'Chats'),
              Tab(text: 'Requests'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _PracticeTab(),
                _ChatsTab(),
                _RequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Connections (call logs + friend actions) ---

class _PracticeTab extends StatelessWidget {
  const _PracticeTab();

  String _formatDate(DateTime? time) {
    if (time == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}, ${time.year}';
  }

  void _openAiChat(BuildContext context, String topic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiChatScreen(topic: topic),
      ),
    );
  }

  void _openAiCall(BuildContext context, String topic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiCallScreen(topic: topic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myUid = auth.uid ?? '';
    final friendIds = List<String>.from(auth.userData?['friendIds'] ?? []);
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    final aiTopics = [
      {
        'title': 'Job Interview Prep',
        'icon': LucideIcons.briefcase,
        'description': 'Practice behavioral and technical questions.',
        'tag': 'Professional',
        'color': Colors.blue,
      },
      {
        'title': 'Daily Talk',
        'icon': LucideIcons.messageCircle,
        'description': 'Discuss your routines, weather, and day.',
        'tag': 'Casual',
        'color': AppTheme.tealAccent,
      },
      {
        'title': 'Favorite Food',
        'icon': LucideIcons.cookie,
        'description': 'Talk about recipes, cuisines, and dining.',
        'tag': 'Cuisine',
        'color': Colors.orange,
      },
      {
        'title': 'Travel Plans',
        'icon': LucideIcons.plane,
        'description': 'Plan your dream vacation and destination.',
        'tag': 'Adventure',
        'color': Colors.purple,
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Practice Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Icon(LucideIcons.sparkles, color: AppTheme.amberPremium, size: 18),
                const SizedBox(width: 8),
                Text(
                  'AI Practice Partner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.tealAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BETA',
                    style: TextStyle(color: AppTheme.tealAccent, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 175,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: aiTopics.length,
              itemBuilder: (context, index) {
                final t = aiTopics[index];
                final tColor = t['color'] as Color;
                return Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(t['icon'] as IconData, color: tColor, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['title'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  t['tag'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          t['description'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openAiChat(context, t['title'] as String),
                              icon: const Icon(LucideIcons.messageSquare, size: 12),
                              label: const Text('AI Chat', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.tealAccent,
                                side: const BorderSide(color: AppTheme.tealAccent, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openAiCall(context, t['title'] as String),
                              icon: const Icon(LucideIcons.phone, size: 12, color: Colors.white),
                              label: const Text('AI Call', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.tealAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Peer Connections Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Row(
              children: [
                Icon(LucideIcons.users, color: textSecondary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Peer Connections',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Call history StreamBuilder list
          StreamBuilder<List<CallSession>>(
            stream: auth.firestore.watchCallHistory(myUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppTheme.tealAccent),
                  ),
                );
              }

              final calls = snapshot.data ?? [];

              if (calls.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.users, size: 40, color: AppTheme.tealAccent),
                        const SizedBox(height: 12),
                        Text(
                          'No call history yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start a call from Radar to connect with practice partners.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              void showPremiumMessagingUpsell(BuildContext ctx) {
                showDialog(
                  context: ctx,
                  builder: (dialogCtx) {
                    final surface = AppTheme.getSurfaceColor(dialogCtx);
                    final txtPrimary = AppTheme.getTextColor(dialogCtx);
                    final txtSecondary = AppTheme.getSecondaryTextColor(dialogCtx);

                    return AlertDialog(
                      backgroundColor: surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Row(
                        children: [
                          Icon(LucideIcons.crown, color: AppTheme.amberPremium, size: 28),
                          SizedBox(width: 12),
                          Text('Premium Direct Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Text(
                        'Direct Messaging after a call is a Premium VIP benefit! Upgrade now to message any partner directly without waiting for friend request approval.',
                        style: TextStyle(color: txtSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(builder: (_) => const PremiumPlansScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.tealAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Upgrade VIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: calls.length,
                itemBuilder: (context, index) {
                  final call = calls[index];
                  final otherId = call.partnerId(myUid);
                  final name = call.participantNames[otherId] ?? 'Practice Partner';
                  final avatar = call.participantAvatars[otherId];
                  final isFriend = friendIds.contains(otherId);
                  final isEnded = call.status == 'ended';
                  final minutes = call.durationMinutes;
                  final date = call.endedAt ?? call.startedAt;

                  return GestureDetector(
                    onTap: () async {
                      final isMePremium = (auth.userData?['isPremium'] as bool?) ?? false;
                      if (isFriend) {
                        final me = auth.appUser;
                        if (me != null) {
                          final partnerDoc = await auth.firestore.getUser(otherId);
                          if (partnerDoc != null && context.mounted) {
                            final convId = await auth.firestore.getOrCreateConversation(
                              myUid: myUid,
                              me: me,
                              partner: partnerDoc,
                            );
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(
                                    conversationId: convId,
                                    friendName: name,
                                    friendId: otherId,
                                    friendAvatar: avatar,
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      } else {
                        if (isMePremium) {
                          final me = auth.appUser;
                          if (me != null) {
                            final partnerDoc = await auth.firestore.getUser(otherId);
                            if (partnerDoc != null && context.mounted) {
                              final convId = await auth.firestore.getOrCreateConversationAsRequest(
                                myUid: myUid,
                                me: me,
                                partner: partnerDoc,
                              );
                              if (context.mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatRoomScreen(
                                      conversationId: convId,
                                      friendName: name,
                                      friendId: otherId,
                                      friendAvatar: avatar,
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        } else {
                          showPremiumMessagingUpsell(context);
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                            backgroundColor: AppTheme.tealAccent,
                            child: avatar == null
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isEnded ? '$minutes min · ${_formatDate(date)}' : 'Call in progress',
                                  style: TextStyle(color: textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          _FriendActionButton(
                            myUid: myUid,
                            otherId: otherId,
                            otherName: name,
                            otherAvatar: avatar,
                            isFriend: isFriend,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FriendActionButton extends StatefulWidget {
  final String myUid;
  final String otherId;
  final String otherName;
  final String? otherAvatar;
  final bool isFriend;

  const _FriendActionButton({
    required this.myUid,
    required this.otherId,
    required this.otherName,
    this.otherAvatar,
    required this.isFriend,
  });

  @override
  State<_FriendActionButton> createState() => _FriendActionButtonState();
}

class _FriendActionButtonState extends State<_FriendActionButton> {
  String? _requestStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (widget.isFriend) {
      setState(() {
        _requestStatus = 'friends';
        _loading = false;
      });
      return;
    }
    final status = await context.read<AuthProvider>().firestore
        .getFriendRequestStatus(
          myUid: widget.myUid,
          otherUid: widget.otherId,
        );
    if (mounted) {
      setState(() {
        _requestStatus = status;
        _loading = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    final auth = context.read<AuthProvider>();
    final me = auth.appUser;
    if (me == null) return;
    setState(() => _loading = true);
    await auth.firestore.sendFriendRequest(
      fromUid: widget.myUid,
      me: me,
      toUid: widget.otherId,
      toName: widget.otherName,
      toAvatar: widget.otherAvatar,
    );
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_requestStatus == 'friends' || widget.isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.userCheck,
                size: 14, color: AppTheme.emeraldGreen),
            SizedBox(width: 4),
            Text(
              'Friends',
              style: TextStyle(
                color: AppTheme.emeraldGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_requestStatus == 'sent') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.amberPremium.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Sent',
          style: TextStyle(
            color: AppTheme.amberPremium,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    if (_requestStatus == 'received') {
      return const Text(
        'Respond in Requests',
        style: TextStyle(
          color: AppTheme.tealAccent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return TextButton(
      onPressed: _sendRequest,
      style: TextButton.styleFrom(
        backgroundColor: AppTheme.tealAccent.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Add Friend',
        style: TextStyle(
          color: AppTheme.tealAccent,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// --- Chats tab ---

class _ChatsTab extends StatefulWidget {
  const _ChatsTab();

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) {
      final hour =
          time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'PM' : 'AM';
      final min = time.minute.toString().padLeft(2, '0');
      return '$hour:$min $period';
    }
    if (diff.inDays == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myUid = auth.uid ?? '';
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Column(
      children: [
        // Search bar at the top of the Chats list
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
            style: TextStyle(color: textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search chats...',
              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 14),
              prefixIcon: Icon(LucideIcons.search, color: textSecondary, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(LucideIcons.x, color: textSecondary, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: surfaceColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.tealAccent, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Conversation>>(
            stream: auth.firestore.watchConversations(myUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.tealAccent),
                );
              }

              final allConversations = snapshot.data ?? [];
              final conversations = allConversations.where((conv) {
                final otherId = conv.otherUserId(myUid);
                final name = (conv.participantNames[otherId] ?? 'Practice Partner').toLowerCase();
                return name.contains(_searchQuery);
              }).toList();

              if (conversations.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _searchQuery.isNotEmpty 
                          ? 'No matching chats found.' 
                          : 'No chats yet. Message a connection after a call!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary),
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  final otherId = conv.otherUserId(myUid);
                  final name =
                      conv.participantNames[otherId] ?? 'Practice Partner';
                  final avatar = conv.participantAvatars[otherId];
                  final unread = conv.unreadCount[myUid] ?? 0;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundImage:
                          avatar != null ? NetworkImage(avatar) : null,
                      backgroundColor: AppTheme.tealAccent,
                      child: avatar == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: textPrimary)),
                    subtitle: Text(
                      conv.lastMessage.isEmpty
                          ? 'Start a conversation'
                          : conv.lastMessage,
                      style: TextStyle(
                        color: unread > 0 ? AppTheme.tealAccent : textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_formatTime(conv.lastMessageAt),
                            style: TextStyle(color: textSecondary, fontSize: 12)),
                        if (unread > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.tealAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatRoomScreen(
                            conversationId: conv.id,
                            friendName: name,
                            friendId: otherId,
                            friendAvatar: avatar,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- Friend requests tab ---

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myUid = auth.uid ?? '';
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return StreamBuilder<List<FriendRequest>>(
      stream: auth.firestore.watchIncomingFriendRequests(myUid),
      builder: (context, incomingSnap) {
        return StreamBuilder<List<FriendRequest>>(
          stream: auth.firestore.watchOutgoingFriendRequests(myUid),
          builder: (context, outgoingSnap) {
            return StreamBuilder<List<Conversation>>(
              stream: auth.firestore.watchIncomingChatRequests(myUid),
              builder: (context, chatReqsSnap) {
                if (incomingSnap.connectionState == ConnectionState.waiting ||
                    outgoingSnap.connectionState == ConnectionState.waiting ||
                    chatReqsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.tealAccent),
                  );
                }

                final incoming = incomingSnap.data ?? [];
                final outgoing = outgoingSnap.data ?? [];
                final chatRequests = chatReqsSnap.data ?? [];

                if (incoming.isEmpty && outgoing.isEmpty && chatRequests.isEmpty) {
                  return Center(
                    child: Text(
                      'No pending requests.',
                      style: TextStyle(color: textSecondary),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (chatRequests.isNotEmpty) ...[
                      Text(
                        'Message Requests',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...chatRequests.map((conv) {
                        final otherId = conv.otherUserId(myUid);
                        final name = conv.participantNames[otherId] ?? 'VIP Partner';
                        final avatar = conv.participantAvatars[otherId];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(
                                    conversationId: conv.id,
                                    friendName: name,
                                    friendId: otherId,
                                    friendAvatar: avatar,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                                  backgroundColor: AppTheme.tealAccent,
                                  child: avatar == null
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        conv.lastMessage.isNotEmpty
                                            ? conv.lastMessage
                                            : 'Direct VIP message request',
                                        style: TextStyle(color: textSecondary, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'Review',
                                  style: TextStyle(
                                    color: AppTheme.tealAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                    if (incoming.isNotEmpty) ...[
                      Text(
                        'Received',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...incoming.map((req) => _RequestCard(
                            request: req,
                            isIncoming: true,
                            myUid: myUid,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                          )),
                      const SizedBox(height: 20),
                    ],
                    if (outgoing.isNotEmpty) ...[
                      Text(
                        'Sent',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...outgoing.map((req) => _RequestCard(
                            request: req,
                            isIncoming: false,
                            myUid: myUid,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                          )),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final FriendRequest request;
  final bool isIncoming;
  final String myUid;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;

  const _RequestCard({
    required this.request,
    required this.isIncoming,
    required this.myUid,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final name = isIncoming ? request.fromName : request.toName;
    final avatar = isIncoming ? request.fromAvatar : request.toAvatar;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            backgroundColor: AppTheme.tealAccent,
            child: avatar == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
          if (isIncoming) ...[
            IconButton(
              icon: const Icon(LucideIcons.check, color: AppTheme.emeraldGreen),
              onPressed: () async {
                await auth.firestore.respondFriendRequest(
                  requestId: request.id,
                  fromUid: request.fromUid,
                  toUid: request.toUid,
                  accept: true,
                );
                await auth.loadUserData(myUid);
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, color: AppTheme.errorRed),
              onPressed: () async {
                await auth.firestore.respondFriendRequest(
                  requestId: request.id,
                  fromUid: request.fromUid,
                  toUid: request.toUid,
                  accept: false,
                );
              },
            ),
          ] else
            const Text(
              'Pending',
              style: TextStyle(
                color: AppTheme.amberPremium,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}