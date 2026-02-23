// 필요한 패키지들을 임포트합니다.
import 'dart:convert';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'evaluation_result_page.dart';

// EvaluationLearningPage 클래스는 단어 평가 화면을 나타내는 StatefulWidget입니다.
class EvaluationLearningPage extends StatefulWidget {
  final int chapterId; // 챕터의 ID입니다.

  const EvaluationLearningPage({required this.chapterId, super.key});

  @override
  State<EvaluationLearningPage> createState() => _EvaluationLearningPageState();
}

// _EvaluationLearningPageState 클래스는 EvaluationLearningPage의 상태를 관리합니다.
class _EvaluationLearningPageState extends State<EvaluationLearningPage> {
  String get baseUrl => ApiService.baseUrl;

  late Future<List<Word>> futureWords; // 미래의 단어 리스트를 저장하는 변수입니다.
  late Future<Chapter> futureChapter; // 미래의 챕터 데이터를 저장하는 변수입니다.
  int currentIndex = 0; // 현재 단어의 인덱스를 나타냅니다.
  bool showPopup = false; // 팝업 표시 여부를 나타냅니다.
  String popupMessage = ""; // 팝업 메시지 내용을 저장합니다.
  bool isCorrectAnswer = false; // 정답 여부를 저장합니다.

  @override
  void initState() {
    super.initState();
    futureWords = ApiService().fetchWords(widget.chapterId); // 단어 데이터를 가져옵니다.
    futureChapter =
        ApiService().fetchChapter(widget.chapterId); // 챕터 데이터를 가져옵니다.
  }

  // 팝업을 표시하는 함수입니다.
  void _showPopup(String message, bool correct) {
    setState(() {
      popupMessage = message;
      isCorrectAnswer = correct;
      showPopup = true;
    });
  }

  // 사용자가 선택한 답을 평가하는 함수입니다.
  void _evaluateAnswer(String selectedWord) {
    futureWords.then((words) {
      if (selectedWord == words[currentIndex].koreanWord) {
        _updateWordIsCorrect(words[currentIndex].id, true, true);
        _showPopup("정답입니다!", true);
      } else {
        _updateWordIsCorrect(words[currentIndex].id, false, false);
        _showPopup("오답입니다!", false);
      }
    });
  }

  // 단어의 정답 여부를 업데이트하는 함수입니다.
  Future<void> _updateWordIsCorrect(
      int wordId, bool isCorrect, bool isCollect) async {
    final response = await http.post(
      Uri.parse('$baseUrl/words/$wordId/update/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'is_correct': isCorrect, 'is_collect': isCollect}),
    );

    if (response.statusCode == 200) {
      setState(() {
        futureWords = futureWords.then((words) {
          words[currentIndex].isCorrect = isCorrect;
          words[currentIndex].isCollect = isCollect;
          return words;
        });
      });
    } else {
      throw Exception('Failed to save word');
    }
  }

  // 다음 단어로 넘어가는 함수입니다.
  void _nextWord(List<Word> words) async {
    if (currentIndex < words.length - 1) {
      setState(() {
        currentIndex++;
        showPopup = false;
      });
    } else {
      // 마지막 단어일 때만 결과 페이지로 이동합니다.
      final chapterId = widget.chapterId;

      // 모든 단어의 is_called를 true로 업데이트합니다.
      for (var word in words) {
        if (!word.isCalled) {
          await ApiService().updateWordIsCalled(word.id);
        }
      }

      // 업데이트된 단어 리스트를 다시 불러옵니다.
      final updatedWords = await ApiService().fetchWords(chapterId);
      final progress = updatedWords.where((word) => word.isCalled).length /
          updatedWords.length *
          100;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EvaluationLearningResultPage(
            progress: progress,
            words: updatedWords,
            chapterId: chapterId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('단어 평가하기'), // 앱바의 제목입니다.
      ),
      body: FutureBuilder<List<Word>>(
        future: futureWords,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator()); // 로딩 중일 때 표시되는 위젯입니다.
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Failed to load words')); // 오류가 발생했을 때 표시되는 위젯입니다.
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text('No words available')); // 데이터가 없을 때 표시되는 위젯입니다.
          } else {
            List<Word> words = snapshot.data!;
            Word currentWord = words[currentIndex];
            return FutureBuilder<Chapter>(
              future: futureChapter,
              builder: (context, chapterSnapshot) {
                if (chapterSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                      child:
                          CircularProgressIndicator()); // 로딩 중일 때 표시되는 위젯입니다.
                } else if (chapterSnapshot.hasError) {
                  return Center(
                      child: Text(
                          'Failed to load chapter')); // 오류가 발생했을 때 표시되는 위젯입니다.
                } else if (!chapterSnapshot.hasData) {
                  return Center(
                      child: Text(
                          'No chapter available')); // 데이터가 없을 때 표시되는 위젯입니다.
                } else {
                  Chapter chapter = chapterSnapshot.data!;
                  List<String> options = [
                    currentWord.koreanWord,
                    "오답 1",
                    "오답 2"
                  ];
                  options.shuffle();
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
                              ],
                            ),
                          ),
                          Expanded(child: Container()),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: options.map((option) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: ElevatedButton(
                                    onPressed: () => _evaluateAnswer(
                                        option), // 버튼 클릭 시 답안을 평가합니다.
                                    child: Text(option,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      backgroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 50),
                                      side: BorderSide(color: Colors.black),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      if (showPopup)
                        Column(
                          children: [
                            Spacer(),
                            if (!isCorrectAnswer)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      showPopup = false;
                                    });
                                  },
                                  child: Text('다시 해보기',
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
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton(
                                onPressed: () =>
                                    _nextWord(words), // 다음 단어로 넘어갑니다.
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text('다음으로',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ),
                            Container(
                              height:
                                  (MediaQuery.of(context).size.height * 0.28)
                                      .clamp(170.0, 260.0)
                                      .toDouble(),
                              decoration: BoxDecoration(
                                color: isCorrectAnswer
                                    ? Colors.green
                                    : Colors.red, // 정답 여부에 따라 색상이 다릅니다.
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Center(
                                child: AnimatedTextKit(
                                  animatedTexts: [
                                    WavyAnimatedText(
                                      popupMessage,
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
