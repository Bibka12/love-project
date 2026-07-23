import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Неправильно указана почта';
      case 'user-not-found':
        return 'Аккаунт с такой почтой не найден';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неправильная почта или пароль';
      case 'email-already-in-use':
        return 'Аккаунт с такой почтой уже существует';
      case 'weak-password':
        return 'Пароль слишком простой';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуй немного позже';
      case 'network-request-failed':
        return 'Проверь подключение к интернету';
      case 'operation-not-allowed':
        return 'Вход по почте ещё не включён в Firebase';
      default:
        return error.message ?? 'Произошла ошибка';
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (!_isLogin && name.isEmpty) {
      _showMessage('Введите имя');
      return;
    }

    if (email.isEmpty) {
      _showMessage('Введите почту');
      return;
    }

    if (password.length < 6) {
      _showMessage('Пароль должен содержать минимум 6 символов');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final UserCredential credential =
            await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await credential.user?.updateDisplayName(name);
        await credential.user?.reload();
      }

      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showMessage(_firebaseErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showMessage('Не удалось выполнить действие');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.pinkAccent),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.07),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.pinkAccent,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff05070D),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff05070D),
              Color(0xff26122E),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
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
                const SizedBox(height: 20),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Colors.pinkAccent,
                        Colors.purpleAccent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withOpacity(0.30),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'N❤️B',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? 'С возвращением ❤️' : 'Создание аккаунта',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Войди, чтобы открыть свой профиль'
                      : 'Создай профиль для общения в приложении',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isLogin
                      ? const SizedBox.shrink()
                      : Padding(
                          key: const ValueKey<String>('name'),
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                            ),
                            decoration: _inputDecoration(
                              hint: 'Имя',
                              icon: Icons.person_rounded,
                            ),
                          ),
                        ),
                ),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: _inputDecoration(
                    hint: 'Почта',
                    icon: Icons.email_rounded,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  onSubmitted: (_) {
                    if (!_isLoading) {
                      _submit();
                    }
                  },
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: _inputDecoration(
                    hint: 'Пароль',
                    icon: Icons.lock_rounded,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.pinkAccent.withOpacity(0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Войти' : 'Создать аккаунт',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                  child: Text(
                    _isLogin
                        ? 'Нет аккаунта? Создать'
                        : 'Уже есть аккаунт? Войти',
                    style: GoogleFonts.poppins(
                      color: Colors.pinkAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
