import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'notification_sender.dart';

enum AppCallType { audio, video }

class AppCall {
  const AppCall({
    required this.id,
    required this.callerUid,
    required this.callerName,
    required this.callerPhotoUrl,
    required this.receiverUid,
    required this.receiverName,
    required this.receiverPhotoUrl,
    required this.type,
    required this.status,
    required this.videoEnabledBy,
  });

  final String id;
  final String callerUid;
  final String callerName;
  final String callerPhotoUrl;
  final String receiverUid;
  final String receiverName;
  final String receiverPhotoUrl;
  final AppCallType type;
  final String status;
  final Map<String, bool> videoEnabledBy;

  bool get isVideo => type == AppCallType.video;

  factory AppCall.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final rawVideoEnabledBy = data['videoEnabledBy'];
    final videoEnabledBy = rawVideoEnabledBy is Map
        ? rawVideoEnabledBy.map(
            (key, value) => MapEntry(key.toString(), value == true),
          )
        : <String, bool>{};
    return AppCall(
      id: document.id,
      callerUid: data['callerUid']?.toString() ?? '',
      callerName: data['callerName']?.toString() ?? 'Пользователь',
      callerPhotoUrl: data['callerPhotoUrl']?.toString() ?? '',
      receiverUid: data['receiverUid']?.toString() ?? '',
      receiverName: data['receiverName']?.toString() ?? 'Пользователь',
      receiverPhotoUrl: data['receiverPhotoUrl']?.toString() ?? '',
      type: data['type'] == 'video'
          ? AppCallType.video
          : AppCallType.audio,
      status: data['status']?.toString() ?? 'ringing',
      videoEnabledBy: videoEnabledBy,
    );
  }
}

class CallService {
  CallService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _calls =>
      _firestore.collection('calls');

  static Future<Map<String, String>> readUserIdentity(String uid) async {
    final document = await _firestore.collection('users').doc(uid).get();
    final data = document.data() ?? <String, dynamic>{};
    return <String, String>{
      'name': (data['name'] ?? data['displayName'] ?? '')
          .toString()
          .trim(),
      'photoUrl': (data['photoUrl'] ?? data['avatarUrl'] ?? '')
          .toString()
          .trim(),
    };
  }

  static const Map<String, dynamic> peerConfiguration = <String, dynamic>{
    'iceServers': <Map<String, dynamic>>[
      <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
      <String, dynamic>{'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  static Stream<AppCall?> watchIncomingCall(String uid) {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return Stream<AppCall?>.value(null);

    return _calls
        .where('receiverUid', isEqualTo: cleanUid)
        .where('status', isEqualTo: 'ringing')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return AppCall.fromDocument(snapshot.docs.first);
        });
  }

  static Stream<AppCall?> watchCall(String callId) {
    return _calls.doc(callId).snapshots().map((document) {
      if (!document.exists) return null;
      return AppCall.fromDocument(document);
    });
  }

  static Stream<String?> watchCallStatus(String callId) {
    return _calls.doc(callId).snapshots().map((document) {
      if (!document.exists) return null;
      return document.data()?['status']?.toString();
    });
  }

  static Future<String> createCall({
    required String callerUid,
    required String callerName,
    required String callerPhotoUrl,
    required String receiverUid,
    required String receiverName,
    required String receiverPhotoUrl,
    required AppCallType type,
    required RTCSessionDescription offer,
  }) async {
    final reference = _calls.doc();
    await reference.set(<String, dynamic>{
      'callerUid': callerUid,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'receiverUid': receiverUid,
      'receiverName': receiverName,
      'receiverPhotoUrl': receiverPhotoUrl,
      'participants': <String>[callerUid, receiverUid],
      'type': type == AppCallType.video ? 'video' : 'audio',
      'status': 'ringing',
      'videoEnabledBy': <String, bool>{
        callerUid: type == AppCallType.video,
        receiverUid: type == AppCallType.video,
      },
      'offer': <String, dynamic>{
        'type': offer.type,
        'sdp': offer.sdp,
      },
      'answer': null,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
      'endedAt': null,
    });
    unawaited(
      NotificationSender.sendCallNotification(callId: reference.id),
    );
    return reference.id;
  }

