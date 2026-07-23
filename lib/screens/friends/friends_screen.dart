import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/friends_service.dart';
import '../profile/user_profile_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xff070810),
      appBar: AppBar(
        backgroundColor: const Color(0xff070810),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Мои друзья',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Сначала войди в аккаунт.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<List<AppUserProfile>>(
              stream: FriendsService.watchFriends(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Ошибка:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.pinkAccent,
                    ),
                  );
                }

                final friends = snapshot.data!;

                if (friends.isEmpty) {
                  return const Center(
                    child: Text(
                      'Список друзей пока пуст.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: friends.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final hasPhoto = friend.photoUrl.isNotEmpty;

                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UserProfileScreen(
                              profile: friend,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 27,
                              backgroundImage: hasPhoto
                                  ? NetworkImage(friend.photoUrl)
                                  : null,
                              child: hasPhoto
                                  ? null
                                  : const Icon(Icons.person_rounded),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    friend.name,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (friend.status.isNotEmpty)
                                    Text(
                                      friend.status,
                                      style: GoogleFonts.poppins(
                                        color: Colors.pinkAccent,
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
                  },
                );
              },
            ),
    );
  }
}
