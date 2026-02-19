import 'package:flutter/material.dart';
import 'dart:math';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class LibraryPage extends StatefulWidget {
  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<Word>> futureWords;
  late Future<List<AppSentence>> futureSentences;
  bool _showAllWords = false;
  bool _showAllSentences = false;

  @override
  void initState() {
    super.initState();
    futureWords = ApiService().fetchSavedWords();
    futureSentences = ApiService().fetchSavedSentences();
  }

  @override
  Widget build(BuildContext context) {
    return GradientPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          const SectionTitle(
            title: '저장된 단어',
            subtitle: '학습 중 저장한 단어를 복습해보세요.',
          ),
          FutureBuilder<List<Word>>(
            future: futureWords,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text('단어 목록을 불러오지 못했습니다.');
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('저장된 단어가 없습니다.');
              }

              final words = snapshot.data!;
              final count = _showAllWords ? words.length : min(words.length, 3);
              return Column(
                children: [
                  for (int i = 0; i < count; i++)
                    ActionTile(
                      title: words[i].koreanWord,
                      subtitle: words[i].northKoreanWord,
                      icon: Icons.bookmark_rounded,
                      onTap: () {},
                    ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAllWords = !_showAllWords),
                    child: Text(_showAllWords ? '간략히 보기' : '모두 보기'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const SectionTitle(
            title: '저장된 문장',
            subtitle: '자주 틀렸던 문장을 다시 확인해보세요.',
          ),
          FutureBuilder<List<AppSentence>>(
            future: futureSentences,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text('문장 목록을 불러오지 못했습니다.');
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('저장된 문장이 없습니다.');
              }

              final sentences = snapshot.data!;
              final count = _showAllSentences
                  ? sentences.length
                  : min(sentences.length, 3);

              return Column(
                children: [
                  for (int i = 0; i < count; i++)
                    ActionTile(
                      title: sentences[i].koreanSentence,
                      subtitle: sentences[i].northKoreanSentence,
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () {},
                    ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAllSentences = !_showAllSentences),
                    child: Text(_showAllSentences ? '간략히 보기' : '모두 보기'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
