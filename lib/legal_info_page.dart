import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sigillum_localization.dart';
import 'sigillum_theme.dart';

class LegalInfoPage extends StatelessWidget {
  const LegalInfoPage({
    super.key,
    required this.languageCode,
  });

  static const supportEmail = 'support@sigillum.app';
  static const privacyUrl = 'https://sigillum.app/privacy';
  static const termsUrl = 'https://sigillum.app/terms';

  final String languageCode;

  String _t(String key) => SigillumCopy.t(languageCode, key);

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_t('copied')}: $value')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('legalPageTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            _t('legalIntro'),
            style: TextStyle(
              color: SigillumTheme.ivory,
              fontSize: 21,
              height: 1.22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _InfoPanel(
            title: _t('legalControls'),
            children: [
              _InfoBullet(_t('checkIntegrity')),
              _InfoBullet(_t('checkSignature')),
              _InfoBullet(_t('checkWatermark')),
              _InfoBullet(_t('checkRegistry')),
              _InfoBullet(_t('checkScreen')),
              _InfoBullet(_t('checkSocial')),
            ],
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: _t('socialVerifyTitle'),
            children: [
              _InfoBullet(_t('socialVerifyStep1')),
              _InfoBullet(_t('socialVerifyStep2')),
              _InfoBullet(_t('socialVerifyStep3')),
              _InfoBullet(_t('socialVerifyStep4')),
            ],
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: _t('legalData'),
            children: [
              _InfoBullet(_t('data1')),
              _InfoBullet(_t('data2')),
              _InfoBullet(_t('data3')),
              _InfoBullet(_t('data4')),
            ],
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: _t('legalLimits'),
            children: [
              _InfoBullet(_t('limit1')),
              _InfoBullet(_t('limit2')),
              _InfoBullet(_t('limit3')),
            ],
          ),
          const SizedBox(height: 16),
          _LinkButton(
            icon: Icons.privacy_tip_outlined,
            title: _t('privacyPolicy'),
            value: privacyUrl,
            onPressed: () => _copy(context, privacyUrl),
          ),
          const SizedBox(height: 10),
          _LinkButton(
            icon: Icons.gavel_outlined,
            title: _t('terms'),
            value: termsUrl,
            onPressed: () => _copy(context, termsUrl),
          ),
          const SizedBox(height: 10),
          _LinkButton(
            icon: Icons.support_agent_rounded,
            title: _t('support'),
            value: supportEmail,
            onPressed: () => _copy(context, supportEmail),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

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
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoBullet extends StatelessWidget {
  const _InfoBullet(this.text);

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
            color: SigillumTheme.accent,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: SigillumTheme.muted,
                fontSize: 16,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.title,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SigillumTheme.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.copy_rounded),
        ],
      ),
    );
  }
}
