import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/user_profile_service.dart';
import '../auth_screen.dart';
import '../friends/find_people_screen.dart';
import '../friends/friend_requests_screen.dart';
import '../friends/friends_screen.dart';
import 'edit_profile_screen.dart';

enum _ProfileAction { settings, about, logout }

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openEdit(BuildContext context, User user) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => EditProfileScreen(user: user)),
    );
  }

  void _openFriends(
    BuildContext context,
    UserProfileData profile,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendsScreen(
          ownerUid: profile.uid,
          ownerName: profile.name,
        ),
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    _ProfileAction action,
  ) async {
    switch (action) {
      case _ProfileAction.settings:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Настройки приложения находятся в разработке.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      case _ProfileAction.about:
        showAboutDialog(
          context: context,
          applicationName: 'N❤️B',
          applicationVersion: '1.0.0',
        );
        return;
      case _ProfileAction.logout:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xff171922),
            title: const Text(
              'Выйти из аккаунта?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Ты сможешь войти снова в любое время.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Выйти',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff080910),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.pinkAccent),
              );
            }

            final user = authSnapshot.data;
            if (user == null) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AuthScreen(),
                    ),
                  ),
                  child: const Text('Войти'),
                ),
              );
            }

            return StreamBuilder<UserProfileData>(
              stream: UserProfileService.watch(user),
              builder: (context, profileSnapshot) {
                if (!profileSnapshot.hasData &&
                    !profileSnapshot.hasError) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.pinkAccent,
                    ),
                  );
                }

                if (profileSnapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Не удалось загрузить профиль.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final profile = profileSnapshot.data ??
                    UserProfileData.fromUserAndMap(user, null);
                return _ProfileBody(
                  profile: profile,
                  onEdit: () => _openEdit(context, user),
                  onFriends: () => _openFriends(context, profile),
                  onMenu: (action) => _onMenu(context, action),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.onEdit,
    required this.onFriends,
    required this.onMenu,
  });

  final UserProfileData profile;
  final VoidCallback onEdit;
  final VoidCallback onFriends;
  final ValueChanged<_ProfileAction> onMenu;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = profile.photoUrl.trim().isNotEmpty;
    final bio = profile.bio.trim();
    final status = profile.status.trim();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<_ProfileAction>(
                onSelected: onMenu,
                color: const Color(0xff1B1D27),
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _ProfileAction.settings,
                    child: Text(
                      'Настройки',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ProfileAction.about,
                    child: Text(
                      'О приложении',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ProfileAction.logout,
                    child: Text(
                      'Выйти',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 94,
                height: 94,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: const Color(0xff252832),
                  backgroundImage:
                      hasPhoto ? NetworkImage(profile.photoUrl) : null,
                  child: hasPhoto
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: InkWell(
                  onTap: onFriends,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          '${profile.friendsCount}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
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
              Expanded(
                child: Column(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.pinkAccent,
                      size: 25,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.isEmpty ? 'нет статуса' : status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.name,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bio.isEmpty ? 'Добавь описание профиля' : bio,
            style: GoogleFonts.poppins(
              color: bio.isEmpty ? Colors.white38 : Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  text: 'Редактировать профиль',
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  text: 'Найти людей',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FindPeopleScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: _ActionButton(
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FriendRequestsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({this.text, this.icon, required this.onPressed});

  final String? text;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: const Color(0xff262832),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: icon != null
            ? Icon(icon, size: 20)
            : Text(
                text ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
