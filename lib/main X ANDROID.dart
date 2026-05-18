import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(const HCVApp());
}

class HCVApp extends StatelessWidget {
  const HCVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HCV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
