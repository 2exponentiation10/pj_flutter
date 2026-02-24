bool get isLikelySafari => false;

bool get hasWebSpeechRecognition => false;

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

Future<AudioWebDiagnostics> getAudioWebDiagnostics() async {
  return const AudioWebDiagnostics(
    isWeb: false,
    isSafari: false,
    hasMediaDevices: false,
    hasGetUserMedia: false,
    hasMediaRecorder: false,
    micPermissionState: 'unsupported',
    supportsAudioMp4: false,
    supportsAudioWebm: false,
    supportsAudioOgg: false,
    hasWebSpeech: false,
    userAgent: 'non-web',
  );
}
