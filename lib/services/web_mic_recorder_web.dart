import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:js/js.dart';

import 'web_mic_recorder_stub.dart';

class WebMicRecorder {
  Object? _mediaStream;
  Object? _mediaRecorder;
  final List<html.Blob> _chunks = [];
  String _mimeType = 'audio/webm';
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw Exception('mediaDevices is not available');
    }

    final stream = await mediaDevices
        .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
    _mediaStream = stream;

    final recorderCtor =
        js_util.getProperty<Object?>(html.window, 'MediaRecorder');
    if (recorderCtor == null) {
      await _stopStream();
      throw Exception('MediaRecorder is not supported');
    }

    final mime = _pickSupportedMimeType(recorderCtor);
    _mimeType = mime ?? 'audio/webm';
    final options = mime == null
        ? null
        : js_util.jsify(<String, dynamic>{'mimeType': mime});

    final recorder = options == null
        ? js_util.callConstructor<Object>(recorderCtor, [stream])
        : js_util.callConstructor<Object>(recorderCtor, [stream, options]);
    _mediaRecorder = recorder;

    _chunks.clear();
    final startedCompleter = Completer<void>();
    final errorCompleter = Completer<void>();

    js_util.callMethod<void>(recorder, 'addEventListener', [
      'dataavailable',
      allowInterop((dynamic event) {
        try {
          final data = js_util.getProperty<Object?>(event, 'data');
          if (data == null) return;
          final size = js_util.getProperty<num>(data, 'size');
          if (size <= 0) return;
          _chunks.add(data as html.Blob);
        } catch (_) {}
      }),
    ]);

    js_util.callMethod<void>(recorder, 'addEventListener', [
      'start',
      allowInterop((dynamic _) {
        if (!startedCompleter.isCompleted) startedCompleter.complete();
      }),
    ]);

    js_util.callMethod<void>(recorder, 'addEventListener', [
      'error',
      allowInterop((dynamic event) {
        final err = js_util.getProperty<Object?>(event, 'error');
        final msg = err == null ? 'Recorder error' : err.toString();
        if (!errorCompleter.isCompleted) {
          errorCompleter.completeError(Exception(msg));
        }
      }),
    ]);

    js_util.callMethod<void>(recorder, 'start', [250]);
    await Future.any([
      startedCompleter.future,
      errorCompleter.future,
    ]).timeout(const Duration(seconds: 5));
    _started = true;
  }

  Future<WebMicRecordResult?> stop() async {
    if (!_started || _mediaRecorder == null) {
      await _stopStream();
      return null;
    }

    final recorder = _mediaRecorder!;
    final stopCompleter = Completer<void>();
    js_util.callMethod<void>(recorder, 'addEventListener', [
      'stop',
      allowInterop((dynamic _) {
        if (!stopCompleter.isCompleted) stopCompleter.complete();
      }),
    ]);

    js_util.callMethod<void>(recorder, 'stop', []);
    await stopCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );

    await _stopStream();

    _started = false;
    _mediaRecorder = null;

    if (_chunks.isEmpty) return null;

    final mimeType =
        _mimeType.isNotEmpty ? _mimeType.toLowerCase() : 'audio/webm';
    final blob = html.Blob(_chunks, mimeType);
    final bytes = await _blobToBytes(blob);
    _chunks.clear();
    if (bytes.isEmpty) return null;

    return WebMicRecordResult(
      bytes: bytes,
      mimeType: mimeType,
      fileName: _buildFileName(mimeType),
    );
  }

  Future<void> dispose() async {
    try {
      if (_started) {
        await stop();
      } else {
        await _stopStream();
      }
    } catch (_) {
      await _stopStream();
    } finally {
      _mediaRecorder = null;
      _chunks.clear();
      _started = false;
    }
  }

  Future<void> _stopStream() async {
    final stream = _mediaStream;
    _mediaStream = null;
    if (stream == null) return;
    try {
      final tracks = js_util.callMethod<List<dynamic>>(stream, 'getTracks', []);
      for (final track in tracks) {
        js_util.callMethod<void>(track, 'stop', []);
      }
    } catch (_) {}
  }
}

Future<Uint8List> _blobToBytes(html.Blob blob) async {
  final reader = html.FileReader();
  final completer = Completer<Uint8List>();
  reader.onLoad.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
    } else {
      completer.complete(Uint8List(0));
    }
  });
  reader.onError.listen((_) {
    completer.completeError(Exception('Failed to read recorded blob'));
  });
  reader.readAsArrayBuffer(blob);
  return completer.future;
}

String _buildFileName(String mimeType) {
  if (mimeType.contains('mp4') || mimeType.contains('m4a'))
    return 'mic_input.m4a';
  if (mimeType.contains('ogg')) return 'mic_input.ogg';
  if (mimeType.contains('wav')) return 'mic_input.wav';
  return 'mic_input.webm';
}

String? _pickSupportedMimeType(Object mediaRecorderCtor) {
  final cands = [
    'audio/mp4;codecs=mp4a.40.2',
    'audio/mp4',
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/ogg;codecs=opus',
    'audio/ogg',
  ];
  for (final candidate in cands) {
    try {
      final ok = js_util.callMethod<bool>(
        mediaRecorderCtor,
        'isTypeSupported',
        [candidate],
      );
      if (ok) return candidate;
    } catch (_) {}
  }
  return null;
}

WebMicRecorder createWebMicRecorder() => WebMicRecorder();
