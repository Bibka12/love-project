import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.075),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.star_rounded,
              value: '7',
              label: 'Звёзд',
            ),
          ),
          _Divider(),
          Expanded(
            child: _StatItem(
              icon: Icons.sports_esports_rounded,
              value: '2',
              label: 'Игры',
            ),
          ),
          _Divider(),
          Expanded(
            child: _StatItem(
              icon: Icons.music_note_rounded,
              value: '3',
              label: 'Песни',
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 43,
      color: Colors.white12,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.pinkAccent,
          size: 23,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
