import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/texttospeech/v1.dart' as tts;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:microphone/microphone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/browser_capability.dart';
import '../services/live_audio_analyzer.dart';
import '../services/tts_service.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/voice_curve_compare_chart.dart';
import 'accent_learning_result_page.dart';

class AccentLearningPage extends StatefulWidget {
  final int chapterId;

  const AccentLearningPage({required this.chapterId, super.key});

  @override
  State<AccentLearningPage> createState() => _AccentLearningPageState();
}

class _AccentLearningPageState extends State<AccentLearningPage> {
  late Future<List<AppSentence>> futureSentences;
  late Future<Chapter> futureChapter;
  final ApiService _api = ApiService();
  late final LiveAudioAnalyzer _liveAudioAnalyzer;

  int currentIndex = 0;
  late AudioPlayer audioPlayer;
  late stt.SpeechToText _speech;

  bool isListening = false;
  bool isPlaying = false;
  bool isEvaluatingAudio = false;
  bool _isFinalizing = false;
  bool speechRecognitionSupported = true;

  String recognizedText = '';
  String listeningStatusText = '직접 말하기를 눌러 음성 입력을 시작하세요.';
  MicrophoneRecorder? _webMicRecorder;
  Uint8List? _webAudioBytes;
  final List<double> _liveInputCurve = [];
  double _soundLevelMin = 0;
  double _soundLevelMax = 0;
  DateTime? _listenStartedAt;
  DateTime? _lastSoundAt;
  int _activeFrames = 0;
  double _liveSpeedEstimate = 0;
  double _livePitchEstimateHz = 0;
  Timer? _webAutoStopTimer;
  bool _webHasSpeech = false;
  DateTime? _webSpeechStartedAt;
  DateTime? _webLastVoiceAt;
  String? _webMicInitError;

  int playCount = 0;

