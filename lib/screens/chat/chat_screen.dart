import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';

import '../../services/chat_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/friends_service.dart';
import '../../services/presence_service.dart';
import '../../services/voice_recorder_service.dart';
import '../../widgets/voice_message_player.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.friend});

  final AppUserProfile friend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _sending = false;
  bool _uploadingImage = false;
  bool _uploadingVoice = false;
  bool _recordingVoice = false;
  bool _hasText = false;
  int _recordingSeconds = 0;

  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  Timer? _recordingTimer;

  final ImagePicker _imagePicker = ImagePicker();

  final Set<String> _messagesBeingMarkedAsRead = <String>{};

  Timer? _typingTimer;
  bool _typingSent = false;

  @override
  void initState() {
    super.initState();

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

    if (currentUser == null || text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    _controller.clear();
    _setTyping(false);

    try {
      await ChatService.sendMessage(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        text: text,
      );
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
      }

      _focusNode.requestFocus();
    }
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

      final imageUrl = await CloudinaryService.uploadChatImage(
        imageFile: File(pickedImage.path),
        userId: currentUser.uid,
      );

      await ChatService.sendImage(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        imageUrl: imageUrl,
      );
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

      final audioFile = await _voiceRecorder.stop();
      if (audioFile == null) {
        throw StateError('Запись не сохранилась. Попробуй ещё раз.');
      }

      final voiceUrl = await CloudinaryService.uploadChatVoice(
        audioFile: audioFile,
        userId: currentUser.uid,
      );

      await ChatService.sendVoice(
        currentUid: currentUser.uid,
        otherUid: widget.friend.uid,
        voiceUrl: voiceUrl,
        durationSeconds: durationSeconds,
      );

      if (await audioFile.exists()) {
        await audioFile.delete();
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
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
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
                      stream: ChatService.watchMessages(
                        currentUid: currentUser.uid,
                        otherUid: friend.uid,
                      ),
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

                            return _MessageBubble(
                              message: message,
                              mine: mine,
                              time: _formatTime(message.createdAt),
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
          child: Row(
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
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !_recordingVoice && !_uploadingVoice,
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
                    onSubmitted: (_) {
                      if (_hasText) {
                        _send();
                      }
                    },
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
                          : IconButton(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.time,
  });

  final ChatMessage message;
  final bool mine;
  final String time;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              mine ? 12 * (1 - value) : -12 * (1 - value),
              4 * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
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
          child: message.isImage
              ? _buildImageMessage(context)
              : message.isVoice
                  ? _buildVoiceMessage()
                  : _buildTextMessage(),
        ),
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
