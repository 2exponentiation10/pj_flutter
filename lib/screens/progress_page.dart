import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'evaluation_learning_result_page.dart';
import 'learning_result_page.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late Future<ProgressData> _futureProgressData;

  @override
  void initState() {
    super.initState();
    _futureProgressData = ApiService().fetchProgressData();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureProgressData = ApiService().fetchProgressData();
    });
    await _futureProgressData;
  }

  Future<void> _showEvaluationResult(int chapterId) async {
    try {
      final words = await ApiService().fetchWords(chapterId);
      final sentences = await ApiService().fetchSentences(chapterId);
      final total = words.length + sentences.length;
      final progress = total == 0
          ? 0.0
          : (words.where((word) => word.isCollect).length +
                  sentences.where((sentence) => sentence.isCollect).length) /
              total *
              100;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EvaluationLearningResultPage(
            progress: progress,
            words: words,
            sentences: sentences,
            chapterId: chapterId,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('평가 결과를 불러오지 못했습니다.')),
      );
    }
  }

  Future<void> _showLearningResult(int chapterId) async {
    try {
      final words = await ApiService().fetchWords(chapterId);
      final sentences = await ApiService().fetchSentences(chapterId);
      final total = words.length + sentences.length;
      final progress = total == 0
          ? 0.0
          : (words.where((word) => word.isCalled).length +
                  sentences.where((sentence) => sentence.isCalled).length) /
              total *
              100;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LearningResultPage(
            progress: progress,
            words: words,
            sentences: sentences,
            chapterId: chapterId,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습 결과를 불러오지 못했습니다.')),
      );
    }
  }

  Widget _buildChapterCard(ChapterProgress chapter) {
    final learningRatio = chapter.totalItems == 0
        ? 0.0
        : chapter.calledItems / chapter.totalItems;
    final evalRatio = chapter.totalItems == 0
        ? 0.0
        : chapter.collectItems / chapter.totalItems;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter.chapterTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '아이템 ${chapter.calledItems}/${chapter.totalItems} 학습 완료 · 평가 ${chapter.collectItems}/${chapter.totalItems}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              '학습 진행률 ${chapter.progress.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: learningRatio.clamp(0.0, 1.0)),
            const SizedBox(height: 10),
            Text(
              '평가 정확도 ${chapter.accuracy.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: evalRatio.clamp(0.0, 1.0),
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLearningResult(chapter.chapterId),
                    icon: const Icon(Icons.school_rounded),
                    label: const Text('학습 결과'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showEvaluationResult(chapter.chapterId),
                    icon: const Icon(Icons.fact_check_rounded),
                    label: const Text('평가 결과'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientPage(
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<ProgressData>(
          future: _futureProgressData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  const HeroIntroCard(
                    eyebrow: 'Progress',
                    title: '진행도 데이터를 불러오지 못했어요',
                    description: '네트워크 상태를 확인하고 다시 시도해 주세요.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('다시 시도'),
                  ),
                ],
              );
            }

            final progressData = snapshot.data;
            if (progressData == null || progressData.progressData.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  const HeroIntroCard(
                    eyebrow: 'Progress',
                    title: '아직 학습 데이터가 없습니다',
                    description: '챕터 학습을 시작하면 진행도와 평가 결과가 쌓입니다.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('새로고침'),
                  ),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: '완료 챕터',
                          value: '${progressData.completedChapters}',
                          icon: Icons.menu_book_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: '평균 평가 점수',
                          value:
                              progressData.overallProgress.toStringAsFixed(0),
                          icon: Icons.analytics_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SectionTitle(
                    title: '챕터별 진행 현황',
                    subtitle: '아래에서 학습/평가 결과를 바로 확인할 수 있습니다.',
                  ),
                  ...progressData.progressData.map(_buildChapterCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
