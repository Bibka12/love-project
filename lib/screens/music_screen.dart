import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../main.dart';
import '../music_audio_handler.dart';

typedef SongInfo = AppSong;

class MusicPlayerController {
  MusicPlayerController._();

  static final MusicPlayerController instance = MusicPlayerController._();

  AudioPlayer get player => musicAudioHandler.player;
  List<SongInfo> get songs => musicAudioHandler.songs;

  bool _initialized = false;
  bool _handlingCompletion = false;
  Timer? _endCheckTimer;

  Future<void> initialize() async {
    if (_initialized) return;

    await musicAudioHandler.ready;
    _startEndWatcher();
    _initialized = true;
  }

  void _startEndWatcher() {
    _endCheckTimer ??= Timer.periodic(
      const Duration(milliseconds: 250),
      (_) async {
        if (_handlingCompletion || !player.playing) return;
        if (player.loopMode != LoopMode.off) return;

        final duration = player.duration;
        if (duration == null || duration == Duration.zero) return;

        final remaining = duration - player.position;

        // Этот контроль работает даже после ручной перемотки почти в конец.
        if (remaining > const Duration(milliseconds: 450)) return;

        if (!player.hasNext) return;

        _handlingCompletion = true;

        try {
          await musicAudioHandler.skipToNext();
          await musicAudioHandler.play();

          // Даём плееру переключить индекс и обновить длительность.
          await Future<void>.delayed(const Duration(milliseconds: 500));
        } catch (_) {
          // При кратковременном состоянии загрузки следующая проверка
          // снова попробует переключить песню.
        } finally {
          _handlingCompletion = false;
        }
      },
    );
  }

  Future<void> playSong(int index) async {
    await initialize();
    await player.seek(Duration.zero, index: index);
    await musicAudioHandler.play();
  }

