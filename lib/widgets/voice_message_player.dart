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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSeconds);

    _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _player.durationStream.listen((duration) {
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
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      if (_player.audioSource == null) {
        await _player.setUrl(widget.url);
      }

      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось открыть аудио');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
    final playing = _player.playing;

    return SizedBox(
      width: 230,
      child: Row(
        children: <Widget>[
          Material(
            color: widget.mine
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xff343743),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _togglePlayback,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
                  onTapDown: (details) async {
                    if (_player.audioSource == null) {
                      await _player.setUrl(widget.url);
                    }
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null || totalMs <= 0) return;
                    final width = box.size.width;
                    final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
                    await _player.seek(
                      Duration(milliseconds: (totalMs * fraction).round()),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.20),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _error ?? '${_format(_position)} / ${_format(_duration)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _error == null ? Colors.white70 : Colors.red.shade100,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
