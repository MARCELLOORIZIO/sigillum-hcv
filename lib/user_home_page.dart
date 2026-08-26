import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_page.dart';
import 'hcv_import_router_page.dart';
import 'hcv_registry_service.dart';
import 'commercial_profile_page.dart';
import 'import_page.dart';
import 'legal_info_page.dart';
import 'registry_verify_page.dart';
import 'sigillum_localization.dart';
import 'sigillum_theme.dart';
import 'sigillum_quick_guide_page.dart';
import 'text_cert_page.dart';
import 'text_social_verify_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key, this.onSessionInvalidated});

  final VoidCallback? onSessionInvalidated;

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  static const MethodChannel _intentChannel = MethodChannel('hcv.intent');
  String? _lastOpenedSharedPath;
  String languageCode = SigillumCopy.initialLanguageCode();

  String _t(String key) => SigillumCopy.t(languageCode, key);

  @override
  void initState() {
    super.initState();
    _intentChannel.setMethodCallHandler(_handleNativeIntent);
    Future.microtask(_loadLanguage);
    Future.microtask(_checkInitialIntent);
    Future.microtask(_retryRegistryOutbox);
  }

  Future<void> _retryRegistryOutbox() async {
    try {
      await const HCVRegistryService().retryPendingUploads();
    } catch (_) {
      // La coda resta disponibile per il tentativo successivo.
    }
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('sigillum_language');
    if (saved == null || saved.isEmpty) return;
    if (!mounted) return;
    setState(() {
      languageCode = SigillumCopy.language(saved).code;
    });
  }

  Future<void> _setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sigillum_language', code);
    if (!mounted) return;
    setState(() {
      languageCode = SigillumCopy.language(code).code;
    });
  }

  Future<dynamic> _handleNativeIntent(MethodCall call) async {
    if (call.method == 'onSharedPath') {
      final path = call.arguments as String?;
      if (path != null && path.isNotEmpty) {
        _openImportedPath(path);
        try {
          await _intentChannel.invokeMethod<bool>('ackSharedPath', {
            'path': path,
          });
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
      debugPrint('Intent error: $e');
    }
  }

  void _openImportedPath(String path) {
    if (!mounted || path.isEmpty || _lastOpenedSharedPath == path) return;
    _lastOpenedSharedPath = path;

    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) {
      File(path)
          .readAsString()
          .then((sharedText) {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TextSocialVerifyPage(
                  languageCode: languageCode,
                  initialText: sharedText,
                ),
              ),
            );
          })
          .catchError((_) {});
      return;
    }
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isMedia
            ? RegistryVerifyPage(
                initialMediaPath: path,
                languageCode: languageCode,
              )
            : HCVImportRouterPage(path: path, languageCode: languageCode),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAFBFF), Color(0xFFFAF9FA), Color(0xFFF2ECFF)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: _Header(
                    languageCode: languageCode,
                    onLanguageChanged: _setLanguage,
                    onIdentity: () => _open(
                      CommercialProfilePage(
                        languageCode: languageCode,
                        onLanguageChanged: _setLanguage,
                        onSessionInvalidated:
                            widget.onSessionInvalidated ?? () {},
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                sliver: SliverList.list(
                  children: [
                    _PrimaryAction(
                      icon: Icons.add_a_photo_rounded,
                      title: _t('certifyMediaTitle'),
                      subtitle: _t('certifyMediaSubtitle'),
                      accent: SigillumTheme.accent,
                      onPressed: () =>
                          _open(CameraPage(languageCode: languageCode)),
                    ),
                    const SizedBox(height: 12),
                    _PrimaryAction(
                      icon: Icons.article_rounded,
                      title: _t('certifyTextTitle'),
                      subtitle: _t('certifyTextSubtitle'),
                      accent: SigillumTheme.accentAlt,
                      onPressed: () =>
                          _open(TextCertPage(languageCode: languageCode)),
                    ),
                    const SizedBox(height: 12),
                    _PrimaryAction(
                      icon: Icons.verified_rounded,
                      title: _t('verifyTitle'),
                      subtitle: _t('verifySubtitle'),
                      accent: SigillumTheme.verified,
                      onPressed: () =>
                          _open(ImportPage(languageCode: languageCode)),
                    ),
                    const SizedBox(height: 12),
                    _PrimaryAction(
                      icon: Icons.manage_accounts_rounded,
                      title: _t('accountTitle'),
                      subtitle: _t('accountSubtitle'),
                      accent: SigillumTheme.warning,
                      onPressed: () => _open(
                        CommercialProfilePage(
                          languageCode: languageCode,
                          onLanguageChanged: _setLanguage,
                          onSessionInvalidated:
                              widget.onSessionInvalidated ?? () {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PrimaryAction(
                      icon: Icons.help_center_rounded,
                      title: _t('quickGuideTitle'),
                      subtitle: _t('quickGuideSubtitle'),
                      accent: SigillumTheme.verified,
                      onPressed: () => _open(
                        SigillumQuickGuidePage(languageCode: languageCode),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PrimaryAction(
                      icon: Icons.info_outline_rounded,
                      title: _t('infoTitle'),
                      subtitle: _t('infoSubtitle'),
                      accent: SigillumTheme.accentAlt,
                      onPressed: () =>
                          _open(LegalInfoPage(languageCode: languageCode)),
                    ),
                    const SizedBox(height: 22),
                    _TrustChainCard(languageCode: languageCode),
                    const SizedBox(height: 14),
                    _ControlsCard(languageCode: languageCode),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.languageCode,
    required this.onLanguageChanged,
    required this.onIdentity,
  });

  final String languageCode;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onIdentity;

  String _t(String key) => SigillumCopy.t(languageCode, key);

  @override
  Widget build(BuildContext context) {
    final language = SigillumCopy.language(languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7645D9), Color(0xFF1FC7D4)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x247645D9),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Colors.white,
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
              tooltip: 'Account',
              onPressed: onIdentity,
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: language.name,
              initialValue: languageCode,
              onSelected: onLanguageChanged,
              itemBuilder: (context) => [
                for (final item in SigillumCopy.languages)
                  PopupMenuItem(value: item.code, child: Text(item.name)),
              ],
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x667E9189)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  language.shortName,
                  style: const TextStyle(
                    color: SigillumTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          _t('headline'),
          style: const TextStyle(
            color: SigillumTheme.ink,
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _t('subtitle'),
          style: const TextStyle(
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
    required this.accent,
    required this.onPressed,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: SigillumTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12280D5F),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 29),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: SigillumTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: SigillumTheme.muted,
                        fontSize: 14,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustChainCard extends StatelessWidget {
  const _TrustChainCard({required this.languageCode});

  final String languageCode;

  String _t(String key) => SigillumCopy.t(languageCode, key);

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: _t('trustChain'),
      child: Column(
        children: [
          _ChainStep(
            number: '1',
            title: _t('capture'),
            text: _t('captureText'),
          ),
          _ChainStep(
            number: '2',
            title: _t('fingerprint'),
            text: _t('fingerprintText'),
          ),
          _ChainStep(
            number: '3',
            title: _t('identityStep'),
            text: _t('identityText'),
          ),
          _ChainStep(
            number: '4',
            title: _t('signature'),
            text: _t('signatureText'),
          ),
          _ChainStep(
            number: '5',
            title: _t('registry'),
            text: _t('registryText'),
          ),
        ],
      ),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({required this.languageCode});

  final String languageCode;

  String _t(String key) => SigillumCopy.t(languageCode, key);

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: _t('controls'),
      child: Column(
        children: [
          _MiniCheck(text: _t('checkIntegrity')),
          _MiniCheck(text: _t('checkSignature')),
          _MiniCheck(text: _t('checkWatermark')),
          _MiniCheck(text: _t('checkRegistry')),
          _MiniCheck(text: _t('checkScreen')),
          _MiniCheck(text: _t('checkSocial')),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SigillumTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10280D5F),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
