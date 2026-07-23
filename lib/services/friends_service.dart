import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FriendshipState { none, outgoingPending, incomingPending, friends }

class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.status,
    required this.bio,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final String status;
  final String bio;

  factory AppUserProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AppUserProfile(
      uid: document.id,
      name: data['name']?.toString().trim().isNotEmpty == true
          ? data['name'].toString().trim()
          : 'Пользователь',
      photoUrl: data['photoUrl']?.toString().trim() ?? '',
      status: data['status']?.toString().trim() ?? '',
      bio: data['bio']?.toString().trim() ?? '',
    );
  }
}

class FriendRequestData {
  const FriendRequestData({
    required this.id,
    required this.senderUid,
    required this.receiverUid,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.receiverName,
    required this.receiverPhotoUrl,
    required this.status,
  });

  final String id;
  final String senderUid;
  final String receiverUid;
  final String senderName;
  final String senderPhotoUrl;
  final String receiverName;
  final String receiverPhotoUrl;
  final String status;

  factory FriendRequestData.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return FriendRequestData(
      id: document.id,
      senderUid: data['senderUid']?.toString() ?? '',
      receiverUid: data['receiverUid']?.toString() ?? '',
      senderName: data['senderName']?.toString().trim().isNotEmpty == true
          ? data['senderName'].toString().trim()
          : 'Пользователь',
      senderPhotoUrl: data['senderPhotoUrl']?.toString().trim() ?? '',
      receiverName: data['receiverName']?.toString().trim().isNotEmpty == true
          ? data['receiverName'].toString().trim()
          : 'Пользователь',
      receiverPhotoUrl: data['receiverPhotoUrl']?.toString().trim() ?? '',
      status: data['status']?.toString() ?? 'pending',
    );
  }
}

class FriendsService {
  FriendsService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('friend_requests');

  static CollectionReference<Map<String, dynamic>> get _friendships =>
      _firestore.collection('friendships');

  static String pairId(String firstUid, String secondUid) {
    final values = <String>[firstUid, secondUid]..sort();
    return '${values[0]}_${values[1]}';
  }

  static Future<List<AppUserProfile>> searchUsers({
    required String query,
    required String currentUid,
  }) async {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return <AppUserProfile>[];
    }

    final snapshot = await _users
        .orderBy('nameLowercase')
        .startAt(<Object>[normalized])
        .endAt(<Object>['$normalized\uf8ff'])
        .limit(20)
        .get()
        .timeout(const Duration(seconds: 15));

