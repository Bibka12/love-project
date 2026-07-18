import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class DateScreen extends StatefulWidget {
  const DateScreen({super.key});

  @override
  State<DateScreen> createState() => _DateScreenState();
}

class _DateScreenState extends State<DateScreen> {
  static final Uri workerUrl = Uri.parse(
    'https://love-date-api.genshinxiaofans.workers.dev/',
  );

  final TextEditingController ideaController = TextEditingController();

  int currentStep = 0;

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedActivity;

  bool isSending = false;

  final List<Map<String, String>> activities = const [
    {'emoji': '🌳', 'title': 'Погулять'},
    {'emoji': '☕', 'title': 'Кафе'},
    {'emoji': '🎬', 'title': 'Кино'},
    {'emoji': '🍕', 'title': 'Покушать'},
    {'emoji': '🌇', 'title': 'Посмотреть закат'},
    {'emoji': '✨', 'title': 'Другое'},
  ];

  @override
  void dispose() {
    ideaController.dispose();
    super.dispose();
  }

  Future<void> lightVibration() async {
    await HapticFeedback.selectionClick();
  }

  Future<void> mediumVibration() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> strongVibration() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> successVibration() async {
    await HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 110));

    await HapticFeedback.lightImpact();
  }

  void goToStep(int step) {
    FocusScope.of(context).unfocus();

    setState(() {
      currentStep = step;
    });
  }

  Future<void> selectDate() async {
    await lightVibration();

    final DateTime now = DateTime.now();

    if (!mounted) return;

    final DateTime? result = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Выбери дату',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xffFF4D8D),
              onPrimary: Colors.white,
              surface: Color(0xff17111F),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xff17111F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (result == null || !mounted) return;

    await mediumVibration();

    if (!mounted) return;

    setState(() {
      selectedDate = result;
    });
  }

  Future<void> selectTime() async {
    await lightVibration();

    if (!mounted) return;

    final TimeOfDay? result = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      helpText: 'Выбери время',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xff9D2EFF),
              onPrimary: Colors.white,
              surface: Color(0xff17111F),
              onSurface: Colors.white,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xff17111F),
              hourMinuteColor: Colors.white.withValues(alpha: 0.08),
              dialBackgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: child!,
        );
      },
    );

    if (result == null || !mounted) return;

    await mediumVibration();

    if (!mounted) return;

    setState(() {
      selectedTime = result;
    });
  }

  String formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String formatTime(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void showMessage(String message) {
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: const Color(0xff24162D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  Future<void> showNotTodayDialog() async {
    await mediumVibration();

    if (!mounted) return;

    bool finalMessage = false;
    bool closing = false;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Не сегодня',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return StatefulBuilder(
              builder: (BuildContext dialogBuilderContext, StateSetter setDialogState) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xff17111F,
                            ).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xffFF2E78,
                                ).withValues(alpha: 0.18),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: 0.94, end: 1)
                                          .animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutBack,
                                            ),
                                          ),
                                      child: child,
                                    ),
                                  );
                                },
                            child: finalMessage
                                ? Column(
                                    key: const ValueKey('final-message'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '❤️',
                                        style: TextStyle(fontSize: 56),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        'Хорошо...',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Тогда буду ждать,\nкогда ты снова соскучишься по мне.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white60,
                                          fontSize: 15,
                                          height: 1.55,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  )
                                : Column(
                                    key: const ValueKey('question-message'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '🥺',
                                        style: TextStyle(fontSize: 58),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        'Ты уверена?',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Мне уже стало немного грустно...\n\n'
                                        'Но я всё равно буду ждать, когда ты снова захочешь увидеться ❤️',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white60,
                                          fontSize: 14,
                                          height: 1.55,
                                        ),
                                      ),
                                      const SizedBox(height: 26),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: closing
                                                  ? null
                                                  : () async {
                                                      await strongVibration();

                                                      closing = true;

                                                      setDialogState(() {
                                                        finalMessage = true;
                                                      });

                                                      await Future.delayed(
                                                        const Duration(
                                                          milliseconds: 1500,
                                                        ),
                                                      );

                                                      if (!dialogContext
                                                          .mounted) {
                                                        return;
                                                      }

                                                      Navigator.of(
                                                        dialogContext,
                                                      ).pop();

                                                      if (!mounted) return;

                                                      Navigator.pop(context);
                                                    },
                                              child: Container(
                                                height: 52,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.07),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.09,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Да...',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white60,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: closing
                                                  ? null
                                                  : () async {
                                                      await mediumVibration();

                                                      if (!dialogContext
                                                          .mounted) {
                                                        return;
                                                      }

                                                      Navigator.of(
                                                        dialogContext,
                                                      ).pop();

                                                      await Future.delayed(
                                                        const Duration(
                                                          milliseconds: 120,
                                                        ),
                                                      );

                                                      if (!mounted) return;

                                                      goToStep(1);
                                                    },
                                              child: Container(
                                                height: 52,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xffFF2E78),
                                                          Color(0xff9D2EFF),
                                                        ],
                                                      ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xffFF2E78,
                                                      ).withValues(alpha: 0.28),
                                                      blurRadius: 18,
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  'Передумала ❤️',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
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
                      ),
                    ),
                  ),
                );
              },
            );
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final Animation<double> curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.86,
                  end: 1,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
    );
  }

  Future<void> sendInvitation() async {
    if (selectedDate == null) {
      showMessage('Сначала выбери дату ❤️');
      return;
    }

    if (selectedTime == null) {
      showMessage('Сначала выбери время ❤️');
      return;
    }

    if (selectedActivity == null) {
      showMessage('Выбери, чем хотите заняться ❤️');
      return;
    }

    if (selectedActivity == 'Другое' && ideaController.text.trim().isEmpty) {
      showMessage('Напиши свою идею ❤️');
      return;
    }

    await mediumVibration();

    if (!mounted) return;

    setState(() {
      isSending = true;
    });

    try {
      final http.Response response = await http
          .post(
            workerUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'date': formatDate(selectedDate!),
              'time': formatTime(selectedTime!),
              'activity': selectedActivity!,
              'idea': ideaController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final dynamic decodedResponse = jsonDecode(response.body);

      final Map<String, dynamic> responseData =
          decodedResponse is Map<String, dynamic>
          ? decodedResponse
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['ok'] == true) {
        await successVibration();

        if (!mounted) return;

        setState(() {
          currentStep = 3;
        });
      } else {
        final String error =
            responseData['error']?.toString() ??
            'Не удалось отправить приглашение';

        showMessage(error);
      }
    } catch (error) {
      if (!mounted) return;

      await strongVibration();

      if (!mounted) return;

      showMessage(
        'Не получилось отправить. Проверь интернет и попробуй ещё раз.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void createAnotherInvitation() {
    mediumVibration();

    setState(() {
      currentStep = 0;
      selectedDate = null;
      selectedTime = null;
      selectedActivity = null;
      ideaController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xff05070D),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff05070D), Color(0xff1A1024), Color(0xff32152F)],
          ),
        ),
        child: Stack(
          children: [
            buildBackgroundGlow(),
            SafeArea(
              child: Column(
                children: [
                  buildTopBar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            final Animation<Offset> stepSlideAnimation =
                                Tween<Offset>(
                                  begin: const Offset(0.08, 0),
                                  end: Offset.zero,
                                ).animate(animation);

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: stepSlideAnimation,
                                child: child,
                              ),
                            );
                          },
                      child: buildCurrentStep(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBackgroundGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff9D2EFF).withValues(alpha: 0.13),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff9D2EFF).withValues(alpha: 0.18),
                    blurRadius: 100,
                    spreadRadius: 25,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xffFF2E78).withValues(alpha: 0.10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffFF2E78).withValues(alpha: 0.15),
                    blurRadius: 110,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 5),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              await lightVibration();

              if (!mounted) return;

              if (currentStep > 0 && currentStep < 3) {
                goToStep(currentStep - 1);
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          Expanded(
            child: Text(
              'Приглашение',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return buildIntroStep(key: const ValueKey('intro'));

      case 1:
        return buildDateStep(key: const ValueKey('date'));

      case 2:
        return buildActivityStep(key: const ValueKey('activity'));

      case 3:
        return buildSuccessStep(key: const ValueKey('success'));

      default:
        return buildIntroStep(key: const ValueKey('intro'));
    }
  }

  Widget buildIntroStep({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 25, 24, 30),
      child: Column(
        children: [
          const SizedBox(height: 25),
          Container(
            width: 145,
            height: 145,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffFF2E78).withValues(alpha: 0.35),
                  blurRadius: 45,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Text('💌', style: TextStyle(fontSize: 65)),
          ),
          const SizedBox(height: 42),
          Text(
            'Жаааным, соскучилась по мне?',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Если хочешь провести со мной время, выбери удобный день и отправь мне приглашение ❤️',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),
          buildMainButton(
            title: 'Конечно ❤️',
            onTap: () async {
              await mediumVibration();

              if (!mounted) return;

              goToStep(1);
            },
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: showNotTodayDialog,
            child: Text(
              'Не сегодня',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDateStep({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildStepLabel(step: 'ШАГ 1 ИЗ 2'),
          const SizedBox(height: 12),
          Text(
            'Когда хочешь встретиться?',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Выбери удобную дату и время',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          buildPickerCard(
            icon: Icons.calendar_month_rounded,
            title: 'Дата',
            value: selectedDate == null
                ? 'Выбрать дату'
                : formatDate(selectedDate!),
            onTap: selectDate,
            colors: const [Color(0xff7B2CBF), Color(0xffC9184A)],
          ),
          const SizedBox(height: 18),
          buildPickerCard(
            icon: Icons.schedule_rounded,
            title: 'Время',
            value: selectedTime == null
                ? 'Выбрать время'
                : formatTime(selectedTime!),
            onTap: selectTime,
            colors: const [Color(0xff172554), Color(0xff581C87)],
          ),
          const SizedBox(height: 38),
          buildMainButton(
            title: 'Продолжить',
            onTap: () async {
              if (selectedDate == null) {
                showMessage('Выбери дату ❤️');
                return;
              }

              if (selectedTime == null) {
                showMessage('Выбери время ❤️');
                return;
              }

              await mediumVibration();

              if (!mounted) return;

              goToStep(2);
            },
          ),
        ],
      ),
    );
  }

  Widget buildActivityStep({required Key key}) {
    return SingleChildScrollView(
      key: key,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildStepLabel(step: 'ШАГ 2 ИЗ 2'),
          const SizedBox(height: 12),
          Text(
            'Чем займёмся?',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Выбери вариант или напиши свою идею',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 26),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 13,
              mainAxisSpacing: 13,
              childAspectRatio: 1.65,
            ),
            itemBuilder: (context, index) {
              final Map<String, String> activity = activities[index];

              final String title = activity['title']!;

              final bool selected = selectedActivity == title;

              return GestureDetector(
                onTap: () async {
                  await lightVibration();

                  if (!mounted) return;

                  setState(() {
                    selectedActivity = title;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
                          )
                        : null,
                    color: selected
                        ? null
                        : Colors.white.withValues(alpha: 0.055),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xffFF2E78,
                              ).withValues(alpha: 0.25),
                              blurRadius: 20,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(
                        activity['emoji']!,
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 25),
          Text(
            'Своя идея',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: ideaController,
            maxLines: 4,
            maxLength: 300,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Например: хочу посмотреть закат или просто увидеть тебя ❤️',
              hintStyle: GoogleFonts.poppins(
                color: Colors.white30,
                fontSize: 13,
                height: 1.4,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.055),
              counterStyle: GoogleFonts.poppins(
                color: Colors.white30,
                fontSize: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(
                  color: Color(0xffFF4D8D),
                  width: 1.4,
                ),
              ),
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
          const SizedBox(height: 25),
          buildSummaryCard(),
          const SizedBox(height: 25),
          buildMainButton(
            title: isSending ? 'Отправляю...' : 'Отправить приглашение 💌',
            loading: isSending,
            onTap: isSending ? null : sendInvitation,
          ),
        ],
      ),
    );
  }

  Widget buildSuccessStep({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 45, 24, 35),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 145,
            height: 145,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffFF2E78).withValues(alpha: 0.32),
                  blurRadius: 55,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Text('🥳', style: TextStyle(fontSize: 67)),
          ),
          const SizedBox(height: 40),
          Text(
            'Приглашение отправлено!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'Я получил твоё приглашение в Telegram. Теперь осталось дождаться моего ответа ❤️',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 35),
          buildSummaryCard(),
          const SizedBox(height: 35),
          buildMainButton(
            title: 'Вернуться на главную',
            onTap: () async {
              await mediumVibration();

              if (!mounted) return;

              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: createAnotherInvitation,
            child: Text(
              'Создать ещё одно',
              style: GoogleFonts.poppins(
                color: const Color(0xffFF8AB4),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStepLabel({required String step}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        step,
        style: GoogleFonts.poppins(
          color: const Color(0xffFF8AB4),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget buildPickerCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    required List<Color> colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.13),
              ),
              child: Icon(icon, color: Colors.white, size: 27),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white60,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          buildSummaryRow(
            icon: Icons.calendar_month_rounded,
            title: 'Дата',
            value: selectedDate == null
                ? 'Не выбрана'
                : formatDate(selectedDate!),
          ),
          const SizedBox(height: 14),
          buildSummaryRow(
            icon: Icons.schedule_rounded,
            title: 'Время',
            value: selectedTime == null
                ? 'Не выбрано'
                : formatTime(selectedTime!),
          ),
          const SizedBox(height: 14),
          buildSummaryRow(
            icon: Icons.favorite_rounded,
            title: 'План',
            value: selectedActivity ?? 'Не выбран',
          ),
        ],
      ),
    );
  }

  Widget buildSummaryRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xffFF7AAA), size: 21),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMainButton({
    required String title,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.65 : 1,
        child: Container(
          width: double.infinity,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffFF2E78).withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: loading
              ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
