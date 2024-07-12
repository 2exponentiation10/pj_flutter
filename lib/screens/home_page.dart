import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'word_learning_page.dart';
import 'progress_page.dart';
import 'library_page.dart';
import 'settings_page.dart';
import 'learning_page.dart';
import 'evaluation_page.dart';
import 'evaluation_learning_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions = <Widget>[
    HomePageContent(),
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
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Image.asset('assets/images/home.png', width: 24, height: 24),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/images/library.png', width: 24, height: 24),
            label: '보관함',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/images/progress.png', width: 24, height: 24),
            label: '진행도',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/images/settings.png', width: 24, height: 24),
            label: '환경 설정',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomePageContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('시나브로'),
          backgroundColor: Colors.lightBlue[100],
          elevation: 0,
        ),
        body: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
    _buildStatusCard('학습한 챕터 수', '3'),
    _buildStatusCard('평가 점수 (100점 기준)', '75'),
    ],
    ),
    SizedBox(height: 20),
    GestureDetector(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ChatPage()),
    );
    },
    child: Container(
    padding: EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
    color: Colors.teal,
    borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
    child: Text(
    'AI와 대화하기',
    style: TextStyle(color: Colors.white, fontSize: 18),
    ),
    ),
    ),
    ),
    SizedBox(height: 20),
    _buildSectionTitle('학습하기'),
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
    GestureDetector(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => WordLearningPage(chapterId: 1)), // 챕터 ID 전달
    );
    },
    child: _buildLearningCard('Chap 1. 기본 인사', '문장 학습하기', 'assets/images/sample1.png'),
    ),
    GestureDetector(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => WordLearningPage(chapterId: 1)), // 챕터 ID 전달
    );
    },
    child: _buildLearningCard('Chap 1. 기본 인사', '단어 학습하기', 'assets/images/sample1.png'),
    ),
    ],
    ),
    SizedBox(height: 10),
    GestureDetector(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => LearningPage()),
      );
    },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.lightBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '학습하기',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    ),
      SizedBox(height: 20),
      _buildSectionTitle('평가하기'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EvaluationLearningPage()),
              );
            },
            child: _buildLearningCard('Chap 1. 기본 인사', '문장 평가하기', 'assets/images/sample1.png'),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EvaluationLearningPage()),
              );
            },
            child: _buildLearningCard('Chap 1. 기본 인사', '단어 평가하기', 'assets/images/sample1.png'),
          ),
        ],
      ),
      SizedBox(height: 10),
      GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EvaluationPage()),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.lightBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '평가하기',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ),
    ],
    ),
        ),
        ),
    );
  }

  Widget _buildStatusCard(String title, String value) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLearningCard(String chapter, String title, String imagePath) {
    return Expanded(
      child: Card(
        child: Column(
          children: [
            Image.asset(imagePath, width: 120, height: 120, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapter, style: TextStyle(fontSize: 14)),
                  SizedBox(height: 4),
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

