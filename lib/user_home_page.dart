import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_page.dart';
import 'hcv_import_router_page.dart';
import 'identity_page.dart';
import 'import_page.dart';
import 'registry_verify_page.dart';
import 'sigillum_theme.dart';
import 'text_cert_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  static const MethodChannel _intentChannel = MethodChannel('hcv.intent');

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
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isMedia
            ? RegistryVerifyPage(initialMediaPath: path)
            : HCVImportRouterPage(path: path),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: _Header(
                  onIdentity: () => _open(const IdentityPage()),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              sliver: SliverList.list(
                children: [
                  _PrimaryAction(
                    icon: Icons.add_a_photo_rounded,
                    title: 'Certifica foto o video',
                    subtitle: 'Registra o scatta e crea il certificato.',
                    onPressed: () => _open(const CameraPage()),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryAction(
                    icon: Icons.article_rounded,
                    title: 'Certifica testo',
                    subtitle: 'Crea un testo verificabile con HCV-ID.',
                    onPressed: () => _open(const TextCertPage()),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryAction(
                    icon: Icons.verified_rounded,
                    title: 'Verifica contenuto',
                    subtitle:
                        'Apri un file, un HCVPACK o verifica dal Registry.',
                    onPressed: () => _open(const ImportPage()),
                  ),
                  const SizedBox(height: 22),
                  const _TrustChainCard(),
                  const SizedBox(height: 14),
                  const _ControlsCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onIdentity,
  });

  final VoidCallback onIdentity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SigillumTheme.ivory,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.security_rounded,
                color: SigillumTheme.ink,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIGILLUM',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    'Human Content Verification',
                    style: TextStyle(
                      color: SigillumTheme.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Identita',
              onPressed: onIdentity,
              icon: const Icon(Icons.badge_outlined),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Certifica contenuti con una prova tecnica verificabile.',
          style: TextStyle(
            color: SigillumTheme.ivory,
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Foto e video vengono collegati a identita tecnica, impronta del file, '
          'certificato firmato e registro online.',
          style: TextStyle(
            color: SigillumTheme.muted,
            fontSize: 16,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.filled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: filled
                      ? SigillumTheme.ink.withValues(alpha: 0.72)
                      : SigillumTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    );

    if (filled) {
      return FilledButton(onPressed: onPressed, child: content);
    }

    return OutlinedButton(onPressed: onPressed, child: content);
  }
}

class _TrustChainCard extends StatelessWidget {
  const _TrustChainCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Catena di controllo',
      child: Column(
        children: const [
          _ChainStep(number: '1', title: 'Cattura', text: 'Creata in app'),
          _ChainStep(number: '2', title: 'Impronta', text: 'Hash del file'),
          _ChainStep(
              number: '3', title: 'Identita', text: 'Creatore collegato'),
          _ChainStep(number: '4', title: 'Firma', text: 'Certificato protetto'),
          _ChainStep(number: '5', title: 'Registro', text: 'Verifica online'),
        ],
      ),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Controlli SIGILLUM',
      child: Column(
        children: const [
          _MiniCheck(text: 'Integrita file e coerenza col certificato'),
          _MiniCheck(text: 'Firma digitale del certificato'),
          _MiniCheck(text: 'Watermark visibile nel contenuto pubblicato'),
          _MiniCheck(text: 'Registro online per verifica futura'),
          _MiniCheck(text: 'Controllo anti-ripresa da schermo'),
          _MiniCheck(text: 'Fingerprint per file ricompressi dai social'),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x334B625A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChainStep extends StatelessWidget {
  const _ChainStep({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SigillumTheme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SigillumTheme.accent),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: SigillumTheme.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title  ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: text,
                    style: const TextStyle(
                      color: SigillumTheme.muted,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCheck extends StatelessWidget {
  const _MiniCheck({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: SigillumTheme.verified,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: SigillumTheme.muted,
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
