import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';

import '../../services/chat_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/friends_service.dart';
import '../../services/presence_service.dart';
import '../../services/voice_recorder_service.dart';
import '../../widgets/voice_message_player.dart';
import '../call/call_screen.dart';
import '../../services/call_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.friend});

  final AppUserProfile friend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final Stream<List<ChatMessage>> _messagesStream;

  bool _sending = false;
  bool _uploadingImage = false;
  bool _uploadingVoice = false;
  bool _recordingVoice = false;
  bool _hasText = false;
  bool _clearingChat = false;
  int _recordingSeconds = 0;
  ChatMessage? _replyingTo;

  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  Timer? _recordingTimer;

  final ImagePicker _imagePicker = ImagePicker();

  final Set<String> _messagesBeingMarkedAsRead = <String>{};

  Timer? _typingTimer;
  bool _typingSent = false;
  final Set<String> _hiddenOwnReactions = <String>{};
  final Map<String, int> _reactionAnimationVersions = <String, int>{};

  @override
  void initState() {
    super.initState();

    final currentUser = FirebaseAuth.instance.currentUser;
    _messagesStream = currentUser == null
        ? Stream<List<ChatMessage>>.value(<ChatMessage>[])
        : ChatService.watchMessages(
            currentUid: currentUser.uid,
            otherUid: widget.friend.uid,
          );
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _controller.removeListener(_handleTextChanged);
    _setTyping(false);
    _controller.dispose();
    _focusNode.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasTextNow = _controller.text.trim().isNotEmpty;

    if (hasTextNow != _hasText && mounted) {
      setState(() {
        _hasText = hasTextNow;
      });
    }

    _typingTimer?.cancel();

    if (!hasTextNow) {
      _setTyping(false);
      return;
    }

    _setTyping(true);

    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTyping(false);
    });
  }

  void _setTyping(bool isTyping) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid == widget.friend.uid) {
      return;
    }

    if (_typingSent == isTyping) {
      return;
    }

    _typingSent = isTyping;

    ChatService.setTyping(
      currentUid: currentUser.uid,
      otherUid: widget.friend.uid,
      isTyping: isTyping,
    ).catchError((_) {
      if (_typingSent == isTyping) {
        _typingSent = !isTyping;
      }
    });
  }

  Future<void> _send() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final text = _controller.text.trim();
    final replyTo = _buildReplyPayload(currentUser);
    final keepKeyboardOpen = kIsWeb || _focusNode.hasFocus;

    if (currentUser == null || text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    _controller.clear();
    if (keepKeyboardOpen) {
      _restoreComposerFocus();
    }
    _setTyping(false);

    try {
      await ChatService.sendMessage(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        text: text,
        replyTo: replyTo,
      );

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }
    } catch (error) {
      if (!mounted) return;

      _controller.text = text;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось отправить сообщение: $error',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
        if (keepKeyboardOpen) {
          _restoreComposerFocus();
        }
      }

    }
  }

  void _restoreComposerFocus() {
    if (!mounted) return;

    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      if (kIsWeb) {
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      }
    });
  }

  String _replyPreview(ChatMessage message) {
    if (message.isImage) {
      return '📷 Фотография';
    }

    if (message.isVoice) {
      return '🎤 Голосовое сообщение';
    }

    final cleanText = message.text.trim();
    if (cleanText.length <= 90) {
      return cleanText;
    }

    return '${cleanText.substring(0, 90)}…';
  }

  ChatReply? _buildReplyPayload(User? currentUser) {
    final message = _replyingTo;

    if (message == null || currentUser == null) {
      return null;
    }

    final senderName = message.senderUid == currentUser.uid
        ? (currentUser.displayName?.trim().isNotEmpty == true
              ? currentUser.displayName!.trim()
              : 'Вы')
        : widget.friend.name;

    return ChatReply(
      messageId: message.id,
      senderUid: message.senderUid,
      senderName: senderName,
      type: message.type,
      preview: _replyPreview(message),
    );
  }

  void _startReply(ChatMessage message) {
    if (_recordingVoice || _uploadingVoice) {
      return;
    }

    setState(() {
      _replyingTo = message;
    });

    _focusNode.requestFocus();
    Vibration.hasVibrator().then((canVibrate) {
      if (canVibrate) {
        Vibration.vibrate(duration: 25);
      }
    });
  }

  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final removing = message.reactionFor(currentUser.uid) == emoji;

    if (removing && mounted) {
      setState(() {
        _hiddenOwnReactions.add(message.id);
      });
    }

    try {
      await ChatService.toggleReaction(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        messageId: message.id,
        emoji: emoji,
      );
      if (!removing && mounted) {
        setState(() {
          _reactionAnimationVersions[message.id] =
              (_reactionAnimationVersions[message.id] ?? 0) + 1;
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (removing) {
        setState(() {
          _hiddenOwnReactions.remove(message.id);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось поставить реакцию: $error')),
      );
    }
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    const reactions = <String>['❤️', '😂', '😍', '😭', '🔥', '👍'];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xff20222B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: reactions.map((emoji) {
                    return InkResponse(
                      radius: 25,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _toggleReaction(message, emoji);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 25),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(
                    Icons.reply_rounded,
                    color: Color(0xffFF5A9E),
                  ),
                  title: const Text(
                    'Ответить',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _startReply(message);
                  },
                ),
                if (message.type == 'text')
                  ListTile(
                    leading: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Копировать',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: message.text),
                      );
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Удалить у себя',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteMessageForMe(message);
                  },
                ),
                if (message.senderUid ==
                    FirebaseAuth.instance.currentUser?.uid)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Удалить у всех',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _deleteMessageForEveryone(message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteMessageForMe(ChatMessage message) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await ChatService.deleteMessageForMe(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        messageId: message.id,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить сообщение: $error')),
      );
    }
  }

  Future<void> _deleteMessageForEveryone(ChatMessage message) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || message.senderUid != currentUser.uid) return;

    try {
      await ChatService.deleteMessageForEveryone(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        messageId: message.id,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить у всех: $error')),
      );
    }
  }

  Future<void> _clearChatForMe() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _clearingChat) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xff20222B),
          title: const Text(
            'Очистить чат?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Все сообщения исчезнут только у вас. '
            'У ${widget.friend.name} переписка останется.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Очистить',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _clearingChat = true;
    });

    try {
      await ChatService.clearChatForMe(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
      );

      if (!mounted) return;
      setState(() {
        _replyingTo = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чат очищен только у вас')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось очистить чат: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _clearingChat = false;
        });
      }
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _showImageSourceSheet() async {
    if (_uploadingImage || _sending) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xff171922),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Отправить фотографию',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _ImageSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Выбрать из галереи',
                  onTap: () {
                    Navigator.pop(sheetContext, ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                _ImageSourceTile(
                  icon: Icons.photo_camera_rounded,
                  title: 'Сделать фотографию',
                  onTap: () {
                    Navigator.pop(sheetContext, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    await _pickAndSendImage(source);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || _uploadingImage) {
      return;
    }

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (pickedImage == null || !mounted) {
        return;
      }

      setState(() {
        _uploadingImage = true;
      });

      _setTyping(false);

      final imageUrl = kIsWeb
          ? await CloudinaryService.uploadChatImageBytes(
              imageBytes: await pickedImage.readAsBytes(),
              fileName: pickedImage.name.trim().isEmpty
                  ? 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg'
                  : pickedImage.name,
              userId: currentUser.uid,
            )
          : await CloudinaryService.uploadChatImage(
              imageFile: File(pickedImage.path),
              userId: currentUser.uid,
            );

      await ChatService.sendImage(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        imageUrl: imageUrl,
        replyTo: _buildReplyPayload(currentUser),
      );

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось отправить фотографию: $error',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_hasText || _sending || _uploadingImage || _uploadingVoice || _recordingVoice) {
      return;
    }

    try {
      _focusNode.unfocus();
      _setTyping(false);
      await _voiceRecorder.start();

      if (!mounted) return;

      setState(() {
        _recordingVoice = true;
        _recordingSeconds = 0;
      });

      final canVibrate = await Vibration.hasVibrator();
      if (canVibrate) {
        Vibration.vibrate(duration: 35);
      }

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordingSeconds++);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось начать запись: $error',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _finishVoiceRecording() async {
    if (!_recordingVoice || _uploadingVoice) return;

    _recordingTimer?.cancel();
    final durationSeconds = _recordingSeconds < 1 ? 1 : _recordingSeconds;

    setState(() {
      _recordingVoice = false;
      _uploadingVoice = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw StateError('Сначала войди в аккаунт.');
      }

      final recordedVoice = await _voiceRecorder.stop();
      if (recordedVoice == null || recordedVoice.bytes.isEmpty) {
        throw StateError('Запись не сохранилась. Попробуй ещё раз.');
      }

      final voiceUrl = await CloudinaryService.uploadChatVoiceBytes(
        audioBytes: recordedVoice.bytes,
        fileName: recordedVoice.fileName,
        userId: currentUser.uid,
      );

      await ChatService.sendVoice(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        voiceUrl: voiceUrl,
        durationSeconds: durationSeconds,
        replyTo: _buildReplyPayload(currentUser),
      );

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось отправить голосовое: $error',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingVoice = false;
          _recordingSeconds = 0;
        });
      }
    }
  }

  String _formatRecordingDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  void _markUnreadMessagesAsRead({
    required String currentUid,
    required String otherUid,
    required List<ChatMessage> messages,
  }) {
    final unreadMessageIds = messages
        .where(
          (message) =>
              message.receiverUid == currentUid &&
              !message.isRead &&
              !_messagesBeingMarkedAsRead.contains(message.id),
        )
        .map((message) => message.id)
        .toList();

    if (unreadMessageIds.isEmpty) {
      return;
    }

    _messagesBeingMarkedAsRead.addAll(unreadMessageIds);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ChatService.markMessagesAsRead(
          currentUid: currentUid,
          otherUid: otherUid,
          messageIds: unreadMessageIds,
        );
      } catch (error) {
        _messagesBeingMarkedAsRead.removeAll(unreadMessageIds);

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Не удалось обновить статус прочтения: $error',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }

    final localTime = dateTime.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final friend = widget.friend;
    final hasPhoto = friend.photoUrl.trim().isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xff070810),
      appBar: AppBar(
        backgroundColor: const Color(0xff0D0E17),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Hero(
              tag: 'avatar_${friend.uid}',
              child: CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xff282B34),
                backgroundImage: hasPhoto
                    ? NetworkImage(friend.photoUrl)
                    : null,
                child: hasPhoto
                    ? null
                    : const Icon(Icons.person_rounded, color: Colors.white),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  StreamBuilder<bool>(
                    stream: currentUser == null
                        ? Stream<bool>.value(false)
                        : ChatService.watchTyping(
                            currentUid: currentUser.uid,
                            otherUid: friend.uid,
                          ),
                    builder: (context, typingSnapshot) {
                      final isTyping = typingSnapshot.data == true;

                      if (isTyping) {
                        return Text(
                          'печатает...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xff71D7FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }

                      return StreamBuilder<UserPresence>(
                        stream: PresenceService.instance.watchPresence(
                          friend.uid,
                        ),
                        builder: (context, presenceSnapshot) {
                          final presence = presenceSnapshot.data;

                          if (presence == null) {
                            return Text(
                              'был(а) недавно',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            );
                          }

                          final online = PresenceService.instance
                              .isActuallyOnline(presence);

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: online
                                      ? const Color(0xff4CE27A)
                                      : Colors.white38,
                                  shape: BoxShape.circle,
                                  boxShadow: online
                                      ? <BoxShadow>[
                                          BoxShadow(
                                            color: const Color(0xff4CE27A)
                                                .withValues(alpha: 0.5),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  PresenceService.instance.presenceText(
                                    presence,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: online
                                        ? const Color(0xff4CE27A)
                                        : Colors.white54,
                                    fontSize: 11,
                                    fontWeight: online
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Аудиозвонок',
            onPressed: currentUser == null
                ? null
                : () {
                    CallOverlayController.instance.startOutgoing(
                      otherUid: friend.uid,
                      otherName: friend.name,
                      otherPhotoUrl: friend.photoUrl,
                      type: AppCallType.audio,
                    );
                  },
            icon: const Icon(
              Icons.call_outlined,
              color: Colors.white70,
              size: 22,
            ),
          ),
          IconButton(
            tooltip: 'Видеозвонок',
            onPressed: currentUser == null
                ? null
                : () {
                    CallOverlayController.instance.startOutgoing(
                      otherUid: friend.uid,
                      otherName: friend.name,
                      otherPhotoUrl: friend.photoUrl,
                      type: AppCallType.video,
                    );
                  },
            icon: const Icon(
              Icons.videocam_outlined,
              color: Colors.white70,
              size: 23,
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_clearingChat,
            color: const Color(0xff20222B),
            surfaceTintColor: Colors.transparent,
            tooltip: 'Меню чата',
            icon: _clearingChat
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white70,
                  ),
            onSelected: (value) {
              if (value == 'clear') {
                _clearChatForMe();
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Очистить чат',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: currentUser == null
          ? _buildNotLoggedIn()
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xff0D0E17),
                    Color(0xff090A12),
                    Color(0xff070810),
                  ],
                ),
              ),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: StreamBuilder<List<ChatMessage>>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _buildError(snapshot.error);
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.pinkAccent,
                            ),
                          );
                        }

                        final messages = snapshot.data!;

                        _markUnreadMessagesAsRead(
                          currentUid: currentUser.uid,
                          otherUid: friend.uid,
                          messages: messages,
                        );

                        if (messages.isEmpty) {
                          return _buildEmptyChat(friend);
                        }

                        return ListView.builder(
                          reverse: true,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final mine = message.isMine(currentUser.uid);
                            if (message
                                .reactionFor(currentUser.uid)
                                .isEmpty) {
                              _hiddenOwnReactions.remove(message.id);
                            }

                            return _SwipeToReply(
                              key: ValueKey<String>('reply_${message.id}'),
                              onReply: () => _startReply(message),
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: () {
                                  _toggleReaction(message, '❤️');
                                },
                                onLongPress: () =>
                                    _showMessageActions(message),
                                child: _MessageBubble(
                                  message: message,
                                  mine: mine,
                                  time: _formatTime(message.createdAt),
                                  currentUid: currentUser.uid,
                                  reactionAnimationVersion:
                                      _reactionAnimationVersions[message.id] ??
                                      0,
                                  hideCurrentUserReaction:
                                      _hiddenOwnReactions.contains(message.id),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _buildMessageInput(),
                ],
              ),
            ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Text(
        'Сначала войди в аккаунт.',
        style: GoogleFonts.poppins(color: Colors.white70),
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 46,
              ),
              const SizedBox(height: 12),
              Text(
                'Не удалось загрузить сообщения',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChat(AppUserProfile friend) {
    final hasPhoto = friend.photoUrl.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xffFF3B82), Color(0xff9C5CFF)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.pinkAccent.withValues(alpha: 0.22),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xff252731),
                backgroundImage: hasPhoto
                    ? NetworkImage(friend.photoUrl)
                    : null,
                child: hasPhoto
                    ? null
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 45,
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              friend.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Сообщений пока нет.\nНапиши первое сообщение 👋',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff0D0E17),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_replyingTo != null) ...<Widget>[
                _ReplyComposer(
                  senderName:
                      _replyingTo!.senderUid ==
                          FirebaseAuth.instance.currentUser?.uid
                      ? 'Вы'
                      : widget.friend.name,
                  preview: _replyPreview(_replyingTo!),
                  onCancel: _cancelReply,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff20222B),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: TextField(
                    key: const ValueKey<String>('chat_message_input'),
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !_recordingVoice && !_uploadingVoice,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: _recordingVoice
                          ? 'Запись ${_formatRecordingDuration(_recordingSeconds)} — отпусти для отправки'
                          : 'Сообщение...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      prefixIcon: IconButton(
                        onPressed: _uploadingImage || _sending || _recordingVoice || _uploadingVoice
                            ? null
                            : _showImageSourceSheet,
                        icon: _uploadingImage
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xffFF5A9E),
                                ),
                              )
                            : const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: Colors.white54,
                              ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                scale: _hasText || _recordingVoice ? 1 : 0.92,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: GestureDetector(
                  onLongPressStart: _hasText ? null : (_) => _startVoiceRecording(),
                  onLongPressEnd: _hasText ? null : (_) => _finishVoiceRecording(),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _hasText || _recordingVoice
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[
                                  Color(0xffFF3B82),
                                  Color(0xffC642FF),
                                ],
                              )
                            : null,
                        color: _hasText || _recordingVoice
                            ? null
                            : const Color(0xff242630),
                        boxShadow: _hasText || _recordingVoice
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: Colors.pinkAccent.withValues(alpha: 0.28),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: _uploadingVoice || _sending
                          ? const Center(
                              child: SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Focus(
                              canRequestFocus: false,
                              descendantsAreFocusable: false,
                              child: IconButton(
                                onPressed: _hasText ? _send : null,
                                icon: Icon(
                                  _hasText
                                      ? Icons.send_rounded
                                      : (_recordingVoice
                                          ? Icons.mic_rounded
                                          : Icons.mic_none_rounded),
                                  color: _hasText || _recordingVoice
                                      ? Colors.white
                                      : Colors.white54,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
  });

  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const double _maximumOffset = 52;
  static const double _triggerOffset = 38;

  double _offset = 0;
  bool _dragging = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    final horizontalDelta = details.delta.dx;

    if (horizontalDelta < 0 && _offset <= 0) {
      return;
    }

    setState(() {
      _dragging = true;
      _offset = (_offset + horizontalDelta * 0.55)
          .clamp(0.0, _maximumOffset)
          .toDouble();
    });
  }

  void _finishDrag() {
    final shouldReply = _offset >= _triggerOffset;

    setState(() {
      _dragging = false;
      _offset = 0;
    });

    if (shouldReply) {
      widget.onReply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_offset / _triggerOffset).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: (_) => _finishDrag(),
      onHorizontalDragCancel: _finishDrag,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.72 + (0.28 * progress),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xffFF3B82,
                    ).withValues(alpha: 0.17),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    color: Color(0xffFF5A9E),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.senderName,
    required this.preview,
    required this.onCancel,
  });

  final String senderName;
  final String preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth >= 720 ? 420.0 : screenWidth * 0.82;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xff20222B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: <Widget>[
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xffFF4F93),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 11),
          const Icon(
            Icons.reply_rounded,
            color: Color(0xffFF5A9E),
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Ответ для $senderName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xffFF6AA7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
              size: 21,
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionLandingAnimation extends StatefulWidget {
  const _ReactionLandingAnimation({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<_ReactionLandingAnimation> createState() =>
      _ReactionLandingAnimationState();
}

class _ReactionLandingAnimationState extends State<_ReactionLandingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _verticalOffset;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.82, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 28,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.18, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.96, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.06, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 34,
      ),
    ]).animate(_controller);

    _verticalOffset = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: -19)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 42,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -19, end: -14)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -14, end: 0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 38,
      ),
    ]).animate(_controller);

    _rotation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: -0.13),
        weight: 28,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -0.13, end: 0.12),
        weight: 24,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.12, end: -0.06),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -0.06, end: 0),
        weight: 28,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _verticalOffset.value),
          child: Transform.rotate(
            angle: _rotation.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.time,
    required this.currentUid,
    required this.reactionAnimationVersion,
    required this.hideCurrentUserReaction,
  });

  final ChatMessage message;
  final bool mine;
  final String time;
  final String currentUid;
  final int reactionAnimationVersion;
  final bool hideCurrentUserReaction;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = screenWidth >= 720 ? 560.0 : screenWidth * 0.78;
    final visibleReactions = Map<String, String>.from(message.reactions);
    if (hideCurrentUserReaction) {
      visibleReactions.remove(currentUid);
    }

    return RepaintBoundary(
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: visibleReactions.isEmpty ? 0 : 13,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
          constraints: BoxConstraints(
            maxWidth: bubbleMaxWidth,
          ),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: message.isImage
              ? const EdgeInsets.all(4)
              : message.isVoice
                  ? const EdgeInsets.fromLTRB(12, 10, 10, 7)
                  : const EdgeInsets.fromLTRB(14, 10, 10, 7),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xffFF3B82), Color(0xffC642FF)],
                  )
                : null,
            color: mine ? null : const Color(0xff23252E),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 5),
              bottomRight: Radius.circular(mine ? 5 : 20),
            ),
            border: mine
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: mine
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (message.hasReply) ...<Widget>[
                _buildReplyQuote(),
                const SizedBox(height: 7),
              ],
              if (message.isImage)
                _buildImageMessage(context)
              else if (message.isVoice)
                _buildVoiceMessage()
              else
                _buildTextMessage(),
            ],
          ),
              ),
              if (visibleReactions.isNotEmpty)
                Positioned(
                  bottom: -12,
                  left: mine ? null : 9,
                  right: mine ? 9 : null,
                  child: reactionAnimationVersion > 0
                      ? _ReactionLandingAnimation(
                          key: ValueKey<String>(
                            'reaction_${message.id}_'
                            '$reactionAnimationVersion',
                          ),
                          child: _buildReactions(visibleReactions),
                        )
                      : _buildReactions(visibleReactions),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactions(Map<String, String> visibleReactions) {
    final counts = <String, int>{};
    for (final emoji in visibleReactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final myReaction = visibleReactions[currentUid] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xff11121A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: counts.entries.map((entry) {
        final selected = entry.key == myReaction;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: const Duration(milliseconds: 180),
            child: Text(
              entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
              style: const TextStyle(fontSize: 16, height: 1),
            ),
          ),
        );
      }).toList(),
      ),
    );
  }

  Widget _buildReplyQuote() {
    final storedName = message.replySenderName.trim();
    final senderName = message.replySenderUid == currentUid
        ? 'Вы'
        : (storedName.isEmpty ? 'Сообщение' : storedName);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: mine ? 0.14 : 0.20),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Colors.white, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyPreview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextMessage() {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      runSpacing: 2,
      children: <Widget>[
        Text(
          message.text,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        _MessageMeta(mine: mine, time: time, isRead: message.isRead),
      ],
    );
  }

  Widget _buildVoiceMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        VoiceMessagePlayer(
          url: message.voiceUrl,
          durationSeconds: message.durationSeconds,
          mine: mine,
        ),
        const SizedBox(height: 3),
        _MessageMeta(mine: mine, time: time, isRead: message.isRead),
      ],
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    final heroTag = 'chat_image_${message.id}';

    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                opaque: false,
                barrierColor: Colors.black,
                pageBuilder: (_, animation, secondaryAnimation) {
                  return FadeTransition(
                    opacity: animation,
                    child: _FullScreenImagePage(
                      imageUrl: message.imageUrl,
                      heroTag: heroTag,
                    ),
                  );
                },
              ),
            );
          },
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(17),
                topRight: const Radius.circular(17),
                bottomLeft: Radius.circular(mine ? 17 : 3),
                bottomRight: Radius.circular(mine ? 3 : 17),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 190,
                  minHeight: 150,
                  maxWidth: 280,
                  maxHeight: 360,
                ),
                child: Image.network(
                  message.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }

                    return Container(
                      width: 240,
                      height: 220,
                      color: const Color(0xff1A1C25),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 240,
                      height: 190,
                      color: const Color(0xff1A1C25),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 42,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Фото не загрузилось',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 7,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _MessageMeta(
              mine: mine,
              time: time,
              isRead: message.isRead,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.mine,
    required this.time,
    required this.isRead,
  });

  final bool mine;
  final String time;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            time,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 9,
            ),
          ),
          if (mine) ...<Widget>[
            const SizedBox(width: 3),
            Icon(
              Icons.done_all_rounded,
              color: isRead
                  ? const Color(0xff71D7FF)
                  : Colors.white.withValues(alpha: 0.76),
              size: 14,
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  const _ImageSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff23252E),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xffFF3B82), Color(0xffC642FF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenImagePage extends StatelessWidget {
  const _FullScreenImagePage({
    required this.imageUrl,
    required this.heroTag,
  });

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }

                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 64,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
