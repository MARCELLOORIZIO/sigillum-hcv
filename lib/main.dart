import 'package:flutter/material.dart';
// import 'package:media_kit/media_kit.dart';

import 'home_page.dart';
import 'sigillum_edition.dart';
import 'sigillum_theme.dart';
import 'user_home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // MediaKit.ensureInitialized();

  runApp(const HCVApp());
}

class HCVApp extends StatelessWidget {
  const HCVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: SigillumBuildConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: SigillumBuildConfig.isLab
          ? ThemeData(useMaterial3: true)
          : SigillumTheme.userTheme(),
      home: SigillumBuildConfig.isLab ? const HomePage() : const UserHomePage(),
    );
  }
}
