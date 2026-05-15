import 'package:flutter/material.dart';

import 'camera_page.dart';
import 'text_cert_page.dart';
import 'verify_page.dart';
import 'video_verify_page.dart';
import 'video_player_verify_page.dart';
import 'hcvpack_player_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => openPage(
                context,
                const CameraPage(),
              ),
              child: const Text("Camera HCV"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => openPage(
                context,
                const TextCertPage(),
              ),
              child: const Text("Testo HCV"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => openPage(
                context,
                const VerifyPage(),
              ),
              child: const Text("Verifica HCV"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => openPage(
                context,
                const VideoVerifyPage(),
              ),
              child: const Text("Verifica Video + HCV"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => openPage(
                context,
                const HCVPackPlayerPage(),
              ),
              child: const Text("Apri HCVPACK"),
            ),
          ],
        ),
      ),
    );
  }
}
