import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/texttospeech/v1.dart' as tts;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'rouge_l.dart';
import 'accent_learning_result_page.dart'; // 새로운 페이지 파일을 임포트합니다.

class AccentLearningPage extends StatefulWidget {
  final int chapterId;

  AccentLearningPage({required this.chapterId});

  @override
  _AccentLearningPageState createState() => _AccentLearningPageState();
}

class _AccentLearningPageState extends State<AccentLearningPage> {
  late Future<List<AppSentence>> futureSentences;
  late Future<Chapter> futureChapter;
  int currentIndex = 0;
  late AudioPlayer audioPlayer;
  late stt.SpeechToText _speech;
  bool isListening = false;
  bool isPlaying = false;
  String recognizedText = '';
  int playCount = 0;

  @override
  void initState() {
    super.initState();
    futureSentences = ApiService().fetchSentences(widget.chapterId);
    futureChapter = ApiService().fetchChapter(widget.chapterId);
    audioPlayer = AudioPlayer();
    _speech = stt.SpeechToText();
  }

  Future<void> _checkPermissions() async {
    if (await Permission.microphone.request().isGranted) {
      print('Microphone permission granted');
    } else {
      print('Microphone permission denied');
    }
  }

  Future<AutoRefreshingAuthClient> _getAuthClient() async {
    try {
      final serviceAccountJson = await rootBundle.loadString('assets/service_account.json');
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      final scopes = [tts.TexttospeechApi.cloudPlatformScope];
      return clientViaServiceAccount(credentials, scopes);
    } catch (e) {
      print('Error loading service account credentials: $e');
      rethrow;
    }
  }

