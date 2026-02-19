import 'dart:async';
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';

import 'live_audio_analyzer.dart';

class _WebLiveAudioAnalyzer implements LiveAudioAnalyzer {
  Object? _audioContext;
  Object? _mediaStream;
  Object? _sourceNode;
  Object? _analyserNode;
  Timer? _timer;
  void Function(LiveAudioStats stats)? _onStats;

  DateTime? _startedAt;
  bool _wasVoiced = false;
  int _syllableEvents = 0;

  @override
  bool get isRunning => _timer != null;

  @override
  Future<bool> start(void Function(LiveAudioStats stats) onStats) async {
    await stop();
    try {
      final navigator =
          js_util.getProperty<Object?>(js_util.globalThis, 'navigator');
      if (navigator == null) return false;
      final mediaDevices =
          js_util.getProperty<Object?>(navigator, 'mediaDevices');
      if (mediaDevices == null) return false;

      final streamPromise = js_util.callMethod<Object>(
        mediaDevices,
        'getUserMedia',
        [
          js_util.jsify(<String, dynamic>{'audio': true})
        ],
      );
      final stream = await js_util.promiseToFuture<Object>(streamPromise);

      final audioContextCtor =
          js_util.getProperty<Object?>(js_util.globalThis, 'AudioContext') ??
              js_util.getProperty<Object?>(
                js_util.globalThis,
                'webkitAudioContext',
              );
      if (audioContextCtor == null) return false;
      final context =
          js_util.callConstructor<Object>(audioContextCtor, const []);
      final source = js_util.callMethod<Object>(
        context,
        'createMediaStreamSource',
        [stream],
      );
      final analyser = js_util.callMethod<Object>(
        context,
        'createAnalyser',
        const [],
      );
      js_util.setProperty(analyser, 'fftSize', 2048);
      js_util.setProperty(analyser, 'smoothingTimeConstant', 0.35);
      js_util.callMethod(source, 'connect', [analyser]);

      _mediaStream = stream;
      _audioContext = context;
      _sourceNode = source;
      _analyserNode = analyser;
      _onStats = onStats;
      _startedAt = DateTime.now();
      _wasVoiced = false;
      _syllableEvents = 0;

      _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
        _sampleAndEmit();
      });
      return true;
    } catch (_) {
      await stop();
      return false;
    }
  }

  void _sampleAndEmit() {
    final analyser = _analyserNode;
    final context = _audioContext;
    final startedAt = _startedAt;
    final onStats = _onStats;
    if (analyser == null ||
        context == null ||
        startedAt == null ||
        onStats == null) {
      return;
    }

    final fftSize = js_util.getProperty<int>(analyser, 'fftSize');
    final timeData = Uint8List(fftSize);
    final freqData = Uint8List(
      js_util.getProperty<int>(analyser, 'frequencyBinCount'),
    );
    js_util.callMethod(analyser, 'getByteTimeDomainData', [timeData]);
    js_util.callMethod(analyser, 'getByteFrequencyData', [freqData]);

    double sumSquares = 0;
    for (final v in timeData) {
      final centered = (v - 128.0) / 128.0;
      sumSquares += centered * centered;
    }
    final rms = math.sqrt(sumSquares / timeData.length);
    final levelNorm = (rms * 2.2).clamp(0.0, 1.0);

    final sampleRate =
        js_util.getProperty<num>(context, 'sampleRate').toDouble();
    final binHz = sampleRate / fftSize;
    final startBin = math.max(1, (70 / binHz).floor());
    final endBin = math.min(freqData.length - 1, (420 / binHz).ceil());

    int maxBin = startBin;
    int maxAmp = 0;
    for (int i = startBin; i <= endBin; i++) {
      final amp = freqData[i];
      if (amp > maxAmp) {
        maxAmp = amp;
        maxBin = i;
      }
    }

    double pitchHz = 0;
    if (maxAmp >= 20) {
      pitchHz = maxBin * binHz;
    }

    final voiced = levelNorm > 0.1 && pitchHz >= 65;
    if (voiced && !_wasVoiced) {
      _syllableEvents += 1;
    }
    _wasVoiced = voiced;

    final elapsedSec =
        DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
    final syllablesPerSec = elapsedSec > 0
        ? (_syllableEvents / elapsedSec).clamp(0.0, 8.0).toDouble()
        : 0.0;

    onStats(
      LiveAudioStats(
        levelNorm: levelNorm.toDouble(),
        pitchHz: pitchHz.toDouble(),
        syllablesPerSec: syllablesPerSec,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _onStats = null;
    _startedAt = null;
    _wasVoiced = false;
    _syllableEvents = 0;

    try {
      if (_sourceNode != null) {
        js_util.callMethod(_sourceNode!, 'disconnect', const []);
      }
    } catch (_) {}
    _sourceNode = null;
    _analyserNode = null;

    final stream = _mediaStream;
    if (stream != null) {
      try {
        final tracks =
            js_util.callMethod<Object>(stream, 'getTracks', const []);
        final length = js_util.getProperty<int>(tracks, 'length');
        for (int i = 0; i < length; i++) {
          final track = js_util.getProperty<Object?>(tracks, i);
          if (track != null) {
            js_util.callMethod(track, 'stop', const []);
          }
        }
      } catch (_) {}
    }
    _mediaStream = null;

    final context = _audioContext;
    _audioContext = null;
    try {
      if (context != null) {
        final closePromise =
            js_util.callMethod<Object>(context, 'close', const []);
        await js_util.promiseToFuture<void>(closePromise);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
  }
}

LiveAudioAnalyzer createLiveAudioAnalyzer() => _WebLiveAudioAnalyzer();
