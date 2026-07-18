import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'music_audio_handler.dart';
import 'screens/loading_screen.dart';

late final MusicAudioHandler musicAudioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      debugShowCheckedModeBanner: false,
      title: 'For Nursaule',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff05070D),
      ),
      home: const LoadingScreen(),
    );
  }
}
