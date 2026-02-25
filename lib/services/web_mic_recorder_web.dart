import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:js/js.dart';

import 'web_mic_recorder_stub.dart';
import 'web_mic_recorder_types.dart';

class WebMicRecorder {
  Object? _mediaStream;
  Object? _mediaRecorder;
  Object? _audioContext;
  Object? _analyserNode;
  Timer? _statsTimer;
  OnWebMicLiveStats? _onStats;
  int _sampleRate = 48000;
  final List<html.Blob> _chunks = [];
  String _mimeType = 'audio/webm';
  bool _started = false;

  Future<void> start({OnWebMicLiveStats? onStats}) async {
    if (_started) return;
    _onStats = onStats;
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw Exception('mediaDevices is not available');
    }

    final stream = await mediaDevices
        .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
    _mediaStream = stream;
    _setupStatsAnalyzer(stream);

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
    final dataCompleter = Completer<void>();

    js_util.callMethod<void>(recorder, 'addEventListener', [
      'dataavailable',
      allowInterop((dynamic event) {
        try {
          final data = js_util.getProperty<Object?>(event, 'data');
          if (data == null) return;
          final size = js_util.getProperty<num>(data, 'size');
          if (size <= 0) return;
          _chunks.add(data as html.Blob);
          if (!dataCompleter.isCompleted) {
            dataCompleter.complete();
          }
        } catch (_) {}
      }),
    ]);

    js_util.callMethod<void>(recorder, 'addEventListener', [
      'stop',
      allowInterop((dynamic _) {
        if (!stopCompleter.isCompleted) stopCompleter.complete();
      }),
    ]);

    // Safari may deliver the final audio blob only after an explicit flush.
    try {
      js_util.callMethod<void>(recorder, 'requestData', []);
    } catch (_) {}
    await Future.any([
      dataCompleter.future,
      Future<void>.delayed(const Duration(milliseconds: 250)),
    ]);

    try {
      final state = js_util.getProperty<String?>(recorder, 'state') ?? '';
      if (state != 'inactive') {
        js_util.callMethod<void>(recorder, 'stop', []);
      }
    } catch (_) {
      try {
        js_util.callMethod<void>(recorder, 'stop', []);
      } catch (_) {}
    }
    await stopCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    if (_chunks.isEmpty) {
      await Future.any([
        dataCompleter.future,
        Future<void>.delayed(const Duration(milliseconds: 450)),
      ]);
    }

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
      _statsTimer?.cancel();
      _statsTimer = null;
      _onStats = null;
      _analyserNode = null;
      final ctx = _audioContext;
      _audioContext = null;
      if (ctx != null) {
        try {
          js_util.callMethod<void>(ctx, 'close', []);
        } catch (_) {}
      }
      _mediaRecorder = null;
      _chunks.clear();
      _started = false;
    }
  }

  Future<void> _stopStream() async {
    _statsTimer?.cancel();
    _statsTimer = null;
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

  void _setupStatsAnalyzer(Object stream) {
    try {
      final contextCtor =
          js_util.getProperty<Object?>(html.window, 'AudioContext') ??
              js_util.getProperty<Object?>(html.window, 'webkitAudioContext');
      if (contextCtor == null) return;

      final context = js_util.callConstructor<Object>(contextCtor, const []);
      final sr = js_util.getProperty<num?>(context, 'sampleRate');
      if (sr != null && sr > 0) {
        _sampleRate = sr.round();
      }
      final source = js_util
          .callMethod<Object>(context, 'createMediaStreamSource', [stream]);
      final analyser =
          js_util.callMethod<Object>(context, 'createAnalyser', []);
      js_util.setProperty(analyser, 'fftSize', 2048);
      js_util.setProperty(analyser, 'smoothingTimeConstant', 0.55);
      js_util.callMethod<void>(source, 'connect', [analyser]);
      _audioContext = context;
      _analyserNode = analyser;

      _statsTimer?.cancel();
      _statsTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        final node = _analyserNode;
        final cb = _onStats;
        if (node == null || cb == null) return;
        final samples = Float32List(2048);
        try {
          js_util.callMethod<void>(node, 'getFloatTimeDomainData', [samples]);
          final level = _computeLevelNorm(samples);
          final pitch = _estimatePitchHz(samples, _sampleRate);
          cb(WebMicLiveStats(levelNorm: level, pitchHz: pitch));
        } catch (_) {}
      });
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
  if (mimeType.contains('mp4') || mimeType.contains('m4a')) {
    return 'mic_input.m4a';
  }
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

double _computeLevelNorm(Float32List samples) {
  if (samples.isEmpty) return 0;
  var sum = 0.0;
  for (final s in samples) {
    sum += s * s;
  }
  final rms = math.sqrt(sum / samples.length);
  return (rms * 10.0).clamp(0.0, 1.0);
}

double _estimatePitchHz(Float32List samples, int sampleRate) {
  if (samples.length < 512) return 0;
  var rms = 0.0;
  for (final s in samples) {
    rms += s * s;
  }
  rms = math.sqrt(rms / samples.length);
  if (rms < 0.01) return 0;

  final minLag = sampleRate ~/ 400;
  final maxLag = sampleRate ~/ 70;
  var bestLag = -1;
  var bestCorr = 0.0;

  for (var lag = minLag; lag <= maxLag; lag++) {
    var corr = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    final end = samples.length - lag;
    for (var i = 0; i < end; i++) {
      final a = samples[i];
      final b = samples[i + lag];
      corr += a * b;
      normA += a * a;
      normB += b * b;
    }
    final denom = math.sqrt(normA * normB) + 1e-9;
    final nccf = corr / denom;
    if (nccf > bestCorr) {
      bestCorr = nccf;
      bestLag = lag;
    }
  }

  if (bestLag <= 0 || bestCorr < 0.2) return 0;
  return (sampleRate / bestLag).clamp(70.0, 420.0);
}

WebMicRecorder createWebMicRecorder() => WebMicRecorder();
