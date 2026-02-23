import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/texttospeech/v1.dart' as tts;
import 'package:onsaemiro/screens/word_learning_result_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animated_text_kit/animated_text_kit.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../models/models.dart';
import '../widgets/custom_widgets.dart';

class WordLearningPage extends StatefulWidget {
  final int chapterId;

  const WordLearningPage({required this.chapterId, super.key});

  @override
  State<WordLearningPage> createState() => _WordLearningPageState();
}

class _WordLearningPageState extends State<WordLearningPage> {
  late Future<List<Word>> futureWords;
  late Future<Chapter> futureChapter;
  int currentIndex = 0;
  late AudioPlayer audioPlayer;
  bool isPlaying = false;
  int playCount = 0;

  @override
  void initState() {
    super.initState();
    futureWords = ApiService().fetchWords(widget.chapterId);
    futureChapter =
        ApiService().fetchChapter(widget.chapterId); // 챕터 제목을 가져오는 Future 초기화
    audioPlayer = AudioPlayer();
  }

  Future<AutoRefreshingAuthClient> _getAuthClient() async {
    try {
      final serviceAccountJson =
          await rootBundle.loadString('assets/service_account.json');
      final credentials =
          ServiceAccountCredentials.fromJson(serviceAccountJson);
      final scopes = [tts.TexttospeechApi.cloudPlatformScope];
      return clientViaServiceAccount(credentials, scopes);
    } catch (e) {
      print('Error loading service account credentials: $e');
      rethrow;
    }
  }

  Future<void> _playTextToSpeech(String text) async {
    if (kIsWeb) {
      final ok = await TtsService.speak(text, rate: 0.9);
      if (ok) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('웹 브라우저 TTS를 사용할 수 없습니다.')),
      );
      return;
    }
    try {
      final authClient = await _getAuthClient();
      final ttsApi = tts.TexttospeechApi(authClient);

      final input = tts.SynthesizeSpeechRequest(
        input: tts.SynthesisInput(text: text),
        voice: tts.VoiceSelectionParams(
            languageCode: 'ko-KR', name: 'ko-KR-Wavenet-D'),
        audioConfig:
            tts.AudioConfig(audioEncoding: 'MP3', speakingRate: 0.9), // 속도 조절
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
      final fallbackOk = await TtsService.speak(text, rate: 0.9);
      if (!fallbackOk && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음성 재생에 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _playAudioFile(String filePath) async {
    await audioPlayer.play(DeviceFileSource(filePath)); // DeviceFileSource 사용
    audioPlayer.onPlayerComplete.listen((event) async {
      playCount++;
      if (playCount < 2) {
        await audioPlayer
            .play(DeviceFileSource(filePath)); // DeviceFileSource 사용
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

  Future<void> _saveWord(int wordId) async {
    final response =
        await http.post(Uri.parse('${ApiService.baseUrl}/words/$wordId/save/'));

    if (response.statusCode == 200) {
      setState(() {
        // Update the word in the current list
        futureWords = futureWords.then((words) {
          words[currentIndex].isCorrect = true;
          return words;
        });
      });
    } else {
      throw Exception('Failed to save word');
    }
  }

  Future<void> _updateWordIsCalled(int wordId) async {
    await ApiService().updateWordIsCalled(wordId);
  }

  void _nextWord(List<Word> words) async {
    await _updateWordIsCalled(words[currentIndex].id);
    setState(() {
      if (currentIndex < words.length - 1) {
        currentIndex++;
      }
    });
  }

  void _completeLearning() async {
    final words = await ApiService().fetchWords(widget.chapterId);

    // 모든 단어의 is_called를 true로 업데이트
    for (var word in words) {
      if (!word.isCalled) {
        await ApiService().updateWordIsCalled(word.id);
      }
    }

    // 업데이트된 단어 리스트 다시 불러오기
    final updatedWords = await ApiService().fetchWords(widget.chapterId);
    final progress = updatedWords.where((word) => word.isCalled).length /
        updatedWords.length *
        100;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WordLearningResultPage(
          progress: progress,
          words: updatedWords,
          chapterId: widget.chapterId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFDFF3FA),
      appBar: AppBar(
        title: Text('Word Learning'),
      ),
      body: FutureBuilder<List<Word>>(
        future: futureWords,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Failed to load words'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No words available'));
          } else {
            List<Word> words = snapshot.data!;
            Word currentWord = words[currentIndex];
            return FutureBuilder<Chapter>(
              future: futureChapter,
              builder: (context, chapterSnapshot) {
                if (chapterSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (chapterSnapshot.hasError) {
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
                                Text('#${chapter.id} #${chapter.title}',
                                    style: TextStyle(fontSize: 14)),
                                SizedBox(height: 10),
                                ManagedImage(
                                  imageUrl: currentWord.imageUrl,
                                  fallbackAssetPath:
                                      'assets/images/${currentWord.koreanWord}.png',
                                  width: double.infinity,
                                  height: (MediaQuery.of(context).size.height *
                                          0.26)
                                      .clamp(140.0, 220.0)
                                      .toDouble(),
                                ),
                                SizedBox(height: 10),
                                Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(currentWord.koreanWord,
                                            style: TextStyle(fontSize: 24)),
                                        Text(': ${currentWord.northKoreanWord}',
                                            style: TextStyle(fontSize: 18)),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text('Greetings',
                                    style: TextStyle(fontSize: 16)),
                                SizedBox(height: 5),
                                Text('${words.length} words',
                                    style: TextStyle(fontSize: 14)),
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
                                    if (currentWord.isCorrect) {
                                      setState(() {
                                        currentWord.isCorrect = false;
                                      });
                                    } else {
                                      _saveWord(currentWord.id);
                                    }
                                  },
                                  child: Text(
                                      currentWord.isCorrect ? '저장됨' : '저장하기',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: currentWord.isCorrect
                                        ? Colors.black
                                        : Colors.white,
                                    foregroundColor: currentWord.isCorrect
                                        ? Colors.white
                                        : Colors.black,
                                    minimumSize: Size(double.infinity, 50),
                                    side: currentWord.isCorrect
                                        ? null
                                        : BorderSide(color: Colors.black),
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
                                    child: Text('이전',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      backgroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 50),
                                      side: BorderSide(color: Colors.black),
                                    ),
                                  ),
                                SizedBox(height: 10),
                                if (currentIndex < words.length - 1)
                                  ElevatedButton(
                                    onPressed: () {
                                      _nextWord(words);
                                    },
                                    child: Text('다음',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      backgroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 50),
                                      side: BorderSide(color: Colors.black),
                                    ),
                                  ),
                                if (currentIndex == words.length - 1)
                                  ElevatedButton(
                                    onPressed: _completeLearning,
                                    child: Text('완료하기',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      minimumSize: Size(double.infinity, 50),
                                    ),
                                  ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () =>
                                      _playTextToSpeech(currentWord.koreanWord),
                                  child: Text('음성 듣기',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
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
                      if (isPlaying)
                        Column(
                          children: [
                            Spacer(),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton(
                                onPressed: _stopTextToSpeech,
                                child: Text('듣기 중지하기',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height:
                                  (MediaQuery.of(context).size.height * 0.28)
                                      .clamp(170.0, 260.0)
                                      .toDouble(),
                              decoration: BoxDecoration(
                                color: Colors.blue
                                    .withOpacity(1.0), // 완전히 불투명하게 설정
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Center(
                                child: AnimatedTextKit(
                                  animatedTexts: [
                                    WavyAnimatedText(
                                      '음성을 듣고 있어요!',
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
