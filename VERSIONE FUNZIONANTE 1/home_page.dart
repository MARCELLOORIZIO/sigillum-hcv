import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_page.dart';
import 'hcvpack_player_page.dart';
import 'hcv_import_router_page.dart';
import 'import_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const MethodChannel _intentChannel = MethodChannel('hcv.intent');

  @override
  void initState() {
    super.initState();

    _intentChannel.setMethodCallHandler(_handleNativeIntent);

    Future.microtask(_checkInitialIntent);
  }

  Future<dynamic> _handleNativeIntent(MethodCall call) async {
    if (call.method == "onSharedPath") {
      final path = call.arguments as String?;

      if (path != null && path.isNotEmpty) {
        _openImportedPath(path);
      }
    }
  }

  Future<void> _checkInitialIntent() async {
    try {
      final path = await _intentChannel.invokeMethod<String>('getSharedPath');

      if (path != null && path.isNotEmpty) {
        _openImportedPath(path);
      }
    } catch (e) {
      debugPrint("Intent error: $e");
    }
  }

  void _openImportedPath(String path) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HCVImportRouterPage(path: path),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  Widget _mainButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 320,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInfo() {
    _open(
      Scaffold(
        appBar: AppBar(
          title: const Text("HCV Info"),
        ),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              "HCV verifica contenuti video tramite hash SHA256, certificato firmato RSA e package .hcvpack.\n\n"
              "Flusso principale:\n\n"
              "1. Crea HCVPACK\n"
              "2. Condividi il file\n"
              "3. Apri/verifica HCVPACK\n\n"
              "Badge:\n"
              "HUMAN VERIFIED = contenuto integro e certificato valido\n"
              "NOT VERIFIED = contenuto mancante, alterato o non certificato",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV Verify"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user,
                size: 72,
                color: Colors.green,
              ),

              const SizedBox(height: 12),

              const Text(
                "Human Content Verification",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  "Crea, condividi e verifica contenuti HUMAN VERIFIED.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ),

              const SizedBox(height: 32),

              _mainButton(
                icon: Icons.videocam,
                title: "CREA HCVPACK",
                subtitle: "Registra o genera contenuto certificato",
                onPressed: () => _open(const CameraPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.file_open,
                title: "IMPORTA / VERIFICA FILE",
                subtitle: "Apri .hcvpack, .hcv o video",
                onPressed: () => _open(const ImportPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.play_circle_fill,
                title: "VERIFICA HCVPACK",
                subtitle: "Apri un file .hcvpack e mostra il badge",
                onPressed: () => _open(const HCVPackPlayerPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.info_outline,
                title: "INFO / TEST",
                subtitle: "Spiegazione del flusso HCV",
                onPressed: _openInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}