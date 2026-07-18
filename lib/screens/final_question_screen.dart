import 'dart:math';
import 'package:flutter/material.dart';

class FinalQuestionScreen extends StatefulWidget {
  const FinalQuestionScreen({super.key});

  @override
  State<FinalQuestionScreen> createState() => _FinalQuestionScreenState();
}

class _FinalQuestionScreenState extends State<FinalQuestionScreen>
    with SingleTickerProviderStateMixin {
  final Random random = Random();

  late AnimationController heartController;
  late Animation<double> heartAnimation;

  double noButtonLeft = 0;
  double noButtonTop = 0;

  int noAttempts = 0;
  bool positionInitialized = false;
  bool showResult = false;

  String resultTitle = '';
  String resultText = '';

  @override
  void initState() {
    super.initState();

    heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    heartAnimation = CurvedAnimation(
      parent: heartController,
      curve: Curves.elasticOut,
    );
  }

  void moveNoButton(double maxWidth, double maxHeight) {
    setState(() {
      noAttempts++;

      final availableWidth = maxWidth - 150;
      final availableHeight = maxHeight - 90;

      noButtonLeft =
          10 +
          random.nextDouble() * (availableWidth > 10 ? availableWidth - 10 : 1);

      noButtonTop =
          10 +
          random.nextDouble() *
              (availableHeight > 10 ? availableHeight - 10 : 1);
    });
  }

  void selectPositiveAnswer(String answer) {
    setState(() {
      showResult = true;

      if (answer == 'ofCourse') {
        resultTitle = 'Я тебя тоже ❤️';
        resultText = 'Очень сильно.\nСпасибо, что ты есть в моей жизни.';
      } else {
        resultTitle = 'Моя любимая 💕';
        resultText = 'Я очень счастлив,\nчто именно ты рядом со мной.';
      }
    });

    heartController.forward(from: 0);
  }

  String get hintText {
    if (noAttempts == 0) {
      return 'Отвечай честно...';
    }

    if (noAttempts == 1) {
      return 'Эй, куда ты нажимаешь? 😏';
    }

    if (noAttempts == 2) {
      return 'Я знаю, что ты врёшь 😂';
    }

    if (noAttempts == 3) {
      return 'Попробуй ещё раз ❤️';
    }

    return 'Нажми уже «Конечно» 😂';
  }

  @override
  void dispose() {
    heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF120817), Color(0xFF41112D), Color(0xFF16091D)],
          ),
        ),
        child: SafeArea(
          child: showResult ? buildResultScreen() : buildQuestionScreen(),
        ),
      ),
    );
  }

  Widget buildQuestionScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),

          Container(
            width: 145,
            height: 145,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
              border: Border.all(
                color: Colors.pinkAccent.withOpacity(0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent.withOpacity(0.35),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Text('❤️', style: TextStyle(fontSize: 80)),
          ),

          const SizedBox(height: 35),

          const Text(
            'ПОСЛЕДНИЙ ВОПРОС',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.pinkAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Ты любишь меня?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              hintText,
              key: ValueKey(noAttempts),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 17,
              ),
            ),
          ),

          const SizedBox(height: 35),

          buildAnswerButton(
            text: 'Конечно ❤️',
            beginColor: const Color(0xFFFF4D8D),
            endColor: const Color(0xFFFF1744),
            onPressed: () => selectPositiveAnswer('ofCourse'),
          ),

          const SizedBox(height: 14),

          buildAnswerButton(
            text: 'Да 💕',
            beginColor: const Color(0xFFD34DFF),
            endColor: const Color(0xFFFF4081),
            onPressed: () => selectPositiveAnswer('yes'),
          ),

          const SizedBox(height: 22),

          SizedBox(
            height: 150,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (!positionInitialized) {
                  noButtonLeft = (constraints.maxWidth - 135) / 2;
                  noButtonTop = 20;
                  positionInitialized = true;
                }

                return Stack(
                  children: [
                    if (noAttempts < 5)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        left: noButtonLeft,
                        top: noButtonTop,
                        child: MouseRegion(
                          onEnter: (_) {
                            moveNoButton(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                          },
                          child: GestureDetector(
                            onTapDown: (_) {
                              moveNoButton(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                            },
                            child: Container(
                              width: 135,
                              height: 55,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4A4550),
                                    Color(0xFF29252E),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Text(
                                'Нет 💔',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (noAttempts >= 5)
                      Center(
                        child: Text(
                          'Кнопка «Нет» исчезла 😌',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 15,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget buildResultScreen() {
    return Stack(
      children: [
        const Positioned(
          top: 70,
          left: 30,
          child: FloatingHeart(emoji: '💕', size: 34),
        ),
        const Positioned(
          top: 150,
          right: 35,
          child: FloatingHeart(emoji: '❤️', size: 28),
        ),
        const Positioned(
          bottom: 150,
          left: 40,
          child: FloatingHeart(emoji: '💖', size: 32),
        ),
        const Positioned(
          bottom: 80,
          right: 30,
          child: FloatingHeart(emoji: '💗', size: 37),
        ),

        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              ScaleTransition(
                scale: heartAnimation,
                child: Container(
                  width: 180,
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: Colors.pinkAccent.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withOpacity(0.45),
                        blurRadius: 60,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text('❤️', style: TextStyle(fontSize: 100)),
                ),
              ),

              const SizedBox(height: 45),

              Text(
                resultTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              Text(
                resultText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 19,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 35),

              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text('💕', style: TextStyle(fontSize: 28)),
                  Text('❤️', style: TextStyle(fontSize: 38)),
                  Text('💖', style: TextStyle(fontSize: 30)),
                  Text('💗', style: TextStyle(fontSize: 35)),
                  Text('💕', style: TextStyle(fontSize: 28)),
                ],
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.12),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  child: const Text(
                    'Вернуться назад',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildAnswerButton({
    required String text,
    required Color beginColor,
    required Color endColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [beginColor, endColor]),
          borderRadius: BorderRadius.circular(21),
          boxShadow: [
            BoxShadow(
              color: endColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(21),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class FloatingHeart extends StatefulWidget {
  final String emoji;
  final double size;

  const FloatingHeart({super.key, required this.emoji, required this.size});

  @override
  State<FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<FloatingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    animation = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, animation.value),
          child: Opacity(
            opacity: 0.65,
            child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
          ),
        );
      },
    );
  }
}
