import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/user_profile_service.dart';
import '../friends/find_people_screen.dart';
import '../friends/friend_requests_screen.dart';
import '../friends/friends_screen.dart';
import '../auth_screen.dart';
import 'edit_profile_screen.dart';

enum _ProfileMenuAction { settings, about, logout }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool musicEnabled = true;
  bool soundEnabled = true;
  bool vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      musicEnabled = prefs.getBool('musicEnabled') ?? true;
      soundEnabled = prefs.getBool('soundEnabled') ?? true;
      vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _openEditProfile(User user) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => EditProfileScreen(user: user)),
    );
  }

  Future<void> _handleMenuAction(_ProfileMenuAction action) async {
    switch (action) {
      case _ProfileMenuAction.settings:
        await _showSettingsSheet();
        break;

      case _ProfileMenuAction.about:
        _showAboutDialog();
        break;

      case _ProfileMenuAction.logout:
        await _confirmLogout();
        break;
    }
  }

  void _openAvatar(String photoUrl, String name) {
    if (photoUrl.trim().isEmpty) {
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenAvatar(photoUrl: photoUrl, name: name),
      ),
    );
  }

  Future<void> _showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget settingTile({
              required IconData icon,
              required String title,
              required String subtitle,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: SwitchListTile(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Colors.pinkAccent,
                  secondary: Icon(icon, color: Colors.pinkAccent),
                  title: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: Color(0xff13101B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 22),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Настройки',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    settingTile(
                      icon: Icons.music_note_rounded,
                      title: 'Музыка',
                      subtitle: 'Фоновая музыка приложения',
                      value: musicEnabled,
                      onChanged: (value) {
                        setSheetState(() {
                          musicEnabled = value;
                        });

                        setState(() {
                          musicEnabled = value;
                        });

                        _saveSetting('musicEnabled', value);
                      },
                    ),
                    settingTile(
                      icon: Icons.volume_up_rounded,
                      title: 'Звуки',
                      subtitle: 'Звуки кнопок и ответов',
                      value: soundEnabled,
                      onChanged: (value) {
                        setSheetState(() {
                          soundEnabled = value;
                        });

                        setState(() {
                          soundEnabled = value;
                        });

                        _saveSetting('soundEnabled', value);
                      },
                    ),
                    settingTile(
                      icon: Icons.vibration_rounded,
                      title: 'Вибрация',
                      subtitle: 'Отклик при нажатиях',
                      value: vibrationEnabled,
                      onChanged: (value) {
                        setSheetState(() {
                          vibrationEnabled = value;
                        });

                        setState(() {
                          vibrationEnabled = value;
                        });

                        _saveSetting('vibrationEnabled', value);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'N❤️B',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Создано специально для Нурсауле ❤️',
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xff17111F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Выйти из аккаунта?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Ты сможешь снова войти в любое время.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Выйти',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Widget _buildLoggedOut() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
          );
        },
        child: const Text('Войти или создать аккаунт'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff05070D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff05070D), Color(0xff17101F), Color(0xff301934)],
          ),
        ),
        child: SafeArea(
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
                return _buildLoggedOut();
              }

              return StreamBuilder<UserProfileData>(
                stream: UserProfileService.watch(user),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !profileSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                      ),
                    );
                  }

                  if (profileSnapshot.hasError) {
                    return _ErrorProfile(
                      message: 'Не удалось загрузить профиль.',
                    );
                  }

                  final profile =
                      profileSnapshot.data ??
                      UserProfileData.fromUserAndMap(user, null);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 24),
                        _buildProfileHeader(user: user, profile: profile),
                        const SizedBox(height: 22),
                        _buildProfileInformation(profile),
                        const SizedBox(height: 18),
                        _buildPartnerCard(),
                        const SizedBox(height: 18),
                        _buildFriendsCard(profile.friendsCount),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Text(
          'Профиль',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        PopupMenuButton<_ProfileMenuAction>(
          color: const Color(0xff21172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          onSelected: _handleMenuAction,
          itemBuilder: (_) {
            return const [
              PopupMenuItem(
                value: _ProfileMenuAction.settings,
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Настройки', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ProfileMenuAction.about,
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('О приложении', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _ProfileMenuAction.logout,
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text('Выйти', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _buildProfileHeader({
    required User user,
    required UserProfileData profile,
  }) {
    final hasPhoto = profile.photoUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: hasPhoto
                ? () {
                    _openAvatar(profile.photoUrl, profile.name);
                  }
                : null,
            child: Hero(
              tag: 'profile-avatar-${profile.uid}',
              child: Container(
                width: 126,
                height: 126,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xffFF2E78),
                      Color(0xff9D2EFF),
                      Color(0xff6D4AFF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.28),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: const Color(0xff211429),
                  backgroundImage: hasPhoto
                      ? NetworkImage(profile.photoUrl)
                      : null,
                  child: hasPhoto
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (profile.status.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              profile.status,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.pinkAccent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: ElevatedButton.icon(
              onPressed: () {
                _openEditProfile(user);
              },
              icon: const Icon(Icons.edit_rounded, size: 19),
              label: Text(
                'Редактировать профиль',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInformation(UserProfileData profile) {
    final bio = profile.bio.trim();

    return _ProfileCard(
      icon: Icons.notes_rounded,
      title: 'О себе',
      child: Text(
        bio.isEmpty ? 'Пользователь пока ничего о себе не рассказал.' : bio,
        style: GoogleFonts.poppins(
          color: bio.isEmpty ? Colors.white38 : Colors.white70,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildPartnerCard() {
    return _ProfileCard(
      icon: Icons.favorite_rounded,
      title: 'Моя пара',
      iconColor: const Color(0xffFF5C9A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xffFF2E78).withValues(alpha: 0.16),
                  const Color(0xff9D2EFF).withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.pinkAccent.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.pinkAccent.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.pinkAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Пара пока не выбрана',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Позже здесь появится профиль твоей пары.',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                _showComingSoon('Система пар будет следующим этапом ❤️');
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                'Найти пару',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.pinkAccent,
                side: BorderSide(
                  color: Colors.pinkAccent.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsCard(int friendsCount) {
    final word = _friendsWord(friendsCount);

    return _ProfileCard(
      icon: Icons.people_alt_rounded,
      title: 'Друзья',
      iconColor: const Color(0xff9D72FF),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xff9D72FF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xffB99AFF),
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$friendsCount $word',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Люди, с которыми ты общаешься',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const FriendsScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _SmallActionButton(
                  icon: Icons.search_rounded,
                  text: 'Найти людей',
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const FindPeopleScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallActionButton(
                  icon: Icons.person_add_alt_1_rounded,
                  text: 'Заявки',
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const FriendRequestsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff21172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  String _friendsWord(int count) {
    final lastTwo = count % 100;
    final lastOne = count % 10;

    if (lastTwo >= 11 && lastTwo <= 14) {
      return 'друзей';
    }

    if (lastOne == 1) {
      return 'друг';
    }

    if (lastOne >= 2 && lastOne <= 4) {
      return 'друга';
    }

    return 'друзей';
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor = Colors.pinkAccent,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 47,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

class _FullScreenAvatar extends StatelessWidget {
  const _FullScreenAvatar({required this.photoUrl, required this.name});

  final String photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Hero(
            tag: 'profile-avatar-${FirebaseAuth.instance.currentUser?.uid}',
            child: Image.network(
              photoUrl,
              width: double.infinity,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return const Center(
                  child: CircularProgressIndicator(color: Colors.pinkAccent),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white54,
                  size: 80,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorProfile extends StatelessWidget {
  const _ErrorProfile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      ),
    );
  }
}
