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

class AudioWebDiagnostics {
  final bool isWeb;
  final bool isSafari;
  final bool hasMediaDevices;
  final bool hasGetUserMedia;
  final bool hasMediaRecorder;
  final String micPermissionState;
  final bool supportsAudioMp4;
  final bool supportsAudioWebm;
  final bool supportsAudioOgg;
  final bool hasWebSpeech;
  final String userAgent;

  const AudioWebDiagnostics({
    required this.isWeb,
    required this.isSafari,
    required this.hasMediaDevices,
    required this.hasGetUserMedia,
    required this.hasMediaRecorder,
    required this.micPermissionState,
    required this.supportsAudioMp4,
    required this.supportsAudioWebm,
    required this.supportsAudioOgg,
    required this.hasWebSpeech,
    required this.userAgent,
  });
}

bool _supportsMime(Object mediaRecorderCtor, String mime) {
  if (!js_util.hasProperty(mediaRecorderCtor, 'isTypeSupported')) return false;
  try {
    return js_util.callMethod<bool>(
      mediaRecorderCtor,
      'isTypeSupported',
      [mime],
    );
  } catch (_) {
    return false;
  }
}

Future<AudioWebDiagnostics> getAudioWebDiagnostics() async {
  final nav = html.window.navigator;
  final userAgent = nav.userAgent;
  final hasMediaDevices = nav.mediaDevices != null;
  final hasGetUserMedia =
      hasMediaDevices && js_util.hasProperty(nav.mediaDevices!, 'getUserMedia');
  final hasRecorder = js_util.hasProperty(html.window, 'MediaRecorder');

  bool supportsMp4 = false;
  bool supportsWebm = false;
  bool supportsOgg = false;
  if (hasRecorder) {
    final mediaRecorderCtor =
        js_util.getProperty<Object>(html.window, 'MediaRecorder');
    supportsMp4 = _supportsMime(mediaRecorderCtor, 'audio/mp4');
    supportsWebm = _supportsMime(mediaRecorderCtor, 'audio/webm');
    supportsOgg = _supportsMime(mediaRecorderCtor, 'audio/ogg');
  }

  var micPermissionState = 'unknown';
  try {
    if (js_util.hasProperty(nav, 'permissions')) {
      final permissions = js_util.getProperty<Object>(nav, 'permissions');
      final queryPromise = js_util.callMethod<Object>(
        permissions,
        'query',
        [
          js_util.jsify(<String, dynamic>{'name': 'microphone'})
        ],
      );
      final status = await js_util.promiseToFuture<Object>(queryPromise);
      final state = js_util.getProperty<Object?>(status, 'state');
      if (state != null) micPermissionState = state.toString();
    }
  } catch (_) {
    micPermissionState = 'unknown';
  }

  return AudioWebDiagnostics(
    isWeb: true,
    isSafari: isLikelySafari,
    hasMediaDevices: hasMediaDevices,
    hasGetUserMedia: hasGetUserMedia,
    hasMediaRecorder: hasRecorder,
    micPermissionState: micPermissionState,
    supportsAudioMp4: supportsMp4,
    supportsAudioWebm: supportsWebm,
    supportsAudioOgg: supportsOgg,
    hasWebSpeech: hasWebSpeechRecognition,
    userAgent: userAgent,
  );
}
