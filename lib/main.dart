import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'music_audio_handler.dart';
import 'screens/loading_screen.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'widgets/incoming_call_listener.dart';

late final MusicAudioHandler musicAudioHandler;
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Подключаем Firebase для текущей платформы: Android или Web.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // Запрашиваем разрешение на уведомления и сохраняем FCM-токен
  // текущего пользователя в Firestore.
  await NotificationService.instance.initialize(
    navigatorKey: appNavigatorKey,
  );

  // Запускаем отслеживание статуса:
  // онлайн / офлайн / последнее посещение.
  await PresenceService.instance.initialize();

  // Запускаем музыкальный сервис.
  musicAudioHandler = await AudioService.init(
    builder: MusicAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.nb.love_project.audio',
      androidNotificationChannelName: 'Музыка N❤️B',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationClickStartsActivity: true,
    ),
  );

  // Ждём загрузки плейлиста и подготовки обложек.
  await musicAudioHandler.ready;

  runApp(const LoveApp());
}

class LoveApp extends StatelessWidget {
  const LoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'For Nursaule',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05070D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D8D),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return IncomingCallListener(
          navigatorKey: appNavigatorKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const LoadingScreen(),
    );
  }
}
