import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.url,
    required this.durationSeconds,
    required this.mine,
  });

  final String url;
  final int durationSeconds;
  final bool mine;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;
  bool _playRequested = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSeconds);

    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() => _duration = duration);
      }
    });

    _stateSubscription = _player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
        await _player.pause();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_loading) {
      setState(() {
        _playRequested = !_playRequested;
      });
      if (!_playRequested) {
        await _player.pause();
      }
      return;
    }

    try {
      final shouldPlay = !_player.playing;
      setState(() {
        _loading = true;
        _playRequested = shouldPlay;
        _error = null;
      });

      if (shouldPlay && _player.audioSource == null) {
        await _player.setUrl(widget.url);
      }

      if (!shouldPlay) {
        await _player.pause();
      } else if (_playRequested) {
        await _player.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _playRequested = false;
          _error = 'Ошибка аудио';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _playRequested = _player.playing;
        });
      }
    }
  }

  String _format(Duration value) {
    final seconds = value.inSeconds.clamp(0, 3599);
    final minutesPart = seconds ~/ 60;
    final secondsPart = seconds % 60;
    return '$minutesPart:${secondsPart.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : widget.durationSeconds * 1000;
    final progress = totalMs <= 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final playing = _player.playing || _playRequested;

    return SizedBox(
      width: 232,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          InkResponse(
            onTap: _togglePlayback,
            radius: 24,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LayoutBuilder(
                  builder: (context, constraints) {
                    const barCount = 32;
                    final playedBars = (barCount * progress).round();

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) async {
                        if (totalMs <= 0 || constraints.maxWidth <= 0) return;
                        if (_player.audioSource == null) {
                          await _player.setUrl(widget.url);
                        }
                        final fraction =
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0.0, 1.0);
                        await _player.seek(
                          Duration(
                            milliseconds: (totalMs * fraction).round(),
                          ),
                        );
                      },
                      child: SizedBox(
                        height: 25,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List<Widget>.generate(barCount, (index) {
                            const heights = <double>[
                              7, 12, 18, 10, 15, 22, 13, 9,
                              17, 24, 14, 8, 19, 12, 21, 10,
                            ];
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  height: heights[index % heights.length],
                                  decoration: BoxDecoration(
                                    color: index < playedBars
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.38),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 1),
                Row(
                  children: <Widget>[
                    Text(
                      _error ?? _format(_position),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _error == null
                            ? Colors.white70
                            : Colors.red.shade100,
                        fontSize: 10,
                      ),
                    ),
                    if (_error == null) ...<Widget>[
                      Text(
                        ' / ${_format(_duration)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      if (_loading)
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
