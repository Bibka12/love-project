import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileData {
  const UserProfileData({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.bio,
    required this.status,
    required this.friendsCount,
  });

  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String bio;
  final String status;
  final int friendsCount;

  factory UserProfileData.fromUserAndMap(
    User user,
    Map<String, dynamic>? data,
  ) {
    final savedName = data?['name']?.toString().trim() ?? '';

    final authName = user.displayName?.trim() ?? '';

    final savedPhoto = data?['photoUrl']?.toString().trim() ?? '';

    final authPhoto = user.photoURL?.trim() ?? '';

    return UserProfileData(
      uid: user.uid,
      name: savedName.isNotEmpty
          ? savedName
          : authName.isNotEmpty
          ? authName
          : 'Пользователь',
      email: data?['email']?.toString().trim() ?? user.email ?? '',
      photoUrl: savedPhoto.isNotEmpty ? savedPhoto : authPhoto,
      bio: data?['bio']?.toString().trim() ?? '',
      status: data?['status']?.toString().trim() ?? '',
      friendsCount: _readInt(data?['friendsCount']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UserProfileService {
  UserProfileService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> document(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  static Stream<UserProfileData> watch(User user) {
    return document(user.uid).snapshots().map((snapshot) {
      return UserProfileData.fromUserAndMap(user, snapshot.data());
    });
  }

  static Future<UserProfileData> load(User user) async {
    final snapshot = await document(
      user.uid,
    ).get().timeout(const Duration(seconds: 10));

    return UserProfileData.fromUserAndMap(user, snapshot.data());
  }

  static Future<void> ensureCreated(User user) async {
    final ref = document(user.uid);

    final snapshot = await ref.get().timeout(const Duration(seconds: 10));

    final authName = user.displayName?.trim() ?? '';

    if (!snapshot.exists) {
      final name = authName.isNotEmpty ? authName : 'Пользователь';

      await ref
          .set({
            'uid': user.uid,
            'name': name,
            'nameLowercase': name.toLowerCase(),
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'bio': '',
            'status': '',
            'friendsCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));

      return;
    }

    final existingData = snapshot.data() ?? {};

    final savedName = existingData['name']?.toString().trim() ?? '';

    final actualName = savedName.isNotEmpty
        ? savedName
        : authName.isNotEmpty
        ? authName
        : 'Пользователь';

    await ref
        .set({
          'uid': user.uid,
          'name': actualName,
          'nameLowercase': actualName.toLowerCase(),
          'email': user.email ?? '',
          'bio': existingData['bio'] ?? '',
          'status': existingData['status'] ?? '',
          'friendsCount': existingData['friendsCount'] ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 15));
  }

  static Future<void> updateProfile({
    required User user,
    required String name,
    required String bio,
    required String status,
    String? photoUrl,
  }) async {
    final cleanName = name.trim();
    final cleanBio = bio.trim();
    final cleanStatus = status.trim();

    final data = <String, dynamic>{
      'uid': user.uid,
      'name': cleanName,
      'nameLowercase': cleanName.toLowerCase(),
      'email': user.email ?? '',
      'bio': cleanBio,
      'status': cleanStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      data['photoUrl'] = photoUrl.trim();
    }

    await document(
      user.uid,
    ).set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
  }
}
