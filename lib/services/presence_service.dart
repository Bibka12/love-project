import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class UserPresence {
  const UserPresence({required this.isOnline, required this.lastSeen});

  final bool isOnline;
  final DateTime? lastSeen;

  factory UserPresence.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final rawLastSeen = data['lastSeen'];

    return UserPresence(
      isOnline: data['isOnline'] == true,
      lastSeen: rawLastSeen is Timestamp ? rawLastSeen.toDate() : null,
    );
  }
}

class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _heartbeatTimer;
  StreamSubscription<User?>? _authSubscription;

  String? _activeUid;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    _authSubscription = _auth.authStateChanges().listen((user) async {
      final previousUid = _activeUid;

      if (previousUid != null && previousUid != user?.uid) {
        await _setOffline(previousUid);
      }

      _activeUid = user?.uid;

      if (user == null) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
        return;
      }

      await _setOnline(user.uid);
      _startHeartbeat(user.uid);
    });

    final currentUser = _auth.currentUser;

    if (currentUser != null) {
      _activeUid = currentUser.uid;
      await _setOnline(currentUser.uid);
      _startHeartbeat(currentUser.uid);
    }
  }

  Stream<UserPresence> watchPresence(String uid) {
    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      return Stream<UserPresence>.value(
        const UserPresence(isOnline: false, lastSeen: null),
      );
    }

    return _firestore
        .collection('users')
        .doc(cleanUid)
        .snapshots()
        .map(UserPresence.fromDocument);
  }

  bool isActuallyOnline(UserPresence presence) {
    if (!presence.isOnline) {
      return false;
    }

    final lastSeen = presence.lastSeen;

    if (lastSeen == null) {
      return false;
    }

    final difference = DateTime.now().difference(lastSeen.toLocal());

    return difference.inMinutes < 2;
  }

  String presenceText(UserPresence presence) {
    if (isActuallyOnline(presence)) {
      return 'онлайн';
    }

    return formatLastSeen(presence.lastSeen);
  }

  String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) {
      return 'был(а) недавно';
    }

    final localDate = lastSeen.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inSeconds < 60) {
      return 'был(а) только что';
    }

    if (difference.inMinutes < 60) {
      return 'был(а) ${difference.inMinutes} мин. назад';
    }

    if (difference.inHours < 24 && now.day == localDate.day) {
      return 'был(а) сегодня в ${_formatTime(localDate)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));

    final wasYesterday =
        yesterday.year == localDate.year &&
        yesterday.month == localDate.month &&
        yesterday.day == localDate.day;

    if (wasYesterday) {
      return 'был(а) вчера в ${_formatTime(localDate)}';
    }

    return 'был(а) ${_formatDate(localDate)} в ${_formatTime(localDate)}';
  }

  Future<void> setCurrentUserOnline() async {
    final user = _auth.currentUser;

    if (user == null) return;

    _activeUid = user.uid;

    await _setOnline(user.uid);
    _startHeartbeat(user.uid);
  }

  Future<void> setCurrentUserOffline() async {
    final uid = _activeUid ?? _auth.currentUser?.uid;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (uid == null) return;

    await _setOffline(uid);
  }

  void _startHeartbeat(String uid) {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_auth.currentUser?.uid != uid) {
        return;
      }

      await _setOnline(uid);
    });
  }

  Future<void> _setOnline(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set(<String, dynamic>{
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Ошибка обновления online: $error');
    }
  }

  Future<void> _setOffline(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set(<String, dynamic>{
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Ошибка обновления offline: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setCurrentUserOnline();
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        setCurrentUserOffline();
        break;
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');

    return '$day.$month.${dateTime.year}';
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _authSubscription?.cancel();
    _authSubscription = null;

    final uid = _activeUid;

    if (uid != null) {
      await _setOffline(uid);
    }

    _activeUid = null;
    _initialized = false;
  }
}
