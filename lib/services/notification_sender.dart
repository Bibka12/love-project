import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationSender {
  NotificationSender._();

  static const String _workerUrl =
      'https://love-notifications.genshinxiaofans.workers.dev';

  static Future<bool> sendCallNotification({
    required String callId,
  }) {
    return _send(<String, String>{
      'kind': 'call',
      'callId': callId,
    });
  }

  static Future<bool> sendMessageNotification({
    required String chatId,
    required String messageId,
  }) {
    return _send(<String, String>{
      'kind': 'message',
      'chatId': chatId,
      'messageId': messageId,
    });
  }

  static Future<bool> _send(Map<String, String> payload) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Push was not sent: user is not authorized');
        return false;
      }

      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.trim().isEmpty) {
        debugPrint('Push was not sent: Firebase ID token is empty');
        return false;
      }

      final response = await http
          .post(
            Uri.parse(_workerUrl),
            headers: <String, String>{
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Push Worker error ${response.statusCode}: ${response.body}',
        );
        return false;
      }

      final decoded = jsonDecode(response.body);
      final result = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final sent = (result['sent'] as num?)?.toInt() ?? 0;
      final reason = result['reason']?.toString() ?? '';

      debugPrint(
        'Push Worker result: sent=$sent'
        '${reason.isEmpty ? '' : ', reason=$reason'}',
      );
      return sent > 0;
    } catch (error, stackTrace) {
      debugPrint('Push request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
