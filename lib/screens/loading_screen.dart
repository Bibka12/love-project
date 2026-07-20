import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'password_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  static const Color backgroundColor = Color(0xFF02040D);
  static const Color pinkColor = Color(0xFFFF4F93);
  static const Color purpleColor = Color(0xFFA855F7);

  late final AnimationController backgroundController;
  late final AnimationController logoController;
  late final AnimationController particlesController;

  late final Animation<double> logoOpacityAnimation;
  late final Animation<double> logoScaleAnimation;
  late final Animation<double> logoGlowAnimation;

  final List<Timer> timers = [];

  bool showLogo = false;
  bool showFirstText = false;
  bool showSecondText = false;
  bool checkingDevice = true;
  bool openingNextScreen = false;

  @override
  void initState() {
    super.initState();

    backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    logoOpacityAnimation = CurvedAnimation(
      parent: logoController,
      curve: const Interval(0.05, 0.55, curve: Curves.easeOut),
    );

    logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.72,
          end: 1.04,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.04,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(logoController);

    logoGlowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.72,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(logoController);

    startApplication();
  }

  void addTimer(Duration duration, VoidCallback callback) {
    final timer = Timer(duration, () {
      if (!mounted) return;
      callback();
    });

    timers.add(timer);
  }

  Future<void> startApplication() async {
    final preferences = await SharedPreferences.getInstance();

    final deviceUnlocked = preferences.getBool('device_unlocked') ?? false;

    if (!mounted) return;

    setState(() {
      checkingDevice = false;
    });

    addTimer(const Duration(milliseconds: 100), () {
      setState(() {
        showLogo = true;
      });

      particlesController.forward(from: 0);
      logoController.forward(from: 0);
    });

    addTimer(const Duration(milliseconds: 1100), () {
      setState(() {
        showFirstText = true;
      });

      HapticFeedback.selectionClick();
    });

    if (deviceUnlocked) {
      addTimer(const Duration(milliseconds: 2850), () {
        setState(() {
          showFirstText = false;
        });
      });

      addTimer(const Duration(milliseconds: 3300), () {
        setState(() {
          showSecondText = true;
        });

        HapticFeedback.mediumImpact();
      });

      addTimer(const Duration(milliseconds: 5000), openHomeScreen);
    } else {
      addTimer(const Duration(milliseconds: 2900), openPassword);
    }
  }

  Future<void> openPassword() async {
    if (openingNextScreen || !mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (_) => const PasswordScreen(),
    );

    if (!mounted) return;

    if (result == true) {
      final preferences = await SharedPreferences.getInstance();

      await preferences.setBool('device_unlocked', true);

      if (!mounted) return;

      await showWelcomeAnimation();
    }
  }

  Future<void> showWelcomeAnimation() async {
    HapticFeedback.mediumImpact();

    setState(() {
      showFirstText = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    setState(() {
      showSecondText = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1750));

    if (!mounted) return;

    await openHomeScreen();
  }

  Future<void> openHomeScreen() async {
    if (openingNextScreen || !mounted) return;

    openingNextScreen = true;

    HapticFeedback.lightImpact();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 950),
        reverseTransitionDuration: const Duration(milliseconds: 500),

        pageBuilder: (context, animation, secondaryAnimation) {
          return const HomeScreen();
        },

        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          final scaleAnimation = Tween<double>(
            begin: 0.985,
            end: 1,
          ).animate(fadeAnimation);

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final timer in timers) {
      timer.cancel();
    }

    backgroundController.dispose();
    logoController.dispose();
    particlesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedBuilder(
        animation: backgroundController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: backgroundColor,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final isCompactHeight = height < 700;

                final logoFontSize = (width * 0.185).clamp(62.0, 82.0);

                final titleSize = (width * 0.078).clamp(27.0, 36.0);

                final subtitleSize = (width * 0.040).clamp(14.0, 18.0);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: WelcomeStarsPainter(
                          animationValue: backgroundController.value,
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: CustomPaint(
                        painter: SpaceFogPainter(
                          animationValue: backgroundController.value,
                        ),
                      ),
                    ),

                    SafeArea(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: width < 390 ? 22 : 30,
                        ),
                        child: Column(
                          children: [
                            const Spacer(flex: 2),

                            SizedBox(
                              height: isCompactHeight ? 170 : 210,
                              child: Center(
                                child: buildAnimatedLogo(
                                  fontSize: logoFontSize,
                                ),
                              ),
                            ),

                            SizedBox(height: isCompactHeight ? 14 : 25),

                            Expanded(
                              flex: 3,
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 750),
                                  reverseDuration: const Duration(
                                    milliseconds: 450,
                                  ),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    final slideAnimation = Tween<Offset>(
                                      begin: const Offset(0, 0.10),
                                      end: Offset.zero,
                                    ).animate(animation);

                                    final scaleAnimation = Tween<double>(
                                      begin: 0.97,
                                      end: 1,
                                    ).animate(animation);

                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: slideAnimation,
                                        child: ScaleTransition(
                                          scale: scaleAnimation,
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  child: showSecondText
                                      ? buildSecondText(
                                          titleSize: titleSize,
                                          subtitleSize: subtitleSize,
                                        )
                                      : showFirstText
                                      ? buildFirstText(
                                          titleSize: titleSize,
                                          subtitleSize: subtitleSize,
                                        )
                                      : checkingDevice
                                      ? buildLoadingIndicator()
                                      : buildLoadingDots(),
                                ),
                              ),
                            ),

                            buildBottomSignature(compact: isCompactHeight),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget buildAnimatedLogo({required double fontSize}) {
    return AnimatedOpacity(
      opacity: showLogo ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          logoController,
          particlesController,
          backgroundController,
        ]),
        builder: (context, child) {
          final pulse = sin(backgroundController.value * pi * 2);

          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(250, 180),
                painter: LogoParticlesPainter(
                  progress: particlesController.value,
                ),
              ),

              Container(
                width: 220,
                height: 135,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  gradient: RadialGradient(
                    colors: [
                      pinkColor.withValues(
                        alpha: 0.12 + logoGlowAnimation.value * 0.08,
                      ),
                      purpleColor.withValues(
                        alpha: 0.06 + logoGlowAnimation.value * 0.05,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: pinkColor.withValues(
                        alpha: 0.12 + logoGlowAnimation.value * 0.10,
                      ),
                      blurRadius: 70,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),

              Opacity(
                opacity: logoOpacityAnimation.value,
                child: Transform.scale(
                  scale: logoScaleAnimation.value + pulse * 0.006,
                  child: child,
                ),
              ),
            ],
          );
        },
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFFD5E5), Color(0xFFFF78AD)],
              stops: [0, 0.48, 1],
            ).createShader(bounds);
          },
          child: Text(
            'N♥B',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              height: 1,
              shadows: [
                Shadow(
                  color: pinkColor.withValues(alpha: 0.55),
                  blurRadius: 22,
                ),
                Shadow(
                  color: purpleColor.withValues(alpha: 0.25),
                  blurRadius: 45,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildFirstText({
    required double titleSize,
    required double subtitleSize,
  }) {
    return Column(
      key: const ValueKey('first-text'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Я ждал именно тебя',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.18,
            letterSpacing: -0.7,
            shadows: [
              Shadow(
                color: Colors.white.withValues(alpha: 0.12),
                blurRadius: 18,
              ),
            ],
          ),
        ),

        const SizedBox(height: 13),

        Text(
          'Мой самый особенный человек ❤️',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: subtitleSize,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget buildSecondText({
    required double titleSize,
    required double subtitleSize,
  }) {
    return Column(
      key: const ValueKey('second-text'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Добро пожаловать',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.18,
            letterSpacing: -0.7,
          ),
        ),

        const SizedBox(height: 12),

        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [Color(0xFFFFB2CF), Color(0xFFFF5D9D)],
            ).createShader(bounds);
          },
          child: Text(
            'Нурсауле ❤️',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: subtitleSize + 7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildLoadingIndicator() {
    return SizedBox(
      key: const ValueKey('loading-indicator'),
      width: 30,
      height: 30,
      child: CircularProgressIndicator(
        color: pinkColor.withValues(alpha: 0.8),
        strokeWidth: 2.2,
      ),
    );
  }

  Widget buildLoadingDots() {
    return const Row(
      key: ValueKey('loading-dots'),
      mainAxisSize: MainAxisSize.min,
      children: [
        LoadingDot(delay: 0),
        SizedBox(width: 10),
        LoadingDot(delay: 140),
        SizedBox(width: 10),
        LoadingDot(delay: 280),
      ],
    );
  }

  Widget buildBottomSignature({required bool compact}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 900),
      opacity: showLogo ? 1 : 0,
      child: Padding(
        padding: EdgeInsets.only(bottom: compact ? 18 : 28),
        child: Column(
          children: [
            Text(
              'FOR NURSAULE',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.32),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 4.3,
              ),
            ),

            const SizedBox(height: 9),

            Container(
              width: 36,
              height: 1.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    pinkColor.withValues(alpha: 0.75),
                    Colors.transparent,
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

class LoadingDot extends StatefulWidget {
  final int delay;

  const LoadingDot({super.key, required this.delay});

  @override
  State<LoadingDot> createState() => _LoadingDotState();
}

class _LoadingDotState extends State<LoadingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> opacityAnimation;
  late final Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    opacityAnimation = Tween<double>(
      begin: 0.25,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    scaleAnimation = Tween<double>(
      begin: 0.65,
      end: 1.05,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacityAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4F93).withValues(alpha: 0.75),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeStarsPainter extends CustomPainter {
  final double animationValue;

  WelcomeStarsPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(37);

    final starCount = size.width < 600 ? 82 : 125;

    for (int i = 0; i < starCount; i++) {
      final x = random.nextDouble() * size.width;
      final originalY = random.nextDouble() * size.height;

      final movement = sin(animationValue * pi * 2 + i) * 2;

      final radius = random.nextDouble() * 1.05 + 0.18;

      final baseOpacity = random.nextDouble() * 0.38 + 0.07;

      final pulse = 0.55 + 0.45 * sin(animationValue * pi * 2 + i * 0.47).abs();

      final paint = Paint()
        ..color = Colors.white.withValues(
          alpha: (baseOpacity * pulse).clamp(0.0, 1.0),
        );

      canvas.drawCircle(Offset(x, originalY + movement), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WelcomeStarsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class SpaceFogPainter extends CustomPainter {
  final double animationValue;

  SpaceFogPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * sin(animationValue * pi * 2);

    final center = Offset(size.width * 0.5, size.height * 0.42);

    final radius = size.width * 0.72;

    final gradient = RadialGradient(
      colors: [
        const Color(0xFFFF4F93).withValues(alpha: 0.035 + pulse * 0.018),
        const Color(0xFFA855F7).withValues(alpha: 0.018 + pulse * 0.012),
        Colors.transparent,
      ],
      stops: const [0, 0.48, 1],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant SpaceFogPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class LogoParticlesPainter extends CustomPainter {
  final double progress;

  LogoParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(91);
    final center = Offset(size.width / 2, size.height / 2);

    const particleCount = 34;

    for (int i = 0; i < particleCount; i++) {
      final angle = random.nextDouble() * pi * 2;

      final startDistance = random.nextDouble() * 95 + 50;

      final endDistance = random.nextDouble() * 42 + 28;

      final easedProgress = Curves.easeOutCubic.transform(
        progress.clamp(0.0, 1.0),
      );

      final distance = lerpDouble(startDistance, endDistance, easedProgress)!;

      final position = Offset(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance * 0.62,
      );

      final fadeOut = progress < 0.7 ? progress / 0.7 : (1 - progress) / 0.3;

      final opacity = fadeOut.clamp(0.0, 1.0);

      final radius = random.nextDouble() * 1.7 + 0.6;

      final color = i.isEven ? const Color(0xFFFF79AD) : Colors.white;

      final paint = Paint()..color = color.withValues(alpha: opacity * 0.72);

      canvas.drawCircle(position, radius, paint);

      if (radius > 1.4) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: opacity * 0.12);

        canvas.drawCircle(position, radius * 4, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LogoParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
