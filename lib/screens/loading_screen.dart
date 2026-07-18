import 'dart:async';
import 'dart:math';

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
  late final AnimationController backgroundController;
  late final AnimationController logoController;

  late final Animation<double> logoScaleAnimation;
  late final Animation<double> logoRotationAnimation;

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
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.94,
          end: 1.045,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.045,
          end: 0.94,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(logoController);

    logoRotationAnimation = Tween<double>(
      begin: -0.012,
      end: 0.012,
    ).animate(CurvedAnimation(parent: logoController, curve: Curves.easeInOut));

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

    addTimer(const Duration(milliseconds: 120), () {
      setState(() {
        showLogo = true;
      });

      logoController.repeat(reverse: true);
    });

    addTimer(const Duration(milliseconds: 850), () {
      setState(() {
        showFirstText = true;
      });
    });

    if (deviceUnlocked) {
      addTimer(const Duration(milliseconds: 2300), () {
        setState(() {
          showFirstText = false;
        });
      });

      addTimer(const Duration(milliseconds: 2750), () {
        setState(() {
          showSecondText = true;
        });

        HapticFeedback.mediumImpact();
      });

      addTimer(const Duration(milliseconds: 4400), openHomeScreen);
    } else {
      addTimer(const Duration(milliseconds: 2300), openPassword);
    }
  }

  Future<void> openPassword() async {
    if (openingNextScreen || !mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
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

    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;

    setState(() {
      showSecondText = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1650));

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
        transitionDuration: const Duration(milliseconds: 850),

        pageBuilder: (context, animation, secondaryAnimation) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,

            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.985,
                end: 1,
              ).animate(curvedAnimation),

              child: const HomeScreen(),
            ),
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

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff05070D),

      body: AnimatedBuilder(
        animation: backgroundController,

        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,

            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,

                colors: [
                  Color(0xff02040D),
                  Color(0xff10091B),
                  Color(0xff251127),
                  Color(0xff3A1735),
                ],

                stops: [0, 0.34, 0.7, 1],
              ),
            ),

            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final isCompactHeight = height < 700;

                final logoSize = (width * (isCompactHeight ? 0.50 : 0.56))
                    .clamp(185.0, 255.0);

                final titleSize = (width * 0.082).clamp(28.0, 38.0);

                final subtitleSize = (width * 0.041).clamp(14.0, 18.0);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: WelcomeStarsPainter(
                          animationValue: backgroundController.value,
                        ),
                      ),
                    ),

                    Positioned(
                      top: -130,
                      right: -110,

                      child: buildGlow(
                        size: 340,
                        color: const Color(0xff9D2EFF),
                        opacity: 0.09 + backgroundController.value * 0.045,
                      ),
                    ),

                    Positioned(
                      bottom: -140,
                      left: -120,

                      child: buildGlow(
                        size: 370,
                        color: const Color(0xffFF2E78),
                        opacity: 0.08 + backgroundController.value * 0.04,
                      ),
                    ),

                    SafeArea(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: width < 390 ? 20 : 28,
                        ),

                        child: Column(
                          children: [
                            SizedBox(height: isCompactHeight ? 28 : 50),

                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 700),
                              opacity: showLogo ? 1 : 0,

                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 850),
                                curve: Curves.easeOutBack,
                                scale: showLogo ? 1 : 0.55,

                                child: AnimatedBuilder(
                                  animation: logoController,

                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: logoRotationAnimation.value,

                                      child: Transform.scale(
                                        scale: logoScaleAnimation.value,

                                        child: child,
                                      ),
                                    );
                                  },

                                  child: buildMainLogo(size: logoSize),
                                ),
                              ),
                            ),

                            SizedBox(height: isCompactHeight ? 25 : 38),

                            Expanded(
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 600),

                                  switchInCurve: Curves.easeOutCubic,

                                  switchOutCurve: Curves.easeInCubic,

                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,

                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.12),
                                          end: Offset.zero,
                                        ).animate(animation),

                                        child: child,
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

                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 700),
                              opacity: showLogo ? 1 : 0,

                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: isCompactHeight ? 18 : 28,
                                ),

                                child: Column(
                                  children: [
                                    Text(
                                      'FOR NURSAULE',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white38,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 3.8,
                                      ),
                                    ),

                                    const SizedBox(height: 7),

                                    Container(
                                      width: 45,
                                      height: 2,

                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),

                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xffFF2E78),
                                            Color(0xff9D2EFF),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

  Widget buildMainLogo({required double size}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.25),

          colors: [
            const Color(0xffFF6FA5).withValues(alpha: 0.28),

            const Color(0xffFF2E78).withValues(alpha: 0.18),

            const Color(0xff9D2EFF).withValues(alpha: 0.09),

            Colors.transparent,
          ],

          stops: const [0, 0.35, 0.72, 1],
        ),

        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1.2,
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xffFF2E78).withValues(alpha: 0.42),
            blurRadius: 65,
            spreadRadius: 8,
          ),

          BoxShadow(
            color: const Color(0xff9D2EFF).withValues(alpha: 0.28),
            blurRadius: 110,
            spreadRadius: 18,
          ),
        ],
      ),

      child: Stack(
        alignment: Alignment.center,

        children: [
          Container(
            width: size * 0.70,
            height: size * 0.70,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: Colors.white.withValues(alpha: 0.05),

              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),

          Text(
            'N♥B',

            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: size * 0.23,
              fontWeight: FontWeight.w800,
              letterSpacing: size * 0.018,

              shadows: [
                Shadow(
                  color: const Color(0xffFF2E78).withValues(alpha: 0.8),
                  blurRadius: 24,
                ),
              ],
            ),
          ),
        ],
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
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 13),

        Text(
          'Мой самый особенный человек ❤️',

          textAlign: TextAlign.center,

          style: GoogleFonts.poppins(
            color: Colors.white60,
            fontSize: subtitleSize,
            fontWeight: FontWeight.w400,
            height: 1.4,
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
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 13),

        Text(
          'Нурсауле ❤️',

          textAlign: TextAlign.center,

          style: GoogleFonts.poppins(
            color: const Color(0xffFF8AB7),
            fontSize: subtitleSize + 6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget buildLoadingIndicator() {
    return const SizedBox(
      key: ValueKey('loading-indicator'),
      width: 34,
      height: 34,

      child: CircularProgressIndicator(
        color: Color(0xffFF5E99),
        strokeWidth: 2.8,
      ),
    );
  }

  Widget buildLoadingDots() {
    return const Row(
      key: ValueKey('loading-dots'),
      mainAxisSize: MainAxisSize.min,

      children: [
        LoadingDot(delay: 0),
        SizedBox(width: 9),
        LoadingDot(delay: 150),
        SizedBox(width: 9),
        LoadingDot(delay: 300),
      ],
    );
  }

  Widget buildGlow({
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        color: color.withValues(alpha: opacity),

        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: 115,
            spreadRadius: 28,
          ),
        ],
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
  late final Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    animation = Tween<double>(
      begin: 0.45,
      end: 1,
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
      opacity: animation,

      child: ScaleTransition(
        scale: animation,

        child: Container(
          width: 9,
          height: 9,

          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,

            boxShadow: [
              BoxShadow(
                color: const Color(0xffFF2E78).withValues(alpha: 0.7),
                blurRadius: 9,
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

    final starCount = size.width < 600 ? 100 : 150;

    for (int i = 0; i < starCount; i++) {
      final x = random.nextDouble() * size.width;
      final originalY = random.nextDouble() * size.height;

      final movement = sin(animationValue * pi * 2 + i) * 3.5;

      final radius = random.nextDouble() * 1.45 + 0.25;

      final baseOpacity = random.nextDouble() * 0.48 + 0.10;

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
