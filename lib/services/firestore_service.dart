import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  CollectionReference<Map<String, dynamic>> get _calls =>
      _db.collection('calls');

  CollectionReference<Map<String, dynamic>> get _feedback =>
      _db.collection('call_feedback');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  CollectionReference<Map<String, dynamic>> get _friendRequests =>
      _db.collection('friend_requests');

  // --- Users ---

  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(uid, doc.data()!);
  }

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(uid, doc.data()!);
    });
  }

  Future<void> setUserOnline(String uid, bool online) async {
    await _users.doc(uid).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
      if (!online) 'isSearching': false,
    }, SetOptions(merge: true));
  }

  Future<void> setSearching(String uid, bool searching) async {
    await _users.doc(uid).set({
      'isSearching': searching,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<AppUser?> findMatchPartner({
    required String myUid,
    String? genderFilter,
  }) async {
    Query<Map<String, dynamic>> query = _users
        .where('isSearching', isEqualTo: true)
        .limit(10);

    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      if (doc.id == myUid) continue;
      final data = doc.data();
      if (genderFilter != null &&
          genderFilter != 'Any Gender' &&
          data['gender'] != genderFilter) {
        continue;
      }
      return AppUser.fromMap(doc.id, data);
    }
    return null;
  }

  Stream<List<LeaderboardEntry>> watchLeaderboard({
    String? stateFilter,
    int limit = 50,
  }) {
    return _users
        .orderBy('xp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          var entries =
              snap.docs.map((d) => LeaderboardEntry.fromDoc(d)).toList();
          if (stateFilter != null && stateFilter.isNotEmpty) {
            entries = entries
                .where((e) =>
                    e.state?.toLowerCase() == stateFilter.toLowerCase())
                .toList();
          }
          return entries.take(limit).toList();
        });
  }

  Future<void> awardXp(String uid, int amount) async {
    await _users.doc(uid).update({
      'xp': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementConversations(String uid) async {
    await _users.doc(uid).update({
      'conversationsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRating(String uid, double newRating) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final oldAvg = (data['avgRating'] as num?)?.toDouble() ?? 5.0;
    final count = (data['conversationsCount'] as num?)?.toInt() ?? 0;
    final updated = count > 0
        ? ((oldAvg * count) + newRating) / (count + 1)
        : newRating;
    await _users.doc(uid).update({
      'avgRating': double.parse(updated.toStringAsFixed(1)),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).set({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- Matching / Calls ---

  Future<CallSession> createCallSession({
    required String myUid,
    required AppUser me,
    required AppUser partner,
  }) async {
    final ref = _calls.doc();
    final data = {
      'participantIds': [myUid, partner.uid],
      'participantNames': {myUid: me.name, partner.uid: partner.name},
      'participantAvatars': {
        myUid: me.avatarUrl,
        partner.uid: partner.avatarUrl,
      },
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data);
    await setSearching(myUid, false);
    await setSearching(partner.uid, false);
    return CallSession.fromDoc(await ref.get());
  }

  Future<void> endCallSession(String callId, {int? durationMinutes}) async {
    final ref = _calls.doc(callId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final startedAt = (data['startedAt'] as Timestamp?)?.toDate();
    int minutes = durationMinutes ?? 0;
    if (minutes <= 0 && startedAt != null) {
      minutes = DateTime.now().difference(startedAt).inMinutes.clamp(1, 999);
    }
    if (minutes <= 0) minutes = 1;

    await ref.update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'durationMinutes': minutes,
    });

    final participants =
        List<String>.from(data['participantIds'] ?? []);
    for (final uid in participants) {
      await _users.doc(uid).update({
        'totalCalls': FieldValue.increment(1),
        'minutesPracticed': FieldValue.increment(minutes),
        'conversationsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<CallSession>> watchCallHistory(String myUid) {
    return _calls
        .where('participantIds', arrayContains: myUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(CallSession.fromDoc).toList();
          list.sort((a, b) {
            final at = a.endedAt ?? a.startedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.endedAt ?? b.startedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bt.compareTo(at);
          });
          return list;
        });
  }

  // --- Friends ---

  Future<bool> areFriends(String uid, String otherUid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return false;
    final friends = List<String>.from(doc.data()?['friendIds'] ?? []);
    return friends.contains(otherUid);
  }

  Future<String?> getFriendRequestStatus({
    required String myUid,
    required String otherUid,
  }) async {
    final sent = await _friendRequests
        .where('fromUid', isEqualTo: myUid)
        .where('toUid', isEqualTo: otherUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (sent.docs.isNotEmpty) return 'sent';

    final received = await _friendRequests
        .where('fromUid', isEqualTo: otherUid)
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (received.docs.isNotEmpty) return 'received';

    return null;
  }

  Future<void> sendFriendRequest({
    required String fromUid,
    required AppUser me,
    required String toUid,
    required String toName,
    String? toAvatar,
  }) async {
    final existing = await _friendRequests
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _friendRequests.add({
      'fromUid': fromUid,
      'toUid': toUid,
      'fromName': me.name,
      'fromAvatar': me.avatarUrl,
      'toName': toName,
      'toAvatar': toAvatar,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required String fromUid,
    required String toUid,
    required bool accept,
  }) async {
    await _friendRequests.doc(requestId).update({
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (accept) {
      await _users.doc(fromUid).update({
        'friendIds': FieldValue.arrayUnion([toUid]),
      });
      await _users.doc(toUid).update({
        'friendIds': FieldValue.arrayUnion([fromUid]),
      });
    }
  }

  Stream<List<FriendRequest>> watchIncomingFriendRequests(String myUid) {
    return _friendRequests
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(FriendRequest.fromDoc).toList());
  }

  Stream<List<FriendRequest>> watchOutgoingFriendRequests(String myUid) {
    return _friendRequests
        .where('fromUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(FriendRequest.fromDoc).toList());
  }

  // --- Conversations ---

  String conversationIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<String> getOrCreateConversation({
    required String myUid,
    required AppUser me,
    required AppUser partner,
  }) async {
    final convId = conversationIdFor(myUid, partner.uid);
    final ref = _conversations.doc(convId);
    final existing = await ref.get();
    if (!existing.exists) {
      await ref.set({
        'participantIds': [myUid, partner.uid],
        'participantNames': {myUid: me.name, partner.uid: partner.name},
        'participantAvatars': {
          myUid: me.avatarUrl,
          partner.uid: partner.avatarUrl,
        },
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {myUid: 0, partner.uid: 0},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return convId;
  }

  Stream<List<Conversation>> watchConversations(String myUid) {
    return _conversations
        .where('participantIds', arrayContains: myUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Conversation.fromDoc).toList();
          list.sort((a, b) {
            final at = a.lastMessageAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.lastMessageAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bt.compareTo(at);
          });
          return list;
        });
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    required String otherUserId,
    bool hasError = false,
    String? correction,
  }) async {
    final convRef = _conversations.doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    await msgRef.set({
      'senderId': senderId,
      'text': text,
      'hasError': hasError,
      if (correction != null) 'correction': correction,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await convRef.update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });
  }

  Future<void> markConversationRead(String conversationId, String myUid) async {
    await _conversations.doc(conversationId).update({
      'unreadCount.$myUid': 0,
    });
  }

  // --- Feedback & Reports ---

  Future<void> submitCallFeedback({
    required String callId,
    required String raterId,
    required String ratedUserId,
    required int politenessRating,
    required int clarityRating,
    required List<String> tags,
  }) async {
    await _feedback.add({
      'callId': callId,
      'raterId': raterId,
      'ratedUserId': ratedUserId,
      'politenessRating': politenessRating,
      'clarityRating': clarityRating,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final avg = (politenessRating + clarityRating) / 2.0;
    await updateRating(ratedUserId, avg);
    await awardXp(raterId, 25);
  }

  Future<void> submitReport({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    required String context,
  }) async {
    await _reports.add({
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'context': context,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
