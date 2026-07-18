import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController passwordController = TextEditingController();
  final FocusNode passwordFocusNode = FocusNode();

  late final AnimationController shakeController;
  late final Animation<double> shakeAnimation;

  bool obscurePassword = true;
  bool checkingPassword = false;

  String message = 'Этот подарок создан только для тебя ❤️';

  @override
  void initState() {
    super.initState();

    shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 10, end: -7), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -7, end: 7), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 7, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: shakeController, curve: Curves.easeOut));

    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        passwordFocusNode.requestFocus();
      }
    });
  }

  Future<void> checkPassword() async {
    if (checkingPassword) return;

    final String password = passwordController.text.trim();

    if (password.isEmpty) {
      showError('Сначала введи пароль ❤️');
      return;
    }

    await HapticFeedback.selectionClick();

    if (!mounted) return;

    setState(() {
      checkingPassword = true;
      message = 'Проверяю...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;

    if (password.toLowerCase() == 'love') {
      await HapticFeedback.mediumImpact();

      if (!mounted) return;

      Navigator.pop(context, true);
    } else {
      showError('Кажется, пароль неверный...');
    }
  }

  void showError(String text) {
    HapticFeedback.heavyImpact();

    setState(() {
      checkingPassword = false;
      message = text;
    });

    passwordController.clear();
    shakeController.forward(from: 0);

    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || checkingPassword) return;

      setState(() {
        message = 'Попробуй ещё раз ❤️';
      });

      passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    passwordController.dispose();
    passwordFocusNode.dispose();
    shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: AnimatedBuilder(
        animation: shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(shakeAnimation.value, 0),
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xff190D25).withValues(alpha: 0.96),
                    const Color(0xff35132F).withValues(alpha: 0.94),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withValues(alpha: 0.22),
                    blurRadius: 45,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        width: 100,
                        height: 100,
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
                              color: Colors.pinkAccent.withValues(alpha: 0.35),
                              blurRadius: 35,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Text('🔐', style: TextStyle(fontSize: 45)),
                      ),
                    ),

                    const SizedBox(height: 25),

                    Text(
                      'Только для Нурсауле',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        message,
                        key: ValueKey<String>(message),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: checkingPassword
                              ? const Color(0xffFF81B0)
                              : Colors.white60,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    TextField(
                      controller: passwordController,
                      focusNode: passwordFocusNode,
                      obscureText: obscurePassword,
                      enabled: !checkingPassword,
                      onSubmitted: (_) {
                        checkPassword();
                      },
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      cursorColor: const Color(0xffFF5E99),
                      decoration: InputDecoration(
                        hintText: 'Введите пароль',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white30,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white54,
                        ),
                        suffixIcon: IconButton(
                          onPressed: checkingPassword
                              ? null
                              : () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white54,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xffFF5E99),
                            width: 1.5,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: checkingPassword ? null : checkPassword,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: checkingPassword ? 0.65 : 1,
                        child: Container(
                          width: double.infinity,
                          height: 57,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xffFF2E78,
                                ).withValues(alpha: 0.28),
                                blurRadius: 22,
                                offset: const Offset(0, 9),
                              ),
                            ],
                          ),
                          child: checkingPassword
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : Text(
                                  'Открыть подарок ❤️',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Пароль потребуется только один раз',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white30,
                        fontSize: 11,
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
