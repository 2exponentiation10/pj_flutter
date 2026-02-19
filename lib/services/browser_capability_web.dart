import 'dart:html' as html;
import 'dart:js_util' as js_util;

bool get isLikelySafari {
  final ua = html.window.navigator.userAgent.toLowerCase();
  final hasSafari = ua.contains('safari');
  final excluded =
      ua.contains('chrome') || ua.contains('chromium') || ua.contains('edg');
  return hasSafari && !excluded;
}

bool get hasWebSpeechRecognition {
  return js_util.hasProperty(html.window, 'SpeechRecognition') ||
      js_util.hasProperty(html.window, 'webkitSpeechRecognition');
}
