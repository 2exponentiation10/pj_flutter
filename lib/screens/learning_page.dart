import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'accent_learning_page.dart';
import 'sentence_learning_page.dart';
import 'word_learning_page.dart';

class LearningPage extends StatefulWidget {
  @override
  _LearningPageState createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  late Future<List<Chapter>> futureChapters;
  String _difficultyFilter = 'all';

  @override
  void initState() {
    super.initState();
    futureChapters = ApiService().fetchChapters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학습하기')),
      body: GradientPage(
        child: FutureBuilder<List<Chapter>>(
          future: futureChapters,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('챕터를 불러오지 못했습니다.'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('학습 가능한 챕터가 없습니다.'));
            }

            final allChapters = snapshot.data!;
            final chapters = _difficultyFilter == 'all'
                ? allChapters
                : allChapters
                    .where((c) => c.difficulty == _difficultyFilter)
                    .toList();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              itemCount: chapters.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip('전체', 'all'),
                      _filterChip('초급', 'beginner'),
                      _filterChip('중급', 'intermediate'),
                      _filterChip('고급', 'advanced'),
                    ],
                  );
                }
                final chapter = chapters[index - 1];
                final colorScheme = Theme.of(context).colorScheme;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '챕터 ${chapter.id} · ${chapter.title}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${chapter.title} 주제로 학습을 진행합니다. (${chapter.difficulty}/${chapter.contextTag})',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        ActionTile(
                          title: '유닛 1. 단어 학습',
                          subtitle: '${chapter.title} 기본 어휘',
                          icon: Icons.spellcheck_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    WordLearningPage(chapterId: chapter.id),
                              ),
                            );
                          },
                        ),
                        ActionTile(
                          title: '유닛 2. 문장 학습',
                          subtitle: '${chapter.title} 실전 문장',
                          icon: Icons.short_text_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SentenceLearningPage(chapterId: chapter.id),
                              ),
                            );
                          },
                        ),
                        ActionTile(
                          title: '유닛 3. 억양 학습',
                          subtitle: '${chapter.title} 발화 연습',
                          icon: Icons.graphic_eq_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AccentLearningPage(chapterId: chapter.id),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _difficultyFilter == value,
      onSelected: (_) {
        setState(() {
          _difficultyFilter = value;
        });
      },
    );
  }
}
