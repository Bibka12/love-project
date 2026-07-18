import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StarsScreen extends StatefulWidget {
  const StarsScreen({super.key});

  @override
  State<StarsScreen> createState() => _StarsScreenState();
}

class _StarsScreenState extends State<StarsScreen>
    with TickerProviderStateMixin {
  final Random random = Random();

  late AnimationController backgroundController;
  late AnimationController finalStarController;

  late Animation<double> backgroundAnimation;
  late Animation<double> finalStarAnimation;

  final Set<int> openedStars = {};

  final List<StarMessage> messages = const [
    StarMessage(
      title: 'Что мне в тебе нравится?',
      text:
          'В тебе мне нравится абсолютно всё. Твоя сладкая улыбка, твоя красивая внешность и твой мягкий, нежный характер. В общем, ты именно та девочка, которая понравилась мне с первого взгляда.',
    ),
    StarMessage(
      title: 'Когда ты просто рядом',
      text:
          'Когда ты рядом, я замечаю, что время течёт совсем иначе. Оно не ускоряется и не замедляется — оно просто перестаёт иметь значение. Я забываю обо всех проблемах, потому что рядом с тобой всё исчезает. Так комфортно мне было только с тобой.',
    ),
    StarMessage(
      title: 'Когда я впервые тебя увидел',
      text:
          'Когда я впервые тебя увидел, твои глаза сияли ярче всех остальных. Уже тогда я решил, что не хочу общаться ни с кем другим — только с тобой. Я даже не представлял, что ты окажешься настолько хорошей девочкой и станешь такой важной частью моей жизни. Спасибо тебе огромное за всё. ❤️',
    ),
    StarMessage(
      title: 'Почему ты особенная',
      text:
          'Потому что таких девочек, как ты, больше нет. Красивых, добрых, милых, заботливых и весёлых. Ты словно самая яркая звезда среди всех звёзд. Для меня ты действительно особенная.',
    ),
    StarMessage(
      title: 'Описать тебя',
      text:
          'Ты переживаешь всё тихо, без лишних слов и пафоса. И при этом всегда находишь силы заботиться о других. Я вижу, как ты устаёшь, но всё равно продолжаешь улыбаться и шутить. Именно в такие моменты я понимаю, что хочу быть только с тобой, моя любимая.',
    ),
    StarMessage(
      title: 'Если бы я снимал фильм',
      text:
          'Если бы я снимал фильм, то он был бы о самом красивом дне моей жизни. Во всех кадрах была бы только ты.\n\nИ знаешь, самое смешное? Я бы не снимал тебя специально. Я снимал бы, как ты смотришь в окно, как кусаешь губу, когда о чём-то думаешь, или как неожиданно улыбаешься своим мыслям. В этих маленьких моментах столько жизни, что я забываю обо всём остальном.\n\nТы делаешь мир вокруг ярче, теплее и красивее. Спасибо тебе за всё, любимая моя. ❤️',
    ),
    StarMessage(
      title: 'Ты должна это знать',
      text:
          'Я трогаю твои волосы не только потому, что мне приятно. Просто они такие мягкие и уютные, что мне всё время хочется поправить тебе причёску. 😄\n\nЛюблю тебя, жаныыым. ❤️',
    ),
  ];

  final List<Offset> starPositions = const [
    Offset(0.14, 0.20),
    Offset(0.72, 0.17),
    Offset(0.42, 0.32),
    Offset(0.82, 0.42),
    Offset(0.18, 0.48),
    Offset(0.58, 0.62),
    Offset(0.24, 0.72),
  ];

  @override
  void initState() {
    super.initState();

    backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    backgroundAnimation = Tween<double>(begin: 0.35, end: 1).animate(
      CurvedAnimation(parent: backgroundController, curve: Curves.easeInOut),
    );

    finalStarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    finalStarAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: finalStarController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    backgroundController.dispose();
    finalStarController.dispose();
    super.dispose();
  }

  bool get allStarsOpened => openedStars.length == messages.length;

  Future<void> openStar(int index) async {
    setState(() {
      openedStars.add(index);
    });

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) {
        return StarMessageDialog(message: messages[index]);
      },
    );
  }

  Future<void> openFinalStar() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (dialogContext) {
        return const FinalStarDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: backgroundAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff030510),
                  Color(0xff120A2B),
                  Color(0xff250B36),
                  Color(0xff070915),
                ],
              ),
            ),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: StarBackgroundPainter(
                    glow: backgroundAnimation.value,
                  ),
                ),

                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 20, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                              ),
                            ),

                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Наши звёзды',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${openedStars.length} из ${messages.length} открыто',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 48),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          allStarsOpened
                              ? 'Ты открыла все звёзды ❤️'
                              : 'Нажимай на большие звёзды и открывай мои мысли о тебе',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),

                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                ...List.generate(messages.length, (index) {
                                  final position = starPositions[index];

                                  return Positioned(
                                    left:
                                        position.dx *
                                        (constraints.maxWidth - 76),
                                    top:
                                        position.dy *
                                        (constraints.maxHeight - 76),
                                    child: InteractiveStar(
                                      opened: openedStars.contains(index),
                                      index: index,
                                      onTap: () {
                                        openStar(index);
                                      },
                                    ),
                                  );
                                }),

                                if (allStarsOpened)
                                  Center(
                                    child: ScaleTransition(
                                      scale: finalStarAnimation,
                                      child: GestureDetector(
                                        onTap: openFinalStar,
                                        child: Container(
                                          width: 115,
                                          height: 115,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const RadialGradient(
                                              colors: [
                                                Color(0xffFFF8B8),
                                                Color(0xffFFD54F),
                                                Color(0xffFF8F00),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.withValues(
                                                  alpha: 0.65,
                                                ),
                                                blurRadius: 50,
                                                spreadRadius: 12,
                                              ),
                                            ],
                                          ),
                                          child: const Text(
                                            '⭐',
                                            style: TextStyle(fontSize: 62),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          allStarsOpened
                              ? 'Нажми на золотую звезду ✨'
                              : 'Каждая звезда хранит что-то важное',
                          style: GoogleFonts.poppins(
                            color: allStarsOpened
                                ? Colors.amberAccent
                                : Colors.white38,
                            fontSize: 13,
                            fontWeight: allStarsOpened
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class InteractiveStar extends StatefulWidget {
  final bool opened;
  final int index;
  final VoidCallback onTap;

  const InteractiveStar({
    super.key,
    required this.opened,
    required this.index,
    required this.onTap,
  });

  @override
  State<InteractiveStar> createState() => _InteractiveStarState();
}

class _InteractiveStarState extends State<InteractiveStar>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000 + widget.index * 90),
    )..repeat(reverse: true);

    scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.12,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.opened
                ? Colors.pinkAccent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: widget.opened
                  ? Colors.pinkAccent.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.opened
                    ? Colors.pinkAccent.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Text(
            widget.opened ? '💖' : '⭐',
            style: const TextStyle(fontSize: 42),
          ),
        ),
      ),
    );
  }
}

