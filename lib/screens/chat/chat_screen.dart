import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/chat_service.dart';
import '../../services/friends_service.dart';
import '../../services/presence_service.dart';

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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      final hasTextNow = _controller.text.trim().isNotEmpty;

      if (hasTextNow != _hasText && mounted) {
        setState(() {
          _hasText = hasTextNow;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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
                  StreamBuilder<UserPresence>(
                    stream: PresenceService.instance.watchPresence(friend.uid),
                    builder: (context, snapshot) {
                      final presence = snapshot.data;

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

                      final isOnline = PresenceService.instance
                          .isActuallyOnline(presence);

                      final statusText = PresenceService.instance
                          .presenceText(presence);

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline
                                  ? const Color(0xff46E38A)
                                  : Colors.white38,
                              boxShadow: isOnline
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: const Color(0xff46E38A)
                                            .withValues(alpha: 0.45),
                                        blurRadius: 7,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: isOnline
                                    ? const Color(0xff46E38A)
                                    : Colors.white54,
                                fontSize: 11,
                                fontWeight: isOnline
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
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
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      prefixIcon: IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          color: Colors.white38,
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
                scale: _hasText ? 1 : 0.92,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _hasText
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xffFF3B82),
                                Color(0xffC642FF),
                              ],
                            )
                          : null,
                      color: _hasText ? null : const Color(0xff242630),
                      boxShadow: _hasText
                          ? <BoxShadow>[
                              BoxShadow(
                                color: Colors.pinkAccent.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: IconButton(
                      onPressed: _sending || !_hasText ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: _hasText ? Colors.white : Colors.white24,
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
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 7),
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
          child: Wrap(
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
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 9,
                      ),
                    ),
                    if (mine) ...<Widget>[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.done_all_rounded,
                        color: Colors.white.withValues(alpha: 0.75),
                        size: 14,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
