import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _webVapidKey =
      'BNvcQtb0tGz-ITPmUy4bikymDGG7a_kYouuQoqYEmF7LY8Ae61wYeNmAcnQdXgQpaBW2xebDQrXHiTFb_92Eon0';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) async {
        if (user != null) {
          await _registerCurrentToken(user.uid);
        }
      },
    );

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _saveToken(uid: uid, token: token);
      }
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundMessage,
    );
  }

  Future<void> _registerCurrentToken(String uid) async {
    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );
      if (token == null || token.trim().isEmpty) return;
      await _saveToken(uid: uid, token: token);
    } catch (error) {
      debugPrint('FCM token registration failed: $error');
    }
  }

  Future<void> _saveToken({
    required String uid,
    required String token,
  }) {
    return _firestore.collection('users').doc(uid).set(
      <String, dynamic>{
        'fcmTokens': FieldValue.arrayUnion(<String>[token]),
        'notificationsUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  void _showForegroundMessage(RemoteMessage message) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final notification = message.notification;
    final title = notification?.title ?? 'N❤️B';
    final body = notification?.body ?? _fallbackBody(message.data);
    if (body.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF20232E),
          content: Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFF3B86),
                child: Icon(
                  Icons.notifications_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  String _fallbackBody(Map<String, dynamic> data) {
    return (data['body'] ?? data['message'] ?? '').toString();
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _initialized = false;
  }
}