class StarMessageDialog extends StatelessWidget {
  final StarMessage message;

  const StarMessageDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff281333), Color(0xff111827)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.pinkAccent.withValues(alpha: 0.24),
              blurRadius: 35,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 54)),

            const SizedBox(height: 16),

            Text(
              message.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  message.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.65,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Закрыть ❤️',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinalStarDialog extends StatelessWidget {
  const FinalStarDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff3B1D16), Color(0xff24152E), Color(0xff15111F)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.amberAccent.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.35),
              blurRadius: 45,
              spreadRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 76)),

            const SizedBox(height: 20),

            Text(
              'Самая яркая звезда',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.amberAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Самая яркая звезда среди всех — это ты. ❤️',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Люблю тебя, Нурсауле.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 17),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: const Color(0xff2B1700),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Закрыть ✨',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StarBackgroundPainter extends CustomPainter {
  final double glow;

  StarBackgroundPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(42);

    for (int i = 0; i < 150; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final double radius = random.nextDouble() * 1.8 + 0.3;
      final double opacity = (random.nextDouble() * 0.55 + 0.2) * glow;

      final Paint paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarBackgroundPainter oldDelegate) {
    return oldDelegate.glow != glow;
  }
}

class StarMessage {
  final String title;
  final String text;

  const StarMessage({required this.title, required this.text});
}
