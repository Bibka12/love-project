import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationSender {
  NotificationSender._();

  static const String _workerUrl =
      'https://love-notifications.genshinxiaofans.workers.dev';

  static Future<void> sendMessageNotification({
    required String chatId,
    required String messageId,
  }) {
    return _send(<String, String>{
      'kind': 'message',
      'chatId': chatId,
      'messageId': messageId,
    });
  }

  static Future<void> sendCallNotification({
    required String callId,
  }) {
    return _send(<String, String>{
      'kind': 'call',
      'callId': callId,
    });
  }

  static Future<void> _send(Map<String, String> payload) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return;

      final response = await http
          .post(
            Uri.parse('$_workerUrl/notify'),
            headers: <String, String>{
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Notification Worker error ${response.statusCode}: '
          '${response.body}',
        );
      }
    } catch (error) {
      // Уведомление не должно ломать отправку сообщения или звонок.
      debugPrint('Notification Worker request failed: $error');
    }
  }
}
