import 'dart:typed_data';

class CapturedAudio {
  final Uint8List bytes;
  final String mimeType;
  final String fileName;

  const CapturedAudio({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });
}

Future<CapturedAudio?> captureAudioFromBrowser({
  bool preferMicrophone = false,
}) async {
  return null;
}
