import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/friends_service.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xff070810),
        appBar: AppBar(
          backgroundColor: const Color(0xff070810),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Заявки в друзья',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            indicatorColor: Colors.pinkAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
            tabs: const <Widget>[
              Tab(text: 'Входящие'),
              Tab(text: 'Отправленные'),
            ],
          ),
        ),
        body: user == null
            ? const Center(
                child: Text(
                  'Сначала войди в аккаунт.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xff070810),
                      Color(0xff17101F),
                      Color(0xff2A1732),
                    ],
                  ),
                ),
                child: TabBarView(
                  children: <Widget>[
                    _IncomingRequests(uid: user.uid),
                    _OutgoingRequests(uid: user.uid),
                  ],
                ),
              ),
      ),
    );
  }
}

class _IncomingRequests extends StatelessWidget {
  const _IncomingRequests({
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequestData>>(
      stream: FriendsService.watchIncomingRequests(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorMessage(error: snapshot.error);
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.pinkAccent,
            ),
          );
        }

        final requests = snapshot.data!;

        if (requests.isEmpty) {
          return const _EmptyRequests(
            icon: Icons.inbox_rounded,
            text: 'Новых заявок пока нет.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = requests[index];

            return _RequestCard(
              name: request.senderName,
              photoUrl: request.senderPhotoUrl,
              subtitle: 'Хочет добавить тебя в друзья',
              actions: <Widget>[
                Expanded(
                  child: _ActionButton(
                    text: 'Отклонить',
                    outlined: true,
                    onPressed: () async {
                      await _runAction(
                        context,
                        () => FriendsService.rejectRequest(
                          requestId: request.id,
                          currentUid: uid,
                        ),
                        'Заявка отклонена.',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ActionButton(
                    text: 'Принять',
                    onPressed: () async {
                      await _runAction(
                        context,
                        () => FriendsService.acceptRequest(
                          requestId: request.id,
                          currentUid: uid,
                        ),
                        'Теперь вы друзья ❤️',
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _OutgoingRequests extends StatelessWidget {
  const _OutgoingRequests({
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequestData>>(
      stream: FriendsService.watchOutgoingRequests(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorMessage(error: snapshot.error);
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.pinkAccent,
            ),
          );
        }

        final requests = snapshot.data!;

        if (requests.isEmpty) {
          return const _EmptyRequests(
            icon: Icons.outbox_rounded,
            text: 'Отправленных заявок нет.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = requests[index];

            return _RequestCard(
              name: request.receiverName,
              photoUrl: request.receiverPhotoUrl,
              subtitle: 'Ожидает ответа',
              actions: <Widget>[
                Expanded(
                  child: _ActionButton(
                    text: 'Отменить заявку',
                    outlined: true,
                    onPressed: () async {
                      await _runAction(
                        context,
                        () => FriendsService.cancelRequest(
                          requestId: request.id,
                          currentUid: uid,
                        ),
                        'Заявка отменена.',
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Future<void> _runAction(
  BuildContext context,
  Future<void> Function() action,
  String successMessage,
) async {
  try {
    await action();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
  } catch (error) {
    if (!context.mounted) return;

    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.name,
    required this.photoUrl,
    required this.subtitle,
    required this.actions,
  });

  final String name;
  final String photoUrl;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xff28152F),
                backgroundImage:
                    hasPhoto ? NetworkImage(photoUrl) : null,
                child: hasPhoto
                    ? null
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 31,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(children: actions),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.text,
    required this.onPressed,
    this.outlined = false,
  });

  final String text;
  final Future<void> Function() onPressed;
  final bool outlined;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _loading = false;

  Future<void> _press() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _loading
        ? const SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(
            widget.text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );

    if (widget.outlined) {
      return SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: _loading ? null : _press,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.15),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _loading ? null : _press,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pinkAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: Colors.white24,
            size: 68,
          ),
          const SizedBox(height: 15),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.error,
  });

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Text(
          'Ошибка загрузки заявок:\n$error',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }
}
