import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'chat_page.dart';
import 'evaluation_page.dart';
import 'learning_page.dart';
import 'library_page.dart';
import 'progress_page.dart';
import 'review_queue_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeContent(),
    LibraryPage(),
    ProgressPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['시나브로', '보관함', '진행도', '설정'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      body: AppShell(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_books_rounded), label: '보관함'),
          BottomNavigationBarItem(
              icon: Icon(Icons.insights_rounded), label: '진행도'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), label: '설정'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Chapter>(
      future: ApiService().fetchNextChapter(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('다음 챕터를 불러오지 못했어요.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('진행 가능한 챕터가 없습니다.'));
        }

        final chapter = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            HeroIntroCard(
              eyebrow: '다음 학습 챕터',
              title: chapter.title,
              description: '오늘 20분 집중 학습으로 단어, 문장, 억양을 한 번에 정리하세요.',
              action: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LearningPage()),
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('바로 학습 시작'),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: '학습한 챕터 수',
                    value: '3',
                    icon: Icons.auto_stories_rounded,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    label: '평균 평가 점수',
                    value: '75',
                    icon: Icons.emoji_events_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const SectionTitle(
              title: '빠른 실행',
              subtitle: '학습, 평가, 복습을 한 번에 연결하세요.',
            ),
            ActionTile(
              title: '학습 모드',
              subtitle: '단어/문장/억양 학습으로 이동',
              icon: Icons.school_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LearningPage()),
                );
              },
            ),
            ActionTile(
              title: '평가 모드',
              subtitle: '단어/문장/억양 평가로 이동',
              icon: Icons.fact_check_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EvaluationPage()),
                );
              },
            ),
            ActionTile(
              title: 'AI와 대화하기',
              subtitle: '남북한 어휘 차이를 질문해보세요.',
              icon: Icons.forum_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatPage()),
                );
              },
            ),
            ActionTile(
              title: '복습 추천 큐',
              subtitle: '최근 발음 결과 기반 개인화 복습',
              icon: Icons.assignment_turned_in_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReviewQueuePage()),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
