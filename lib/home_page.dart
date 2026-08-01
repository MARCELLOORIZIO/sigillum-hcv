import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hcv_build_info.dart';
import 'hcv_identity.dart';
import 'hcv_import_router_page.dart';
import 'hcv_registry_service.dart';
import 'hcvpack_verifier_page.dart';
import 'identity_page.dart';
import 'import_page.dart';
import 'production_camera_session_page.dart';
import 'registry_verify_page.dart';
import 'screen_replay_calibration_page.dart';
import 'screen_replay_diagnostics_page.dart';
import 'text_cert_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const MethodChannel _intentChannel = MethodChannel('hcv.intent');
  final HCVRegistryService _registry = const HCVRegistryService();
  String? _startupStatus;

  @override
  void initState() {
    super.initState();
    _intentChannel.setMethodCallHandler(_handleNativeIntent);
    Future.microtask(_checkInitialIntent);
    Future.microtask(_runStartupRecovery);
  }

  Future<void> _runStartupRecovery() async {
    final messages = <String>[];
    try {
      final report = await _registry.retryPendingUploads();
      if (report.uploaded > 0) {
        messages.add('${report.uploaded} certificati Registry pubblicati');
      }
      if (report.pending > 0) {
        messages.add('${report.pending} pubblicazioni Registry conservate in coda');
      }
      if (report.hasTerminalFailures) {
        messages.add('${report.discarded} pubblicazioni richiedono controllo');
      }
    } catch (_) {
      messages.add('Registry non raggiungibile: pubblicazioni conservate in coda');
    }

    try {
      final identity = await HCVIdentity().loadIdentity();
      final kycStatus = identity['kycStatus']?.toString() ?? '';
      final recoveryError = identity['kycRecoveryError']?.toString() ?? '';
      if (kycStatus == 'verified') {
        messages.add('Identita KYC verificata');
      } else if (recoveryError.isNotEmpty) {
        messages.add('Recupero KYC non completato');
      }
    } catch (_) {
      messages.add('Identita tecnica non caricata');
    }

    if (!mounted || messages.isEmpty) return;
    setState(() {
      _startupStatus = messages.join(' · ');
    });
  }

  Future<dynamic> _handleNativeIntent(MethodCall call) async {
    if (call.method == 'onSharedPath') {
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
      debugPrint('Intent error: $e');
    }
  }

  void _openImportedPath(String path) {
    if (!mounted) return;

    final lower = path.toLowerCase();
    final isMedia = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a');

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
        appBar: AppBar(title: const Text('Come funziona HCV')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                'HCV crea una prova digitale per un contenuto.\n\n'
                'Quando crei una foto, un video o un testo, l app genera:\n\n'
                '- un contenuto standard condivisibile\n'
                '- un HCV-ID\n'
                '- un certificato firmato\n'
                '- un pacchetto HCVPACK opzionale\n\n'
                'Il controllo combina integrita del file, cattura live, watermark visibile, certificato firmato, Registry, fingerprint per file ricompressi dai social e analisi del rischio di replay da schermo.\n\n'
                'La verifica locale continua a funzionare anche quando il Registry non e momentaneamente raggiungibile.',
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
        title: const Text('HCV Verify'),
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
                'Human Content Verification',
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
                  'Crea contenuti verificabili con controlli su integrita, cattura live, Registry, social fingerprint e rischio schermo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Build ${HCVBuildInfo.shortCommit} · ${HCVBuildInfo.branch}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (_startupStatus != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    _startupStatus!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _mainButton(
                icon: Icons.videocam,
                title: 'CREA FOTO O VIDEO VERIFICABILE',
                subtitle: 'Pipeline integrata con firma locale e coda Registry',
                onPressed: () => _open(const ProductionCameraSessionPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.cloud_done,
                title: 'VERIFICA CONTENUTO CON HCV-ID',
                subtitle: 'Verifica dal Registry o dal certificato locale',
                onPressed: () => _open(const RegistryVerifyPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.file_open,
                title: 'IMPORTA FILE HCV',
                subtitle: 'Apri .hcv, .hcvpack o file ricevuti',
                onPressed: () => _open(const ImportPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.play_circle_fill,
                title: 'APRI HCVPACK',
                subtitle: 'Verifica offline pacchetti foto, video e documenti',
                onPressed: () => _open(const HCVPackVerifierPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.text_fields,
                title: 'CERTIFICA TESTO',
                subtitle: 'Crea un testo verificabile con HCV',
                onPressed: () => _open(const TextCertPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.badge,
                title: 'IDENTITA CREATOR',
                subtitle: 'Imposta nome e identita del creatore',
                onPressed: () => _open(const IdentityPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.analytics,
                title: 'DIAGNOSTICA SCHERMO',
                subtitle: 'Raccogli sessioni test e leggi i valori tecnici',
                onPressed: () => _open(const ScreenReplayDiagnosticsPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.model_training,
                title: 'AUTO TRAINING ML',
                subtitle: 'Raccogli campioni, conferma label ed esporta ZIP',
                onPressed: () => _open(const ScreenReplayCalibrationPage()),
              ),
              const SizedBox(height: 14),
              _mainButton(
                icon: Icons.info_outline,
                title: 'COME FUNZIONA',
                subtitle: 'Spiegazione semplice del sistema',
                onPressed: _openInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
