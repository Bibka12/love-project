import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryUploadException implements Exception {
  const CloudinaryUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudinaryService {
  CloudinaryService._();

  static const String cloudName = 'ogfod6oh';
  static const String uploadPreset = 'love_project_upload';

  static Uri _uploadUri(String resourceType) => Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
      );

  static Future<String> uploadProfileAvatar({
    required File imageFile,
    required String userId,
  }) {
    return _uploadFile(
      file: imageFile,
      resourceType: 'image',
      tags: 'profile_avatar,user_$userId',
      missingFileMessage: 'Выбранная фотография не найдена на телефоне.',
      missingUrlMessage: 'Cloudinary не вернул ссылку на фотографию.',
    );
  }

  static Future<String> uploadChatImage({
    required File imageFile,
    required String userId,
  }) {
    return _uploadFile(
      file: imageFile,
      resourceType: 'image',
      tags: 'chat_image,user_$userId',
      missingFileMessage: 'Выбранная фотография не найдена на телефоне.',
      missingUrlMessage: 'Cloudinary не вернул ссылку на фотографию.',
    );
  }

  /// Загрузка фотографии чата из байтов.
  ///
  /// Этот вариант нужен Flutter Web, потому что браузер не предоставляет
  /// приложению обычный путь к локальному файлу.
  static Future<String> uploadChatImageBytes({
    required Uint8List imageBytes,
    required String fileName,
    required String userId,
  }) {
    return _uploadBytes(
      bytes: imageBytes,
      fileName: fileName,
      resourceType: 'image',
      tags: 'chat_image,user_$userId',
      emptyFileMessage: 'Выбранная фотография пустая.',
      missingUrlMessage: 'Cloudinary не вернул ссылку на фотографию.',
    );
  }

  static Future<String> uploadChatVoice({
    required File audioFile,
    required String userId,
  }) {
    return _uploadFile(
      file: audioFile,
      resourceType: 'video',
      tags: 'chat_voice,user_$userId',
      missingFileMessage: 'Записанный голосовой файл не найден.',
      missingUrlMessage: 'Cloudinary не вернул ссылку на голосовое сообщение.',
    );
  }

  static Future<String> _uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String resourceType,
    required String tags,
    required String emptyFileMessage,
    required String missingUrlMessage,
  }) async {
    if (bytes.isEmpty) {
      throw CloudinaryUploadException(emptyFileMessage);
    }

    final safeFileName = fileName.trim().isEmpty
        ? 'upload_${DateTime.now().millisecondsSinceEpoch}'
        : fileName.trim();

    final request = http.MultipartRequest('POST', _uploadUri(resourceType))
      ..fields['upload_preset'] = uploadPreset
      ..fields['tags'] = tags
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: safeFileName,
        ),
      );

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 90),
        );

    final response = await http.Response.fromStream(streamedResponse);

    Map<String, dynamic> json = <String, dynamic>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      }
    } catch (_) {
      // Ниже покажем понятную ошибку по HTTP-коду.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : null;

      throw CloudinaryUploadException(
        message ?? 'Cloudinary вернул ошибку ${response.statusCode}.',
      );
    }

    final secureUrl = json['secure_url']?.toString();

    if (secureUrl == null || secureUrl.isEmpty) {
      throw CloudinaryUploadException(missingUrlMessage);
    }

    return secureUrl;
  }

  static Future<String> _uploadFile({
    required File file,
    required String resourceType,
    required String tags,
    required String missingFileMessage,
    required String missingUrlMessage,
  }) async {
    if (!await file.exists()) {
      throw CloudinaryUploadException(missingFileMessage);
    }

    final request = http.MultipartRequest('POST', _uploadUri(resourceType))
      ..fields['upload_preset'] = uploadPreset
      ..fields['tags'] = tags
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 90),
        );

    final response = await http.Response.fromStream(streamedResponse);

    Map<String, dynamic> json = <String, dynamic>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      }
    } catch (_) {
      // Ниже покажем понятную ошибку по HTTP-коду.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : null;

      throw CloudinaryUploadException(
        message ?? 'Cloudinary вернул ошибку ${response.statusCode}.',
      );
    }

    final secureUrl = json['secure_url']?.toString();

    if (secureUrl == null || secureUrl.isEmpty) {
      throw CloudinaryUploadException(missingUrlMessage);
    }

    return secureUrl;
  }
}
