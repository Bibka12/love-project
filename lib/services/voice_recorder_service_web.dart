import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import 'recorded_voice.dart';

class VoiceRecorderService {
  VoiceRecorderService();

  final AudioRecorder _recorder = AudioRecorder();

  AudioEncoder _activeEncoder = AudioEncoder.opus;
  bool _recording = false;

  Future<void> start() async {
    final hasPermission = await _recorder.hasPermission();

    if (!hasPermission) {
      throw StateError(
        'Разреши браузеру доступ к микрофону и попробуй ещё раз.',
      );
    }

    _activeEncoder = await _selectSupportedEncoder();

    await _recorder.start(
      RecordConfig(
        encoder: _activeEncoder,
        bitRate: 96000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      // Для Web пакет record создаёт Blob сам.
      path: '',
    );

    _recording = true;
  }

  Future<AudioEncoder> _selectSupportedEncoder() async {
    final preferredEncoders = <AudioEncoder>[
      AudioEncoder.opus,
      AudioEncoder.aacLc,
    ];

    for (final encoder in preferredEncoders) {
      if (await _recorder.isEncoderSupported(encoder)) {
        return encoder;
      }
    }

    throw StateError(
      'Этот браузер не поддерживает запись голосовых сообщений.',
    );
  }

  Future<RecordedVoice?> stop() async {
    if (!_recording) {
      return null;
    }

    final blobUrl = await _recorder.stop();
    _recording = false;

    if (blobUrl == null || blobUrl.trim().isEmpty) {
      return null;
    }

    final response = await http.get(Uri.parse(blobUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Браузер не смог подготовить голосовое сообщение '
        '(ошибка ${response.statusCode}).',
      );
    }

    final bytes = response.bodyBytes;

    if (bytes.isEmpty) {
      return null;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension =
        _activeEncoder == AudioEncoder.aacLc ? 'm4a' : 'webm';

    return RecordedVoice(
      bytes: bytes,
      fileName: 'voice_$timestamp.$extension',
    );
  }

  Future<void> cancel() async {
    if (_recording) {
      await _recorder.cancel();
      _recording = false;
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
