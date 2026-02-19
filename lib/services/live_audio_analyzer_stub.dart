import 'live_audio_analyzer.dart';

class _NoopLiveAudioAnalyzer implements LiveAudioAnalyzer {
  @override
  bool get isRunning => false;

  @override
  Future<bool> start(void Function(LiveAudioStats stats) onStats) async {
    return false;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

LiveAudioAnalyzer createLiveAudioAnalyzer() => _NoopLiveAudioAnalyzer();
