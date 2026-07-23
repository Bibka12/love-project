import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';
import '../../services/user_profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final User user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker picker = ImagePicker();

  late final TextEditingController nameController;

  late final TextEditingController emailController;

  late final TextEditingController bioController;

  late final TextEditingController statusController;

  XFile? selectedImage;

  String currentPhotoUrl = '';

  bool loadingProfile = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController();

    emailController = TextEditingController(text: widget.user.email ?? '');

    bioController = TextEditingController();
    statusController = TextEditingController();

    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    bioController.dispose();
    statusController.dispose();

    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserProfileService.load(
        widget.user,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      nameController.text = profile.name;
      emailController.text = profile.email;
      bioController.text = profile.bio;
      statusController.text = profile.status;

      setState(() {
        currentPhotoUrl = profile.photoUrl;
        loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;

      nameController.text = widget.user.displayName?.trim() ?? '';

      emailController.text = widget.user.email?.trim() ?? '';

      currentPhotoUrl = widget.user.photoURL?.trim() ?? '';

      setState(() {
        loadingProfile = false;
      });

      _showMessage(
        'Не удалось загрузить данные. '
        'Можно заполнить профиль вручную.',
      );
    }
  }

  Future<void> _pickImage() async {
    if (saving) return;

    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        selectedImage = image;
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('Не удалось открыть галерею: $error');
    }
  }

  Future<void> _save() async {
    if (saving) return;

    final name = nameController.text.trim();
    final bio = bioController.text.trim();
    final status = statusController.text.trim();

    if (name.length < 2) {
      _showMessage('Имя должно содержать минимум 2 символа.');
      return;
    }

    if (name.length > 40) {
      _showMessage('Имя не должно быть длиннее 40 символов.');
      return;
    }

    if (status.length > 60) {
      _showMessage('Статус не должен быть длиннее 60 символов.');
      return;
    }

    if (bio.length > 180) {
      _showMessage('Описание не должно быть длиннее 180 символов.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      saving = true;
    });

    try {
      String? uploadedPhotoUrl;

      if (selectedImage != null) {
        uploadedPhotoUrl = await CloudinaryService.uploadProfileAvatar(
          imageFile: File(selectedImage!.path),
          userId: widget.user.uid,
        ).timeout(const Duration(seconds: 30));
      }

      await UserProfileService.updateProfile(
        user: widget.user,
        name: name,
        bio: bio,
        status: status,
        photoUrl: uploadedPhotoUrl,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on TimeoutException {
      if (!mounted) return;

      _showMessage(
        'Сохранение заняло слишком много времени. '
        'Проверь интернет и попробуй снова.',
      );
    } on CloudinaryUploadException catch (error) {
      if (!mounted) return;

      _showMessage(
        'Ошибка загрузки фотографии: '
        '${error.message}',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Не удалось сохранить профиль: $error');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  ImageProvider<Object>? _avatarProvider() {
    if (selectedImage != null) {
      return FileImage(File(selectedImage!.path));
    }

    if (currentPhotoUrl.isNotEmpty) {
      return NetworkImage(currentPhotoUrl);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarProvider();

    return Scaffold(
      backgroundColor: const Color(0xff080A12),
      appBar: AppBar(
        backgroundColor: const Color(0xff080A12),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'Редактировать профиль',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff080A12), Color(0xff25122C)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: loadingProfile
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.pinkAccent),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 40),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: saving ? null : _pickImage,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xffFF2E78),
                                    Color(0xff9D2EFF),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xffFF2E78,
                                    ).withValues(alpha: 0.25),
                                    blurRadius: 28,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor: const Color(0xff211429),
                                backgroundImage: avatar,
                                child: avatar == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 66,
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: 4,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.pinkAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xff080A12),
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: saving ? null : _pickImage,
                        child: Text(
                          'Изменить фотографию',
                          style: GoogleFonts.poppins(
                            color: Colors.pinkAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: nameController,
                        label: 'Имя',
                        hint: 'Как тебя зовут?',
                        icon: Icons.person_outline_rounded,
                        maxLength: 40,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: statusController,
                        label: 'Статус',
                        hint: 'Например: Счастлив ❤️',
                        icon: Icons.favorite_border_rounded,
                        maxLength: 60,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: bioController,
                        label: 'О себе',
                        hint: 'Расскажи немного о себе...',
                        icon: Icons.notes_rounded,
                        maxLength: 180,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        enabled: false,
                        controller: emailController,
                        style: GoogleFonts.poppins(color: Colors.white38),
                        decoration: _inputDecoration(
                          label: 'Электронная почта',
                          hint: '',
                          icon: Icons.mail_outline_rounded,
                          enabled: false,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.pinkAccent
                                .withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: saving
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 23,
                                      height: 23,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Сохраняем...'),
                                  ],
                                )
                              : Text(
                                  'Сохранить изменения',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required int maxLength,
    required TextInputAction textInputAction,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !saving,
      maxLength: maxLength,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
        enabled: true,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled,
  }) {
    final color = enabled ? Colors.white54 : Colors.white38;

    return InputDecoration(
      labelText: label,
      hintText: hint.isEmpty ? null : hint,
      hintStyle: GoogleFonts.poppins(color: Colors.white24),
      labelStyle: GoogleFonts.poppins(color: color),
      prefixIcon: Icon(icon, color: color),
      counterStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
      filled: true,
      fillColor: Colors.white.withValues(alpha: enabled ? 0.06 : 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.pinkAccent),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }
}
