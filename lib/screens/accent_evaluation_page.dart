import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/browser_capability.dart';
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

  int currentIndex = 0;
  bool isListening = false;
  bool isEvaluatingAudio = false;
  bool isEvaluatingManualText = false;
  bool speechRecognitionSupported = true;
  String recognizedText = '';
  String listeningStatusText = '직접 말하기를 눌러 음성 입력을 시작하세요.';
  final TextEditingController _manualController = TextEditingController();

  List<AppSentence> sentences = [];

  @override
  void initState() {
    super.initState();
    futureSentences = _api.fetchSentences(widget.chapterId);
    futureChapter = _api.fetchChapter(widget.chapterId);
    _speech = stt.SpeechToText();
    if (kIsWeb) {
      speechRecognitionSupported = hasWebSpeechRecognition;
      if (!speechRecognitionSupported) {
        listeningStatusText = isLikelySafari
            ? 'Safari에서는 웹 음성 입력이 제한될 수 있습니다. 텍스트 입력/오디오 업로드를 사용해 주세요.'
            : '현재 브라우저에서 웹 음성 입력을 사용할 수 없습니다.';
      }
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
    if (kIsWeb && !speechRecognitionSupported) {
      _showErrorDialog('이 브라우저에서는 음성 입력이 제한됩니다. 텍스트 입력 또는 음성 파일 업로드를 사용해 주세요.');
      return;
    }

    await _checkPermissions();

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            isListening = false;
            listeningStatusText = '음성 입력이 종료되었습니다.';
          });
          _evaluateRecognizedText();
        }
      },
      onError: (error) {
        setState(() {
          isListening = false;
          listeningStatusText = '음성 입력 오류: ${error.errorMsg}';
        });
        _showErrorDialog('음성 인식 오류: ${error.errorMsg}');
      },
    );

    if (!available) {
      setState(() {
        speechRecognitionSupported = false;
        listeningStatusText = '음성 입력 초기화에 실패했습니다. 텍스트 입력/오디오 업로드를 사용해 주세요.';
      });
      _showErrorDialog('이 기기에서는 음성 인식을 사용할 수 없습니다.');
      return;
    }

    setState(() {
      isListening = true;
      recognizedText = '';
      listeningStatusText = '음성 입력 중... 또박또박 말해 주세요.';
    });
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
      listenOptions: stt.SpeechListenOptions(partialResults: true),
    );
  }

  void _stopListening() {
    if (!isListening) return;
    setState(() {
      isListening = false;
      listeningStatusText = '음성 입력을 중지했습니다.';
    });
    _speech.stop();
  }

  Future<void> _evaluateManualText() async {
    if (isEvaluatingManualText) return;
    final text = _manualController.text.trim();
    if (text.isEmpty) {
      _showErrorDialog('평가할 텍스트를 먼저 입력해 주세요.');
      return;
    }
    setState(() {
      recognizedText = text;
      isEvaluatingManualText = true;
      listeningStatusText = '텍스트 기반 평가 중...';
    });
    try {
      await _evaluateRecognizedText();
    } finally {
      if (mounted) {
        setState(() => isEvaluatingManualText = false);
      }
    }
  }

  Future<void> _evaluateRecognizedText() async {
    final sentence = sentences[currentIndex];
    if (recognizedText.trim().isEmpty) {
      _showErrorDialog('인식된 텍스트가 없습니다. 다시 시도해 주세요.');
      return;
    }

    try {
      final result = await _api.evaluatePronunciation(
        sentenceId: sentence.id,
        referenceText: sentence.koreanSentence,
        recognizedText: recognizedText,
      );
      await _applyEvaluationResult(sentence, result);
    } catch (e) {
      _showErrorDialog('평가 요청 실패: $e');
    }
  }

  Future<void> _pickAudioAndEvaluate() async {
    final sentence = sentences[currentIndex];

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['webm', 'wav', 'mp3', 'm4a', 'ogg'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showErrorDialog('파일 데이터를 읽지 못했습니다.');
      return;
    }

    setState(() => isEvaluatingAudio = true);
    try {
      final result = await _api.evaluatePronunciation(
        sentenceId: sentence.id,
        referenceText: sentence.koreanSentence,
        audioBytes: bytes,
        fileName: file.name,
        contentType: _mimeTypeFromName(file.name),
      );
      await _applyEvaluationResult(sentence, result);
    } catch (e) {
      _showErrorDialog('오디오 평가 실패: $e');
    } finally {
      if (mounted) {
        setState(() => isEvaluatingAudio = false);
      }
    }
  }

  String _mimeTypeFromName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/webm';
  }

  Future<void> _applyEvaluationResult(
    AppSentence sentence,
    PronunciationEvaluationResult result,
  ) async {
    recognizedText = result.transcript;
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('점수: ${result.scorePercent.toStringAsFixed(2)}%'),
            const SizedBox(height: 6),
            Text('등급: ${result.scoreLevel.isEmpty ? '-' : result.scoreLevel}'),
            const SizedBox(height: 6),
            Text(
                '문자 유사도: ${(result.charSimilarity * 100).toStringAsFixed(1)}%'),
            Text(
                '핵심 단어 일치율: ${(result.tokenSimilarity * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 6),
            Text('텍스트 점수: ${(result.textScore * 100).toStringAsFixed(1)}%'),
            if (result.audioMetricsAvailable) ...[
              const SizedBox(height: 6),
              Text(
                  '속도 점수: ${((result.speedScore ?? 0) * 100).toStringAsFixed(1)}%'),
              Text(
                  '피치 점수: ${((result.pitchScore ?? 0) * 100).toStringAsFixed(1)}%'),
              Text(
                  '음성 길이: ${(result.audioDurationSec ?? 0).toStringAsFixed(2)}초 / 말속도: ${(result.syllablesPerSec ?? 0).toStringAsFixed(2)}음절/초'),
              Text(
                  '피치 중앙값: ${(result.pitchMedianHz ?? 0).toStringAsFixed(1)}Hz / 변동성: ${(result.pitchStdHz ?? 0).toStringAsFixed(1)}Hz'),
            ],
            Text('전사: ${result.transcript}'),
            const SizedBox(height: 6),
            Text('피드백: ${result.feedback}'),
            const SizedBox(height: 6),
            Text(
              result.audioMetricsAvailable
                  ? '평가 기준: 텍스트 60% + 속도 20% + 피치 20%'
                  : '평가 기준: 문자 유사도 75% + 핵심 단어 일치율 25%',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text('모델: ${result.model}', style: const TextStyle(fontSize: 12)),
          ],
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
    _speech.stop();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accent Evaluation'),
        actions: [
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
                            if (kIsWeb && !speechRecognitionSupported) ...[
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
                                  isLikelySafari
                                      ? 'Safari에서는 웹 음성인식이 제한됩니다. 아래 텍스트 평가 또는 음성 파일 업로드를 사용하세요.'
                                      : '현재 브라우저에서는 웹 음성인식이 제한됩니다. 텍스트 평가/음성 파일 업로드를 사용하세요.',
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
                                    '오디오 업로드 시: 텍스트 60% + 속도 20% + 피치 20%',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '텍스트만 평가 시: 문자 유사도 75% + 핵심 단어 일치율 25%',
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
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _manualController,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: '직접 말한 문장을 텍스트로 입력해 평가할 수 있습니다.',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: isEvaluatingManualText
                                  ? null
                                  : _evaluateManualText,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: Text(
                                isEvaluatingManualText
                                    ? '텍스트 평가 중...'
                                    : '텍스트로 평가하기',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: isEvaluatingAudio
                                  ? null
                                  : _pickAudioAndEvaluate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: Text(
                                isEvaluatingAudio
                                    ? '오디오 평가 중...'
                                    : '음성 파일 업로드 평가',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 10),
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
