import 'dart:typed_data';

class WebMicRecordResult {
  final Uint8List bytes;
  final String mimeType;
  final String fileName;

  const WebMicRecordResult({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });
}

class WebMicRecorder {
  Future<void> start() async {
    throw UnsupportedError(
        'Web microphone recording is only available on web.');
  }

  Future<WebMicRecordResult?> stop() async => null;

  Future<void> dispose() async {}
}

WebMicRecorder createWebMicRecorder() => WebMicRecorder();
