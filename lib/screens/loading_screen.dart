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
  late final AnimationController heartController;
  late final Animation<double> heartAnimation;

  final List<Timer> timers = [];

  bool showHeart = false;
  bool showFirstText = false;
  bool showSecondText = false;
  bool checkingDevice = true;
  bool openingNextScreen = false;

  @override
  void initState() {
    super.initState();

    backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    heartAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.85, end: 1.08),
            weight: 45,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.08, end: 1),
            weight: 55,
          ),
        ]).animate(
          CurvedAnimation(parent: heartController, curve: Curves.easeInOut),
        );

    startApplication();
  }

  void addTimer(Duration duration, VoidCallback callback) {
    final Timer timer = Timer(duration, () {
      if (!mounted) return;
      callback();
    });

    timers.add(timer);
  }

  Future<void> startApplication() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final bool deviceUnlocked = preferences.getBool('device_unlocked') ?? false;

    if (!mounted) return;

    setState(() {
      checkingDevice = false;
    });

    addTimer(const Duration(milliseconds: 350), () {
      setState(() {
        showHeart = true;
      });

      heartController.repeat(reverse: true);
    });

    addTimer(const Duration(milliseconds: 1200), () {
      setState(() {
        showFirstText = true;
      });
    });

    if (deviceUnlocked) {
      addTimer(const Duration(milliseconds: 2600), () {
        setState(() {
          showFirstText = false;
        });
      });

      addTimer(const Duration(milliseconds: 3150), () {
        setState(() {
          showSecondText = true;
        });

        HapticFeedback.mediumImpact();
      });

      addTimer(const Duration(milliseconds: 5000), openHomeScreen);
    } else {
      addTimer(const Duration(milliseconds: 2600), openPassword);
    }
  }

  Future<void> openPassword() async {
    if (openingNextScreen || !mounted) return;

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) {
        return const PasswordScreen();
      },
    );

    if (!mounted) return;

    if (result == true) {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      await preferences.setBool('device_unlocked', true);

      if (!mounted) return;

      await showWelcomeAnimation();
    }
  }

  Future<void> showWelcomeAnimation() async {
    await HapticFeedback.mediumImpact();

    if (!mounted) return;

    setState(() {
      showFirstText = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;

    setState(() {
      showSecondText = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    await openHomeScreen();
  }

  Future<void> openHomeScreen() async {
    if (openingNextScreen || !mounted) return;

    openingNextScreen = true;

    await HapticFeedback.lightImpact();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1100),
        pageBuilder: (context, animation, secondaryAnimation) {
          final Animation<double> curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.97,
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
    for (final Timer timer in timers) {
      timer.cancel();
    }

    backgroundController.dispose();
    heartController.dispose();

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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff02040D),
                  Color(0xff120821),
                  Color(0xff35102F),
                  Color(0xff080A18),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: WelcomeStarsPainter(
                      animationValue: backgroundController.value,
                    ),
                  ),
                ),

                Positioned(
                  top: -120,
                  right: -100,
                  child: buildGlow(
                    size: 310,
                    color: const Color(0xff9D2EFF),
                    opacity: 0.08 + backgroundController.value * 0.05,
                  ),
                ),

                Positioned(
                  bottom: -140,
                  left: -110,
                  child: buildGlow(
                    size: 330,
                    color: const Color(0xffFF2E78),
                    opacity: 0.07 + backgroundController.value * 0.04,
                  ),
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      children: [
                        const Spacer(),

                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 900),
                          opacity: showHeart ? 1 : 0,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutBack,
                            scale: showHeart ? 1 : 0.4,
                            child: ScaleTransition(
                              scale: heartAnimation,
                              child: buildHeart(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 55),

                        SizedBox(
                          height: 150,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 700),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.15),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: showSecondText
                                  ? buildSecondText()
                                  : showFirstText
                                  ? buildFirstText()
                                  : checkingDevice
                                  ? buildLoadingIndicator()
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),

                        const Spacer(),

                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 700),
                          opacity: showHeart ? 0.55 : 0,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 25),
                            child: Text(
                              'N ♥ B',
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildFirstText() {
    return Column(
      key: const ValueKey('first-text'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Я ждал именно тебя',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Мой самый особенный человек ❤️',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 15),
        ),
      ],
    );
  }

  Widget buildSecondText() {
    return Column(
      key: const ValueKey('second-text'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Добро пожаловать домой',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Нурсауле ❤️',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: const Color(0xffFF81B0),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget buildLoadingIndicator() {
    return const SizedBox(
      key: ValueKey('loading'),
      width: 25,
      height: 25,
      child: CircularProgressIndicator(
        color: Color(0xffFF5E99),
        strokeWidth: 2.4,
      ),
    );
  }

  Widget buildHeart() {
    return Container(
      width: 165,
      height: 165,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xffFF2E78).withValues(alpha: 0.25),
            const Color(0xff9D2EFF).withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffFF2E78).withValues(alpha: 0.40),
            blurRadius: 65,
            spreadRadius: 9,
          ),
          BoxShadow(
            color: const Color(0xff9D2EFF).withValues(alpha: 0.22),
            blurRadius: 95,
            spreadRadius: 15,
          ),
        ],
      ),
      child: const Text('❤️', style: TextStyle(fontSize: 83)),
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
            blurRadius: 110,
            spreadRadius: 25,
          ),
        ],
      ),
    );
  }
}

class WelcomeStarsPainter extends CustomPainter {
  final double animationValue;

  WelcomeStarsPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(37);

    for (int i = 0; i < 130; i++) {
      final double x = random.nextDouble() * size.width;
      final double originalY = random.nextDouble() * size.height;

      final double movement = sin(animationValue * pi * 2 + i) * 4;

      final double radius = random.nextDouble() * 1.55 + 0.25;

      final double baseOpacity = random.nextDouble() * 0.50 + 0.10;

      final double pulse =
          0.55 + 0.45 * sin(animationValue * pi * 2 + i * 0.47).abs();

      final Paint paint = Paint()
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
