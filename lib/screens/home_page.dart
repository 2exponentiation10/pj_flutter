import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'accent_learning_page.dart';
import 'chat_page.dart';
import 'admin_console_page.dart';
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
  int _logoTapCount = 0;
  DateTime? _lastLogoTapAt;
  static const String _defaultAdminPin = '1004';

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
      appBar: AppBar(
        title: _buildAppBarTitle(titles[_selectedIndex]),
      ),
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

  Widget _buildAppBarTitle(String title) {
    if (_selectedIndex != 0) return Text(title);
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        if (_lastLogoTapAt == null ||
            now.difference(_lastLogoTapAt!) > const Duration(seconds: 3)) {
          _logoTapCount = 0;
        }
        _lastLogoTapAt = now;
        _logoTapCount += 1;
        if (_logoTapCount >= 10) {
          _logoTapCount = 0;
          final adminPin = await _verifyAdminPin();
          if (!mounted || adminPin == null) return;
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AdminConsolePage(adminPin: adminPin)));
          return;
        }
        if (_logoTapCount >= 7) {
          final remaining = 10 - _logoTapCount;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('관리자 모드까지 $remaining번 더 터치하세요.')),
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.auto_awesome_rounded, size: 18),
          SizedBox(width: 8),
          Text('시나브로'),
        ],
      ),
    );
  }

  Future<String?> _verifyAdminPin() async {
    final configuredPin = const String.fromEnvironment(
      'ADMIN_CONSOLE_PIN',
      defaultValue: _defaultAdminPin,
    );
    final controller = TextEditingController();
    String? errorText;

    final unlocked = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              title: const Text('관리자 인증'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('관리자 PIN을 입력하세요.'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      errorText: errorText,
                    ),
                    onSubmitted: (_) {
                      if (controller.text.trim() == configuredPin) {
                        Navigator.pop(context, true);
                      } else {
                        setStateDialog(() {
                          errorText = 'PIN이 올바르지 않습니다.';
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim() == configuredPin) {
                      Navigator.pop(context, true);
                    } else {
                      setStateDialog(() {
                        errorText = 'PIN이 올바르지 않습니다.';
                      });
                    }
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!unlocked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 인증에 실패했습니다.')),
      );
    }
    return unlocked ? controller.text.trim() : null;
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final ApiService _api = ApiService();
  late Future<_HomeDashboardData> _futureDashboard;

  @override
  void initState() {
    super.initState();
    _futureDashboard = _loadDashboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureDashboard = _loadDashboard();
    });
    await _futureDashboard;
  }

  Future<_HomeDashboardData> _loadDashboard() async {
    Chapter? nextChapter;
    ProgressData? progress;
    List<ReviewQueueItem> reviewItems = const [];
    Object? firstError;

    try {
      nextChapter = await _api.fetchNextChapter();
    } catch (e) {
      firstError ??= e;
    }

    try {
      progress = await _api.fetchProgressData();
    } catch (e) {
      firstError ??= e;
    }

    try {
      reviewItems = await _api.fetchReviewQueue(limit: 3);
    } catch (e) {
      firstError ??= e;
    }

    if (nextChapter == null && progress == null && reviewItems.isEmpty) {
      throw Exception(firstError?.toString() ?? '대시보드 데이터를 불러오지 못했습니다.');
    }

    return _HomeDashboardData(
      nextChapter: nextChapter,
      progress: progress,
      reviewItems: reviewItems,
      degraded: firstError != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeDashboardData>(
      future: _futureDashboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              const HeroIntroCard(
                eyebrow: 'Dashboard',
                title: '홈 데이터를 불러오지 못했습니다',
                description: '네트워크 또는 서버 상태를 확인하고 다시 시도해 주세요.',
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

        final dashboard = snapshot.data!;
        final nextChapter = dashboard.nextChapter;
        final progress = dashboard.progress;
        final reviewItems = dashboard.reviewItems;
        final completed = progress?.completedChapters ?? 0;
        final avgScore = progress?.overallProgress ?? 0.0;
        final totalItems = progress == null
            ? 0
            : progress.progressData.fold<int>(
                0,
                (sum, item) => sum + item.totalItems,
              );
        final calledItems = progress == null
            ? 0
            : progress.progressData.fold<int>(
                0,
                (sum, item) => sum + item.calledItems,
              );

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              if (dashboard.degraded)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '일부 데이터만 불러왔습니다. 아래로 당겨 새로고침할 수 있어요.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              HeroIntroCard(
                eyebrow: '다음 학습 챕터',
                title: nextChapter?.title ?? '추천 챕터를 준비 중입니다',
                description: '오늘 20분 집중 학습으로 단어, 문장, 억양을 한 번에 정리하세요.',
                action: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: nextChapter == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AccentLearningPage(
                                    chapterId: nextChapter.id,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('추천 챕터 억양 연습'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LearningPage()),
                        );
                      },
                      icon: const Icon(Icons.view_list_rounded),
                      label: const Text('챕터 목록 보기'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: '완료 챕터',
                      value: '$completed',
                      icon: Icons.auto_stories_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: '평균 평가 점수',
                      value: avgScore.toStringAsFixed(0),
                      icon: Icons.emoji_events_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timeline_rounded),
                  title: const Text('전체 학습 진도'),
                  subtitle: Text(
                    totalItems == 0
                        ? '아직 학습 기록이 없습니다.'
                        : '$calledItems / $totalItems 아이템 완료',
                  ),
                  trailing: Text(
                    totalItems == 0
                        ? '0%'
                        : '${((calledItems / totalItems) * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
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
                subtitle: reviewItems.isEmpty
                    ? '현재 추천 항목 없음'
                    : '추천 ${reviewItems.length}개 확인',
                icon: Icons.assignment_turned_in_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ReviewQueuePage()),
                  );
                },
              ),
              if (reviewItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                const SectionTitle(
                  title: '지금 복습 추천',
                  subtitle: '최근 발음 결과 기반 우선순위 항목',
                ),
                ...reviewItems.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(
                        item.koreanSentence,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '우선순위 ${item.priorityScore.toStringAsFixed(1)} · 챕터 ${item.chapterId}',
                      ),
                      trailing:
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AccentLearningPage(chapterId: item.chapterId),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HomeDashboardData {
  final Chapter? nextChapter;
  final ProgressData? progress;
  final List<ReviewQueueItem> reviewItems;
  final bool degraded;

  const _HomeDashboardData({
    required this.nextChapter,
    required this.progress,
    required this.reviewItems,
    required this.degraded,
  });
}
