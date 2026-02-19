import 'live_audio_analyzer_stub.dart'
    if (dart.library.html) 'live_audio_analyzer_web.dart' as impl;

class LiveAudioStats {
  final double levelNorm;
  final double pitchHz;
  final double syllablesPerSec;

  const LiveAudioStats({
    required this.levelNorm,
    required this.pitchHz,
    required this.syllablesPerSec,
  });
}

abstract class LiveAudioAnalyzer {
  bool get isRunning;
  Future<bool> start(void Function(LiveAudioStats stats) onStats);
  Future<void> stop();
  void dispose();
}

LiveAudioAnalyzer createLiveAudioAnalyzer() => impl.createLiveAudioAnalyzer();
