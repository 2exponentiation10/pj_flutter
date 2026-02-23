import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'accent_learning_page.dart';

class ReviewQueuePage extends StatefulWidget {
  const ReviewQueuePage({super.key});

  @override
  State<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends State<ReviewQueuePage> {
  late Future<List<ReviewQueueItem>> _futureQueue;

  @override
  void initState() {
    super.initState();
    _futureQueue = ApiService().fetchReviewQueue(limit: 20);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('복습 추천 큐')),
      body: GradientPage(
        child: FutureBuilder<List<ReviewQueueItem>>(
          future: _futureQueue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('복습 큐를 불러오지 못했습니다.'));
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const Center(child: Text('현재 복습 추천 항목이 없습니다.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '우선순위 ${item.priorityScore.toStringAsFixed(1)} · 챕터 ${item.chapterId}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.koreanSentence,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ': ${item.northKoreanSentence}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '난이도 ${item.difficulty} / 상황 ${item.contextTag}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '최근평균 ${item.recentAvgScorePercent?.toStringAsFixed(1) ?? '-'} / 마지막 ${item.lastScorePercent?.toStringAsFixed(1) ?? '-'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(item.reason),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AccentLearningPage(
                                    chapterId: item.chapterId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('이 문맥 복습하기'),
                          ),
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
}
