import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/friends_service.dart';
import '../profile/user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    this.ownerUid,
    this.ownerName,
  });

  final String? ownerUid;
  final String? ownerName;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final ownerUid = widget.ownerUid ?? currentUser?.uid;
    final isOwnList = ownerUid == currentUser?.uid;
    final title = isOwnList
        ? 'Друзья'
        : 'Друзья ${widget.ownerName?.trim().isNotEmpty == true ? widget.ownerName!.trim() : 'пользователя'}';

    return Scaffold(
      backgroundColor: const Color(0xff070810),
      appBar: AppBar(
        backgroundColor: const Color(0xff070810),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ownerUid == null
          ? const Center(
              child: Text(
                'Сначала войди в аккаунт.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _query = value.trim().toLowerCase());
                    },
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Поиск',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white54,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                              ),
                            ),
                      filled: true,
                      fillColor: const Color(0xff1A1C25),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<AppUserProfile>>(
                    stream: FriendsService.watchFriends(ownerUid),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _Message(
                          icon: Icons.error_outline_rounded,
                          text: 'Не удалось загрузить друзей.',
                          color: Colors.redAccent,
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.pinkAccent,
                          ),
                        );
                      }

                      final friends = snapshot.data!
                          .where(
                            (friend) =>
                                _query.isEmpty ||
                                friend.name.toLowerCase().contains(_query),
                          )
                          .toList()
                        ..sort(
                          (first, second) => first.name.toLowerCase().compareTo(
                                second.name.toLowerCase(),
                              ),
                        );

                      if (friends.isEmpty) {
                        return _Message(
                          icon: _query.isEmpty
                              ? Icons.people_outline_rounded
                              : Icons.search_off_rounded,
                          text: _query.isEmpty
                              ? 'Список друзей пока пуст.'
                              : 'Ничего не найдено.',
                        );
                      }

                      return ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: friends.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 72,
                          color: Color(0xff242630),
                        ),
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return _FriendTile(
                            friend: friend,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      UserProfileScreen(profile: friend),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onTap});

  final AppUserProfile friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = friend.photoUrl.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xff272A33),
              backgroundImage: hasPhoto ? NetworkImage(friend.photoUrl) : null,
              child: hasPhoto
                  ? null
                  : const Icon(Icons.person_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (friend.status.trim().isNotEmpty)
                    Text(
                      friend.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.color = Colors.white54,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          Text(text, style: GoogleFonts.poppins(color: color)),
        ],
      ),
    );
  }
}
