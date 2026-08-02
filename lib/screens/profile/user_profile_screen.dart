import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/friends_service.dart';
import '../chat/chat_screen.dart';
import '../friends/friends_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.profile});

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
    try {
      await FriendsService.sendFriendRequest(
        currentUser: user,
        receiver: widget.profile,
      );
      if (mounted) setState(() => _refreshVersion++);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff080910),
      appBar: AppBar(
        backgroundColor: const Color(0xff080910),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.profile.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profile.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = data['name']?.toString().trim().isNotEmpty == true
              ? data['name'].toString().trim()
              : widget.profile.name;
          final photoUrl = data['photoUrl']?.toString().trim().isNotEmpty == true
              ? data['photoUrl'].toString().trim()
              : widget.profile.photoUrl;
          final bio = data['bio']?.toString().trim().isNotEmpty == true
              ? data['bio'].toString().trim()
              : widget.profile.bio;
          final status = data['status']?.toString().trim().isNotEmpty == true
              ? data['status'].toString().trim()
              : widget.profile.status;
          final rawCount = data['friendsCount'];
          final friendsCount = rawCount is num ? rawCount.toInt() : 0;
          final liveProfile = AppUserProfile(
            uid: widget.profile.uid,
            name: name,
            photoUrl: photoUrl,
            status: status,
            bio: bio,
          );

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xff272A33),
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 50,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FriendsScreen(
                              ownerUid: widget.profile.uid,
                              ownerName: name,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Column(
                            children: [
                              Text(
                                '$friendsCount',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'друзья',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    status,
                    style: GoogleFonts.poppins(
                      color: Colors.pinkAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    bio,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FutureBuilder<FriendshipState>(
                  key: ValueKey(_refreshVersion),
                  future: _loadState(),
                  builder: (context, stateSnapshot) {
                    if (!stateSnapshot.hasData) {
                      return const LinearProgressIndicator(
                        color: Colors.pinkAccent,
                      );
                    }
                    final state = stateSnapshot.data!;
                    final areFriends = state == FriendshipState.friends;
                    return Row(
                      children: [
                        Expanded(
                          child: _ProfileButton(
                            text: areFriends
                                ? 'Друзья ✓'
                                : state == FriendshipState.outgoingPending
                                    ? 'Заявка отправлена'
                                    : state == FriendshipState.incomingPending
                                        ? 'В заявках'
                                        : 'Добавить в друзья',
                            primary: state == FriendshipState.none,
                            onPressed: state == FriendshipState.none
                                ? _sendRequest
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ProfileButton(
                            text: 'Сообщение',
                            onPressed: areFriends
                                ? () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            ChatScreen(friend: liveProfile),
                                      ),
                                    )
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.text,
    required this.onPressed,
    this.primary = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              primary ? Colors.pinkAccent : const Color(0xff292B35),
          disabledBackgroundColor: const Color(0xff292B35),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
