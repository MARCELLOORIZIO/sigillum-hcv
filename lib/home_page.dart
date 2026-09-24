import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_page.dart';
import 'hcv_import_router_page.dart';
import 'hcvpack_player_page.dart';
import 'identity_page.dart';
import 'import_page.dart';
import 'registry_verify_page.dart';
import 'verified_originals_page.dart';
import 'screen_replay_calibration_page.dart';
import 'screen_replay_diagnostics_page.dart';
import 'text_cert_page.dart';
import 'sigillum_localization.dart';
import 'lab_ui_copy.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const MethodChannel _intentChannel = MethodChannel('hcv.intent');
  String? _lastOpenedSharedPath;
  String languageCode = SigillumCopy.initialLanguageCode();
  String _l(String key) => LabUiCopy.t(languageCode, key);

  @override
  void initState() {
    super.initState();
    _intentChannel.setMethodCallHandler(_handleNativeIntent);
    Future.microtask(_checkInitialIntent);
  }

  Future<dynamic> _handleNativeIntent(MethodCall call) async {
    if (call.method == 'onSharedPath') {
      final path = call.arguments as String?;
      if (path != null && path.isNotEmpty) {
        _openImportedPath(path);
        try {
          await _intentChannel.invokeMethod<bool>(
            'ackSharedPath',
            {'path': path},
          );
        } catch (_) {}
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
    if (!mounted || path.isEmpty || _lastOpenedSharedPath == path) return;
    _lastOpenedSharedPath = path;

    final lower = path.toLowerCase();

    final isMedia = lower.endsWith('.mp4') ||
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
            languageCode: languageCode,
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
        appBar: AppBar(title: Text(_l('infoTitle'))),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                _l('infoBody'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.4),
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
        title: Text(_l('title')),
        actions: [
          PopupMenuButton<String>(
            tooltip: SigillumCopy.language(languageCode).name,
            onSelected: (value) => setState(() => languageCode = value),
            itemBuilder: (_) => [
              for (final item in SigillumCopy.languages)
                PopupMenuItem(value: item.code, child: Text(item.name)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(child: Text(SigillumCopy.language(languageCode).shortName)),
            ),
          ),
        ],
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
              Text(
                _l('subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _l('tagline'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              _mainButton(
                icon: Icons.videocam,
                title: _l('createVideo'),
                subtitle: _l('createVideoSub'),
                onPressed: () => _open(CameraPage(languageCode: languageCode)),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.cloud_done,
                title: _l('verifyVideo'),
                subtitle: _l('verifyVideoSub'),
                onPressed: () => _open(RegistryVerifyPage(languageCode: languageCode)),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.video_library_outlined,
                title: 'SIGILLUM Verified Originals',
                subtitle: 'Verifica HCV-ID o guarda la copia autorizzata',
                onPressed: () => _open(VerifiedOriginalsPage(languageCode: languageCode)),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.file_open,
                title: _l('import'),
                subtitle: _l('importSub'),
                onPressed: () => _open(const ImportPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.play_circle_fill,
                title: _l('openPack'),
                subtitle: _l('openPackSub'),
                onPressed: () => _open(HCVPackPlayerPage(languageCode: languageCode)),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.text_fields,
                title: _l('certText'),
                subtitle: _l('certTextSub'),
                onPressed: () => _open(TextCertPage(languageCode: languageCode)),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.badge,
                title: _l('identity'),
                subtitle: _l('identitySub'),
                onPressed: () => _open(IdentityPage(languageCode: languageCode)),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.analytics,
                title: _l('diagnostics'),
                subtitle: _l('diagnosticsSub'),
                onPressed: () => _open(ScreenReplayDiagnosticsPage(languageCode: languageCode)),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.model_training,
                title: _l('training'),
                subtitle: _l('trainingSub'),
                onPressed: () => _open(ScreenReplayCalibrationPage(languageCode: languageCode)),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.info_outline,
                title: _l('how'),
                subtitle: _l('howSub'),
                onPressed: _openInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