    return snapshot.docs
        .where((document) => document.id != currentUid)
        .map(AppUserProfile.fromDocument)
        .toList();
  }

  static Future<FriendshipState> getFriendshipState({
    required String currentUid,
    required String otherUid,
  }) async {
    final id = pairId(currentUid, otherUid);

    final results = await Future.wait([
      _friendships.doc(id).get(),
      _requests.doc(id).get(),
    ]).timeout(const Duration(seconds: 15));

    final friendship = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final request = results[1] as DocumentSnapshot<Map<String, dynamic>>;

    if (friendship.exists) {
      return FriendshipState.friends;
    }

    if (!request.exists) {
      return FriendshipState.none;
    }

    final data = request.data() ?? <String, dynamic>{};

    if (data['status'] != 'pending') {
      return FriendshipState.none;
    }

    if (data['senderUid'] == currentUid) {
      return FriendshipState.outgoingPending;
    }

    if (data['receiverUid'] == currentUid) {
      return FriendshipState.incomingPending;
    }

    return FriendshipState.none;
  }

  static Future<void> sendFriendRequest({
    required User currentUser,
    required AppUserProfile receiver,
  }) async {
    if (currentUser.uid == receiver.uid) {
      throw StateError('Нельзя отправить заявку самому себе.');
    }

    final id = pairId(currentUser.uid, receiver.uid);
    final currentUserRef = _users.doc(currentUser.uid);
    final receiverRef = _users.doc(receiver.uid);
    final requestRef = _requests.doc(id);
    final friendshipRef = _friendships.doc(id);

    await _firestore
        .runTransaction((transaction) async {
          final currentUserSnapshot = await transaction.get(currentUserRef);
          final receiverSnapshot = await transaction.get(receiverRef);
          final requestSnapshot = await transaction.get(requestRef);
          final friendshipSnapshot = await transaction.get(friendshipRef);

          if (!receiverSnapshot.exists) {
            throw StateError('Пользователь больше не существует.');
          }

          if (friendshipSnapshot.exists) {
            throw StateError('Вы уже друзья.');
          }

          if (requestSnapshot.exists) {
            final requestData = requestSnapshot.data() ?? <String, dynamic>{};

            if (requestData['status'] == 'pending') {
              throw StateError('Заявка между вами уже существует.');
            }
          }

          final currentData = currentUserSnapshot.data() ?? <String, dynamic>{};
          final receiverData = receiverSnapshot.data() ?? <String, dynamic>{};

          transaction.set(requestRef, <String, dynamic>{
            'pairId': id,
            'senderUid': currentUser.uid,
            'receiverUid': receiver.uid,
            'senderName':
                currentData['name']?.toString().trim().isNotEmpty == true
                ? currentData['name'].toString().trim()
                : currentUser.displayName?.trim().isNotEmpty == true
                ? currentUser.displayName!.trim()
                : 'Пользователь',
            'senderPhotoUrl':
                currentData['photoUrl']?.toString().trim() ??
                currentUser.photoURL?.trim() ??
                '',
            'receiverName':
                receiverData['name']?.toString().trim().isNotEmpty == true
                ? receiverData['name'].toString().trim()
                : receiver.name,
            'receiverPhotoUrl':
                receiverData['photoUrl']?.toString().trim() ??
                receiver.photoUrl,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  static Future<void> acceptRequest({
    required String requestId,
    required String currentUid,
  }) async {
    final requestRef = _requests.doc(requestId);

    await _firestore
        .runTransaction((transaction) async {
          final requestSnapshot = await transaction.get(requestRef);

          if (!requestSnapshot.exists) {
            throw StateError('Заявка больше не существует.');
          }

          final requestData = requestSnapshot.data() ?? <String, dynamic>{};

          if (requestData['receiverUid'] != currentUid) {
            throw StateError('Эта заявка предназначена другому пользователю.');
          }

          if (requestData['status'] != 'pending') {
            throw StateError('Эта заявка уже обработана.');
          }

          final senderUid = requestData['senderUid']?.toString() ?? '';
          final receiverUid = requestData['receiverUid']?.toString() ?? '';

          if (senderUid.isEmpty || receiverUid.isEmpty) {
            throw StateError('В заявке отсутствуют данные пользователей.');
          }

          final friendshipId = pairId(senderUid, receiverUid);
          final friendshipRef = _friendships.doc(friendshipId);
          final senderRef = _users.doc(senderUid);
          final receiverRef = _users.doc(receiverUid);

          final friendshipSnapshot = await transaction.get(friendshipRef);
          final senderSnapshot = await transaction.get(senderRef);
          final receiverSnapshot = await transaction.get(receiverRef);

          if (!senderSnapshot.exists || !receiverSnapshot.exists) {
            throw StateError('Один из пользователей больше не существует.');
          }

          if (!friendshipSnapshot.exists) {
            transaction.set(friendshipRef, <String, dynamic>{
              'userIds': <String>[senderUid, receiverUid],
              'createdAt': FieldValue.serverTimestamp(),
            });

            transaction.set(senderRef, <String, dynamic>{
              'friendsCount': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            transaction.set(receiverRef, <String, dynamic>{
              'friendsCount': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          transaction.update(requestRef, <String, dynamic>{
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  static Future<void> rejectRequest({
    required String requestId,
    required String currentUid,
  }) async {
    final requestRef = _requests.doc(requestId);

    await _firestore
        .runTransaction((transaction) async {
          final snapshot = await transaction.get(requestRef);

          if (!snapshot.exists) {
            return;
          }

          final data = snapshot.data() ?? <String, dynamic>{};

          if (data['receiverUid'] != currentUid) {
            throw StateError('Нельзя отклонить чужую заявку.');
          }

          transaction.update(requestRef, <String, dynamic>{
            'status': 'declined',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  static Future<void> cancelRequest({
    required String requestId,
    required String currentUid,
  }) async {
    final requestRef = _requests.doc(requestId);

    await _firestore
        .runTransaction((transaction) async {
          final snapshot = await transaction.get(requestRef);

          if (!snapshot.exists) {
            return;
          }

          final data = snapshot.data() ?? <String, dynamic>{};

          if (data['senderUid'] != currentUid) {
            throw StateError('Нельзя отменить чужую заявку.');
          }

          transaction.update(requestRef, <String, dynamic>{
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  static Stream<List<FriendRequestData>> watchIncomingRequests(
    String currentUid,
  ) {
    return _requests
        .where('receiverUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(FriendRequestData.fromDocument)
              .toList();

          return requests;
        });
  }

  static Stream<List<FriendRequestData>> watchOutgoingRequests(
    String currentUid,
  ) {
    return _requests
        .where('senderUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(FriendRequestData.fromDocument)
              .toList();

          return requests;
        });
  }

  static Stream<List<AppUserProfile>> watchFriends(String currentUid) {
    return _friendships
        .where('userIds', arrayContains: currentUid)
        .snapshots()
        .asyncMap((snapshot) async {
          final otherUids = snapshot.docs
              .map((document) {
                final ids = List<String>.from(
                  document.data()['userIds'] as List<dynamic>? ?? <dynamic>[],
                );

                return ids.firstWhere(
                  (uid) => uid != currentUid,
                  orElse: () => '',
                );
              })
              .where((uid) => uid.isNotEmpty)
              .toList();

          if (otherUids.isEmpty) {
            return <AppUserProfile>[];
          }

          final profiles = await Future.wait(
            otherUids.map((uid) => _users.doc(uid).get()),
          );

          return profiles
              .where((document) => document.exists)
              .map(AppUserProfile.fromDocument)
              .toList();
        });
  }

  static Future<void> removeFriend({
    required String currentUid,
    required String otherUid,
  }) async {
    final id = pairId(currentUid, otherUid);
    final friendshipRef = _friendships.doc(id);
    final currentRef = _users.doc(currentUid);
    final otherRef = _users.doc(otherUid);

    await _firestore
        .runTransaction((transaction) async {
          final friendshipSnapshot = await transaction.get(friendshipRef);
          final currentSnapshot = await transaction.get(currentRef);
          final otherSnapshot = await transaction.get(otherRef);

          if (!friendshipSnapshot.exists) {
            return;
          }

          transaction.delete(friendshipRef);

          if (currentSnapshot.exists) {
            transaction.set(currentRef, <String, dynamic>{
              'friendsCount': FieldValue.increment(-1),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          if (otherSnapshot.exists) {
            transaction.set(otherRef, <String, dynamic>{
              'friendsCount': FieldValue.increment(-1),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        })
        .timeout(const Duration(seconds: 20));
  }
}
