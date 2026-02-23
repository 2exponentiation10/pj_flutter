import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:microphone/microphone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/browser_capability.dart';
import '../services/live_audio_analyzer.dart';
import '../services/web_audio_capture.dart';
import '../widgets/voice_curve_compare_chart.dart';
import 'accent_evaluation_result_page.dart';

class AccentEvaluationPage extends StatefulWidget {
  final int chapterId;

  const AccentEvaluationPage({required this.chapterId});

  @override
  _AccentEvaluationPageState createState() => _AccentEvaluationPageState();
}

class _AccentEvaluationPageState extends State<AccentEvaluationPage> {
  late Future<List<AppSentence>> futureSentences;
  late Future<Chapter> futureChapter;

  late stt.SpeechToText _speech;
  final _api = ApiService();
  late final LiveAudioAnalyzer _liveAudioAnalyzer;

  int currentIndex = 0;
  bool isListening = false;
  bool isEvaluatingAudio = false;
  bool speechRecognitionSupported = true;
  bool _isFinalizing = false;
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

  List<AppSentence> sentences = [];

  @override
  void initState() {
    super.initState();
    futureSentences = _api.fetchSentences(widget.chapterId);
    futureChapter = _api.fetchChapter(widget.chapterId);
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

  Future<void> _completeEvaluation() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AccentEvaluationResultPage(chapterId: widget.chapterId),
      ),
    );
  }

  Future<void> _resetCurrentSentenceAttempts() async {
    if (sentences.isEmpty) return;
    final sentenceId = sentences[currentIndex].id;
    try {
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

  void _nextSentence() {
    setState(() {
      if (currentIndex < sentences.length - 1) {
        currentIndex++;
      }
    });
  }

  void _prevSentence() {
    setState(() {
      if (currentIndex > 0) {
        currentIndex--;
      }
    });
  }

  Future<void> _startListening() async {
    await _checkPermissions();
    if (kIsWeb) {
      await _startWebMicRecordingIfPossible();
      if (_webMicRecorder == null) {
        final fallback = await captureAudioFromBrowser();
        if (fallback != null && fallback.bytes.isNotEmpty) {
          if (mounted) {
            setState(() {
              listeningStatusText = '녹음 업로드 평가 중...';
            });
          }
          await _evaluateRecognizedText(
            audioBytes: fallback.bytes,
            overrideContentType: fallback.mimeType,
            overrideFileName: fallback.fileName,
          );
          return;
        }
        final message = _buildWebMicInitErrorMessage() +
            '\n(대안) 파일 업로드 방식 녹음이 취소되었거나 실패했습니다.';
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
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            isListening = false;
            listeningStatusText = '음성 입력이 종료되었습니다.';
          });
          _stopLiveAudioAnalyzerIfPossible();
          _finalizeAndEvaluate();
        }
      },
      onError: (error) {
        setState(() {
          isListening = false;
          listeningStatusText = '음성 입력 오류: ${error.errorMsg}';
        });
        _stopLiveAudioAnalyzerIfPossible();
        _stopWebMicRecordingIfPossible();
        _showErrorDialog('음성 인식 오류: ${error.errorMsg}');
      },
    );

    if (!available) {
      setState(() {
        speechRecognitionSupported = false;
        listeningStatusText = '음성 입력 초기화에 실패했습니다.';
      });
      await _stopWebMicRecordingIfPossible();
      _showErrorDialog('이 기기에서는 음성 인식을 사용할 수 없습니다.');
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
        setState(() {
          recognizedText = val.recognizedWords;
          if (val.finalResult) {
            listeningStatusText = '입력 완료. 평가 중...';
          }
        });
      },
      listenFor: const Duration(seconds: 6),
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
      await _evaluateRecognizedText(audioBytes: _webAudioBytes);
    } finally {
      if (mounted) {
        setState(() => isEvaluatingAudio = false);
      }
      _isFinalizing = false;
    }
  }

  Future<void> _evaluateRecognizedText({
    Uint8List? audioBytes,
    String? overrideContentType,
    String? overrideFileName,
  }) async {
    final sentence = sentences[currentIndex];
    if (audioBytes == null || audioBytes.isEmpty) {
      _showErrorDialog('녹음된 음성이 없습니다. 다시 시도해 주세요.');
      return;
    }

    try {
      final contentType =
          overrideContentType ?? _detectAudioContentType(audioBytes);
      final result = await _api.evaluatePronunciation(
        sentenceId: sentence.id,
        referenceText: sentence.koreanSentence,
        recognizedText: '',
        audioBytes: audioBytes,
        fileName: overrideFileName ?? _buildAudioFileName(contentType),
        contentType: contentType,
      );
      await _applyEvaluationResult(sentence, result);
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

  Future<void> _applyEvaluationResult(
    AppSentence sentence,
    PronunciationEvaluationResult result,
  ) async {
    recognizedText = '음성 평가 완료';
    await _api.updateSentenceAccuracyAndText(
      sentence.id,
      result.accuracyRatio,
      result.transcript,
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('발음 평가 결과'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('점수: ${result.scorePercent.toStringAsFixed(2)}%'),
                const SizedBox(height: 6),
                Text(
                    '등급: ${result.scoreLevel.isEmpty ? '-' : result.scoreLevel}'),
                if (result.audioMetricsAvailable) ...[
                  const SizedBox(height: 6),
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
                ],
                const SizedBox(height: 8),
                Text('피드백: ${result.feedback}'),
                const SizedBox(height: 6),
                const Text(
                  '평가 기준: 피치 45% + 속도 35% + 음량 20% (음성 직접 비교)',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text('모델: ${result.model}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (currentIndex < sentences.length - 1) {
      _nextSentence();
    } else {
      _completeEvaluation();
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accent Evaluation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '현재 문장 평가기록 초기화',
            onPressed: _resetCurrentSentenceAttempts,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _completeEvaluation,
          ),
        ],
      ),
      body: FutureBuilder<List<AppSentence>>(
        future: futureSentences,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load sentences'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No sentences available'));
          }

          sentences = snapshot.data!;
          final currentSentence = sentences[currentIndex];

          return FutureBuilder<Chapter>(
            future: futureChapter,
            builder: (context, chapterSnapshot) {
              if (chapterSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (chapterSnapshot.hasError || !chapterSnapshot.hasData) {
                return const Center(child: Text('No chapter available'));
              }

              final chapter = chapterSnapshot.data!;

              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${chapter.id} #${chapter.title}',
                                style: const TextStyle(fontSize: 14)),
                            Text(
                              '난이도: ${chapter.difficulty} / 상황: ${chapter.contextTag}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (!kIsWeb && !speechRecognitionSupported) ...[
                              const SizedBox(height: 10),
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
                            Container(
                              color: Colors.grey[200],
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Text(currentSentence.koreanSentence,
                                      style: const TextStyle(fontSize: 24)),
                                  Text(
                                      ': ${currentSentence.northKoreanSentence}',
                                      style: const TextStyle(fontSize: 18)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('인식 결과: $recognizedText',
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 12),
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
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
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
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_isFinalizing || isEvaluatingAudio)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            if (currentIndex > 0)
                              ElevatedButton(
                                onPressed: _prevSentence,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  side: const BorderSide(color: Colors.black),
                                ),
                                child: const Text('이전',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            if (currentIndex < sentences.length - 1)
                              ElevatedButton(
                                onPressed: _nextSentence,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  side: const BorderSide(color: Colors.black),
                                ),
                                child: const Text('다음',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            if (currentIndex == sentences.length - 1)
                              ElevatedButton(
                                onPressed: _completeEvaluation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                child: const Text('평가 완료',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                          ],
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
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: const BorderRadius.only(
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
