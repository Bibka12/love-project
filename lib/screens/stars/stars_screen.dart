import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'stars_finale.dart';

class StarsScreen extends StatefulWidget {
  const StarsScreen({super.key});

  @override
  State<StarsScreen> createState() => _StarsScreenState();
}

class _StarsScreenState extends State<StarsScreen>
    with TickerProviderStateMixin {
  final Set<int> openedStars = {};

  int? selectedStar;
  bool showMessage = false;
  bool animationRunning = false;

  late final AnimationController backgroundController;
  late final AnimationController sceneController;

  final List<StarData> stars = const [
    StarData(
      title: 'Что мне в тебе нравится?',
      text:
          'В тебе мне нравится абсолютно всё. Твоя сладкая улыбка, твоя красивая внешность и твой мягкий, нежный характер. В общем, ты именно та девочка, которая понравилась мне с первого взгляда.',
      color: Color(0xffFF5F9E),
    ),
    StarData(
      title: 'Когда ты просто рядом',
      text:
          'Когда ты рядом, я замечаю, что время течёт совсем иначе. Оно не ускоряется и не замедляется — оно просто перестаёт иметь значение. Я забываю обо всех проблемах, потому что рядом с тобой всё исчезает. Так комфортно мне было только с тобой.',
      color: Color(0xffA678FF),
    ),
    StarData(
      title: 'Когда я впервые тебя увидел',
      text:
          'Когда я впервые тебя увидел, твои глаза сияли ярче всех остальных. Уже тогда я решил, что не хочу общаться ни с кем другим — только с тобой. Я даже не представлял, что ты окажешься настолько хорошей девочкой и станешь такой важной частью моей жизни. Спасибо тебе огромное за всё. ❤️',
      color: Color(0xff63D8FF),
    ),
    StarData(
      title: 'Почему ты особенная',
      text:
          'Потому что таких девочек, как ты, больше нет. Красивых, добрых, милых, заботливых и весёлых. Ты словно самая яркая звезда среди всех звёзд. Для меня ты действительно особенная.',
      color: Color(0xffFFD45E),
    ),
    StarData(
      title: 'Описать тебя',
      text:
          'Ты переживаешь всё тихо, без лишних слов и пафоса. И при этом всегда находишь силы заботиться о других. Я вижу, как ты устаёшь, но всё равно продолжаешь улыбаться и шутить. Именно в такие моменты я понимаю, что хочу быть только с тобой, моя любимая.',
      color: Color(0xffFF86C8),
    ),
    StarData(
      title: 'Если бы я снимал фильм',
      text:
          'Если бы я снимал фильм, то он был бы о самом красивом дне моей жизни. Во всех кадрах была бы только ты.\n\nЯ бы снимал, как ты смотришь в окно, как о чём-то думаешь или как неожиданно улыбаешься своим мыслям.\n\nВ этих маленьких моментах столько жизни, что я забываю обо всём остальном. Ты делаешь мир вокруг ярче, теплее и красивее. Спасибо тебе за всё, любимая моя. ❤️',
      color: Color(0xff68E1C4),
    ),
    StarData(
      title: 'Ты должна это знать',
      text:
          'Я трогаю твои волосы не только потому, что мне приятно. Просто они такие мягкие и уютные, что мне всё время хочется поправить тебе причёску. 😄\n\nЛюблю тебя, жаныыым. ❤️',
      color: Color(0xffC993FF),
    ),
    StarData(
      title: 'За что я благодарен судьбе',
      text:
          'За то, что судьба подарила мне такого близкого человека — тебя. Я очень рад, что она свела нас вместе. Надеюсь, что это навсегда и мы всегда будем счастливы с тобой, любимая моя.',
      color: Color(0xffFFAA5F),
    ),
    StarData(
      title: 'О чём я мечтаю с тобой',
      text:
          'Я хочу, чтобы ты всегда была рядом со мной, заботилась обо мне и делала мои дни счастливыми одним своим присутствием.\n\nЯ мечтаю провести с тобой всю жизнь, милая моя. Хочу, чтобы ты всегда оставалась такой же красивой, заботливой и счастливой, как сейчас.\n\nЧтобы у тебя не было переживаний и стресса, и чтобы у нас всё было хорошо, любимая моя.',
      color: Color(0xff6EACFF),
    ),
    StarData(
      title: 'Твоя улыбка',
      text:
          'Твоя улыбка поднимает мне настроение и делает меня счастливым на весь день. Мне правда очень нравится, когда ты улыбаешься.\n\nКогда ты смотришь на меня с улыбкой, я понимаю, насколько ты прекрасная девочка. А твои глаза — вообще космос.\n\nПоэтому улыбайся почаще, милая моя. ❤️',
      color: Color(0xffFF7194),
    ),
  ];

  final List<Offset> positions = const [
    Offset(0.06, 0.06),
    Offset(0.69, 0.04),
    Offset(0.34, 0.17),
    Offset(0.78, 0.27),
    Offset(0.05, 0.31),
    Offset(0.48, 0.43),
    Offset(0.16, 0.56),
    Offset(0.70, 0.59),
    Offset(0.40, 0.72),
    Offset(0.05, 0.78),
  ];

  final List<Offset> escapeDirections = const [
    Offset(-1.3, -1.1),
    Offset(1.3, -1.1),
    Offset(-0.3, -1.5),
    Offset(1.5, -0.3),
    Offset(-1.5, -0.2),
    Offset(1.4, 0.6),
    Offset(-1.4, 0.8),
    Offset(1.3, 1.0),
    Offset(0.2, 1.5),
    Offset(-1.1, 1.3),
  ];

  @override
  void initState() {
    super.initState();

    backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    sceneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    backgroundController.dispose();
    sceneController.dispose();
    super.dispose();
  }

  bool get allOpened => openedStars.length == stars.length;

  Future<void> lightHaptic() async {
    await HapticFeedback.selectionClick();
  }

  Future<void> mediumHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> strongHaptic() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> finaleHaptic() async {
    await HapticFeedback.heavyImpact();

    await Future<void>.delayed(const Duration(milliseconds: 130));

    await HapticFeedback.mediumImpact();

    await Future<void>.delayed(const Duration(milliseconds: 100));

    await HapticFeedback.lightImpact();
  }

  Future<void> openStar(int index) async {
    if (animationRunning || selectedStar != null) return;

    animationRunning = true;

    await lightHaptic();

    if (!mounted) return;

    setState(() {
      selectedStar = index;
      openedStars.add(index);
      showMessage = false;
    });

    await sceneController.forward(from: 0);

    if (!mounted) return;

    await mediumHaptic();

    if (!mounted) return;

    setState(() {
      showMessage = true;
      animationRunning = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 120));

    await HapticFeedback.lightImpact();
  }

  Future<void> closeStar() async {
    if (animationRunning) return;

    animationRunning = true;

    await lightHaptic();

    if (!mounted) return;

    setState(() {
      showMessage = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    await sceneController.reverse();

    if (!mounted) return;

    final bool shouldOpenFinale = allOpened;

    setState(() {
      selectedStar = null;
      animationRunning = false;
    });

    if (shouldOpenFinale) {
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      await finaleHaptic();

      if (!mounted) return;

      await Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) {
            final Animation<double> curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.96,
                  end: 1,
                ).animate(curvedAnimation),
                child: const StarsFinale(),
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff030510),
      body: AnimatedBuilder(
        animation: Listenable.merge([backgroundController, sceneController]),
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
                  Color(0xff100725),
                  Color(0xff270A38),
                  Color(0xff080A18),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StarsBackgroundPainter(
                      glow: 0.4 + backgroundController.value * 0.6,
                      sceneProgress: sceneController.value,
                    ),
                  ),
                ),
                Positioned(
                  top: -100,
                  right: -90,
                  child: _GlowCircle(
                    size: 280,
                    color: const Color(0xff854EFF),
                    opacity: 0.12 + backgroundController.value * 0.05,
                  ),
                ),
                Positioned(
                  bottom: -130,
                  left: -110,
                  child: _GlowCircle(
                    size: 320,
                    color: const Color(0xffFF4D9A),
                    opacity: 0.09 + backgroundController.value * 0.04,
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 8),
                      _buildDescription(),
                      Expanded(child: _buildStarsArea()),
                      _buildBottomText(),
                    ],
                  ),
                ),
                if (selectedStar != null) _buildMessageOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final bool hidden = selectedStar != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: hidden ? 0 : 1,
      child: IgnorePointer(
        ignoring: hidden,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 18, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  await lightHaptic();

                  if (!mounted) return;

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
                    const Text(
                      'Наши звёзды',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${openedStars.length} из ${stars.length} открыто',
                      style: const TextStyle(
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
      ),
    );
  }

  Widget _buildDescription() {
    final bool hidden = selectedStar != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: hidden ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Text(
          allOpened
              ? 'Ты открыла все мои мысли о тебе ❤️'
              : 'Нажимай на звёзды и открывай то, что я хотел тебе сказать',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildStarsArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ...List.generate(stars.length, (index) {
              return _buildPositionedStar(index, constraints);
            }),
          ],
        );
      },
    );
  }

  Widget _buildPositionedStar(int index, BoxConstraints constraints) {
    const double starSize = 72;

    final Offset position = positions[index];

    final double originalLeft = position.dx * (constraints.maxWidth - starSize);

    final double originalTop = position.dy * (constraints.maxHeight - starSize);

    final bool isSelected = selectedStar == index;

    final bool anotherSelected = selectedStar != null && selectedStar != index;

    final double centerLeft = constraints.maxWidth / 2 - starSize / 2;

    final double centerTop = constraints.maxHeight / 2 - starSize / 2 - 45;

    final Offset escape = escapeDirections[index];

    final double escapedLeft =
        originalLeft + escape.dx * constraints.maxWidth * 0.7;

    final double escapedTop =
        originalTop + escape.dy * constraints.maxHeight * 0.65;

    double left = originalLeft;
    double top = originalTop;
    double opacity = 1;
    double scale = 1;

    if (isSelected) {
      left = _lerp(originalLeft, centerLeft, sceneController.value);

      top = _lerp(originalTop, centerTop, sceneController.value);

      scale = _lerp(1, 1.65, sceneController.value);
    } else if (anotherSelected) {
      left = _lerp(originalLeft, escapedLeft, sceneController.value);

      top = _lerp(originalTop, escapedTop, sceneController.value);

      opacity = 1 - sceneController.value;
      scale = 1 - sceneController.value * 0.35;
    }

    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: _StarButton(
            index: index,
            opened: openedStars.contains(index),
            selected: isSelected,
            color: stars[index].color,
            onTap: () {
              openStar(index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomText() {
    final bool hidden = selectedStar != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: hidden ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(
          allOpened
              ? 'Все звёзды открыты ❤️'
              : 'Каждая звезда хранит что-то важное',
          style: TextStyle(
            color: allOpened ? Colors.pinkAccent : Colors.white38,
            fontSize: 13,
            fontWeight: allOpened ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageOverlay() {
    final StarData star = stars[selectedStar!];

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !showMessage,
        child: Container(
          color: Colors.black.withValues(alpha: 0.25 * sceneController.value),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 450),
                    opacity: showMessage ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      scale: showMessage ? 1 : 0.82,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 560),
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              star.color.withValues(alpha: 0.22),
                              const Color(0xff25122F).withValues(alpha: 0.97),
                              const Color(0xff0D111E).withValues(alpha: 0.98),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: star.color.withValues(alpha: 0.58),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: star.color.withValues(alpha: 0.32),
                              blurRadius: 45,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: star.color.withValues(alpha: 0.14),
                                boxShadow: [
                                  BoxShadow(
                                    color: star.color.withValues(alpha: 0.45),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Text(
                                '⭐',
                                style: TextStyle(fontSize: 42),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              star.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.3,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Flexible(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: _TypingText(
                                  text: star.text,
                                  visible: showMessage,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: closeStar,
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: Text(
                                  allOpened
                                      ? 'Открыть финал ✨'
                                      : 'Назад к звёздам',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: star.color,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _lerp(double begin, double end, double value) {
    return begin + (end - begin) * value;
  }
}

class _StarButton extends StatefulWidget {
  final int index;
  final bool opened;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StarButton({
    required this.index,
    required this.opened,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  State<_StarButton> createState() => _StarButtonState();
}

class _StarButtonState extends State<_StarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> scaleAnimation;
  late final Animation<double> movementAnimation;

  bool pressed = false;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200 + widget.index * 90),
    )..repeat(reverse: true);

    scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.12,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    movementAnimation = Tween<double>(
      begin: -3,
      end: 3,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void setPressed(bool value) {
    if (!mounted) return;

    setState(() {
      pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: widget.selected
              ? Offset.zero
              : Offset(
                  sin(widget.index * 1.7) * movementAnimation.value,
                  movementAnimation.value,
                ),
          child: Transform.scale(
            scale: widget.selected ? 1 : scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) {
          setPressed(true);
        },
        onTapCancel: () {
          setPressed(false);
        },
        onTapUp: (_) {
          setPressed(false);
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          scale: pressed ? 0.82 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color.withValues(alpha: widget.opened ? 0.27 : 0.16),
                  widget.color.withValues(alpha: 0.03),
                ],
              ),
              border: Border.all(
                color: widget.color.withValues(
                  alpha: widget.opened ? 0.72 : 0.34,
                ),
                width: widget.opened ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(
                    alpha: widget.opened ? 0.58 : 0.28,
                  ),
                  blurRadius: widget.opened ? 30 : 21,
                  spreadRadius: widget.opened ? 5 : 2,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Text(
                widget.opened ? '💖' : '⭐',
                key: ValueKey<bool>(widget.opened),
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingText extends StatelessWidget {
  final String text;
  final bool visible;

  const _TypingText({required this.text, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: max(1200, text.length * 10)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        final int length = (text.length * value).round().clamp(0, text.length);

        return Text(
          text.substring(0, length),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.65,
          ),
        );
      },
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: 100,
            spreadRadius: 25,
          ),
        ],
      ),
    );
  }
}

class _StarsBackgroundPainter extends CustomPainter {
  final double glow;
  final double sceneProgress;

  _StarsBackgroundPainter({required this.glow, required this.sceneProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(42);

    for (int i = 0; i < 180; i++) {
      final double originalX = random.nextDouble() * size.width;

      final double originalY = random.nextDouble() * size.height;

      final double centerX = size.width / 2;
      final double centerY = size.height / 2;

      final double x = originalX + (originalX - centerX) * sceneProgress * 0.22;

      final double y = originalY + (originalY - centerY) * sceneProgress * 0.22;

      final double radius = random.nextDouble() * 1.7 + 0.3;

      final double opacity =
          (random.nextDouble() * 0.55 + 0.18) *
          glow *
          (1 - sceneProgress * 0.4);

      final Paint paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsBackgroundPainter oldDelegate) {
    return oldDelegate.glow != glow ||
        oldDelegate.sceneProgress != sceneProgress;
  }
}

class StarData {
  final String title;
  final String text;
  final Color color;

  const StarData({
    required this.title,
    required this.text,
    required this.color,
  });
}
