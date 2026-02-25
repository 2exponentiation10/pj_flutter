import 'dart:typed_data';

import 'web_mic_recorder_types.dart';

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
  Future<void> start({OnWebMicLiveStats? onStats}) async {
    throw UnsupportedError(
        'Web microphone recording is only available on web.');
  }

  Future<WebMicRecordResult?> stop() async => null;

  Future<void> dispose() async {}
}

WebMicRecorder createWebMicRecorder() => WebMicRecorder();
