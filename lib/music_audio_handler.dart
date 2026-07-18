import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AppSong {
  const AppSong({
    required this.title,
    required this.artist,
    required this.audioPath,
    required this.coverPath,
  });

  final String title;
  final String artist;
  final String audioPath;
  final String coverPath;
}

class MusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  MusicAudioHandler() {
    ready = _initialize();
  }

  final AudioPlayer player = AudioPlayer();
  late final Future<void> ready;

  final List<AppSong> songs = const [
    AppSong(
      title: 'Сүйгенім',
      artist: 'Айкын Толепберген',
      audioPath: 'assets/music/song1.mp3',
      coverPath: 'assets/covers/song1.jpeg',
    ),
    AppSong(
      title: 'Біз жолығамыз',
      artist: 'Abzal Uteshov',
      audioPath: 'assets/music/song2.mp3',
      coverPath: 'assets/covers/song2.jpeg',
    ),
    AppSong(
      title: 'Korkemim',
      artist: 'Kazybek Kuraiysh',
      audioPath: 'assets/music/song3.mp3',
      coverPath: 'assets/covers/song3.jpeg',
    ),
    AppSong(
      title: 'Sagynysh',
      artist: 'Sadraddin, Bakr',
      audioPath: 'assets/music/song4.mp3',
      coverPath: 'assets/covers/song4.jpeg',
    ),
    AppSong(
      title: 'KETPE',
      artist: 'Dasdinlovee',
      audioPath: 'assets/music/song5.mp3',
      coverPath: 'assets/covers/song5.jpeg',
    ),
  ];

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<int?>? _indexSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _shuffleSubscription;
  StreamSubscription<LoopMode>? _loopSubscription;

  Future<void> _initialize() async {
    final mediaItems = <MediaItem>[];

    for (int index = 0; index < songs.length; index++) {
      final song = songs[index];

      // На Android/iOS копируем обложку в настоящий файл.
      // В Web dart:io/path_provider недоступны, поэтому берём asset по URL.
      final Uri coverUri;
      if (kIsWeb) {
        coverUri = Uri.base.resolve(song.coverPath);
      } else {
        final coverFile = await _copyCoverToLocalFile(song.coverPath, index);
        coverUri = coverFile.uri;
      }

      mediaItems.add(
        MediaItem(
          id: 'nb_song_${index + 1}',
          album: 'Для Нурсауле ❤️',
          title: song.title,
          artist: song.artist,
          artUri: coverUri,
        ),
      );
    }

    queue.add(mediaItems);

    final sources = songs.asMap().entries.map((entry) {
      return AudioSource.asset(
        entry.value.audioPath,
        tag: mediaItems[entry.key],
      );
    }).toList();

    await player.setAudioSources(
      sources,
      initialIndex: 0,
      initialPosition: Duration.zero,
      preload: true,
    );

    await player.setLoopMode(LoopMode.off);

    mediaItem.add(mediaItems.first);

    _playerStateSubscription = player.playerStateStream.listen((_) {
      _broadcastState();
    });

    _positionSubscription = player.positionStream.listen((_) {
      _broadcastState();
    });

    _indexSubscription = player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= queue.value.length) return;
      mediaItem.add(queue.value[index]);
      _broadcastState();
    });

    _durationSubscription = player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current == null || duration == null) return;

      final updated = current.copyWith(duration: duration);
      mediaItem.add(updated);

      final updatedQueue = [...queue.value];
      final index = player.currentIndex ?? 0;
      if (index >= 0 && index < updatedQueue.length) {
        updatedQueue[index] = updated;
        queue.add(updatedQueue);
      }

      _broadcastState();
    });

    _shuffleSubscription = player.shuffleModeEnabledStream.listen((_) {
      _broadcastState();
    });

    _loopSubscription = player.loopModeStream.listen((_) {
      _broadcastState();
    });

    _broadcastState();
  }

  Future<File> _copyCoverToLocalFile(String assetPath, int index) async {
    final directory = await getApplicationSupportDirectory();
    final coversDirectory = Directory('${directory.path}/notification_covers');

    if (!await coversDirectory.exists()) {
      await coversDirectory.create(recursive: true);
    }

    final extension = assetPath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final file = File('${coversDirectory.path}/song_${index + 1}.$extension');

    // Перезаписываем файл, чтобы новая обложка появилась после обновления.
    final data = await rootBundle.load(assetPath);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );

    return file;
  }

  void _broadcastState() {
    final playing = player.playing;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        // Здесь специально нет MediaAction.stop —
        // поэтому квадратная кнопка в уведомлении исчезает.
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(player.processingState),
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: player.currentIndex,
        shuffleMode: player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _mapRepeatMode(player.loopMode),
      ),
    );
  }

  AudioProcessingState _mapProcessingState(
    ProcessingState processingState,
  ) {
    switch (processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  AudioServiceRepeatMode _mapRepeatMode(LoopMode loopMode) {
    switch (loopMode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  @override
  Future<void> play() async {
    await ready;

    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero, index: player.currentIndex ?? 0);
    }

    await player.play();
  }

  @override
  Future<void> pause() async {
    await ready;
    await player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await ready;
    await player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await ready;

    if (player.hasNext) {
      await player.seekToNext();
      await player.play();
      return;
    }

    if (player.loopMode == LoopMode.all) {
      await player.seek(Duration.zero, index: 0);
      await player.play();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    await ready;

    if (player.position > const Duration(seconds: 4)) {
      await player.seek(Duration.zero);
      return;
    }

    if (player.hasPrevious) {
      await player.seekToPrevious();
      await player.play();
    } else {
      await player.seek(Duration.zero);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await ready;

    final enabled = shuffleMode != AudioServiceShuffleMode.none;

    if (enabled) {
      await player.shuffle();
    }

    await player.setShuffleModeEnabled(enabled);
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await ready;

    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await player.setLoopMode(LoopMode.all);
        break;
    }

    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  Future<void> disposeHandler() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _indexSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _shuffleSubscription?.cancel();
    await _loopSubscription?.cancel();
    await player.dispose();
  }
}
