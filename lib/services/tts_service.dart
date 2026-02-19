import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

import 'web_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();

  static Future<bool> speak(String text, {double rate = 0.9}) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return false;
    }

    if (kIsWeb) {
      return speakOnWeb(normalized, rate: rate);
    }

    try {
      await _tts.stop();
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      final result = await _tts.speak(normalized);
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    if (kIsWeb) {
      await stopWebSpeech();
      return;
    }
    await _tts.stop();
  }
}
