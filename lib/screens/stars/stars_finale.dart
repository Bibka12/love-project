import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class StarsFinale extends StatefulWidget {
  const StarsFinale({super.key});

  @override
  State<StarsFinale> createState() => _StarsFinaleState();
}

class _StarsFinaleState extends State<StarsFinale>
    with TickerProviderStateMixin {
  int phase = 0;
  int visibleText = 0;

  bool goldenStarPressed = false;

  late final AnimationController backgroundController;
  late final AnimationController goldenController;
  late final AnimationController pulseController;
  late final AnimationController particleController;

  late final Animation<double> goldenScale;
  late final Animation<double> pulseAnimation;

  final List<Timer> timers = [];

  final List<Offset> startPositions = const [
    Offset(0.08, 0.10),
    Offset(0.73, 0.08),
    Offset(0.38, 0.19),
    Offset(0.83, 0.30),
    Offset(0.08, 0.36),
    Offset(0.56, 0.43),
    Offset(0.25, 0.57),
    Offset(0.76, 0.61),
    Offset(0.47, 0.75),
    Offset(0.10, 0.81),
  ];

  final List<Offset> heartPositions = const [
    Offset(0.50, 0.68),
    Offset(0.34, 0.53),
    Offset(0.24, 0.39),
    Offset(0.28, 0.25),
    Offset(0.42, 0.22),
    Offset(0.50, 0.35),
    Offset(0.58, 0.22),
    Offset(0.72, 0.25),
    Offset(0.76, 0.39),
    Offset(0.66, 0.53),
  ];

  final List<Color> starColors = const [
    Color(0xffFF5F9E),
    Color(0xffA678FF),
    Color(0xff63D8FF),
    Color(0xffFFD45E),
    Color(0xffFF86C8),
    Color(0xff68E1C4),
    Color(0xffC993FF),
    Color(0xffFFAA5F),
    Color(0xff6EACFF),
    Color(0xffFF7194),
  ];

  @override
  void initState() {
    super.initState();

    backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    goldenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(reverse: true);

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    goldenScale = Tween<double>(begin: 0.92, end: 1.10).animate(
      CurvedAnimation(parent: goldenController, curve: Curves.easeInOut),
    );

    pulseAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: pulseController, curve: Curves.easeOut));

    startFinale();
  }

  void addTimer(Duration duration, VoidCallback action) {
    timers.add(
      Timer(duration, () {
        if (!mounted) return;
        action();
      }),
    );
  }

  void startFinale() {
    addTimer(const Duration(milliseconds: 500), () {
      setState(() {
        phase = 1;
      });
    });

    addTimer(const Duration(milliseconds: 1400), () {
      setState(() {
        phase = 2;
      });
    });

    addTimer(const Duration(milliseconds: 2800), () {
      setState(() {
        phase = 3;
      });
    });

    addTimer(const Duration(milliseconds: 4600), () {
      setState(() {
        phase = 4;
      });
    });

    addTimer(const Duration(milliseconds: 6500), () {
      setState(() {
        phase = 5;
      });

      pulseController.forward(from: 0);
    });

    addTimer(const Duration(milliseconds: 7800), () {
      setState(() {
        phase = 6;
      });

      pulseController.forward(from: 0);
    });

    addTimer(const Duration(milliseconds: 9000), () {
      setState(() {
        phase = 7;
      });
    });

    addTimer(const Duration(milliseconds: 10300), () {
      setState(() {
        visibleText = 1;
      });
    });

    addTimer(const Duration(milliseconds: 11900), () {
      setState(() {
        visibleText = 2;
      });
    });

    addTimer(const Duration(milliseconds: 13500), () {
      setState(() {
        visibleText = 3;
      });
    });

    addTimer(const Duration(milliseconds: 15200), () {
      setState(() {
        visibleText = 4;
      });
    });
  }

  void pressGoldenStar() {
    if (goldenStarPressed || visibleText < 4) return;

    setState(() {
      goldenStarPressed = true;
      phase = 8;
    });

    goldenController.stop();
    pulseController.forward(from: 0);

    addTimer(const Duration(milliseconds: 1000), () {
      setState(() {
        phase = 9;
      });
    });
  }

  @override
  void dispose() {
    for (final timer in timers) {
      timer.cancel();
    }

    backgroundController.dispose();
    goldenController.dispose();
    pulseController.dispose();
    particleController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff01030A),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          backgroundController,
          pulseController,
          particleController,
        ]),
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff01030A),
                  Color(0xff0A071B),
                  Color(0xff1E092D),
                  Color(0xff080411),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FinaleSpacePainter(
                        glow: 0.35 + backgroundController.value * 0.65,
                        movement: particleController.value,
                        phase: phase,
                      ),
                    ),
                  ),

                  if (phase >= 4)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _FloatingHeartPainter(
                          progress: particleController.value,
                          opacity: phase >= 7 ? 0.8 : 0.35,
                        ),
                      ),
                    ),

                  _buildBackButton(),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          ...List.generate(
                            10,
                            (index) => _buildMovingStar(index, constraints),
                          ),

                          _buildOpeningText(),

                          if (phase == 5 || phase == 6) _buildHeartGlow(),

                          if (phase >= 7 && phase < 9) _buildGoldenStar(),

                          if (phase >= 7 && phase < 9) _buildStoryText(),

                          if (phase == 8) _buildGoldenFlash(),

                          if (phase == 9) _buildFinalResult(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 8,
      left: 8,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: phase >= 7 ? 1 : 0.25,
        child: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMovingStar(int index, BoxConstraints constraints) {
    final bool formingHeart = phase >= 4;

    final Offset targetPosition = formingHeart
        ? heartPositions[index]
        : startPositions[index];

    final bool visible = phase < 6;

    final double size = phase >= 3 ? 60 : 48;

    final Color color = starColors[index];

    double starScale = phase >= 3 ? 1.15 : 0.85;

    if (phase == 5) {
      starScale += sin(pulseAnimation.value * pi) * 0.25;
    }

    if (phase == 6) {
      starScale = 1.35;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOutCubic,
      left: targetPosition.dx * (constraints.maxWidth - size),
      top: targetPosition.dy * (constraints.maxHeight - size),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 850),
        opacity: visible ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutBack,
          scale: starScale,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: phase >= 3 ? 0.38 : 0.18),
                  color.withValues(alpha: 0.03),
                ],
              ),
              border: Border.all(
                color: color.withValues(alpha: phase >= 3 ? 0.75 : 0.35),
                width: phase >= 3 ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: phase >= 3 ? 0.85 : 0.28),
                  blurRadius: phase >= 3 ? 35 : 18,
                  spreadRadius: phase >= 3 ? 8 : 2,
                ),
              ],
            ),
            child: Text(
              formingHeart ? '💖' : '⭐',
              style: TextStyle(fontSize: formingHeart ? 35 : 31),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpeningText() {
    return Align(
      alignment: const Alignment(0, -0.68),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 700),
        opacity: phase >= 2 && phase < 4 ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          offset: phase >= 2 ? Offset.zero : const Offset(0, -0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 12),
              const Text(
                'Подожди...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Все звёзды хотят сказать тебе кое-что',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeartGlow() {
    return Center(
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1 + sin(pulseAnimation.value * pi) * 0.25,
          child: Container(
            width: phase == 6 ? 250 : 190,
            height: phase == 6 ? 250 : 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.pinkAccent.withValues(alpha: phase == 6 ? 0.50 : 0.22),
                  Colors.purpleAccent.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent.withValues(
                    alpha: phase == 6 ? 0.75 : 0.35,
                  ),
                  blurRadius: phase == 6 ? 100 : 60,
                  spreadRadius: phase == 6 ? 25 : 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoldenStar() {
    final bool disappearing = phase == 8;

    return Align(
      alignment: const Alignment(0, -0.42),
      child: GestureDetector(
        onTap: visibleText >= 4 ? pressGoldenStar : null,
        child: ScaleTransition(
          scale: goldenScale,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            scale: disappearing ? 3.2 : 1,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 700),
              opacity: disappearing ? 0 : 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.amberAccent.withValues(alpha: 0.22),
                          Colors.amber.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 148,
                    height: 148,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xffFFFFFF),
                          Color(0xffFFF6A5),
                          Color(0xffFFD43B),
                          Color(0xffFF9500),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amberAccent.withValues(alpha: 0.95),
                          blurRadius: 80,
                          spreadRadius: 22,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.55),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Text('🌟', style: TextStyle(fontSize: 84)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryText() {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: const Color(0xff070A14).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 30,
              spreadRadius: 3,
            ),
            BoxShadow(
              color: Colors.pinkAccent.withValues(alpha: 0.10),
              blurRadius: 35,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextLine(text: 'Я долго думал...', visible: visibleText >= 1),

            const SizedBox(height: 5),

            _buildTextLine(
              text: 'Какая звезда самая красивая...',
              visible: visibleText >= 2,
            ),

            const SizedBox(height: 5),

            _buildTextLine(
              text: 'Но потом понял...',
              visible: visibleText >= 3,
            ),

            const SizedBox(height: 10),

            _buildTextLine(
              text:
                  'Даже десяти звёзд недостаточно,\nчтобы описать всё, что я чувствую к тебе.',
              visible: visibleText >= 4,
              important: true,
            ),

            const SizedBox(height: 8),

            _buildTextLine(
              text: 'Самая яркая звезда в моей жизни —\nэто ты, Нурсауле ❤️',
              visible: visibleText >= 4,
              important: true,
              pink: true,
            ),

            const SizedBox(height: 12),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 700),
              opacity: visibleText >= 4 ? 1 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 700),
                scale: visibleText >= 4 ? 1 : 0.8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'Нажми на золотую звезду ✨',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextLine({
    required String text,
    required bool visible,
    bool important = false,
    bool pink = false,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 850),
      opacity: visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 0.25),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: pink
                ? Colors.pinkAccent
                : important
                ? Colors.white
                : Colors.white70,
            fontSize: important ? 18 : 15,
            height: 1.4,
            fontWeight: important ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGoldenFlash() {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            final double opacity = sin(value * pi);

            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: opacity * 0.95),
                    Colors.amberAccent.withValues(alpha: opacity * 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFinalResult() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.28),
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.65, end: 1),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xff34162F),
                      Color(0xff171127),
                      Color(0xff09101C),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.pinkAccent.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.28),
                      blurRadius: 55,
                      spreadRadius: 7,
                    ),
                    BoxShadow(
                      color: Colors.amberAccent.withValues(alpha: 0.18),
                      blurRadius: 80,
                      spreadRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.pinkAccent.withValues(alpha: 0.20),
                                Colors.amberAccent.withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 145,
                          height: 145,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xffFFF9CB),
                                Color(0xffFFD752),
                                Color(0xffFF8A00),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amberAccent.withValues(
                                  alpha: 0.75,
                                ),
                                blurRadius: 70,
                                spreadRadius: 18,
                              ),
                            ],
                          ),
                          child: const Text(
                            '🌟',
                            style: TextStyle(fontSize: 82),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Ты открыла все звёзды ❤️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Каждая из них хранила одну мою мысль о тебе.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 17,
                        height: 1.55,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Но даже если бы звёзд было бесконечно много, их всё равно не хватило бы, чтобы рассказать, насколько ты для меня важна.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Моя самая яркая звезда — это ты, Нурсауле.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.pinkAccent,
                        fontSize: 21,
                        height: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Люблю тебя, жаныыым ❤️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text(
                          'Вернуться к звёздам',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent.withValues(
                            alpha: 0.88,
                          ),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinaleSpacePainter extends CustomPainter {
  final double glow;
  final double movement;
  final int phase;

  _FinaleSpacePainter({
    required this.glow,
    required this.movement,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(52);

    for (int i = 0; i < 180; i++) {
      final double originalX = random.nextDouble() * size.width;
      final double originalY = random.nextDouble() * size.height;

      final double speed = 0.5 + random.nextDouble() * 1.5;

      final double y =
          (originalY + movement * size.height * 0.08 * speed) % size.height;

      final double x = originalX + sin((movement * pi * 2) + i) * speed * 2;

      final double radius = random.nextDouble() * 1.8 + 0.3;

      final double opacity = (0.16 + random.nextDouble() * 0.55) * glow;

      final Paint paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    final Paint nebulaPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xff9B4DFF).withValues(alpha: 0.10 * glow),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.72, size.height * 0.34),
              radius: size.width * 0.65,
            ),
          );

    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.34),
      size.width * 0.65,
      nebulaPaint,
    );

    final Paint pinkNebula = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(
                0xffFF3E8F,
              ).withValues(alpha: phase >= 4 ? 0.09 : 0.04),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.24, size.height * 0.72),
              radius: size.width * 0.55,
            ),
          );

    canvas.drawCircle(
      Offset(size.width * 0.24, size.height * 0.72),
      size.width * 0.55,
      pinkNebula,
    );
  }

  @override
  bool shouldRepaint(covariant _FinaleSpacePainter oldDelegate) {
    return oldDelegate.glow != glow ||
        oldDelegate.movement != movement ||
        oldDelegate.phase != phase;
  }
}

class _FloatingHeartPainter extends CustomPainter {
  final double progress;
  final double opacity;

  _FloatingHeartPainter({required this.progress, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(17);

    for (int i = 0; i < 24; i++) {
      final double baseX = random.nextDouble() * size.width;
      final double baseY = random.nextDouble() * size.height;

      final double speed = 0.4 + random.nextDouble() * 1.2;

      final double y =
          (baseY - progress * size.height * 0.18 * speed) % size.height;

      final double x = baseX + sin(progress * pi * 2 + i) * 8;

      final double sizeValue = 7 + random.nextDouble() * 9;

      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: i.isEven ? '❤' : '✦',
          style: TextStyle(
            color: i.isEven
                ? Colors.pinkAccent.withValues(alpha: opacity)
                : Colors.amberAccent.withValues(alpha: opacity * 0.8),
            fontSize: sizeValue,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      painter.layout();

      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingHeartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
