import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.receiverUid,
    required this.text,
    required this.imageUrl,
    required this.voiceUrl,
    required this.durationSeconds,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.readAt,
  });

  final String id;
  final String senderUid;
  final String receiverUid;
  final String text;
  final String imageUrl;
  final String voiceUrl;
  final int durationSeconds;
  final String type;
  final DateTime? createdAt;
  final bool isRead;
  final DateTime? readAt;

  bool isMine(String currentUid) {
    return senderUid == currentUid;
  }

  bool get isImage {
    return type == 'image' && imageUrl.trim().isNotEmpty;
  }

  bool get isVoice {
    return type == 'voice' && voiceUrl.trim().isNotEmpty;
  }

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final createdAtValue = data['createdAt'];
    final readAtValue = data['readAt'];

    return ChatMessage(
      id: document.id,
      senderUid: data['senderUid']?.toString() ?? '',
      receiverUid: data['receiverUid']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      voiceUrl: data['voiceUrl']?.toString() ?? '',
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      type: data['type']?.toString() ?? 'text',
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
      isRead: data['isRead'] == true,
      readAt: readAtValue is Timestamp ? readAtValue.toDate() : null,
    );
  }
}

class ChatPreview {
  const ChatPreview({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastSenderUid,
    required this.updatedAt,
  });

  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderUid;
  final DateTime? updatedAt;

