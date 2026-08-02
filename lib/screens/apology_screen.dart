import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ApologyScreen extends StatefulWidget {
  const ApologyScreen({super.key});

  @override
  State<ApologyScreen> createState() => _ApologyScreenState();
}

class _ApologyScreenState extends State<ApologyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _heartController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff070810),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff070810),
              Color(0xff241020),
              Color(0xff32123F),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: -80,
                right: -70,
                child: _GlowCircle(
                  size: 230,
                  color: Color(0x33FF2E78),
                ),
              ),
              const Positioned(
                bottom: -100,
                left: -90,
                child: _GlowCircle(
                  size: 280,
                  color: Color(0x339D2EFF),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Для тебя',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: Column(
                            children: [
                              AnimatedBuilder(
                                animation: _heartController,
                                builder: (context, child) {
                                  final value = _heartController.value;
                                  final scale =
                                      1 + math.sin(value * math.pi * 2) * 0.04;
                                  return Transform.scale(
                                    scale: scale,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xffFF2E78),
                                        Color(0xff9D2EFF),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xffFF2E78)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 34,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.mail_rounded,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Text(
                                'Мне важно это сказать',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Text(
                                  'Я понимаю, почему ты обиделась. Я действительно поступил неправильно, когда сказал, что нам нужно перестать общаться. Я накрутил себя и сделал поспешный вывод, не подумав, насколько сильно мои слова могут тебя задеть.\n\n'
                                  'Это не оправдание — я признаю свою ошибку. Прости меня, пожалуйста. Я не хочу давить на тебя и понимаю, если тебе нужно время. Просто хочу, чтобы ты знала: я искренне сожалею и постараюсь больше не принимать такие решения на эмоциях.',
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontSize: 14,
                                    height: 1.65,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xffFF3D81),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    'Я прочитала',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Без ожиданий и без давления.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
