import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../date_screen.dart';
import 'game_screen.dart';
import 'stars/stars_screen.dart';
import 'music_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController entranceController;
  late final Animation<double> fadeAnimation;
  late final Animation<Offset> slideAnimation;

  final PageController tabsController = PageController();

  final PageController cardsController = PageController(viewportFraction: 0.87);

  int currentTabIndex = 0;
  int currentCardIndex = 0;

  @override
  void initState() {
    super.initState();

    entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    fadeAnimation = CurvedAnimation(
      parent: entranceController,
      curve: Curves.easeOut,
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    entranceController.forward();
  }

  @override
  void dispose() {
    entranceController.dispose();
    tabsController.dispose();
    cardsController.dispose();
    super.dispose();
  }

  void openGame() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void openStars() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StarsScreen()),
    );
  }

  void openDateInvitation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DateScreen()),
    );
  }

  void changeTab(int index) {
    if (currentTabIndex == index) return;

    tabsController.animateToPage(
      index,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
    );
  }

  Alignment getIndicatorAlignment() {
    const int tabCount = 4;
    final double x = -1 + (2 * currentTabIndex / (tabCount - 1));
    return Alignment(x, 0);
  }

  Widget getTabPage(int index) {
    switch (index) {
      case 0:
        return buildHomePage();

      case 1:
        return buildChatPage();

      case 2:
        return const MusicScreen();

      case 3:
        return buildProfilePage();

      default:
        return buildHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff05070D),

      body: PageView.builder(
        controller: tabsController,
        itemCount: 4,
        physics: const BouncingScrollPhysics(),

        onPageChanged: (index) {
          setState(() {
            currentTabIndex = index;
          });
        },

        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: tabsController,

            builder: (context, child) {
              double page = currentTabIndex.toDouble();

              if (tabsController.hasClients &&
                  tabsController.position.haveDimensions) {
                page = tabsController.page ?? currentTabIndex.toDouble();
              }

              final double difference = (page - index).abs().clamp(0.0, 1.0);

              final double scale = 1 - difference * 0.015;
              final double opacity = 1 - difference * 0.05;

              return Transform.scale(
                scale: scale,

                child: Opacity(opacity: opacity, child: child),
              );
            },

            child: getTabPage(index),
          );
        },
      ),

      bottomNavigationBar: buildBottomNavigationBar(),
    );
  }

  // =====================================================
  // ГЛАВНАЯ
  // =====================================================

  Widget buildHomePage() {
    return Container(
      width: double.infinity,
      height: double.infinity,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,

          colors: [Color(0xff05070D), Color(0xff17101F), Color(0xff301934)],
        ),
      ),

      child: SafeArea(
        bottom: false,

        child: FadeTransition(
          opacity: fadeAnimation,

          child: SlideTransition(
            position: slideAnimation,

            child: LayoutBuilder(
              builder: (context, constraints) {
                final double cardHeight = (constraints.maxHeight * 0.60).clamp(
                  410.0,
                  490.0,
                );

                return Column(
                  children: [
                    const SizedBox(height: 18),

                    Text(
                      'N♥B',
                      textAlign: TextAlign.center,

                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'For Nursaule',

                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: cardHeight + 55,

                      child: PageView(
                        controller: cardsController,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,

                        onPageChanged: (index) {
                          setState(() {
                            currentCardIndex = index;
                          });
                        },

                        children: [
                          buildCardPage(
                            index: 0,

                            child: buildSectionCard(
                              icon: '🎮',
                              title: 'Насколько ты меня знаешь?',
                              subtitle:
                                  'Пройди два этапа и ответь на финальный вопрос ❤️',
                              hint: 'Проверь, насколько хорошо ты меня знаешь',

                              colors: const [
                                Color(0xff7B2CBF),
                                Color(0xffC9184A),
                              ],

                              onTap: openGame,
                            ),
                          ),

                          buildCardPage(
                            index: 1,

                            child: buildSectionCard(
                              icon: '⭐',
                              title: 'Наши звёзды',
                              subtitle:
                                  'Открывай звёзды и читай то, что я хочу тебе сказать ✨',
                              hint: 'В каждой звезде спрятаны мои слова',

                              colors: const [
                                Color(0xff172554),
                                Color(0xff581C87),
                              ],

                              onTap: openStars,
                            ),
                          ),

                          buildCardPage(
                            index: 2,

                            child: buildSectionCard(
                              icon: '💌',
                              title: 'Приглашение',
                              subtitle:
                                  'Выбери день, время и предложи, куда пойдём вместе ❤️',
                              hint: 'Хочешь провести время со мной?',

                              colors: const [
                                Color(0xffA4133C),
                                Color(0xff5A189A),
                              ],

                              onTap: openDateInvitation,
                            ),
                          ),
                        ],
                      ),
                    ),

                    buildCardIndicators(),

                    const Spacer(),

                    Text(
                      'Листай наши разделы',

                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Для самой особенной девочки ❤️',

                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // АНИМАЦИЯ КАРТОЧЕК
  // =====================================================

  Widget buildCardPage({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: cardsController,

      builder: (context, _) {
        double page = currentCardIndex.toDouble();

        if (cardsController.hasClients &&
            cardsController.position.haveDimensions) {
          page = cardsController.page ?? currentCardIndex.toDouble();
        }

        final double difference = (page - index).abs().clamp(0.0, 1.0);

        final double scale = 1 - difference * 0.055;
        final double opacity = 1 - difference * 0.17;

        return Transform.scale(
          scale: scale,

          child: Opacity(
            opacity: opacity,

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 28),

              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget buildCardIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,

      children: List.generate(3, (index) {
        final bool selected = currentCardIndex == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,

          width: selected ? 25 : 7,
          height: 7,

          margin: const EdgeInsets.symmetric(horizontal: 4),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),

            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
                  )
                : null,

            color: selected ? null : Colors.white24,

            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xffFF2E78).withValues(alpha: 0.45),

                      blurRadius: 9,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // =====================================================
  // КАРТОЧКА
  // =====================================================

  Widget buildSectionCard({
    required String icon,
    required String title,
    required String subtitle,
    required String hint,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),

          borderRadius: BorderRadius.circular(34),

          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),

          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.25),
              blurRadius: 22,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),

            BoxShadow(
              color: colors.first.withValues(alpha: 0.16),
              blurRadius: 35,
              spreadRadius: 1,
              offset: const Offset(0, -4),
            ),
          ],
        ),

        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),

          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -60,

                child: Container(
                  width: 210,
                  height: 210,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),

              Positioned(
                right: 30,
                top: 135,

                child: Container(
                  width: 60,
                  height: 60,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.045),
                  ),
                ),
              ),

              Positioned(
                left: -80,
                bottom: -100,

                child: Container(
                  width: 240,
                  height: 240,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(27),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          alignment: Alignment.center,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            color: Colors.white.withValues(alpha: 0.13),

                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.13),

                                blurRadius: 14,
                              ),
                            ],
                          ),

                          child: Text(
                            icon,

                            style: const TextStyle(fontSize: 47),
                          ),
                        ),

                        Container(
                          width: 46,
                          height: 46,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            color: Colors.white.withValues(alpha: 0.13),

                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),

                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    Text(
                      hint.toUpperCase(),

                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      title,

                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 13),

                    Text(
                      subtitle,

                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 22),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),

                        borderRadius: BorderRadius.circular(22),

                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),

                      child: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          Text(
                            'Открыть',

                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(width: 7),

                          const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // ЧАТ
  // =====================================================

  Widget buildChatPage() {
    return Container(
      width: double.infinity,
      height: double.infinity,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,

          colors: [Color(0xff05070D), Color(0xff1E1633)],
        ),
      ),

      child: SafeArea(
        bottom: false,

        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Container(
                width: 95,
                height: 95,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: Colors.white.withValues(alpha: 0.05),

                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff9D2EFF).withValues(alpha: 0.18),

                      blurRadius: 30,
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white54,
                  size: 48,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Чат',

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Здесь позже появится чат ❤️',

                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // ПРОФИЛЬ
  // =====================================================

  Widget buildProfilePage() {
    return Container(
      width: double.infinity,
      height: double.infinity,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,

          colors: [Color(0xff05070D), Color(0xff301934)],
        ),
      ),

      child: SafeArea(
        bottom: false,

        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Container(
                width: 95,
                height: 95,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: Colors.white.withValues(alpha: 0.05),

                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffFF2E78).withValues(alpha: 0.18),

                      blurRadius: 30,
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white54,
                  size: 52,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Профиль',

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Этот раздел добавим позже ✨',

                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // НИЖНЕЕ МЕНЮ
  // =====================================================

  Widget buildBottomNavigationBar() {
    return Container(
      color: const Color(0xff05070D),

      child: SafeArea(
        top: false,

        child: Container(
          height: 52,

          margin: const EdgeInsets.fromLTRB(16, 2, 16, 5),

          decoration: BoxDecoration(
            color: const Color(0xff0D0E17),

            borderRadius: BorderRadius.circular(18),

            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),

          child: LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = constraints.maxWidth / 4;

              return Stack(
                alignment: Alignment.center,

                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 480),
                    curve: Curves.easeInOutCubic,

                    alignment: getIndicatorAlignment(),

                    child: SizedBox(
                      width: itemWidth,
                      height: 52,

                      child: Center(
                        child: Container(
                          width: 42,
                          height: 38,

                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),

                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,

                              colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
                            ),

                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xffFF2E78,
                                ).withValues(alpha: 0.45),

                                blurRadius: 14,
                                spreadRadius: 1,
                              ),

                              BoxShadow(
                                color: const Color(
                                  0xff9D2EFF,
                                ).withValues(alpha: 0.25),

                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      buildNavigationButton(
                        index: 0,
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                      ),

                      buildNavigationButton(
                        index: 1,
                        icon: Icons.chat_bubble_outline_rounded,
                        selectedIcon: Icons.chat_bubble_rounded,
                      ),

                      buildNavigationButton(
                        index: 2,
                        icon: Icons.music_note_outlined,
                        selectedIcon: Icons.music_note_rounded,
                      ),

                      buildNavigationButton(
                        index: 3,
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildNavigationButton({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final bool selected = currentTabIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => changeTab(index),

        child: SizedBox(
          height: 52,

          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              scale: selected ? 1.08 : 1,

              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),

                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,

                    child: ScaleTransition(scale: animation, child: child),
                  );
                },

                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey<bool>(selected),
                  size: selected ? 23 : 22,
                  color: selected ? Colors.white : Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
