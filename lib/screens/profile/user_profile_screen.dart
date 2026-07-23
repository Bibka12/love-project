import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/friends_service.dart';
import '../chat/chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.profile,
  });

  final AppUserProfile profile;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _refreshVersion = 0;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<FriendshipState> _loadState() async {
    final user = _currentUser;
    if (user == null) return FriendshipState.none;

    return FriendsService.getFriendshipState(
      currentUid: user.uid,
      otherUid: widget.profile.uid,
    );
  }

  Future<void> _sendRequest() async {
    final user = _currentUser;
    if (user == null) return;

    await FriendsService.sendFriendRequest(
      currentUser: user,
      receiver: widget.profile,
    );

    if (!mounted) return;
    setState(() => _refreshVersion++);
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(friend: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final hasPhoto = profile.photoUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xff090A10),
      appBar: AppBar(
        backgroundColor: const Color(0xff090A10),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          profile.name,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xff272A33),
                    backgroundImage:
                        hasPhoto ? NetworkImage(profile.photoUrl) : null,
                    child: hasPhoto
                        ? null
                        : const Icon(
                            Icons.person_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(profile.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        final count = data?['friendsCount'] is int
                            ? data!['friendsCount'] as int
                            : 0;

                        return Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _StatItem(value: '$count', label: 'друзья'),
                            const _StatItem(
                              value: '0',
                              label: 'публикации',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  profile.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (profile.status.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    profile.status,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ),
            if (profile.bio.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    profile.bio,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: FutureBuilder<FriendshipState>(
                key: ValueKey(_refreshVersion),
                future: _loadState(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const LinearProgressIndicator(
                      color: Colors.pinkAccent,
                    );
                  }

                  final state =
                      snapshot.data ?? FriendshipState.none;
                  final friends = state == FriendshipState.friends;

                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: state == FriendshipState.none
                                ? _sendRequest
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: friends
                                  ? const Color(0xff2A2D35)
                                  : Colors.pinkAccent,
                              disabledBackgroundColor:
                                  const Color(0xff2A2D35),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white,
                            ),
                            child: Text(
                              state == FriendshipState.friends
                                  ? 'Друзья ✓'
                                  : state ==
                                          FriendshipState.outgoingPending
                                      ? 'Заявка отправлена'
                                      : state ==
                                              FriendshipState.incomingPending
                                          ? 'В заявках'
                                          : 'Добавить в друзья',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: friends ? _openChat : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xff2A2D35),
                              disabledBackgroundColor:
                                  const Color(0xff2A2D35),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white38,
                            ),
                            child: const Text('Сообщение'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xff272932), height: 1),
            const SizedBox(height: 16),
            const Icon(Icons.grid_on_rounded, color: Colors.white),
            const SizedBox(height: 16),
            const Divider(color: Color(0xff272932), height: 1),
            SizedBox(
              height: 330,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Пока нет публикаций',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
