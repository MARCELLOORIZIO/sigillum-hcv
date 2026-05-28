import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_page.dart';
import 'hcvpack_player_page.dart';
import 'hcv_import_router_page.dart';
import 'import_page.dart';
import 'identity_page.dart';
import 'text_cert_page.dart';
import 'registry_verify_page.dart';
import 'screen_replay_diagnostics_page.dart';
import 'screen_replay_calibration_page.dart';

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

    final lower = path.toLowerCase();

    final isMedia =
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav');

    if (isMedia) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegistryVerifyPage(
            initialMediaPath: path,
          ),
        ),
      );
      return;
    }

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
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _mainButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: 330,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 34),
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
        appBar: AppBar(title: const Text("Come funziona HCV")),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                "HCV crea una prova digitale per un contenuto.\n\n"
                "Quando crei un video, l'app genera:\n\n"
                "• un file MP4 standard\n"
                "• un HCV-ID\n"
                "• un certificato firmato\n"
                "• un pacchetto HCVPACK opzionale\n\n"
                "Per verificare online, l'app usa l'HCV-ID per recuperare il certificato dal Registry e confronta l'hash del file.\n\n"
                "Se il contenuto è identico all'originale, appare HUMAN VERIFIED.\n\n"
                "Se il file è stato modificato, appare NOT VERIFIED.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
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
                size: 76,
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
                  "Crea video verificabili e controlla se un contenuto è originale.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),

              _mainButton(
                icon: Icons.videocam,
                title: "CREA VIDEO VERIFICABILE",
                subtitle: "Registra un video e genera HCV-ID",
                onPressed: () => _open(const CameraPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.cloud_done,
                title: "VERIFICA VIDEO CON HCV-ID",
                subtitle: "Seleziona un MP4 e verifica dal Registry",
                onPressed: () => _open(const RegistryVerifyPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.file_open,
                title: "IMPORTA FILE HCV",
                subtitle: "Apri .hcv, .hcvpack o file ricevuti",
                onPressed: () => _open(const ImportPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.play_circle_fill,
                title: "APRI HCVPACK",
                subtitle: "Verifica un pacchetto completo offline",
                onPressed: () => _open(const HCVPackPlayerPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.text_fields,
                title: "CERTIFICA TESTO",
                subtitle: "Crea un testo verificabile con HCV",
                onPressed: () => _open(const TextCertPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.badge,
                title: "IDENTITÀ CREATOR",
                subtitle: "Imposta nome e identità del creatore",
                onPressed: () => _open(const IdentityPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.analytics,
                title: "DIAGNOSTICA SCHERMO",
                subtitle: "Leggi i valori tecnici di foto e video",
                onPressed: () => _open(const ScreenReplayDiagnosticsPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.sensors,
                title: "CALIBRAZIONE SCHERMO",
                subtitle: "Raccogli campioni live schermo/realtÃ ",
                onPressed: () => _open(const ScreenReplayCalibrationPage()),
              ),

              const SizedBox(height: 14),

              _mainButton(
                icon: Icons.info_outline,
                title: "COME FUNZIONA",
                subtitle: "Spiegazione semplice del sistema",
                onPressed: _openInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
