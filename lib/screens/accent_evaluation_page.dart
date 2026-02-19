import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/models.dart';
import '../services/api_service.dart';
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
  String recognizedText = '';

  List<AppSentence> sentences = [];

  @override
  void initState() {
    super.initState();
    futureSentences = _api.fetchSentences(widget.chapterId);
    futureChapter = _api.fetchChapter(widget.chapterId);
    _speech = stt.SpeechToText();
  }

  Future<void> _checkPermissions() async {
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
    await _checkPermissions();

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => isListening = false);
          _evaluateRecognizedText();
        }
      },
      onError: (error) {
        setState(() => isListening = false);
        _showErrorDialog('음성 인식 오류: ${error.errorMsg}');
      },
    );

    if (!available) {
      _showErrorDialog('이 기기에서는 음성 인식을 사용할 수 없습니다.');
      return;
    }

    setState(() => isListening = true);
    _speech.listen(
      onResult: (val) {
        setState(() {
          recognizedText = val.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
      localeId: 'ko_KR',
    );
  }

  void _stopListening() {
    if (!isListening) return;
    setState(() => isListening = false);
    _speech.stop();
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
            Text('전사: ${result.transcript}'),
            const SizedBox(height: 6),
            Text('피드백: ${result.feedback}'),
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
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed: () => isListening
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
