import 'dart:typed_data';

class RecordedVoice {
  const RecordedVoice({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}
