import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings_provider.dart';
import '../widgets/custom_widgets.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientPage(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            const SectionTitle(
              title: '앱 설정',
              subtitle: '학습 환경을 내 스타일에 맞춰 조정하세요.',
            ),
            Card(
              child: Consumer<SettingsProvider>(
                builder: (context, settingsProvider, child) {
                  return SwitchListTile(
                    title: const Text('다크 모드'),
                    subtitle: const Text('밤 시간대에 눈의 피로를 줄입니다.'),
                    value: settingsProvider.isDarkMode,
                    onChanged: (_) => settingsProvider.toggleDarkMode(),
                  );
                },
              ),
            ),
            Card(
              child: const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('버전 정보'),
                subtitle: Text('1.0.0'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