  static Future<RTCSessionDescription?> readOffer(String callId) async {
    final document = await _calls.doc(callId).get();
    final offer = document.data()?['offer'];
    if (offer is! Map) return null;
    return RTCSessionDescription(
      offer['sdp']?.toString(),
      offer['type']?.toString(),
    );
  }

  static Future<void> answerCall({
    required String callId,
    required RTCSessionDescription answer,
  }) {
    return _calls.doc(callId).update(<String, dynamic>{
      'answer': <String, dynamic>{
        'type': answer.type,
        'sdp': answer.sdp,
      },
      'status': 'active',
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<RTCSessionDescription?> watchAnswer(String callId) {
    return _calls.doc(callId).snapshots().map((document) {
      final answer = document.data()?['answer'];
      if (answer is! Map) return null;
      return RTCSessionDescription(
        answer['sdp']?.toString(),
        answer['type']?.toString(),
      );
    });
  }

  static Future<void> addCandidate({
    required String callId,
    required bool fromCaller,
    required RTCIceCandidate candidate,
  }) {
    final collection = fromCaller ? 'callerCandidates' : 'calleeCandidates';
    return _calls.doc(callId).collection(collection).add(<String, dynamic>{
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  static Stream<RTCIceCandidate> watchRemoteCandidates({
    required String callId,
    required bool localIsCaller,
  }) {
    final collection = localIsCaller
        ? 'calleeCandidates'
        : 'callerCandidates';
    return _calls
        .doc(callId)
        .collection(collection)
        .snapshots()
        .expand((snapshot) => snapshot.docChanges)
        .where((change) => change.type == DocumentChangeType.added)
        .map((change) {
          final data = change.doc.data();
          return RTCIceCandidate(
            data?['candidate']?.toString(),
            data?['sdpMid']?.toString(),
            data?['sdpMLineIndex'] as int?,
          );
        });
  }

  static Future<void> setStatus(String callId, String status) {
    return _calls.doc(callId).update(<String, dynamic>{
      'status': status,
      if (status == 'ended' ||
          status == 'declined' ||
          status == 'cancelled')
        'endedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setVideoEnabled({
    required String callId,
    required String uid,
    required bool enabled,
  }) {
    return _calls.doc(callId).update(<String, dynamic>{
      'videoEnabledBy.$uid': enabled,
    });
  }

  static Future<void> saveCallHistory({
    required String callId,
    required String callerUid,
    required String receiverUid,
    required AppCallType type,
    required int durationSeconds,
  }) async {
    final ids = <String>[callerUid.trim(), receiverUid.trim()]..sort();
    final chatId = '${ids[0]}_${ids[1]}';
    final chatReference = _firestore.collection('chats').doc(chatId);
    final messageReference =
        chatReference.collection('messages').doc('call_$callId');
    final label = type == AppCallType.video
        ? '🎥 Видеозвонок'
        : '📞 Звонок';
    final durationLabel = durationSeconds > 0
        ? ' · ${(durationSeconds ~/ 60).toString().padLeft(2, '0')}:${(durationSeconds % 60).toString().padLeft(2, '0')}'
        : '';

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(messageReference);
      if (existing.exists) return;

      transaction.set(
        chatReference,
        <String, dynamic>{
          'participants': ids,
          'lastMessage': '$label$durationLabel',
          'lastSenderUid': callerUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(messageReference, <String, dynamic>{
        'senderUid': callerUid,
        'receiverUid': receiverUid,
        'text': '$label$durationLabel',
        'imageUrl': '',
        'voiceUrl': '',
        'durationSeconds': 0,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'readAt': null,
        'replyToId': '',
        'replySenderUid': '',
        'replySenderName': '',
        'replyType': '',
        'replyPreview': '',
        'reactions': <String, String>{},
        'deletedFor': <String>[],
      });
    });
  }
}
