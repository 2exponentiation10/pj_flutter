import 'dart:html' as html;

Future<bool> speakOnWeb(String text, {double rate = 0.9}) async {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return false;
  }

  final synth = html.window.speechSynthesis;
  if (synth == null) {
    return false;
  }

  synth.cancel();
  final utterance = html.SpeechSynthesisUtterance(normalized)
    ..lang = 'ko-KR'
    ..rate = rate;
  final voices = synth.getVoices();
  for (final voice in voices) {
    if ((voice.lang ?? '').toLowerCase().startsWith('ko')) {
      utterance.voice = voice;
      break;
    }
  }
  synth.speak(utterance);
  return true;
}

Future<void> stopWebSpeech() async {
  html.window.speechSynthesis?.cancel();
}
