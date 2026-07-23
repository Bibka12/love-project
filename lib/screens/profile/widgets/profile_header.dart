import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/user_profile_service.dart';

class ProfileHeader extends StatefulWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.onEdit,
  });

  final UserProfileData profile;
  final VoidCallback onEdit;

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  bool emailVisible = false;

  String get hiddenEmail {
    final email = widget.profile.email;

    if (emailVisible || email.isEmpty) return email;

    final parts = email.split('@');

    if (parts.length != 2) return '••••••••';

    final name = parts.first;
    final domain = parts.last;
    final visibleStart = name.isEmpty ? '' : name.substring(0, 1);

    return '$visibleStart••••@${domain.isEmpty ? '•••' : domain}';
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.profile.photoUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.pinkAccent.withValues(alpha: 0.16),
            Colors.purpleAccent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xffFF2E78),
                      Color(0xff9D2EFF),
                    ],
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: const Color(0xff211429),
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 52,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hiddenEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 35,
                            minHeight: 35,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              emailVisible = !emailVisible;
                            });
                          },
                          icon: Icon(
                            emailVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white54,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'N❤️B',
                        style: GoogleFonts.poppins(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          SizedBox(
            width: double.infinity,
            height: 51,
            child: OutlinedButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_rounded, size: 19),
              label: Text(
                'Редактировать профиль',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.pinkAccent.withValues(alpha: 0.55),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.035),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
