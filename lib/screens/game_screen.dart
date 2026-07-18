import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import '../data/questions.dart';
import 'final_question_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  int currentStage = 1;
  int currentQuestion = 0;
  int stageHearts = 0;
  int totalHearts = 0;

  bool answered = false;
  bool showHeartAnimation = false;
  int? selectedAnswer;

  final AudioPlayer audioPlayer = AudioPlayer();

  late AnimationController questionController;
  late Animation<double> questionFadeAnimation;
  late Animation<Offset> questionSlideAnimation;

  late AnimationController heartController;
  late Animation<double> heartScaleAnimation;
  late Animation<Offset> heartMoveAnimation;

  List<Question> get currentQuestions {
    return currentStage == 1 ? stage1Questions : stage2Questions;
  }

  Question get question => currentQuestions[currentQuestion];

  @override
  void initState() {
    super.initState();

    questionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    questionFadeAnimation = CurvedAnimation(
      parent: questionController,
      curve: Curves.easeOut,
    );

    questionSlideAnimation =
        Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: questionController,
            curve: Curves.easeOutCubic,
          ),
        );

    heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    heartScaleAnimation = Tween<double>(begin: 0.5, end: 1.25).animate(
      CurvedAnimation(parent: heartController, curve: Curves.elasticOut),
    );

    heartMoveAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.4),
    ).animate(CurvedAnimation(parent: heartController, curve: Curves.easeOut));

    questionController.forward();
  }

  @override
  void dispose() {
    questionController.dispose();
    heartController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> playCorrectSound() async {
    try {
      await audioPlayer.stop();
      await audioPlayer.play(AssetSource('sounds/true.mp3'));
    } catch (error) {
      debugPrint('Ошибка правильного звука: $error');
    }
  }

  Future<void> playWinSound() async {
    try {
      await audioPlayer.stop();
      await audioPlayer.play(AssetSource('sounds/win.mp3'));
    } catch (error) {
      debugPrint('Ошибка победного звука: $error');
    }
  }

  Future<void> vibrateWrongAnswer() async {
    try {
      final bool hasVibrator = await Vibration.hasVibrator();

      if (hasVibrator) {
        await Vibration.vibrate(duration: 250);
      }
    } catch (error) {
      debugPrint('Ошибка вибрации: $error');
    }
  }

  Future<void> chooseAnswer(int index) async {
    if (answered) return;

    final bool isCorrect = index == question.correct;

    setState(() {
      answered = true;
      selectedAnswer = index;

      if (isCorrect) {
        stageHearts++;
        totalHearts++;
        showHeartAnimation = true;
      }
    });

    if (isCorrect) {
      playCorrectSound();

      heartController.forward(from: 0);

      Future.delayed(const Duration(milliseconds: 750), () {
        if (!mounted) return;

        setState(() {
          showHeartAnimation = false;
        });
      });
    } else {
      vibrateWrongAnswer();
    }

    await Future.delayed(const Duration(milliseconds: 1100));

    if (!mounted) return;

    if (currentQuestion < currentQuestions.length - 1) {
      await questionController.reverse();

      if (!mounted) return;

      setState(() {
        currentQuestion++;
        answered = false;
        selectedAnswer = null;
      });

      questionController.forward();
    } else {
      showStageResult();
    }
  }

  void showStageResult() {
    playWinSound();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final bool isFirstStage = currentStage == 1;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff281333), Color(0xff111827)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.pinkAccent.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Text(
                    isFirstStage ? '🏆' : '💖',
                    style: const TextStyle(fontSize: 60),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  isFirstStage
                      ? 'Первый этап пройден!'
                      : 'Второй этап пройден!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  '❤️ $stageHearts / ${currentQuestions.length}',
                  style: GoogleFonts.poppins(
                    color: Colors.pinkAccent,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  isFirstStage
                      ? 'Молодец! Ты прошла первое испытание ❤️\n\nГотова ко второму этапу?'
                      : 'Ты вообще умничка ❤️\n\nТеперь тебя ждёт финальный вопрос.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);

                      if (isFirstStage) {
                        startSecondStage();
                      } else {
                        openFinalQuestion();
                      }
                    },
                    child: Text(
                      isFirstStage ? 'Продолжить ❤️' : 'Финальный этап 💖',
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
      },
    );
  }

  void startSecondStage() {
    questionController.reset();

    setState(() {
      currentStage = 2;
      currentQuestion = 0;
      stageHearts = 0;
      answered = false;
      selectedAnswer = null;
    });

    questionController.forward();
  }

  void openFinalQuestion() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const FinalQuestionScreen()),
    );
  }

  Color answerColor(int index) {
    if (!answered) {
      return Colors.white.withOpacity(0.09);
    }

    final bool isCorrect = index == question.correct;
    final bool isSelected = index == selectedAnswer;

    if (isCorrect) {
      return Colors.green.withOpacity(0.75);
    }

    if (isSelected) {
      return Colors.red.withOpacity(0.75);
    }

    return Colors.white.withOpacity(0.06);
  }

  Color answerBorderColor(int index) {
    if (!answered) {
      return Colors.white.withOpacity(0.12);
    }

    final bool isCorrect = index == question.correct;
    final bool isSelected = index == selectedAnswer;

    if (isCorrect) {
      return Colors.greenAccent;
    }

    if (isSelected) {
      return Colors.redAccent;
    }

    return Colors.white.withOpacity(0.08);
  }

  Widget buildAnswerButton(int index) {
    final bool isCorrect = index == question.correct;
    final bool isSelected = index == selectedAnswer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: answerColor(index),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: answerBorderColor(index),
          width: answered && (isCorrect || isSelected) ? 1.8 : 1,
        ),
        boxShadow: answered && isCorrect
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: answered
              ? null
              : () {
                  chooseAnswer(index);
                },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    question.answers[index],
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                if (answered && isCorrect)
                  const Icon(Icons.check_circle_rounded, color: Colors.white),

                if (answered && isSelected && !isCorrect)
                  const Icon(Icons.cancel_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (currentQuestion + 1) / currentQuestions.length;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: currentStage == 1
                    ? const [Color(0xff05070D), Color(0xff301934)]
                    : const [Color(0xff070511), Color(0xff24113F)],
              ),
            ),
          ),

          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.pinkAccent.withOpacity(0.08),
              ),
            ),
          ),

          Positioned(
            bottom: -110,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.07),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Row(
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
                        child: Text(
                          '🎮 Этап $currentStage',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 450),
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 9,
                                backgroundColor: Colors.white12,
                                color: Colors.pinkAccent,
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Text(
                          '❤️ $stageHearts',
                          key: ValueKey(stageHearts),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Вопрос ${currentQuestion + 1} из ${currentQuestions.length}',
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Expanded(
                    child: FadeTransition(
                      opacity: questionFadeAnimation,
                      child: SlideTransition(
                        position: questionSlideAnimation,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 28,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  question.question,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 23,
                                    height: 1.35,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              ...List.generate(
                                question.answers.length,
                                buildAnswerButton,
                              ),

                              if (answered)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      selectedAnswer == question.correct
                                          ? 'Правильно ❤️'
                                          : 'Не угадала, но ничего 😄',
                                      key: ValueKey(selectedAnswer),
                                      style: GoogleFonts.poppins(
                                        color:
                                            selectedAnswer == question.correct
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
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

                  Text(
                    'Всего сердечек: $totalHearts',
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (showHeartAnimation)
            Center(
              child: SlideTransition(
                position: heartMoveAnimation,
                child: ScaleTransition(
                  scale: heartScaleAnimation,
                  child: const Text(
                    '+1 ❤️',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
