import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class NativeMicLiveStats {
  final double levelNorm;
  final double pitchHz;

  const NativeMicLiveStats({
    required this.levelNorm,
    required this.pitchHz,
  });
}

class NativeMicRecording {
  final Uint8List bytes;
  final String mimeType;
  final String fileName;

  const NativeMicRecording({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });
}

class NativeMicRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _outputPath;
  double _previousLevel = 0;
  DateTime? _previousAt;

  Future<void> start({
    required void Function(NativeMicLiveStats stats) onStats,
  }) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('마이크 권한이 없습니다.');
    }

    final tmpDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _outputPath = '${tmpDir.path}/native_mic_$ts.m4a';

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      numChannels: 1,
      sampleRate: 44100,
      bitRate: 128000,
    );

    await _recorder.start(config, path: _outputPath!);

    await _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
      // dB(-160..0) -> 0..1 normalized envelope
      final db = amp.current.isFinite ? amp.current : -160.0;
      final levelNorm = ((db + 60.0) / 60.0).clamp(0.0, 1.0);

      final now = DateTime.now();
      double pitchHz = 0.0;
      if (_previousAt != null) {
        final dt = (now.difference(_previousAt!).inMilliseconds / 1000.0)
            .clamp(0.001, 1.0);
        final delta = (levelNorm - _previousLevel).abs();
        pitchHz = (75.0 + (delta / dt) * 180.0).clamp(60.0, 420.0);
      }

      _previousAt = now;
      _previousLevel = levelNorm;

      onStats(
        NativeMicLiveStats(
          levelNorm: levelNorm,
          pitchHz: pitchHz,
        ),
      );
    });
  }

  Future<NativeMicRecording?> stop() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final output = await _recorder.stop();
    final path = output ?? _outputPath;
    _outputPath = null;

    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    final fileName = path.split('/').last;
    final lower = fileName.toLowerCase();
    final mimeType = lower.endsWith('.aac') ? 'audio/aac' : 'audio/mp4';

    return NativeMicRecording(
      bytes: bytes,
      mimeType: mimeType,
      fileName: fileName,
    );
  }

  Future<void> dispose() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {
      // Ignore dispose-time recorder state errors.
    }

    _recorder.dispose();
  }
}
