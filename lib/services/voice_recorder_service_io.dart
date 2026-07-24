import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'recorded_voice.dart';

class VoiceRecorderService {
  VoiceRecorderService();

  final AudioRecorder _recorder = AudioRecorder();
  String? _activePath;

  Future<void> start() async {
    final hasPermission = await _recorder.hasPermission();

    if (!hasPermission) {
      throw StateError('Разреши приложению доступ к микрофону.');
    }

    final directory = await getTemporaryDirectory();
    final fileName =
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = '${directory.path}/$fileName';

    _activePath = path;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 96000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );
  }

  Future<RecordedVoice?> stop() async {
    final resultPath = await _recorder.stop();
    final path = resultPath ?? _activePath;
    _activePath = null;

    if (path == null || path.trim().isEmpty) {
      return null;
    }

    final file = File(path);

    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.isEmpty
        ? 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a'
        : file.uri.pathSegments.last;

    try {
      await file.delete();
    } catch (_) {
      // Временный файл можно удалить позже системой.
    }

    if (bytes.isEmpty) {
      return null;
    }

    return RecordedVoice(
      bytes: bytes,
      fileName: fileName,
    );
  }

  Future<void> cancel() async {
    await _recorder.cancel();

    final path = _activePath;
    _activePath = null;

    if (path == null || path.isEmpty) {
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Игнорируем ошибку очистки временного файла.
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
