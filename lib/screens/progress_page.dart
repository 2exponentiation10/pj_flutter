import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'evaluation_learning_result_page.dart';
import 'learning_result_page.dart';

class ProgressPage extends StatefulWidget {
  @override
  _ProgressPageState createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late Future<ProgressData> futureProgressData;

  @override
  void initState() {
    super.initState();
    futureProgressData = ApiService().fetchProgressData();
  }

  void _showEvaluationResult(int chapterId) async {
    try {
      final words = await ApiService().fetchWords(chapterId);
      final sentences = await ApiService().fetchSentences(chapterId);
      final progress = (words.where((word) => word.isCollect).length +
              sentences.where((sentence) => sentence.isCollect).length) /
          (words.length + sentences.length) *
          100;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('평가 결과를 불러오지 못했습니다.')),
      );
    }
  }

  void _showLearningResult(int chapterId) async {
    try {
      final words = await ApiService().fetchWords(chapterId);
      final sentences = await ApiService().fetchSentences(chapterId);
      final progress = (words.where((word) => word.isCalled).length +
              sentences.where((sentence) => sentence.isCalled).length) /
          (words.length + sentences.length) *
          100;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습 결과를 불러오지 못했습니다.')),
      );
    }
  }

  Future<double> _calculateLearningProgress(int chapterId) async {
    final words = await ApiService().fetchWords(chapterId);
    final sentences = await ApiService().fetchSentences(chapterId);
    return (words.where((word) => word.isCalled).length +
            sentences.where((sentence) => sentence.isCalled).length) /
        (words.length + sentences.length) *
        100;
  }

  Future<double> _calculateEvaluationProgress(int chapterId) async {
    final words = await ApiService().fetchWords(chapterId);
    final sentences = await ApiService().fetchSentences(chapterId);
    return (words.where((word) => word.isCollect).length +
            sentences.where((sentence) => sentence.isCollect).length) /
        (words.length + sentences.length) *
        100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientPage(
        child: FutureBuilder<ProgressData>(
          future: futureProgressData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('진행도를 불러오지 못했습니다.'));
            }
            if (!snapshot.hasData || snapshot.data!.progressData.isEmpty) {
              return const Center(child: Text('진행 데이터가 없습니다.'));
            }

            final progressData = snapshot.data!;

            return ListView(
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
                        label: '평균 점수',
                        value: progressData.overallProgress.toStringAsFixed(0),
                        icon: Icons.analytics_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const SectionTitle(title: '학습 진행률'),
                for (final chapter in progressData.progressData)
                  FutureBuilder<double>(
                    future: _calculateLearningProgress(chapter.chapterId),
                    builder: (context, snapshot) {
                      final progress = snapshot.data ?? 0;
                      return ActionTile(
                        title: chapter.chapterTitle,
                        subtitle: '${progress.toStringAsFixed(0)}% 완료',
                        icon: progress >= 75
                            ? Icons.check_circle_rounded
                            : Icons.hourglass_bottom_rounded,
                        onTap: () => _showLearningResult(chapter.chapterId),
                      );
                    },
                  ),
                const SizedBox(height: 10),
                const SectionTitle(title: '평가 진행률'),
                for (final chapter in progressData.progressData)
                  FutureBuilder<double>(
                    future: _calculateEvaluationProgress(chapter.chapterId),
                    builder: (context, snapshot) {
                      final progress = snapshot.data ?? 0;
                      return ActionTile(
                        title: chapter.chapterTitle,
                        subtitle: '${progress.toStringAsFixed(0)}% 완료',
                        icon: progress >= 75
                            ? Icons.emoji_events_rounded
                            : Icons.flag_outlined,
                        onTap: () => _showEvaluationResult(chapter.chapterId),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