  @override
  void initState() {
    super.initState();
    futureSentences = _api.fetchSentences(widget.chapterId);
    futureChapter = _api.fetchChapter(widget.chapterId);
    audioPlayer = AudioPlayer();
    _speech = stt.SpeechToText();
    _liveAudioAnalyzer = createLiveAudioAnalyzer();

    if (kIsWeb) {
      speechRecognitionSupported = true;
      listeningStatusText = '직접 말하기를 눌러 음성 입력을 시작하세요.';
    }
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) return;
    await Permission.microphone.request();
  }

  Future<AutoRefreshingAuthClient> _getAuthClient() async {
    final serviceAccountJson =
        await rootBundle.loadString('assets/service_account.json');
    final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    final scopes = [tts.TexttospeechApi.cloudPlatformScope];
    return clientViaServiceAccount(credentials, scopes);
  }

  Future<void> _playTextToSpeech(String text) async {
    if (kIsWeb) {
      final ok = await TtsService.speak(text, rate: 0.9);
      if (ok) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('웹 브라우저 TTS를 사용할 수 없습니다.')),
      );
      return;
    }

    try {
      final authClient = await _getAuthClient();
      final ttsApi = tts.TexttospeechApi(authClient);

      final input = tts.SynthesizeSpeechRequest(
        input: tts.SynthesisInput(text: text),
        voice: tts.VoiceSelectionParams(
          languageCode: 'ko-KR',
          name: 'ko-KR-Wavenet-D',
        ),
        audioConfig: tts.AudioConfig(audioEncoding: 'MP3', speakingRate: 0.9),
      );

      final response = await ttsApi.text.synthesize(input);
      final audioContent = base64Decode(response.audioContent!);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/tts.mp3');
      await tempFile.writeAsBytes(audioContent);

      setState(() {
        isPlaying = true;
        playCount = 0;
      });

      await _playAudioFile(tempFile.path);
    } catch (_) {
      final fallbackOk = await TtsService.speak(text, rate: 0.9);
      if (!fallbackOk && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음성 재생에 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _playAudioFile(String filePath) async {
    await audioPlayer.play(DeviceFileSource(filePath));

    audioPlayer.onPlayerComplete.listen((_) async {
      playCount++;
      if (playCount < 2) {
        await audioPlayer.play(DeviceFileSource(filePath));
      } else {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        setState(() => isPlaying = false);
      }
    });
  }

  Future<void> _saveSentence(int sentenceId) async {
    final response = await http
        .post(Uri.parse('${ApiService.baseUrl}/sentences/$sentenceId/save/'));

    if (response.statusCode == 200) {
      setState(() {
        futureSentences = futureSentences.then((sentences) {
          sentences[currentIndex].isCorrect = true;
          return sentences;
        });
      });
      return;
    }

    throw Exception('Failed to save sentence');
  }

  Future<void> _updateSentenceIsCalled(int sentenceId) async {
    await _api.updateSentenceIsCalled(sentenceId);
  }

  void _nextSentence(List<AppSentence> sentences) async {
    await _updateSentenceIsCalled(sentences[currentIndex].id);
    setState(() {
      if (currentIndex < sentences.length - 1) {
        currentIndex++;
      }
    });
  }

  void _completeLearning() async {
    final sentences = await _api.fetchSentences(widget.chapterId);

    for (final sentence in sentences) {
      if (!sentence.isCalled) {
        await _api.updateSentenceIsCalled(sentence.id);
      }
    }

    final updatedSentences = await _api.fetchSentences(widget.chapterId);
    final progress =
        updatedSentences.where((sentence) => sentence.isCalled).length /
            updatedSentences.length *
            100;

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AccentLearningResultPage(
          progress: progress,
          sentences: updatedSentences,
          chapterId: widget.chapterId,
        ),
      ),
    );
  }

  Future<void> _resetCurrentSentenceAttempts() async {
    try {
      final list = await futureSentences;
      if (list.isEmpty) return;
      final sentenceId = list[currentIndex].id;
      final result = await _api.resetSentencePronunciation(sentenceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '기록 초기화 완료: ${result['deleted_attempts'] ?? 0}개 삭제',
          ),
        ),
      );
      setState(() {
        futureSentences = _api.fetchSentences(widget.chapterId);
        recognizedText = '';
      });
    } catch (e) {
      _showErrorDialog('기록 초기화 실패: $e');
    }
  }

  Future<void> _startListening() async {
    await _checkPermissions();
    if (kIsWeb) {
      await _startWebMicRecordingIfPossible();
      if (_webMicRecorder == null) {
        final message = _buildWebMicInitErrorMessage();
        setState(() {
          listeningStatusText = message;
        });
        _showErrorDialog(message);
        return;
      }

      setState(() {
        isListening = true;
        recognizedText = '';
        listeningStatusText = '발화를 시작해 주세요. 무음이 감지되면 자동 종료됩니다.';
        _liveInputCurve.clear();
        _soundLevelMin = 0;
        _soundLevelMax = 0;
        _listenStartedAt = DateTime.now();
        _lastSoundAt = null;
        _activeFrames = 0;
        _liveSpeedEstimate = 0;
        _livePitchEstimateHz = 0;
        _webHasSpeech = false;
        _webSpeechStartedAt = null;
        _webLastVoiceAt = null;
        _webMicInitError = null;
      });
      await _startLiveAudioAnalyzerIfPossible();
      _webAutoStopTimer?.cancel();
      _webAutoStopTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && isListening) {
          _stopListening();
        }
      });
      return;
    }

    if (!speechRecognitionSupported) {
      _showErrorDialog('이 기기에서는 음성 입력이 제한됩니다.');
      return;
    }

    final available = await _speech.initialize(
      onStatus: (val) {
        if (!mounted) return;
        setState(() {
          if (val == 'done' || val == 'notListening') {
            isListening = false;
            listeningStatusText = '음성 입력이 종료되었습니다.';
          }
        });
        if (val == 'done' || val == 'notListening') {
          _stopLiveAudioAnalyzerIfPossible();
        }
      },
      onError: (val) {
        if (!mounted) return;
        setState(() {
          isListening = false;
          listeningStatusText = '음성 입력 오류: ${val.errorMsg}';
        });
        _stopLiveAudioAnalyzerIfPossible();
        _stopWebMicRecordingIfPossible();
      },
    );

    if (!available) {
      if (!mounted) return;
      setState(() {
        isListening = false;
        speechRecognitionSupported = false;
        listeningStatusText = '음성 입력 초기화에 실패했습니다.';
      });
      await _stopWebMicRecordingIfPossible();
      await _speech.stop();
      return;
    }

    setState(() {
      isListening = true;
      recognizedText = '';
      listeningStatusText = '음성 입력 중... 또박또박 말해 주세요.';
      _liveInputCurve.clear();
      _soundLevelMin = 0;
      _soundLevelMax = 0;
      _listenStartedAt = DateTime.now();
      _lastSoundAt = null;
      _activeFrames = 0;
      _liveSpeedEstimate = 0;
      _livePitchEstimateHz = 0;
    });
    await _startLiveAudioAnalyzerIfPossible();

    _speech.listen(
      onResult: (val) {
        if (!mounted) return;
        setState(() {
          recognizedText = val.recognizedWords;
          if (val.finalResult) {
            listeningStatusText = '입력 완료. 평가 중...';
            isListening = false;
          }
        });
        if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
          _finalizeAndEvaluate();
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      localeId: 'ko-KR',
      onSoundLevelChange: (level) {
        if (!kIsWeb) _onSoundLevelChange(level);
      },
      listenOptions: stt.SpeechListenOptions(partialResults: true),
    );
  }

  Future<void> _stopListening() async {
    if (!isListening) return;
    _webAutoStopTimer?.cancel();
    _webAutoStopTimer = null;
    final hasSpeech = !kIsWeb || _webHasSpeech;
    setState(() {
      isListening = false;
      listeningStatusText =
          hasSpeech ? '음성 입력을 중지했습니다.' : '음성이 감지되지 않았습니다. 다시 시도해 주세요.';
    });
    await _stopLiveAudioAnalyzerIfPossible();
    if (!kIsWeb) {
      await _speech.stop();
    }
    if (!hasSpeech) {
      await _stopWebMicRecordingIfPossible();
      return;
    }
    await _finalizeAndEvaluate();
  }

  Future<void> _startLiveAudioAnalyzerIfPossible() async {
    if (!kIsWeb) return;
    await _liveAudioAnalyzer.start((stats) {
      if (!mounted || !isListening) return;
      final now = DateTime.now();
      final isVoice = stats.levelNorm > 0.12 || stats.pitchHz > 75;
      if (isVoice) {
        _webLastVoiceAt = now;
        _webSpeechStartedAt ??= now;
        _webHasSpeech = true;
      }
      setState(() {
        _liveSpeedEstimate = stats.syllablesPerSec;
        _livePitchEstimateHz = stats.pitchHz;
        _liveInputCurve.add(stats.levelNorm);
        if (_liveInputCurve.length > 64) {
          _liveInputCurve.removeAt(0);
        }
        if (_webHasSpeech) {
          listeningStatusText = '발화 감지됨... 계속 말해 주세요.';
        }
      });

      final startedAt = _webSpeechStartedAt;
      final lastVoiceAt = _webLastVoiceAt;
      if (!_webHasSpeech || startedAt == null || lastVoiceAt == null) return;
      final speechMs = now.difference(startedAt).inMilliseconds;
      final silenceMs = now.difference(lastVoiceAt).inMilliseconds;
      if (speechMs >= 700 && silenceMs >= 1200) {
        _stopListening();
      }
    });
  }

  Future<void> _stopLiveAudioAnalyzerIfPossible() async {
    if (!kIsWeb) return;
    await _liveAudioAnalyzer.stop();
  }

  void _onSoundLevelChange(double level) {
    final l = level.isFinite ? level : 0.0;
    if (_liveInputCurve.isEmpty) {
      _soundLevelMin = l;
      _soundLevelMax = l;
    } else {
      _soundLevelMin = math.min(_soundLevelMin, l);
      _soundLevelMax = math.max(_soundLevelMax, l);
    }
    final denom = (_soundLevelMax - _soundLevelMin).abs() + 0.0001;
    final normalized = ((l - _soundLevelMin) / denom).clamp(0.0, 1.0);
    final now = DateTime.now();
    if (normalized > 0.24) {
      _activeFrames += 1;
    }
    if (_listenStartedAt != null) {
      final elapsedSec =
          now.difference(_listenStartedAt!).inMilliseconds / 1000.0;
      if (elapsedSec > 0) {
        _liveSpeedEstimate = (_activeFrames / elapsedSec).clamp(0.0, 8.0);
      }
    }
    if (_lastSoundAt != null) {
      final dtSec = (now.difference(_lastSoundAt!).inMilliseconds / 1000.0)
          .clamp(0.001, 1.0);
      final hz = (1.0 / (dtSec * 2.0)).clamp(60.0, 420.0);
      _livePitchEstimateHz = 0.85 * _livePitchEstimateHz + 0.15 * hz;
    }
    _lastSoundAt = now;
    if (!mounted) return;
    setState(() {
      _liveInputCurve.add(normalized);
      if (_liveInputCurve.length > 64) {
        _liveInputCurve.removeAt(0);
      }
    });
  }

  Future<void> _startWebMicRecordingIfPossible() async {
    if (!kIsWeb) return;
    try {
      _webMicRecorder?.dispose();
      final recorder = MicrophoneRecorder();
      await recorder.init();
      await recorder.start();
      _webMicRecorder = recorder;
      _webAudioBytes = null;
      _webMicInitError = null;
    } catch (e) {
      _webMicRecorder = null;
      _webAudioBytes = null;
      _webMicInitError = e.toString();
    }
  }

  String _buildWebMicInitErrorMessage() {
    final raw = (_webMicInitError ?? '').toLowerCase();
    final isHttpsLike = Uri.base.scheme == 'https' ||
        Uri.base.host == 'localhost' ||
        Uri.base.host == '127.0.0.1';
    if (!isHttpsLike) {
      return '마이크는 HTTPS에서만 동작합니다. https 주소로 다시 접속해 주세요.';
    }
    if (raw.contains('notallowed') || raw.contains('permission')) {
      return isLikelySafari
          ? '마이크 권한이 거부되었습니다. iOS 설정 > Safari > 마이크 또는 주소창 aA > 웹 사이트 설정에서 마이크를 허용해 주세요.'
          : '마이크 권한이 거부되었습니다. 브라우저 사이트 설정에서 마이크를 허용해 주세요.';
    }
    if (raw.contains('notfound')) {
      return '사용 가능한 마이크를 찾지 못했습니다. 기기 마이크 연결 상태를 확인해 주세요.';
    }
    if (raw.contains('notreadable') ||
        raw.contains('trackstart') ||
        raw.contains('abort')) {
      return '다른 앱이 마이크를 사용 중입니다. 통화/녹음 앱을 종료하고 다시 시도해 주세요.';
    }
    if (raw.contains('notsupported') ||
        raw.contains('mediarecorder') ||
        raw.contains('unsupported')) {
      return isLikelySafari
          ? '현재 Safari 환경에서 녹음 초기화에 실패했습니다. 인앱 브라우저가 아닌 Safari에서 열고 마이크 권한을 허용해 주세요.'
          : '현재 브라우저에서 녹음 기능을 지원하지 않습니다. 최신 Safari/Chrome으로 다시 시도해 주세요.';
    }
    return '마이크 초기화에 실패했습니다. 권한 허용 후 새로고침해서 다시 시도해 주세요.';
  }

  Future<void> _stopWebMicRecordingIfPossible() async {
    if (!kIsWeb || _webMicRecorder == null) return;
    try {
      await _webMicRecorder!.stop();
      _webAudioBytes = await _webMicRecorder!.toBytes();
    } catch (_) {
      _webAudioBytes = null;
    } finally {
      _webMicRecorder?.dispose();
      _webMicRecorder = null;
    }
  }

  Future<void> _finalizeAndEvaluate() async {
    if (_isFinalizing) return;
    _isFinalizing = true;
    try {
      if (mounted) {
        setState(() => isEvaluatingAudio = true);
      }
      await _stopLiveAudioAnalyzerIfPossible();
      await _stopWebMicRecordingIfPossible();
      await _evaluateSpeech(audioBytes: _webAudioBytes);
    } finally {
      if (mounted) {
        setState(() => isEvaluatingAudio = false);
      }
      _isFinalizing = false;
    }
  }

  Future<void> _evaluateSpeech({
    Uint8List? audioBytes,
    String? overrideContentType,
    String? overrideFileName,
  }) async {
    if (audioBytes == null || audioBytes.isEmpty) {
      _showErrorDialog('녹음된 음성이 없습니다. 다시 시도해 주세요.');
      return;
    }

    final sentences = await futureSentences;
    final current = sentences[currentIndex];

    try {
      final contentType =
          overrideContentType ?? _detectAudioContentType(audioBytes);
      final result = await _api.evaluatePronunciation(
        sentenceId: current.id,
        referenceText: current.koreanSentence,
        recognizedText: '',
        audioBytes: audioBytes,
        fileName: overrideFileName ?? _buildAudioFileName(contentType),
        contentType: contentType,
      );
      await _api.updateSentenceAccuracyAndText(
        current.id,
        result.accuracyRatio,
        result.transcript,
      );
      if (!mounted) return;
      _showEvaluationPopup(result);
    } catch (e) {
      _showErrorDialog('평가 요청 실패: $e');
    }
  }

  String _detectAudioContentType(Uint8List? bytes) {
    if (bytes == null || bytes.length < 4) return 'audio/webm';
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'audio/wav';
    }
    if (bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53) {
      return 'audio/ogg';
    }
    if (bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      return 'audio/webm';
    }
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return 'audio/mp4';
    }
    return 'audio/webm';
  }

  String _buildAudioFileName(String contentType) {
    if (contentType.contains('wav')) return 'mic_input.wav';
    if (contentType.contains('ogg')) return 'mic_input.ogg';
    if (contentType.contains('mp4') || contentType.contains('m4a')) {
      return 'mic_input.m4a';
    }
    return 'mic_input.webm';
  }

  String _detectContentTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.flac')) return 'audio/flac';
    return 'audio/webm';
  }

  Future<void> _uploadAudioAndEvaluate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const [
          'm4a',
          'mp3',
          'wav',
          'ogg',
          'webm',
          'aac',
          'flac',
        ],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        _showErrorDialog('선택한 음성 파일을 읽을 수 없습니다.');
        return;
      }

      final fileName = file.name.isNotEmpty ? file.name : 'uploaded_audio.m4a';
      final contentType = _detectContentTypeFromFileName(fileName);
      if (mounted) {
        setState(() => listeningStatusText = '음성 파일 평가 중...');
      }
      await _evaluateSpeech(
        audioBytes: bytes,
        overrideContentType: contentType,
        overrideFileName: fileName,
      );
    } catch (e) {
      _showErrorDialog('음성 파일 업로드 실패: $e');
    }
  }

  void _showEvaluationPopup(PronunciationEvaluationResult result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('평가 결과'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('점수: ${result.scorePercent.toStringAsFixed(2)}%'),
                  const SizedBox(height: 8),
                  Text('피드백: ${result.feedback}'),
                  const SizedBox(height: 8),
                  if (result.audioMetricsAvailable) ...[
                    const SizedBox(height: 8),
                    Text(
                        '속도 점수: ${((result.speedScore ?? 0) * 100).toStringAsFixed(1)}%'),
                    Text(
                        '피치 점수: ${((result.pitchScore ?? 0) * 100).toStringAsFixed(1)}%'),
                    Text(
                        '음량 점수: ${((result.volumeScore ?? 0) * 100).toStringAsFixed(1)}%'),
                    Text(
                        '음성 길이(내/기준): ${(result.audioDurationSec ?? 0).toStringAsFixed(2)}초 / ${(result.referenceDurationSec ?? 0).toStringAsFixed(2)}초'),
                    Text(
                        '피치 중앙값: ${(result.pitchMedianHz ?? 0).toStringAsFixed(1)}Hz / 변동성: ${(result.pitchStdHz ?? 0).toStringAsFixed(1)}Hz'),
                    if (result.pitchCurveSimilarity != null)
                      Text(
                        '피치 유사도: ${(result.pitchCurveSimilarity! * 100).toStringAsFixed(1)}%',
                      ),
                    if (result.volumeCurveSimilarity != null)
                      Text(
                        '음량 유사도: ${(result.volumeCurveSimilarity! * 100).toStringAsFixed(1)}%',
                      ),
                    if (result.pitchVerdict.isNotEmpty)
                      Text('피치 판정: ${result.pitchVerdict}'),
                    if (result.sentenceAttemptsCount != null)
                      Text('누적 시도: ${result.sentenceAttemptsCount}회'),
                    if (result.sentenceBestScore != null)
                      Text(
                        '최고 점수: ${result.sentenceBestScore!.toStringAsFixed(2)}%',
                      ),
                    if (result.recentAvgScore != null)
                      Text(
                        '최근 ${result.recentWindowSize ?? 3}회 평균: ${result.recentAvgScore!.toStringAsFixed(2)}% (편차 ${(result.recentScoreStddev ?? 0).toStringAsFixed(2)})',
                      ),
                    if (result.referencePitchCurve.isNotEmpty &&
                        result.userPitchCurve.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('피치 곡선 비교',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 120,
                        child: VoiceCurveCompareChart(
                          referenceCurve: result.referencePitchCurve,
                          userCurve: result.userPitchCurve,
                          referenceLabel: '기준 TTS',
                          userLabel: '내 입력',
                        ),
                      ),
                    ],
                    if (result.referenceVolumeCurve.isNotEmpty &&
                        result.userVolumeCurve.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('음량 곡선 비교',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 120,
                        child: VoiceCurveCompareChart(
                          referenceCurve: result.referenceVolumeCurve,
                          userCurve: result.userVolumeCurve,
                          referenceLabel: '기준 TTS',
                          userLabel: '내 입력',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    '평가 기준: 피치 45% + 속도 35% + 음량 20% (음성 직접 비교)',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '모델: ${result.model}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _webAutoStopTimer?.cancel();
    _speech.stop();
    _liveAudioAnalyzer.dispose();
    _webMicRecorder?.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFF3FA),
      appBar: AppBar(
        title: const Text('Accent Learning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '현재 문장 평가기록 초기화',
            onPressed: _resetCurrentSentenceAttempts,
          ),
        ],
      ),
      body: FutureBuilder<List<AppSentence>>(
        future: futureSentences,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load sentences'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No sentences available'));
          }

          final sentences = snapshot.data!;
          final currentSentence = sentences[currentIndex];

          return FutureBuilder<Chapter>(
            future: futureChapter,
            builder: (context, chapterSnapshot) {
              if (chapterSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (chapterSnapshot.hasError || !chapterSnapshot.hasData) {
                return const Center(child: Text('No chapter available'));
              }

              final chapter = chapterSnapshot.data!;

              return Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${chapter.id} #${chapter.title}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              '난이도: ${chapter.difficulty} / 상황: ${chapter.contextTag}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (!kIsWeb && !speechRecognitionSupported) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF6E8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE6C27A),
                                  ),
                                ),
                                child: Text(
                                  '현재 기기에서는 음성 인식 기능이 제한될 수 있습니다.',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            ManagedImage(
                              imageUrl: currentSentence.imageUrl,
                              fallbackAssetPath:
                                  'assets/images/${currentSentence.koreanSentence}.png',
                              width: double.infinity,
                              height:
                                  (MediaQuery.of(context).size.height * 0.26)
                                      .clamp(140.0, 220.0)
                                      .toDouble(),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      currentSentence.koreanSentence,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    Text(
                                      ': ${currentSentence.northKoreanSentence}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('Greetings',
                                style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 5),
                            Text(
                              '${sentences.length} sentences',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  isListening
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: isListening
                                      ? Colors.redAccent
                                      : Colors.black54,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    listeningStatusText,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            if (_liveInputCurve.length > 2) ...[
                              const SizedBox(height: 10),
                              const Text('입력 음성 형태(실시간 레벨)'),
                              const SizedBox(height: 4),
                              Text(
                                '실시간 속도 추정: ${_liveSpeedEstimate.toStringAsFixed(2)} / 피치 추정: ${_livePitchEstimateHz.toStringAsFixed(0)}Hz',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 90,
                                child: VoiceCurveCompareChart(
                                  referenceCurve: const [],
                                  userCurve: _liveInputCurve,
                                  referenceLabel: '',
                                  userLabel: '입력 레벨',
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFD9DEEA),
                                ),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '평가 방식',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '직접 말하기(마이크): 피치 45% + 속도 35% + 음량 20%',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (currentSentence.isCorrect) {
                                    setState(() =>
                                        currentSentence.isCorrect = false);
                                  } else {
                                    _saveSentence(currentSentence.id);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: currentSentence.isCorrect
                                      ? Colors.black
                                      : Colors.white,
                                  foregroundColor: currentSentence.isCorrect
                                      ? Colors.white
                                      : Colors.black,
                                  minimumSize: const Size(double.infinity, 50),
                                  side: currentSentence.isCorrect
                                      ? null
                                      : const BorderSide(color: Colors.black),
                                ),
                                child: Text(
                                  currentSentence.isCorrect ? '저장됨' : '저장하기',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (currentIndex > 0)
                                ElevatedButton(
                                  onPressed: () =>
                                      setState(() => currentIndex--),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    backgroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                    side: const BorderSide(color: Colors.black),
                                  ),
                                  child: const Text(
                                    '이전',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              if (currentIndex < sentences.length - 1)
                                ElevatedButton(
                                  onPressed: () => _nextSentence(sentences),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    backgroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                    side: const BorderSide(color: Colors.black),
                                  ),
                                  child: const Text(
                                    '다음',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (currentIndex == sentences.length - 1)
                                ElevatedButton(
                                  onPressed: _completeLearning,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                  ),
                                  child: const Text(
                                    '완료하기',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _playTextToSpeech(
                                  currentSentence.koreanSentence,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                child: const Text(
                                  '음성 듣기',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed:
                                    (!kIsWeb && !speechRecognitionSupported)
                                        ? null
                                        : () => isListening
                                            ? _stopListening()
                                            : _startListening(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                child: Text(
                                  isListening ? '듣기 중지하기' : '직접 말하기',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _isFinalizing || isEvaluatingAudio
                                    ? null
                                    : _uploadAudioAndEvaluate,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('음성 파일 업로드(임시)'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                              if (_isFinalizing || isEvaluatingAudio)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: LinearProgressIndicator(minHeight: 2),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isListening)
                    Column(
                      children: [
                        const Spacer(),
                        Container(
                          height: (MediaQuery.of(context).size.height * 0.28)
                              .clamp(170.0, 260.0)
                              .toDouble(),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Center(
                            child: AnimatedTextKit(
                              animatedTexts: [
                                WavyAnimatedText(
                                  '말하는 중...',
                                  textStyle: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              isRepeatingAnimation: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