  String otherUid(String currentUid) {
    return participants.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );
  }

  factory ChatPreview.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final timestamp = data['updatedAt'];

    final rawParticipants =
        data['participants'] as List<dynamic>? ?? <dynamic>[];

    return ChatPreview(
      id: document.id,
      participants: rawParticipants
          .map((value) => value.toString())
          .where((uid) => uid.trim().isNotEmpty)
          .toList(),
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastSenderUid: data['lastSenderUid']?.toString() ?? '',
      updatedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class ChatService {
  ChatService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _chats {
    return _firestore.collection('chats');
  }

  static String chatId(String firstUid, String secondUid) {
    final ids = <String>[firstUid.trim(), secondUid.trim()]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  static DocumentReference<Map<String, dynamic>> _chatRef(
    String firstUid,
    String secondUid,
  ) {
    return _chats.doc(chatId(firstUid, secondUid));
  }

  static Stream<List<ChatMessage>> watchMessages({
    required String currentUid,
    required String otherUid,
  }) {
    final cleanCurrentUid = currentUid.trim();
    final cleanOtherUid = otherUid.trim();

    if (cleanCurrentUid.isEmpty || cleanOtherUid.isEmpty) {
      return Stream<List<ChatMessage>>.value(<ChatMessage>[]);
    }

    return _chatRef(cleanCurrentUid, cleanOtherUid)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(ChatMessage.fromDocument).where((message) {
            if (message.senderUid.isEmpty) {
              return false;
            }

            if (message.isImage || message.isVoice) {
              return true;
            }

            return message.type == 'text' && message.text.trim().isNotEmpty;
          }).toList();
        });
  }

  static Stream<List<ChatPreview>> watchChats({required String currentUid}) {
    final cleanCurrentUid = currentUid.trim();

    if (cleanCurrentUid.isEmpty) {
      return Stream<List<ChatPreview>>.value(<ChatPreview>[]);
    }

    return _chats
        .where('participants', arrayContains: cleanCurrentUid)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs.map(ChatPreview.fromDocument).where((
            chat,
          ) {
            return chat.participants.length >= 2 &&
                chat.lastMessage.trim().isNotEmpty &&
                chat.otherUid(cleanCurrentUid).isNotEmpty;
          }).toList();

          chats.sort((first, second) {
            final firstDate = first.updatedAt;
            final secondDate = second.updatedAt;

            if (firstDate == null && secondDate == null) {
              return second.id.compareTo(first.id);
            }

            if (firstDate == null) {
              return 1;
            }

            if (secondDate == null) {
              return -1;
            }

            return secondDate.compareTo(firstDate);
          });

          return chats;
        });
  }

  static Future<void> sendMessage({
    required String currentUid,
    required String otherUid,
    required String text,
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    await _sendMessageData(
      currentUid: currentUid,
      otherUid: otherUid,
      lastMessage: cleanText,
      messageData: <String, dynamic>{
        'text': cleanText,
        'imageUrl': '',
        'voiceUrl': '',
        'durationSeconds': 0,
        'type': 'text',
      },
    );
  }

  static Future<void> sendImage({
    required String currentUid,
    required String otherUid,
    required String imageUrl,
  }) async {
    final cleanImageUrl = imageUrl.trim();

    if (cleanImageUrl.isEmpty) {
      throw StateError('Cloudinary не вернул ссылку на фотографию.');
    }

    await _sendMessageData(
      currentUid: currentUid,
      otherUid: otherUid,
      lastMessage: '📷 Фото',
      messageData: <String, dynamic>{
        'text': '',
        'imageUrl': cleanImageUrl,
        'voiceUrl': '',
        'durationSeconds': 0,
        'type': 'image',
      },
    );
  }

  static Future<void> sendVoice({
    required String currentUid,
    required String otherUid,
    required String voiceUrl,
    required int durationSeconds,
  }) async {
    final cleanVoiceUrl = voiceUrl.trim();

    if (cleanVoiceUrl.isEmpty) {
      throw StateError('Cloudinary не вернул ссылку на голосовое сообщение.');
    }

    final safeDuration = durationSeconds.clamp(1, 3600);

    await _sendMessageData(
      currentUid: currentUid,
      otherUid: otherUid,
      lastMessage: '🎤 Голосовое сообщение',
      messageData: <String, dynamic>{
        'text': '',
        'imageUrl': '',
        'voiceUrl': cleanVoiceUrl,
        'durationSeconds': safeDuration,
        'type': 'voice',
      },
    );
  }

  static Future<void> _sendMessageData({
    required String currentUid,
    required String otherUid,
    required String lastMessage,
    required Map<String, dynamic> messageData,
  }) async {
    final cleanCurrentUid = currentUid.trim();
    final cleanOtherUid = otherUid.trim();

    if (cleanCurrentUid.isEmpty) {
      throw StateError('Не удалось определить отправителя.');
    }

    if (cleanOtherUid.isEmpty) {
      throw StateError('Не удалось определить получателя.');
    }

    if (cleanCurrentUid == cleanOtherUid) {
      throw StateError('Нельзя отправить сообщение самому себе.');
    }

    final chatReference = _chatRef(cleanCurrentUid, cleanOtherUid);
    final messageReference = chatReference.collection('messages').doc();
    final participants = <String>[cleanCurrentUid, cleanOtherUid]..sort();
    final chatSnapshot = await chatReference.get();
    final batch = _firestore.batch();

    final chatData = <String, dynamic>{
      'participants': participants,
      'lastMessage': lastMessage,
      'lastSenderUid': cleanCurrentUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!chatSnapshot.exists) {
      chatData['createdAt'] = FieldValue.serverTimestamp();
    }

    batch.set(chatReference, chatData, SetOptions(merge: true));

    batch.set(messageReference, <String, dynamic>{
      'senderUid': cleanCurrentUid,
      'receiverUid': cleanOtherUid,
      ...messageData,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'readAt': null,
    });

    await batch.commit();
  }

  static Future<void> markMessagesAsRead({
    required String currentUid,
    required String otherUid,
    required List<String> messageIds,
  }) async {
    final cleanCurrentUid = currentUid.trim();
    final cleanOtherUid = otherUid.trim();
    final cleanMessageIds = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanCurrentUid.isEmpty ||
        cleanOtherUid.isEmpty ||
        cleanMessageIds.isEmpty) {
      return;
    }

    final messagesReference =
        _chatRef(cleanCurrentUid, cleanOtherUid).collection('messages');

    for (var start = 0; start < cleanMessageIds.length; start += 450) {
      final end = (start + 450 < cleanMessageIds.length)
          ? start + 450
          : cleanMessageIds.length;

      final batch = _firestore.batch();

      for (final messageId in cleanMessageIds.sublist(start, end)) {
        batch.set(
          messagesReference.doc(messageId),
          <String, dynamic>{
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }

  static Stream<bool> watchTyping({
    required String currentUid,
    required String otherUid,
  }) {
    final cleanCurrentUid = currentUid.trim();
    final cleanOtherUid = otherUid.trim();

    if (cleanCurrentUid.isEmpty || cleanOtherUid.isEmpty) {
      return Stream<bool>.value(false);
    }

    return _chatRef(cleanCurrentUid, cleanOtherUid)
        .collection('typing')
        .doc(cleanOtherUid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();

          if (data == null || data['isTyping'] != true) {
            return false;
          }

          final updatedAt = data['updatedAt'];

          if (updatedAt is! Timestamp) {
            return false;
          }

          final age = DateTime.now().difference(updatedAt.toDate());
          return age < const Duration(seconds: 5);
        });
  }

  static Future<void> setTyping({
    required String currentUid,
    required String otherUid,
    required bool isTyping,
  }) async {
    final cleanCurrentUid = currentUid.trim();
    final cleanOtherUid = otherUid.trim();

    if (cleanCurrentUid.isEmpty || cleanOtherUid.isEmpty) {
      return;
    }

    if (cleanCurrentUid == cleanOtherUid) {
      return;
    }

    final typingReference = _chatRef(cleanCurrentUid, cleanOtherUid)
        .collection('typing')
        .doc(cleanCurrentUid);

    await typingReference.set(
      <String, dynamic>{
        'uid': cleanCurrentUid,
        'isTyping': isTyping,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
