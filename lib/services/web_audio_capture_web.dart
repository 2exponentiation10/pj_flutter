import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'web_audio_capture_stub.dart';

Future<CapturedAudio?> captureAudioFromBrowser() async {
  final input = html.FileUploadInputElement();
  input.accept = 'audio/*';
  input.setAttribute('capture', 'microphone');

  final completer = Completer<CapturedAudio?>();

  input.onChange.listen((_) async {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    if (result == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final bytes = Uint8List.view((result as ByteBuffer));
    final mime = (file.type.isNotEmpty ? file.type : 'audio/m4a').toLowerCase();
    final name = file.name.isNotEmpty ? file.name : 'captured_audio.m4a';
    if (!completer.isCompleted) {
      completer.complete(
        CapturedAudio(bytes: bytes, mimeType: mime, fileName: name),
      );
    }
  });

  input.click();

  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () => null,
  );
}
