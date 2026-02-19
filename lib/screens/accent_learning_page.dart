import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
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
import '../services/tts_service.dart';
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

  int playCount = 0;

  @override
  void initState() {
    super.initState();
    futureSentences = _api.fetchSentences(widget.chapterId);
    futureChapter = _api.fetchChapter(widget.chapterId);
    audioPlayer = AudioPlayer();
    _speech = stt.SpeechToText();

    if (kIsWeb) {
      speechRecognitionSupported = hasWebSpeechRecognition;
      if (!speechRecognitionSupported) {
        listeningStatusText = isLikelySafari
            ? 'Safari에서는 웹 음성 입력이 제한될 수 있습니다.'
            : '현재 브라우저에서 웹 음성 입력을 사용할 수 없습니다.';
      }
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
    if (kIsWeb && !speechRecognitionSupported) {
      _showErrorDialog('이 브라우저에서는 음성 입력이 제한됩니다.');
      return;
    }

    await _checkPermissions();
    await _startWebMicRecordingIfPossible();

    final available = await _speech.initialize(
      onStatus: (val) {
        if (!mounted) return;
        setState(() {
          if (val == 'done' || val == 'notListening') {
            isListening = false;
            listeningStatusText = '음성 입력이 종료되었습니다.';
          }
        });
      },
      onError: (val) {
        if (!mounted) return;
        setState(() {
          isListening = false;
          listeningStatusText = '음성 입력 오류: ${val.errorMsg}';
        });
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
    });

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
      onSoundLevelChange: _onSoundLevelChange,
      listenOptions: stt.SpeechListenOptions(partialResults: true),
    );
  }

  Future<void> _stopListening() async {
    if (!isListening) return;
    setState(() {
      isListening = false;
      listeningStatusText = '음성 입력을 중지했습니다.';
    });
    await _speech.stop();
    await _finalizeAndEvaluate();
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
    } catch (_) {
      _webMicRecorder = null;
      _webAudioBytes = null;
    }
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
      await _stopWebMicRecordingIfPossible();
      if (recognizedText.trim().isNotEmpty) {
        await _evaluateSpeech(audioBytes: _webAudioBytes);
      }
    } finally {
      if (mounted) {
        setState(() => isEvaluatingAudio = false);
      }
      _isFinalizing = false;
    }
  }

  Future<void> _evaluateSpeech({Uint8List? audioBytes}) async {
    final recognized = recognizedText.trim();
    if (recognized.isEmpty) {
      _showErrorDialog('인식된 텍스트가 없습니다. 다시 시도해 주세요.');
      return;
    }

    final sentences = await futureSentences;
    final current = sentences[currentIndex];

    try {
      final result = await _api.evaluatePronunciation(
        sentenceId: current.id,
        referenceText: current.koreanSentence,
        recognizedText: recognized,
        audioBytes: audioBytes,
        fileName: 'mic_input',
        contentType: _detectAudioContentType(audioBytes),
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
    return 'audio/webm';
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
                  Text('전사: ${result.transcript}'),
                  const SizedBox(height: 8),
                  Text('피드백: ${result.feedback}'),
                  const SizedBox(height: 8),
                  Text(
                      '문자 유사도: ${(result.charSimilarity * 100).toStringAsFixed(1)}%'),
                  Text(
                      '핵심 단어 일치율: ${(result.tokenSimilarity * 100).toStringAsFixed(1)}%'),
                  const SizedBox(height: 8),
                  Text(
                      '텍스트 점수: ${(result.textScore * 100).toStringAsFixed(1)}%'),
                  if (result.audioMetricsAvailable) ...[
                    const SizedBox(height: 8),
                    Text(
                        '속도 점수: ${((result.speedScore ?? 0) * 100).toStringAsFixed(1)}%'),
                    Text(
                        '피치 점수: ${((result.pitchScore ?? 0) * 100).toStringAsFixed(1)}%'),
                    Text(
                        '음성 길이: ${(result.audioDurationSec ?? 0).toStringAsFixed(2)}초 / 말속도: ${(result.syllablesPerSec ?? 0).toStringAsFixed(2)}음절/초'),
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
                  Text(
                    result.audioMetricsAvailable
                        ? '평가 기준: 텍스트 60% + 속도 20% + 피치 20%'
                        : '평가 기준: 문자 유사도 75% + 핵심 단어 일치율 25%',
                    style: const TextStyle(fontSize: 12),
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
    _speech.stop();
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            if (kIsWeb && !speechRecognitionSupported) ...[
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
                                  isLikelySafari
                                      ? 'Safari에서는 웹 음성인식이 제한될 수 있습니다.'
                                      : '현재 브라우저에서는 웹 음성인식이 제한될 수 있습니다.',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Image.asset(
                              'assets/images/${currentSentence.koreanSentence}.png',
                              width: double.infinity,
                              height:
                                  (MediaQuery.of(context).size.height * 0.26)
                                      .clamp(140.0, 220.0)
                                      .toDouble(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Text(
                                  'Error loading image',
                                  style: TextStyle(color: Colors.red),
                                );
                              },
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
                                    '직접 말하기(마이크): 텍스트 60% + 속도 20% + 피치 20%',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                if (currentSentence.isCorrect) {
                                  setState(
                                      () => currentSentence.isCorrect = false);
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
                                onPressed: () => setState(() => currentIndex--),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  side: const BorderSide(color: Colors.black),
                                ),
                                child: const Text(
                                  '이전',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (currentIndex < sentences.length - 1)
                              ElevatedButton(
                                onPressed: () => _nextSentence(sentences),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  side: const BorderSide(color: Colors.black),
                                ),
                                child: const Text(
                                  '다음',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            if (currentIndex == sentences.length - 1)
                              ElevatedButton(
                                onPressed: _completeLearning,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: const Size(double.infinity, 50),
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
                              onPressed: (kIsWeb && !speechRecognitionSupported)
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
                            if (_isFinalizing || isEvaluatingAudio)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(minHeight: 2),
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
