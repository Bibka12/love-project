import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
    final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

  Future<File?> stop() async {
    final resultPath = await _recorder.stop();
    final path = resultPath ?? _activePath;
    _activePath = null;

    if (path == null || path.trim().isEmpty) {
      return null;
    }

    final file = File(path);
    return await file.exists() ? file : null;
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _activePath = null;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
