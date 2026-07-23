import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/chat_service.dart';
import '../../services/friends_service.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xff05070D),
            Color(0xff11101A),
            Color(0xff1B1428),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: currentUser == null
            ? const _NotAuthorizedView()
            : StreamBuilder<List<ChatPreview>>(
                stream: ChatService.watchChats(currentUid: currentUser.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorView(error: snapshot.error);
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xffFF3B82),
                      ),
                    );
                  }

                  final chats = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Чаты',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: Color(0xffFF5A98),
                                size: 21,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: chats.isEmpty
                            ? const _EmptyChatsView()
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  3,
                                  12,
                                  110,
                                ),
                                itemCount: chats.length,
                                itemBuilder: (context, index) {
                                  final chat = chats[index];
                                  final friendUid = chat.otherUid(
                                    currentUser.uid,
                                  );

                                  return _ChatPreviewTile(
                                    chat: chat,
                                    friendUid: friendUid,
                                    currentUid: currentUser.uid,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _ChatPreviewTile extends StatelessWidget {
  const _ChatPreviewTile({
    required this.chat,
    required this.friendUid,
    required this.currentUid,
  });

  final ChatPreview chat;
  final String friendUid;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    if (friendUid.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(friendUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return const _LoadingChatTile();
        }

        final document = snapshot.data!;

        if (!document.exists) {
          return const SizedBox.shrink();
        }

        final friend = AppUserProfile.fromDocument(document);

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(23),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
                );
              },
              child: Ink(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.075),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    _FriendAvatar(name: friend.name, photoUrl: friend.photoUrl),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  friend.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatChatTime(chat.updatedAt),
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: <Widget>[
                              if (chat.lastSenderUid == currentUid)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    'Вы:',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xffFF5A98),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  chat.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white24,
                      size: 23,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatChatTime(DateTime? date) {
    if (date == null) {
      return '';
    }

    final localDate = date.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final messageDay = DateTime(localDate.year, localDate.month, localDate.day);

    final difference = today.difference(messageDay);

    if (difference.inDays == 0) {
      final hour = localDate.hour.toString().padLeft(2, '0');

      final minute = localDate.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    }

    if (difference.inDays == 1) {
      return 'Вчера';
    }

    if (difference.inDays < 7) {
      const weekdays = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

      return weekdays[localDate.weekday - 1];
    }

    final day = localDate.day.toString().padLeft(2, '0');

    final month = localDate.month.toString().padLeft(2, '0');

    return '$day.$month';
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xffFF3B82), Color(0xff9B3DFF)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xff15151D),
        ),
        child: CircleAvatar(
          backgroundColor: const Color(0xff2A2B35),
          backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
          child: hasPhoto
              ? null
              : Text(
                  _firstLetter(name),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  static String _firstLetter(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      return '?';
    }

    return cleanName.characters.first.toUpperCase();
  }
}

class _LoadingChatTile extends StatelessWidget {
  const _LoadingChatTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
    );
  }
}

class _EmptyChatsView extends StatelessWidget {
  const _EmptyChatsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(35, 0, 35, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 102,
              height: 102,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.045),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xff9B3DFF).withValues(alpha: 0.18),
                    blurRadius: 35,
                  ),
                ],
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: Colors.white38,
                size: 49,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Пока нет переписок',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Открой профиль друга и отправь первое сообщение. После этого чат появится здесь.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotAuthorizedView extends StatelessWidget {
  const _NotAuthorizedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Сначала войди в аккаунт.',
        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 15),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 13),
            Text(
              'Не удалось загрузить чаты',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