  Future<void> togglePlayPause() async {
    await initialize();

    if (player.playing) {
      await musicAudioHandler.pause();
      return;
    }

    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero, index: player.currentIndex ?? 0);
    }

    await musicAudioHandler.play();
  }

  Future<void> next() async {
    await initialize();

    if (player.hasNext) {
      await musicAudioHandler.skipToNext();
      await musicAudioHandler.play();
      return;
    }

    // Если включён повтор всего плейлиста, после последней песни
    // кнопка «Далее» возвращает на первую.
    if (player.loopMode == LoopMode.all) {
      await player.seek(Duration.zero, index: 0);
      await musicAudioHandler.play();
    }
  }

  Future<void> previous() async {
    await initialize();

    if (player.position > const Duration(seconds: 4)) {
      await player.seek(Duration.zero);
      return;
    }

    if (player.hasPrevious) {
      await musicAudioHandler.skipToPrevious();
      await musicAudioHandler.play();
    } else {
      await player.seek(Duration.zero);
    }
  }

  Future<void> toggleShuffle() async {
    await initialize();

    final enableShuffle = !player.shuffleModeEnabled;

    if (enableShuffle) {
      await player.shuffle();
    }

    await musicAudioHandler.setShuffleMode(
      enableShuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  Future<void> changeLoopMode() async {
    await initialize();
    switch (player.loopMode) {
      case LoopMode.off:
        await musicAudioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        return;
      case LoopMode.one:
        await musicAudioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        return;
      case LoopMode.all:
        await musicAudioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        return;
    }
  }
}

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final MusicPlayerController controller = MusicPlayerController.instance;
  late final AnimationController rotationController;

  StreamSubscription<PlayerState>? playerStateSubscription;
  Object? loadingError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );

    playerStateSubscription = controller.player.playerStateStream.listen((
      state,
    ) {
      if (!mounted) return;

      if (state.playing && state.processingState != ProcessingState.completed) {
        rotationController.repeat();
      } else {
        rotationController.stop();
      }
    });

    controller.initialize().catchError((Object error) {
      if (!mounted) return;
      setState(() => loadingError = error);
    });
  }

  @override
  void dispose() {
    playerStateSubscription?.cancel();
    rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff05070D), Color(0xff17101F), Color(0xff301934)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: FloatingHearts())),
          SafeArea(
            bottom: false,
            child: loadingError == null
                ? _buildPlayerContent()
                : _buildErrorState(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'Не удалось загрузить песни',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Проверь названия файлов: song1.mp3–song5.mp3 и song1.jpeg–song5.jpeg.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    return StreamBuilder<int?>(
      stream: controller.player.currentIndexStream,
      initialData: controller.player.currentIndex ?? 0,
      builder: (context, indexSnapshot) {
        final int currentIndex = (indexSnapshot.data ?? 0).clamp(
          0,
          controller.songs.length - 1,
        );
        final song = controller.songs[currentIndex];

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                child: Column(
                  children: [
                    Text(
                      'Музыка для Нурсауле ❤️',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Песни, которые напоминают мне о тебе',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildRotatingCover(song),
                    const SizedBox(height: 23),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Column(
                        key: ValueKey(song.audioPath),
                        children: [
                          Text(
                            song.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            song.artist,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildProgressBar(),
                    const SizedBox(height: 10),
                    _buildMainControls(),
                    const SizedBox(height: 8),
                    _buildExtraControls(),
                    const SizedBox(height: 25),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Наш плейлист',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: controller.songs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildSongTile(
                    controller.songs[index],
                    index,
                    index == currentIndex,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRotatingCover(SongInfo song) {
    return Container(
      width: 236,
      height: 236,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffFF2E78).withValues(alpha: 0.32),
            blurRadius: 32,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xff9D2EFF).withValues(alpha: 0.20),
            blurRadius: 55,
            spreadRadius: 2,
          ),
        ],
      ),
      child: RotationTransition(
        turns: rotationController,
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(song.coverPath, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.08)),
              Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff090A11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: controller.player.positionStream,
      initialData: Duration.zero,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: controller.player.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final position = positionSnapshot.data ?? Duration.zero;
            final maxMilliseconds = math.max(duration.inMilliseconds, 1);
            final currentMilliseconds = position.inMilliseconds.clamp(
              0,
              maxMilliseconds,
            );

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: const Color(0xffFF2E78),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: const Color(
                      0xffFF2E78,
                    ).withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMilliseconds.toDouble(),
                    value: currentMilliseconds.toDouble(),
                    onChanged: (value) {
                      controller.player.seek(
                        Duration(milliseconds: value.round()),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _durationText(position),
                      _durationText(duration),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _durationText(Duration duration) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final minutes = duration.inMinutes;
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return Text(
      '$minutes:$seconds',
      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
    );
  }

  Widget _buildMainControls() {
    return StreamBuilder<PlayerState>(
      stream: controller.player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.playing ?? false;
        final processingState = state?.processingState;
        final isLoading =
            processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _roundControlButton(
              icon: Icons.skip_previous_rounded,
              size: 30,
              onTap: controller.previous,
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: isLoading ? null : controller.togglePlayPause,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xffFF2E78), Color(0xff9D2EFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffFF2E78).withValues(alpha: 0.42),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
              ),
            ),
            const SizedBox(width: 24),
            _roundControlButton(
              icon: Icons.skip_next_rounded,
              size: 30,
              onTap: controller.next,
            ),
          ],
        );
      },
    );
  }

  Widget _roundControlButton({
    required IconData icon,
    required double size,
    required Future<void> Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  Widget _buildExtraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<bool>(
          stream: controller.player.shuffleModeEnabledStream,
          initialData: controller.player.shuffleModeEnabled,
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? false;
            return IconButton(
              onPressed: controller.toggleShuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                color: enabled ? const Color(0xffFF5C9D) : Colors.white38,
              ),
            );
          },
        ),
        const SizedBox(width: 58),
        StreamBuilder<LoopMode>(
          stream: controller.player.loopModeStream,
          initialData: controller.player.loopMode,
          builder: (context, snapshot) {
            final mode = snapshot.data ?? LoopMode.off;
            return IconButton(
              onPressed: controller.changeLoopMode,
              icon: Icon(
                mode == LoopMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: mode == LoopMode.off
                    ? Colors.white38
                    : const Color(0xffFF5C9D),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSongTile(SongInfo song, int index, bool selected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => controller.playSong(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xffFF2E78).withValues(alpha: 0.13)
              : Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xffFF2E78).withValues(alpha: 0.38)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.asset(
                song.coverPath,
                width: 57,
                height: 57,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (selected)
              StreamBuilder<PlayerState>(
                stream: controller.player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return Icon(
                    playing
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    color: const Color(0xffFF5C9D),
                  );
                },
              )
            else
              Text(
                '${index + 1}',
                style: GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

class FloatingHearts extends StatefulWidget {
  const FloatingHearts({super.key});

  @override
  State<FloatingHearts> createState() => _FloatingHeartsState();
}

class _FloatingHeartsState extends State<FloatingHearts>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, _) {
        return CustomPaint(painter: HeartsPainter(animationController.value));
      },
    );
  }
}

class HeartsPainter extends CustomPainter {
  HeartsPainter(this.progress);

  final double progress;

  static const List<Offset> heartPositions = [
    Offset(0.10, 0.92),
    Offset(0.28, 0.73),
    Offset(0.84, 0.86),
    Offset(0.73, 0.61),
    Offset(0.16, 0.54),
    Offset(0.91, 0.43),
    Offset(0.38, 0.34),
    Offset(0.65, 0.20),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < heartPositions.length; i++) {
      final base = heartPositions[i];
      final localProgress = (progress + i * 0.13) % 1.0;
      final y = (base.dy - localProgress * 0.22) % 1.0;
      final x = base.dx + math.sin((localProgress + i) * math.pi * 2) * 0.018;
      final opacity = math.sin(localProgress * math.pi).clamp(0.0, 1.0) * 0.18;
      final fontSize = 12.0 + (i % 3) * 4;

      final textPainter = TextPainter(
        text: TextSpan(
          text: i.isEven ? '♥' : '✦',
          style: TextStyle(
            color: Colors.white.withValues(alpha: opacity),
            fontSize: fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x * size.width, y * size.height));
    }
  }

  @override
  bool shouldRepaint(covariant HeartsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
