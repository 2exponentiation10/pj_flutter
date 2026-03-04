import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../settings_provider.dart';
import '../widgets/custom_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _checkMicPermission() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('웹에서는 브라우저 주소창 사이트 설정에서 마이크 권한을 확인해 주세요.'),
        ),
      );
      return;
    }

    final status = await Permission.microphone.request();
    if (!mounted) return;
    final message = switch (status) {
      PermissionStatus.granted => '마이크 권한이 허용되었습니다.',
      PermissionStatus.limited => '마이크 권한이 제한 허용 상태입니다.',
      PermissionStatus.denied => '마이크 권한이 거부되었습니다.',
      PermissionStatus.permanentlyDenied => '권한이 영구 거부되어 설정 화면으로 이동이 필요합니다.',
      PermissionStatus.restricted => '기기 정책으로 권한이 제한되었습니다.',
      _ => '권한 상태를 확인할 수 없습니다.',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return GradientPage(
      child: SafeArea(
        bottom: false,
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
            Card(
              child: ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('연결된 API 주소'),
                subtitle: Text(ApiService.baseUrl),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mic_rounded),
                title: const Text('마이크 권한 점검'),
                subtitle: const Text('권한 상태를 바로 확인합니다.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _checkMicPermission,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
