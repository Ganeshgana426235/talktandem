import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String phoneNumber;
  final String? avatarUrl;
  final String gender;
  final String? location;
  final String? state;
  final List<String> interests;
  final int xp;
  final int streak;
  final int conversationsCount;
  final int totalCalls;
  final int minutesPracticed;
  final List<String> friendIds;
  final double avgRating;
  final bool isPremium;
  final bool isSearching;
  final bool isOnline;

  AppUser({
    required this.uid,
    required this.name,
    required this.phoneNumber,
    this.avatarUrl,
    this.gender = 'Male',
    this.location,
    this.state,
    this.interests = const [],
    this.xp = 0,
    this.streak = 0,
    this.conversationsCount = 0,
    this.totalCalls = 0,
    this.minutesPracticed = 0,
    this.friendIds = const [],
    this.avgRating = 5.0,
    this.isPremium = false,
    this.isSearching = false,
    this.isOnline = false,
  });

  factory AppUser.fromMap(String docId, Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'] as String? ?? docId,
      name: data['name'] as String? ?? 'User',
      phoneNumber: data['phoneNumber'] as String? ?? (docId.startsWith('+') ? docId : ''),
      avatarUrl: data['avatarUrl'] as String?,
      gender: data['gender'] as String? ?? 'Male',
      location: data['location'] as String?,
      state: data['state'] as String?,
      interests: List<String>.from(data['interests'] ?? []),
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      conversationsCount: (data['conversationsCount'] as num?)?.toInt() ?? 0,
      totalCalls: (data['totalCalls'] as num?)?.toInt() ??
          (data['conversationsCount'] as num?)?.toInt() ??
          0,
      minutesPracticed: (data['minutesPracticed'] as num?)?.toInt() ?? 0,
      friendIds: List<String>.from(data['friendIds'] ?? []),
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 5.0,
      isPremium: data['isPremium'] as bool? ?? false,
      isSearching: data['isSearching'] as bool? ?? false,
      isOnline: data['isOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl,
        'gender': gender,
        'location': location ?? '',
        'state': state ?? '',
        'interests': interests,
        'xp': xp,
        'streak': streak,
        'conversationsCount': conversationsCount,
        'totalCalls': totalCalls,
        'minutesPracticed': minutesPracticed,
        'friendIds': friendIds,
        'avgRating': avgRating,
        'isPremium': isPremium,
        'isSearching': isSearching,
        'isOnline': isOnline,
      };
}

class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantAvatars;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCount;

  Conversation({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantAvatars,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = const {},
  });

  factory Conversation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantAvatars: Map<String, String?>.from(data['participantAvatars'] ?? {}),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      ),
    );
  }

  String otherUserId(String myUid) =>
      participantIds.firstWhere((id) => id != myUid, orElse: () => '');
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool hasError;
  final String? correction;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.hasError = false,
    this.correction,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasError: data['hasError'] as bool? ?? false,
      correction: data['correction'] as String?,
    );
  }
}

class LeaderboardEntry {
  final String uid;
  final String name;
  final String? avatarUrl;
  final int xp;
  final int streak;
  final String? state;

  LeaderboardEntry({
    required this.uid,
    required this.name,
    this.avatarUrl,
    required this.xp,
    required this.streak,
    this.state,
  });

  factory LeaderboardEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LeaderboardEntry(
      uid: doc.id,
      name: data['name'] as String? ?? 'User',
      avatarUrl: data['avatarUrl'] as String?,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      state: data['state'] as String?,
    );
  }
}

class CallSession {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantAvatars;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationMinutes;

  CallSession({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantAvatars,
    this.status = 'active',
    this.startedAt,
    this.endedAt,
    this.durationMinutes = 0,
  });

  factory CallSession.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CallSession(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantAvatars: Map<String, String?>.from(data['participantAvatars'] ?? {}),
      status: data['status'] as String? ?? 'active',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  String partnerId(String myUid) =>
      participantIds.firstWhere((id) => id != myUid, orElse: () => '');
}

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String? fromAvatar;
  final String toName;
  final String? toAvatar;
  final String status;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    this.fromAvatar,
    required this.toName,
    this.toAvatar,
    this.status = 'pending',
  });

  factory FriendRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FriendRequest(
      id: doc.id,
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      fromName: data['fromName'] as String? ?? 'User',
      fromAvatar: data['fromAvatar'] as String?,
      toName: data['toName'] as String? ?? 'User',
      toAvatar: data['toAvatar'] as String?,
      status: data['status'] as String? ?? 'pending',
    );
  }
}