  Future<void> _playTextToSpeech(String text) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('웹 버전에서는 현재 TTS 기능이 비활성화되어 있습니다.')),
      );
      return;
    }
    try {
      final authClient = await _getAuthClient();
      final ttsApi = tts.TexttospeechApi(authClient);

      final input = tts.SynthesizeSpeechRequest(
        input: tts.SynthesisInput(text: text),
        voice: tts.VoiceSelectionParams(languageCode: 'ko-KR', name: 'ko-KR-Wavenet-D'),
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
    } catch (e) {
      print('Error occurred: $e');
    }
  }

  Future<void> _playAudioFile(String filePath) async {
    await audioPlayer.play(DeviceFileSource(filePath)); // 반환값을 확인할 필요 없음

    audioPlayer.onPlayerComplete.listen((event) async {
      playCount++;
      if (playCount < 2) {
        await audioPlayer.play(DeviceFileSource(filePath));
      } else {
        await Future.delayed(Duration(seconds: 1)); // 팝업을 더 길게 유지
        setState(() {
          isPlaying = false;
        });
      }
    });
  }

  Future<void> _stopTextToSpeech() async {
    await audioPlayer.stop();
    setState(() {
      isPlaying = false;
    });
  }

  Future<void> _saveSentence(int sentenceId) async {
    final response = await http.post(Uri.parse('${ApiService.baseUrl}/sentences/$sentenceId/save/'));

    if (response.statusCode == 200) {
      setState(() {
        futureSentences = futureSentences.then((sentences) {
          sentences[currentIndex].isCorrect = true;
          return sentences;
        });
      });
    } else {
      throw Exception('Failed to save sentence');
    }
  }

  Future<void> _updateSentenceIsCalled(int sentenceId) async {
    await ApiService().updateSentenceIsCalled(sentenceId);
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
    final sentences = await ApiService().fetchSentences(widget.chapterId);

    for (var sentence in sentences) {
      if (!sentence.isCalled) {
        await ApiService().updateSentenceIsCalled(sentence.id);
      }
    }

    final updatedSentences = await ApiService().fetchSentences(widget.chapterId);
    final progress = updatedSentences.where((sentence) => sentence.isCalled).length / updatedSentences.length * 100;

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

  void _startListening() async {
    await _checkPermissions(); // 권한 확인

    bool available = await _speech.initialize(
      onStatus: (val) {
        print('onStatus: $val');
        setState(() {
          if (val == 'done' || val == 'notListening') {
            isListening = false;
          }
        });
      },
      onError: (val) {
        print('onError: $val');
        setState(() {
          isListening = false;
        });
      },
    );
    if (available) {
      setState(() => isListening = true);
      _speech.listen(
        onResult: (val) {
          print('onResult: ${val.recognizedWords}');
          setState(() {
            recognizedText = val.recognizedWords;
            _evaluateSpeech();
          });
        },
        listenFor: Duration(seconds: 5),
        pauseFor: Duration(seconds: 3),
        partialResults: false,
        localeId: 'ko_KR',
        onSoundLevelChange: (level) {
          print('Sound level: $level');
        },
      );
    } else {
      setState(() => isListening = false);
      _speech.stop();
    }
  }

  void _stopListening() {
    if (!isListening) return; // 이미 listening 상태가 아니면 return
    setState(() => isListening = false);
    _speech.stop();
  }

  void _evaluateSpeech() {
    futureSentences.then((sentences) {
      final referenceText = sentences[currentIndex].koreanSentence;
      final result = calculateRougeL(referenceText, recognizedText);
      final score = result['f1Score']!;
      final precision = result['precision']!;
      final recall = result['recall']!;
      _showEvaluationPopup(score, precision, recall);
    });
  }

  void _showEvaluationPopup(double score, double precision, double recall) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
      return AlertDialog(
          title: Text('평가 결과'),
    content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    Text('억양 정확도: ${(score * 100).toStringAsFixed(2)}%'),
    SizedBox(height: 10),
    Text('Precision: ${(precision * 100).toStringAsFixed(2)}%'),
    SizedBox(height: 10),
    Text('Recall: ${(recall * 100).toStringAsFixed(2)}%'),
    SizedBox(height: 10),
    Text('인식된 내용: $recognizedText'),
    ],
    ),
        actions: <Widget>[
          TextButton(
            child: Text('닫기'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFDFF3FA),
      appBar: AppBar(
        title: Text('Accent Learning'),
      ),
      body: FutureBuilder<List<AppSentence>>(
        future: futureSentences,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print('Error fetching sentences: ${snapshot.error}');
            return Center(child: Text('Failed to load sentences'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No sentences available'));
          } else {
            List<AppSentence> sentences = snapshot.data!;
            AppSentence currentSentence = sentences[currentIndex];
            return FutureBuilder<Chapter>(
              future: futureChapter,
              builder: (context, chapterSnapshot) {
                if (chapterSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (chapterSnapshot.hasError) {
                  print('Error fetching chapter: ${chapterSnapshot.error}');
                  return Center(child: Text('Failed to load chapter'));
                } else if (!chapterSnapshot.hasData) {
                  return Center(child: Text('No chapter available'));
                } else {
                  Chapter chapter = chapterSnapshot.data!;
                  return Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('#${chapter.id} #${chapter.title}', style: TextStyle(fontSize: 14)),
                                SizedBox(height: 10),
                                Image.asset(
                                  'assets/images/${currentSentence.koreanSentence}.png',
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text('Error loading image', style: TextStyle(color: Colors.red));
                                  },
                                ),
                                SizedBox(height: 10),
                                Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(currentSentence.koreanSentence, style: TextStyle(fontSize: 24)),
                                        Text(': ${currentSentence.northKoreanSentence}', style: TextStyle(fontSize: 18)),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text('Greetings', style: TextStyle(fontSize: 16)),
                                SizedBox(height: 5),
                                Text('${sentences.length} sentences', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          Expanded(child: Container()),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    if (currentSentence.isCorrect) {
                                      setState(() {
                                        currentSentence.isCorrect = false;
                                      });
                                    } else {
                                      _saveSentence(currentSentence.id);
                                    }
                                  },
                                  child: Text(currentSentence.isCorrect ? '저장됨' : '저장하기', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: currentSentence.isCorrect ? Colors.black : Colors.white,
                                    foregroundColor: currentSentence.isCorrect ? Colors.white : Colors.black,
                                    minimumSize: Size(double.infinity, 50),
                                    side: currentSentence.isCorrect ? null : BorderSide(color: Colors.black),
                                  ),
                                ),
                                SizedBox(height: 10),
                                if (currentIndex > 0)
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        currentIndex--;
                                      });
                                    },
                                    child: Text('이전', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.black, backgroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 50),
                                      side: BorderSide(color: Colors.black),
                                    ),
                                  ),
                                SizedBox(height: 10),
                                if (currentIndex < sentences.length - 1)
                                  ElevatedButton(
                                    onPressed: () {
                                      _nextSentence(sentences);
                                    },
                                    child: Text('다음', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.black, backgroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 50),
                                      side: BorderSide(color: Colors.black),
                                    ),
                                  ),
                                if (currentIndex == sentences.length - 1)
                                  ElevatedButton(
                                    onPressed: _completeLearning,
                                    child: Text('완료하기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      minimumSize: Size(double.infinity, 50),
                                    ),
                                  ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () => _playTextToSpeech(currentSentence.koreanSentence),
                                  child: Text('음성 듣기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    minimumSize: Size(double.infinity, 50),
                                  ),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () => isListening ? _stopListening() : _startListening(),
                                  child: Text(isListening ? '듣기 중지하기' : '직접 말하기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    minimumSize: Size(double.infinity, 50),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isListening)
                        Column(
                          children: [
                            Spacer(),
                            Container(
                              height: MediaQuery.of(context).size.height / 3,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(1.0),
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
                                      textStyle: TextStyle(
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
                }
              },
            );
          }
        },
      ),
    );
  }
}
