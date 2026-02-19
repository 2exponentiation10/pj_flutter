import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onsaemiro/services/api_service.dart';
import 'package:provider/provider.dart';

import 'models/models.dart';
import 'screens/home_page.dart';
import 'settings_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Optional in local/web environments.
  }

  try {
    final apiService = ApiService();
    final Chapter nextChapter = await apiService.fetchNextChapter();
    debugPrint('Next chapter loaded: ${nextChapter.title}');
  } catch (e) {
    debugPrint('Error in main: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return MaterialApp(
          title: '시나브로',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode:
              settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: HomePage(),
        );
      },
    );
  }
}
