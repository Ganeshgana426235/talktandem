import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/auth_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'chat_room_screen.dart';

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
              Tab(text: 'Connections'),
              Tab(text: 'Chats'),
              Tab(text: 'Requests'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _ConnectionsTab(),
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

class _ConnectionsTab extends StatelessWidget {
  const _ConnectionsTab();

  String _formatDate(DateTime? time) {
    if (time == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}, ${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myUid = auth.uid ?? '';
    final friendIds =
        List<String>.from(auth.userData?['friendIds'] ?? []);
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return StreamBuilder<List<CallSession>>(
      stream: auth.firestore.watchCallHistory(myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.tealAccent),
          );
        }

        final calls = snapshot.data ?? [];

        if (calls.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.users,
                      size: 56, color: AppTheme.tealAccent),
                  const SizedBox(height: 16),
                  Text(
                    'No connections yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a call from Radar to see your practice partners here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: calls.length,
          itemBuilder: (context, index) {
            final call = calls[index];
            final otherId = call.partnerId(myUid);
            final name =
                call.participantNames[otherId] ?? 'Practice Partner';
            final avatar = call.participantAvatars[otherId];
            final isFriend = friendIds.contains(otherId);
            final isEnded = call.status == 'ended';
            final minutes = call.durationMinutes;
            final date = call.endedAt ?? call.startedAt;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEnded
                              ? '$minutes min · ${_formatDate(date)}'
                              : 'Call in progress',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
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
            );
          },
        );
      },
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

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

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

    return StreamBuilder<List<Conversation>>(
      stream: auth.firestore.watchConversations(myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.tealAccent),
          );
        }

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return Center(
            child: Text(
              'No chats yet. Message a connection after a call!',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
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
            if (incomingSnap.connectionState == ConnectionState.waiting ||
                outgoingSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.tealAccent),
              );
            }

            final incoming = incomingSnap.data ?? [];
            final outgoing = outgoingSnap.data ?? [];

            if (incoming.isEmpty && outgoing.isEmpty) {
              return Center(
                child: Text(
                  'No pending friend requests.',
                  style: TextStyle(color: textSecondary),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
