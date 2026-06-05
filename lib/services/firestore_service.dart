import 'dart:async';
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

  // --- Internal Helper: Resolve User Phone Number from either Phone or UID ---
  Future<String> _resolvePhone(String identifier) async {
    if (identifier.startsWith('+')) return identifier;
    try {
      final query = await _users.where('uid', isEqualTo: identifier).limit(1).get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
    } catch (e) {
      print("[TalkTandem FirestoreService] Error resolving phone for $identifier: $e");
    }
    return identifier;
  }

  // --- Users ---

  Future<AppUser?> getUser(String identifier) async {
    try {
      if (identifier.startsWith('+')) {
        final doc = await _users.doc(identifier).get();
        if (!doc.exists) return null;
        return AppUser.fromMap(identifier, doc.data()!);
      } else {
        final query = await _users.where('uid', isEqualTo: identifier).limit(1).get();
        if (query.docs.isEmpty) return null;
        return AppUser.fromMap(query.docs.first.id, query.docs.first.data());
      }
    } catch (e) {
      print("[TalkTandem FirestoreService] Error getting user: $e");
      return null;
    }
  }

  Stream<AppUser?> watchUser(String identifier) {
    if (identifier.startsWith('+')) {
      return _users.doc(identifier).snapshots().map((doc) {
        if (!doc.exists) return null;
        return AppUser.fromMap(identifier, doc.data()!);
      });
    } else {
      return _users
          .where('uid', isEqualTo: identifier)
          .limit(1)
          .snapshots()
          .map((snap) {
            if (snap.docs.isEmpty) return null;
            return AppUser.fromMap(snap.docs.first.id, snap.docs.first.data());
          });
    }
  }

  Future<void> setUserOnline(String identifier, bool online) async {
    final phone = await _resolvePhone(identifier);
    await _users.doc(phone).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
      if (!online) 'isSearching': false,
    }, SetOptions(merge: true));
  }

  Future<void> setSearching(String identifier, bool searching) async {
    final phone = await _resolvePhone(identifier);
    await _users.doc(phone).set({
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
    int limit = 20, // Limit ranking list to top 20 as requested
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

  Future<void> awardXp(String identifier, int amount) async {
    final phone = await _resolvePhone(identifier);
    await _users.doc(phone).update({
      'xp': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementConversations(String identifier) async {
    final phone = await _resolvePhone(identifier);
    await _users.doc(phone).update({
      'conversationsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRating(String identifier, double newRating) async {
    final phone = await _resolvePhone(identifier);
    final doc = await _users.doc(phone).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final oldAvg = (data['avgRating'] as num?)?.toDouble() ?? 5.0;
    final count = (data['conversationsCount'] as num?)?.toInt() ?? 0;
    final updated = count > 0
        ? ((oldAvg * count) + newRating) / (count + 1)
        : newRating;
    await _users.doc(phone).update({
      'avgRating': double.parse(updated.toStringAsFixed(1)),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(String identifier, Map<String, dynamic> fields) async {
    final phone = await _resolvePhone(identifier);
    await _users.doc(phone).set({
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

    final participants = List<String>.from(data['participantIds'] ?? []);
    for (final uid in participants) {
      final phone = await _resolvePhone(uid);
      
      // Update primary user stats
      await _users.doc(phone).update({
        'totalCalls': FieldValue.increment(1),
        'minutesPracticed': FieldValue.increment(minutes),
        'conversationsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write to nested call_history subcollection
      await _users.doc(phone).collection('call_history').doc(callId).set({
        'callId': callId,
        'participantIds': participants,
        'participantNames': data['participantNames'],
        'participantAvatars': data['participantAvatars'],
        'status': 'ended',
        'startedAt': data['startedAt'],
        'endedAt': FieldValue.serverTimestamp(),
        'durationMinutes': minutes,
      });
    }
  }

  Stream<List<CallSession>> watchCallHistory(String myUid) {
    // Return call history stream from the nested subcollection
    return StreamBuilderHelper.watchSubcollectionCallHistory(_users, myUid);
  }

  // --- Friends Subcollections Lifecycle ---

  Future<bool> areFriends(String myIdentifier, String otherIdentifier) async {
    final phone = await _resolvePhone(myIdentifier);
    final friendPhone = await _resolvePhone(otherIdentifier);
    final doc = await _users.doc(phone).collection('friends').doc(friendPhone).get();
    return doc.exists;
  }

  Future<String?> getFriendRequestStatus({
    required String myUid,
    required String otherUid,
  }) async {
    final myPhone = await _resolvePhone(myUid);
    final otherPhone = await _resolvePhone(otherUid);

    // Look up directly in subcollection
    final doc = await _users.doc(myPhone).collection('friend_requests').doc(otherPhone).get();
    if (doc.exists) {
      final data = doc.data()!;
      if (data['status'] == 'pending') {
        return data['fromPhone'] == myPhone ? 'sent' : 'received';
      }
    }
    return null;
  }

  Future<void> sendFriendRequest({
    required String fromUid,
    required AppUser me,
    required String toUid,
    required String toName,
    String? toAvatar,
  }) async {
    final fromPhone = await _resolvePhone(fromUid);
    final toPhone = await _resolvePhone(toUid);

    final requestData = {
      'fromUid': fromUid,
      'toUid': toUid,
      'fromPhone': fromPhone,
      'toPhone': toPhone,
      'fromName': me.name,
      'fromAvatar': me.avatarUrl,
      'toName': toName,
      'toAvatar': toAvatar,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save in BOTH user subcollections
    await _users.doc(toPhone).collection('friend_requests').doc(fromPhone).set(requestData);
    await _users.doc(fromPhone).collection('friend_requests').doc(toPhone).set(requestData);
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required String fromUid,
    required String toUid,
    required bool accept,
  }) async {
    final fromPhone = await _resolvePhone(fromUid);
    final toPhone = await _resolvePhone(toUid);

    // Update statuses in BOTH subcollections
    await _users.doc(toPhone).collection('friend_requests').doc(fromPhone).update({
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _users.doc(fromPhone).collection('friend_requests').doc(toPhone).update({
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (accept) {
      // 1. Update friend arrays on base user profiles
      await _users.doc(fromPhone).update({
        'friendIds': FieldValue.arrayUnion([toPhone]),
      });
      await _users.doc(toPhone).update({
        'friendIds': FieldValue.arrayUnion([fromPhone]),
      });

      // 2. Fetch profiles to write friends subcollection documents
      final docA = await _users.doc(fromPhone).get();
      final docB = await _users.doc(toPhone).get();
      
      final dataA = docA.data() ?? {};
      final dataB = docB.data() ?? {};

      // 3. Write nested friends subcollections
      await _users.doc(fromPhone).collection('friends').doc(toPhone).set({
        'uid': toUid,
        'name': dataB['name'] ?? 'User',
        'avatarUrl': dataB['avatarUrl'],
        'phoneNumber': toPhone,
        'addedAt': FieldValue.serverTimestamp(),
      });

      await _users.doc(toPhone).collection('friends').doc(fromPhone).set({
        'uid': fromUid,
        'name': dataA['name'] ?? 'User',
        'avatarUrl': dataA['avatarUrl'],
        'phoneNumber': fromPhone,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // 4. Auto-generate Lounge conversation immediately so they show up in Lounge chats list
      final userA = AppUser.fromMap(fromPhone, dataA);
      final userB = AppUser.fromMap(toPhone, dataB);
      await getOrCreateConversation(
        myUid: fromUid,
        me: userA,
        partner: userB,
      );
    }
  }

  Stream<List<FriendRequest>> watchIncomingFriendRequests(String myUid) {
    return StreamBuilderHelper.watchIncomingRequests(_users, myUid);
  }

  Stream<List<FriendRequest>> watchOutgoingFriendRequests(String myUid) {
    return StreamBuilderHelper.watchOutgoingRequests(_users, myUid);
  }

  // --- Conversations & Snapchat Chat Lifecycle ---

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
    // Retrieve and apply client-side 24-hour message filtering
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          final cutoff = now.subtract(const Duration(hours: 24));
          return snap.docs
              .map(ChatMessage.fromDoc)
              .where((msg) => msg.timestamp.isAfter(cutoff))
              .toList();
        });
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

  // --- Snapchat Edit & Delete Chat Features ---

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    await _conversations
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _conversations
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
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

// --- Stream Query Resolvers helper ---
class StreamBuilderHelper {
  static Stream<List<CallSession>> watchSubcollectionCallHistory(
      CollectionReference<Map<String, dynamic>> usersRef, String myUid) {
    // UIDs vs Phone numbers resolution
    final StreamController<List<CallSession>> controller = StreamController<List<CallSession>>.broadcast();
    
    // Auto-resolve myUid to phone number
    if (myUid.startsWith('+')) {
      _listenToCallHistorySubcollection(usersRef, myUid, controller);
    } else {
      usersRef.where('uid', isEqualTo: myUid).limit(1).get().then((query) {
        if (query.docs.isNotEmpty) {
          _listenToCallHistorySubcollection(usersRef, query.docs.first.id, controller);
        } else {
          // Fallback to top-level calls collection
          FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem')
              .collection('calls')
              .where('participantIds', arrayContains: myUid)
              .snapshots()
              .map((snap) => snap.docs.map(CallSession.fromDoc).toList())
              .listen(controller.add, onError: controller.addError);
        }
      }).catchError((e) {
        controller.addError(e);
      });
    }
    return controller.stream;
  }

  static void _listenToCallHistorySubcollection(
      CollectionReference<Map<String, dynamic>> usersRef,
      String phone,
      StreamController<List<CallSession>> controller) {
    usersRef
        .doc(phone)
        .collection('call_history')
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(CallSession.fromDoc).toList();
          list.sort((a, b) {
            final at = a.endedAt ?? a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.endedAt ?? b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bt.compareTo(at);
          });
          return list;
        })
        .listen(controller.add, onError: controller.addError);
  }

  static Stream<List<FriendRequest>> watchIncomingRequests(
      CollectionReference<Map<String, dynamic>> usersRef, String myUid) {
    final StreamController<List<FriendRequest>> controller = StreamController<List<FriendRequest>>.broadcast();
    
    if (myUid.startsWith('+')) {
      _listenToIncomingRequestsSubcollection(usersRef, myUid, controller);
    } else {
      usersRef.where('uid', isEqualTo: myUid).limit(1).get().then((query) {
        if (query.docs.isNotEmpty) {
          _listenToIncomingRequestsSubcollection(usersRef, query.docs.first.id, controller);
        }
      });
    }
    return controller.stream;
  }

  static void _listenToIncomingRequestsSubcollection(
      CollectionReference<Map<String, dynamic>> usersRef,
      String phone,
      StreamController<List<FriendRequest>> controller) {
    usersRef
        .doc(phone)
        .collection('friend_requests')
        .where('status', isEqualTo: 'pending')
        .where('toPhone', isEqualTo: phone)
        .snapshots()
        .map((snap) => snap.docs.map(FriendRequest.fromDoc).toList())
        .listen(controller.add, onError: controller.addError);
  }

  static Stream<List<FriendRequest>> watchOutgoingRequests(
      CollectionReference<Map<String, dynamic>> usersRef, String myUid) {
    final StreamController<List<FriendRequest>> controller = StreamController<List<FriendRequest>>.broadcast();
    
    if (myUid.startsWith('+')) {
      _listenToOutgoingRequestsSubcollection(usersRef, myUid, controller);
    } else {
      usersRef.where('uid', isEqualTo: myUid).limit(1).get().then((query) {
        if (query.docs.isNotEmpty) {
          _listenToOutgoingRequestsSubcollection(usersRef, query.docs.first.id, controller);
        }
      });
    }
    return controller.stream;
  }

  static void _listenToOutgoingRequestsSubcollection(
      CollectionReference<Map<String, dynamic>> usersRef,
      String phone,
      StreamController<List<FriendRequest>> controller) {
    usersRef
        .doc(phone)
        .collection('friend_requests')
        .where('status', isEqualTo: 'pending')
        .where('fromPhone', isEqualTo: phone)
        .snapshots()
        .map((snap) => snap.docs.map(FriendRequest.fromDoc).toList())
        .listen(controller.add, onError: controller.addError);
  }
}
