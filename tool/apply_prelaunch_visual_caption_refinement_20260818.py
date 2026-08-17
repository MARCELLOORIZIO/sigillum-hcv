from pathlib import Path
import re


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


def replace_regex(source: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count == 1:
        return updated
    if replacement in source:
        return source
    raise RuntimeError(f'{label}: regex anchor missing')


# 1) Commercial landing + all non-landing access screens.
gate_path = Path('lib/commercial_gate.dart')
gate = gate_path.read_text(encoding='utf-8')
create_account_card = r'''                  const SizedBox(height: 11),
                  _landingAction(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Crea account',
                    subtitle: 'Unisciti a SIGILLUM in un attimo',
                    accent: const Color(0xFF1FC7D4),
                    onTap: () => setState(() {
                      _loginMode = false;
                      _forgotMode = false;
                      _stage = _GateStage.auth;
                    }),
                  ),
'''
if create_account_card in gate:
    gate = gate.replace(create_account_card, '', 1)
if "title: 'Crea account'" in gate:
    raise RuntimeError('duplicate landing create-account action remains')

non_landing_pattern = r'''    return AutofillGroup\(\n.*?\n    \);\n  \}\n\n  Widget _content\(\)'''
non_landing_replacement = r'''    return AutofillGroup(
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9FA),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEAFBFF),
                Color(0xFFFAF9FA),
                Color(0xFFF2ECFF),
              ],
              stops: [0.0, 0.56, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: SigillumTheme.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x15280D5F),
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _content(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content()'''
gate = replace_regex(gate, non_landing_pattern, non_landing_replacement, 'commercial access landing-style shell')
for token in ["title: 'Accedi al tuo account'", "title: 'Diventa creator'", 'Color(0xFFEAFBFF)', 'BorderRadius.circular(30)', 'return AutofillGroup(']:
    if token not in gate:
        raise RuntimeError(f'commercial visual token missing: {token}')
gate_path.write_text(gate, encoding='utf-8')


# 2) Verification hub: media/document verification + dedicated text verification.
import_path = Path('lib/import_page.dart')
import_path.write_text(r'''import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'hcv_import_router_page.dart';
import 'sigillum_localization.dart';
import 'sigillum_theme.dart';
import 'text_social_verify_page.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, this.languageCode = 'it'});
  final String languageCode;
  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String status = '';
  String? selectedPath;
  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  bool get _it => widget.languageCode.toLowerCase().startsWith('it');

  @override
  void initState() {
    super.initState();
    status = _t('selectFileToVerify');
  }

  Future<void> pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      if (res == null) {
        setState(() => status = _t('noFileSelected'));
        return;
      }
      final path = res.files.single.path;
      if (path == null) {
        setState(() => status = _t('filePathUnavailable'));
        return;
      }
      setState(() {
        selectedPath = path;
        status = '${_t('fileSelected')}:\n$path';
      });
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HCVImportRouterPage(path: path, languageCode: widget.languageCode),
        ),
      );
    } catch (e) {
      setState(() => status = '${_t('importError')}: $e');
    }
  }

  void _openTextVerification() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextSocialVerifyPage(languageCode: widget.languageCode),
      ),
    );
  }

  bool isSupported(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.hcvpack') || lower.endsWith('.hcv') || lower.endsWith('.txt') ||
        lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') ||
        lower.endsWith('.pdf') || lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.m4v');
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: SigillumTheme.border),
            boxShadow: const [BoxShadow(color: Color(0x12280D5F), blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), shape: BoxShape.circle),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: SigillumTheme.ink, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: SigillumTheme.muted, fontSize: 14, height: 1.3)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(_t('verifyContentHeading'))),
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
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Verifica contenuto', textAlign: TextAlign.center, style: TextStyle(color: SigillumTheme.ink, fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(_it ? 'Scegli cosa vuoi controllare con SIGILLUM.' : 'Choose what you want to verify with SIGILLUM.', textAlign: TextAlign.center, style: const TextStyle(color: SigillumTheme.muted, fontSize: 16)),
                const SizedBox(height: 24),
                _actionCard(
                  icon: Icons.photo_library_outlined,
                  title: _it ? 'Verifica foto, video o documento' : 'Verify photo, video or document',
                  subtitle: _it ? 'Seleziona il contenuto originale o condiviso da controllare.' : 'Select the original or shared content to check.',
                  accent: SigillumTheme.accent,
                  onTap: pickFile,
                ),
                const SizedBox(height: 14),
                _actionCard(
                  icon: Icons.text_snippet_outlined,
                  title: _it ? 'VERIFICA TESTO PUBBLICATO' : 'VERIFY PUBLISHED TEXT',
                  subtitle: _it ? 'Messaggi, post e testi copiati da social o chat.' : 'Messages, posts and text copied from social media or chats.',
                  accent: SigillumTheme.accentAlt,
                  onTap: _openTextVerification,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(24), border: Border.all(color: SigillumTheme.border)),
                  child: Column(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: SigillumTheme.verified, size: 34),
                      const SizedBox(height: 8),
                      Text(status, textAlign: TextAlign.center, style: const TextStyle(color: SigillumTheme.muted)),
                      if (selectedPath != null) ...[
                        const SizedBox(height: 8),
                        Text(selectedPath!, textAlign: TextAlign.center, style: const TextStyle(color: SigillumTheme.muted, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
''', encoding='utf-8')


# 3) Creator home: same gradient/card visual language as first landing.
home_path = Path('lib/user_home_page.dart')
home = home_path.read_text(encoding='utf-8')
home_build_pattern = r'''  @override\n  Widget build\(BuildContext context\) \{\n    return Scaffold\(.*?\n  \}\n\}\n\nclass _Header'''
home_build_replacement = r'''  @override
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
                        onSessionInvalidated: widget.onSessionInvalidated ?? () {},
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                sliver: SliverList.list(
                  children: [
                    _PrimaryAction(icon: Icons.add_a_photo_rounded, title: _t('certifyMediaTitle'), subtitle: _t('certifyMediaSubtitle'), accent: SigillumTheme.accent, onPressed: () => _open(CameraPage(languageCode: languageCode))),
                    const SizedBox(height: 12),
                    _PrimaryAction(icon: Icons.article_rounded, title: _t('certifyTextTitle'), subtitle: _t('certifyTextSubtitle'), accent: SigillumTheme.accentAlt, onPressed: () => _open(TextCertPage(languageCode: languageCode))),
                    const SizedBox(height: 12),
                    _PrimaryAction(icon: Icons.verified_rounded, title: _t('verifyTitle'), subtitle: _t('verifySubtitle'), accent: SigillumTheme.verified, onPressed: () => _open(ImportPage(languageCode: languageCode))),
                    const SizedBox(height: 12),
                    _PrimaryAction(
                      icon: Icons.manage_accounts_rounded,
                      title: _t('accountTitle'),
                      subtitle: _t('accountSubtitle'),
                      accent: SigillumTheme.warning,
                      onPressed: () => _open(CommercialProfilePage(languageCode: languageCode, onLanguageChanged: _setLanguage, onSessionInvalidated: widget.onSessionInvalidated ?? () {})),
                    ),
                    const SizedBox(height: 12),
                    _PrimaryAction(icon: Icons.info_outline_rounded, title: _t('infoTitle'), subtitle: _t('infoSubtitle'), accent: SigillumTheme.accentAlt, onPressed: () => _open(LegalInfoPage(languageCode: languageCode))),
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

class _Header'''
home = replace_regex(home, home_build_pattern, home_build_replacement, 'creator home gradient shell')
header_logo_old = r'''            Container(
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
            ),'''
header_logo_new = r'''            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7645D9), Color(0xFF1FC7D4)]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Color(0x247645D9), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: const Icon(Icons.verified_user_rounded, color: Colors.white),
            ),'''
home = replace_once(home, header_logo_old, header_logo_new, 'creator home logo')
home = home.replace('color: SigillumTheme.ivory,\n            fontSize: 30,', 'color: SigillumTheme.ink,\n            fontSize: 30,', 1)
home = home.replace('color: SigillumTheme.ivory,\n                    fontWeight: FontWeight.w900,', 'color: SigillumTheme.ink,\n                    fontWeight: FontWeight.w900,', 1)
primary_pattern = r'''class _PrimaryAction extends StatelessWidget \{.*?\n\}\n\nclass _TrustChainCard'''
primary_replacement = r'''class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onPressed});
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
            boxShadow: const [BoxShadow(color: Color(0x12280D5F), blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(width: 55, height: 55, decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), shape: BoxShape.circle), child: Icon(icon, color: accent, size: 29)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: SigillumTheme.ink, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: SigillumTheme.muted, fontSize: 14, height: 1.28)),
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

class _TrustChainCard'''
home = replace_regex(home, primary_pattern, primary_replacement, 'creator home action cards')
panel_old = r'''      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x334B625A)),
      ),'''
panel_new = r'''      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SigillumTheme.border),
        boxShadow: const [BoxShadow(color: Color(0x10280D5F), blurRadius: 18, offset: Offset(0, 7))],
      ),'''
home = replace_once(home, panel_old, panel_new, 'creator home information panels')
home_path.write_text(home, encoding='utf-8')


# 4) Profile + legal pages.
profile_path = Path('lib/commercial_profile_page.dart')
profile = profile_path.read_text(encoding='utf-8')
profile = profile.replace(
    "    return Scaffold(\n      appBar: AppBar(title: Text(_t('title'))),\n      body: ListView(",
    "    return Scaffold(\n      backgroundColor: const Color(0xFFEAFBFF),\n      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(_t('title'))),\n      body: ListView(", 1)
profile = profile.replace(
    'borderRadius: BorderRadius.circular(12),',
    '''borderRadius: BorderRadius.circular(28),
              border: Border.all(color: SigillumTheme.border),
              boxShadow: const [BoxShadow(color: Color(0x12280D5F), blurRadius: 22, offset: Offset(0, 8))],''', 1)
section_old = r'''      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(12),
      ),'''
section_new = r'''      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: SigillumTheme.border),
        boxShadow: const [BoxShadow(color: Color(0x10280D5F), blurRadius: 18, offset: Offset(0, 7))],
      ),'''
profile = replace_once(profile, section_old, section_new, 'profile rounded sections')
profile_path.write_text(profile, encoding='utf-8')

legal_path = Path('lib/legal_info_page.dart')
legal = legal_path.read_text(encoding='utf-8')
legal = legal.replace(
    "    return Scaffold(\n      appBar: AppBar(title: Text(_t('legalPageTitle'))),",
    "    return Scaffold(\n      backgroundColor: const Color(0xFFEAFBFF),\n      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(_t('legalPageTitle'))),", 1)
legal = legal.replace('color: SigillumTheme.ivory,', 'color: SigillumTheme.ink,', 1)
legal_panel_old = r'''      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x334B625A)),
      ),'''
legal_panel_new = r'''      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: SigillumTheme.border),
        boxShadow: const [BoxShadow(color: Color(0x10280D5F), blurRadius: 18, offset: Offset(0, 7))],
      ),'''
legal = replace_once(legal, legal_panel_old, legal_panel_new, 'legal rounded panels')
legal_path.write_text(legal, encoding='utf-8')


# 5) Published text verification result page: landing-style surface/cards.
text_path = Path('lib/text_social_verify_page.dart')
text = text_path.read_text(encoding='utf-8')
if "import 'sigillum_theme.dart';" not in text:
    text = replace_once(text, "import 'hcv_verifier.dart';\n", "import 'hcv_verifier.dart';\nimport 'sigillum_theme.dart';\n", 'text verifier theme import')
text_build_pattern = r'''  @override\n  Widget build\(BuildContext context\) \{\n    final hasResult = _match != null \|\| _signatureValid == false;.*?\n  \}\n\}'''
text_build_replacement = r'''  @override
  Widget build(BuildContext context) {
    final hasResult = _match != null || _signatureValid == false;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(_label('Verifica testo pubblicato', 'Verify published text'))),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEAFBFF), Color(0xFFFAF9FA), Color(0xFFF2ECFF)]),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: SigillumTheme.border),
                boxShadow: const [BoxShadow(color: Color(0x12280D5F), blurRadius: 22, offset: Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.text_snippet_outlined, color: SigillumTheme.accentAlt, size: 42),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _textController,
                    minLines: 7,
                    maxLines: 18,
                    onChanged: (value) {
                      final detected = HCVTextIntegrity.extractHcvId(value);
                      if (detected != null && _idController.text != detected) _idController.text = detected;
                    },
                    decoration: InputDecoration(labelText: _label('Testo copiato dal social', 'Text copied from social media'), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _idController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(labelText: 'HCV-ID', helperText: _label('Viene letto automaticamente dalla riga SIGILLUM.', 'Automatically read from the SIGILLUM line.')),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _busy ? null : _verifyRegistryText,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(_busy ? _label('VERIFICA IN CORSO…', 'VERIFYING…') : _label('VERIFICA DAL REGISTRY', 'VERIFY FROM REGISTRY')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _busy ? null : _verifyTextPackage, icon: const Icon(Icons.inventory_2_outlined), label: Text(_label('APRI HCVPACK TESTO', 'OPEN TEXT HCVPACK'))),
                  if (_busy) ...[const SizedBox(height: 14), const LinearProgressIndicator()],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: hasResult ? _resultColor().withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.94),
                border: Border.all(color: hasResult ? _resultColor() : SigillumTheme.border),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Color(0x10280D5F), blurRadius: 18, offset: Offset(0, 7))],
              ),
              child: Column(
                children: [
                  Icon(hasResult ? Icons.verified_outlined : Icons.text_snippet_outlined, color: hasResult ? _resultColor() : SigillumTheme.muted, size: 48),
                  const SizedBox(height: 8),
                  Text(_resultTitle(), textAlign: TextAlign.center, style: TextStyle(color: hasResult ? _resultColor() : SigillumTheme.ink, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: SigillumTheme.ink)),
                  if (_source != null) ...[
                    const SizedBox(height: 6),
                    Text('${_label('Fonte', 'Source')}: $_source', style: const TextStyle(color: SigillumTheme.muted, fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (_originalFromPackage != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _copyOriginal, icon: const Icon(Icons.copy_all_outlined), label: Text(_label('COPIA TESTO ORIGINALE', 'COPY ORIGINAL TEXT'))),
            ],
          ],
        ),
      ),
    );
  }
}'''
text = replace_regex(text, text_build_pattern, text_build_replacement, 'text verifier visual composition')
text_path.write_text(text, encoding='utf-8')


# 6) Camera presentation only: white upper status, double-height proceed, derived captioned video.
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text(encoding='utf-8')
status_old = r'''      return Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
      );'''
status_new = r'''      return Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );'''
camera = replace_once(camera, status_old, status_new, 'camera upper status white')
proceed_old = r'''          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              italian ? 'ORA PUOI PROCEDERE' : 'PROCEED NOW',
            ),
          ),'''
proceed_new = r'''          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(280, 124),
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.check_rounded, size: 30),
            label: Text(italian ? 'ORA PUOI PROCEDERE' : 'PROCEED NOW', textAlign: TextAlign.center),
          ),'''
camera = replace_once(camera, proceed_old, proceed_new, 'double-height proceed control')
if 'String? _captionedVideoPath;' not in camera:
    camera = replace_once(camera, '  String? _subtitlePath;\n', '  String? _subtitlePath;\n  String? _captionedVideoPath;\n', 'captioned video state')
transcribe_old = r'''      setState(() {
        _videoTranscript = transcript.text;
        _subtitlePath = transcript.subtitlePath;
        status = 'TRASCRIZIONE PRONTA';
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trascrizione audio'),
          content: SingleChildScrollView(
            child: SelectableText(
              transcript.text.isEmpty
                  ? 'Sottotitoli creati.'
                  : transcript.text,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CHIUDI'),
            ),
          ],
        ),
      );'''
transcribe_new = r'''      setState(() {
        _videoTranscript = transcript.text;
        _subtitlePath = transcript.subtitlePath;
        _captionedVideoPath = transcript.captionedVideoPath;
        status = 'VIDEO SOTTOTITOLATO PRONTO';
      });
      await saveContentToGallery(transcript.captionedVideoPath);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Video sottotitolato creato'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Le scritte sono sincronizzate con l’audio e impresse nella copia video. L’originale certificato resta invariato.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                SelectableText(transcript.text.isEmpty ? 'Sottotitoli creati.' : transcript.text),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CHIUDI'))],
        ),
      );'''
camera = replace_once(camera, transcribe_old, transcribe_new, 'captioned video result')
share_subtitle_method = r'''  Future<void> _shareSubtitleFile() async {
    final path = _subtitlePath;
    if (path == null) return;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/x-subrip')],
      text: _videoTranscript == null || _videoTranscript!.isEmpty
          ? 'Sottotitoli SIGILLUM'
          : _videoTranscript!,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

'''
share_captioned_method = share_subtitle_method + r'''  Future<void> _shareCaptionedVideo() async {
    final path = _captionedVideoPath;
    if (path == null) return;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'video/mp4')],
      text: 'Copia video SIGILLUM con sottotitoli sincronizzati. L’originale certificato resta invariato.',
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

'''
if 'Future<void> _shareCaptionedVideo()' not in camera:
    camera = replace_once(camera, share_subtitle_method, share_captioned_method, 'captioned video share method')
camera = camera.replace("'TRASCRIVI AUDIO / CREA SOTTOTITOLI'", "'CREA VIDEO CON SOTTOTITOLI'", 1)
subtitle_buttons_old = r'''          if (_subtitlePath != null)
            SizedBox(
              width: 340,
              child: OutlinedButton.icon(
                onPressed: _shareSubtitleFile,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('CONDIVIDI SOTTOTITOLI .SRT'),
              ),
            ),
          if (_subtitlePath != null) const SizedBox(height: 10),'''
subtitle_buttons_new = r'''          if (_captionedVideoPath != null)
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                onPressed: _shareCaptionedVideo,
                icon: const Icon(Icons.closed_caption_rounded),
                label: const Text('CONDIVIDI VIDEO SOTTOTITOLATO'),
              ),
            ),
          if (_captionedVideoPath != null) const SizedBox(height: 10),
          if (_subtitlePath != null)
            SizedBox(
              width: 340,
              child: OutlinedButton.icon(
                onPressed: _shareSubtitleFile,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('CONDIVIDI SOTTOTITOLI .SRT'),
              ),
            ),
          if (_subtitlePath != null) const SizedBox(height: 10),'''
camera = replace_once(camera, subtitle_buttons_old, subtitle_buttons_new, 'captioned video action')
reset_anchor = r'''                                registryStatus = null;
                                recording = false;'''
reset_replacement = r'''                                registryStatus = null;
                                _videoTranscript = null;
                                _subtitlePath = null;
                                _captionedVideoPath = null;
                                recording = false;'''
camera = camera.replace(reset_anchor, reset_replacement)
for token in ['color: Colors.white,\n          fontSize: 14', 'minimumSize: const Size(280, 124)', 'CREA VIDEO CON SOTTOTITOLI', 'CONDIVIDI VIDEO SOTTOTITOLATO', 'L’originale certificato resta invariato.', 'transcript.captionedVideoPath']:
    if token not in camera:
        raise RuntimeError(f'camera presentation/caption token missing: {token}')
for forbidden in ['HCVDisplayRiskFusion.combine =', 'HCVEngine().setClaims =', 'verifyFile =']:
    if forbidden in camera:
        raise RuntimeError(f'engine mutation marker found in final UI patch: {forbidden}')
camera_path.write_text(camera, encoding='utf-8')


# 7) iOS derived-video renderer: exports a NEW mp4, never edits the certified source.
scene_path = Path('ios/Runner/SceneDelegate.swift')
scene = scene_path.read_text(encoding='utf-8')
if 'import QuartzCore\n' not in scene:
    scene = replace_once(scene, 'import Speech\n', 'import Speech\nimport QuartzCore\n', 'QuartzCore subtitle renderer import')
burn_branch_anchor = '''        self.transcribeVideo(path: path, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
'''
burn_branch = '''        self.transcribeVideo(path: path, result: result)
      } else if call.method == "burnSubtitles" {
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let outputPath = args["outputPath"] as? String,
          let segments = args["segments"] as? [[String: Any]],
          !path.isEmpty,
          !outputPath.isEmpty
        else {
          result(FlutterError(code: "INVALID_SUBTITLE_EXPORT", message: "Parametri sottotitoli non validi.", details: nil))
          return
        }
        self.burnSubtitles(videoPath: path, outputPath: outputPath, segments: segments, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
'''
if 'call.method == "burnSubtitles"' not in scene:
    scene = replace_once(scene, burn_branch_anchor, burn_branch, 'burn subtitles media-channel branch')
burn_method = r'''  private func burnSubtitles(
    videoPath: String,
    outputPath: String,
    segments: [[String: Any]],
    result: @escaping FlutterResult
  ) {
    let sourceURL = URL(fileURLWithPath: videoPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    let asset = AVURLAsset(url: sourceURL)

    guard let sourceVideoTrack = asset.tracks(withMediaType: .video).first else {
      result(FlutterError(code: "SUBTITLE_VIDEO_TRACK_MISSING", message: "Traccia video non disponibile.", details: nil))
      return
    }
    let composition = AVMutableComposition()
    guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      result(FlutterError(code: "SUBTITLE_COMPOSITION_ERROR", message: "Impossibile preparare la copia sottotitolata.", details: nil))
      return
    }
    do {
      try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: sourceVideoTrack, at: .zero)
      if let sourceAudioTrack = asset.tracks(withMediaType: .audio).first,
         let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
        try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: sourceAudioTrack, at: .zero)
      }
    } catch {
      result(FlutterError(code: "SUBTITLE_COMPOSITION_ERROR", message: error.localizedDescription, details: nil))
      return
    }

    let naturalRect = CGRect(origin: .zero, size: sourceVideoTrack.naturalSize)
    let transformedRect = naturalRect.applying(sourceVideoTrack.preferredTransform)
    let renderSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
    guard renderSize.width > 0, renderSize.height > 0 else {
      result(FlutterError(code: "SUBTITLE_RENDER_SIZE_ERROR", message: "Dimensioni video non valide.", details: nil))
      return
    }
    var normalizedTransform = sourceVideoTrack.preferredTransform
    normalizedTransform.tx -= transformedRect.origin.x
    normalizedTransform.ty -= transformedRect.origin.y
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
    layerInstruction.setTransform(normalizedTransform, at: .zero)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
    instruction.layerInstructions = [layerInstruction]
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = renderSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.instructions = [instruction]

    let parentLayer = CALayer()
    parentLayer.frame = CGRect(origin: .zero, size: renderSize)
    let videoLayer = CALayer()
    videoLayer.frame = parentLayer.frame
    let overlayLayer = CALayer()
    overlayLayer.frame = parentLayer.frame
    parentLayer.addSublayer(videoLayer)
    parentLayer.addSublayer(overlayLayer)
    let horizontalInset = max(22.0, renderSize.width * 0.055)
    let captionHeight = max(76.0, renderSize.height * 0.13)
    let captionY = max(34.0, renderSize.height * 0.065)
    let fontSize = max(24.0, min(46.0, renderSize.width * 0.052))

    for item in segments {
      guard let text = item["text"] as? String,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
      let start = (item["start"] as? NSNumber)?.doubleValue ?? 0
      let duration = max(0.45, (item["duration"] as? NSNumber)?.doubleValue ?? 1.0)
      let captionLayer = CATextLayer()
      captionLayer.string = text
      captionLayer.frame = CGRect(x: horizontalInset, y: captionY, width: renderSize.width - (horizontalInset * 2), height: captionHeight)
      captionLayer.alignmentMode = .center
      captionLayer.truncationMode = .end
      captionLayer.isWrapped = true
      captionLayer.fontSize = fontSize
      captionLayer.contentsScale = 2.0
      captionLayer.foregroundColor = UIColor.white.cgColor
      captionLayer.backgroundColor = UIColor.black.withAlphaComponent(0.72).cgColor
      captionLayer.cornerRadius = max(10.0, renderSize.width * 0.018)
      captionLayer.masksToBounds = true
      captionLayer.opacity = 0
      let visibility = CAKeyframeAnimation(keyPath: "opacity")
      visibility.values = [0.0, 1.0, 1.0, 0.0]
      visibility.keyTimes = [0.0, 0.03, 0.97, 1.0]
      visibility.beginTime = AVCoreAnimationBeginTimeAtZero + max(0, start)
      visibility.duration = duration
      visibility.isRemovedOnCompletion = false
      visibility.fillMode = .both
      captionLayer.add(visibility, forKey: "sigillumCaptionVisibility")
      overlayLayer.addSublayer(captionLayer)
    }
    videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

    do {
      try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: outputURL.path) { try FileManager.default.removeItem(at: outputURL) }
    } catch {
      result(FlutterError(code: "SUBTITLE_OUTPUT_ERROR", message: error.localizedDescription, details: nil))
      return
    }
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      result(FlutterError(code: "SUBTITLE_EXPORT_ERROR", message: "Esportazione video non disponibile.", details: nil))
      return
    }
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.videoComposition = videoComposition
    exporter.exportAsynchronously {
      DispatchQueue.main.async {
        switch exporter.status {
        case .completed:
          result(["path": outputPath])
        case .failed, .cancelled:
          result(FlutterError(code: "SUBTITLE_EXPORT_ERROR", message: exporter.error?.localizedDescription ?? "Creazione del video sottotitolato non riuscita.", details: nil))
        default:
          result(FlutterError(code: "SUBTITLE_EXPORT_ERROR", message: "Esportazione video non completata.", details: nil))
        }
      }
    }
  }

'''
if 'private func burnSubtitles(' not in scene:
    scene = replace_once(scene, '  private func transcribeVideo(path: String, result: @escaping FlutterResult) {\n', burn_method + '  private func transcribeVideo(path: String, result: @escaping FlutterResult) {\n', 'native burn-subtitles method')
for token in ['call.method == "burnSubtitles"', 'AVVideoCompositionCoreAnimationTool', 'CATextLayer()', 'outputFileType = .mp4']:
    if token not in scene:
        raise RuntimeError(f'native subtitle token missing: {token}')
scene_path.write_text(scene, encoding='utf-8')


# Final contracts.
Path('test/prelaunch_visual_caption_refinement_contract_test.dart').write_text(
    r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landing has one creator-registration entry and matching visual shell', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    expect(gate, contains("title: 'Accedi al tuo account'"));
    expect(gate, contains("title: 'Diventa creator'"));
    expect(gate, isNot(contains("title: 'Crea account'")));
    expect(gate, contains('Color(0xFFEAFBFF)'));
    expect(gate, contains('BorderRadius.circular(30)'));
  });

  test('verification hub exposes dedicated published-text verification', () {
    final page = File('lib/import_page.dart').readAsStringSync();
    expect(page, contains('VERIFICA TESTO PUBBLICATO'));
    expect(page, contains('TextSocialVerifyPage('));
    expect(page, contains('Verifica foto, video o documento'));
  });

  test('camera status is white and proceed control is double height', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    expect(camera, contains('minimumSize: const Size(280, 124)'));
    expect(camera, contains('color: Colors.white,\n          fontSize: 14'));
  });

  test('captioned video is a derived synchronized copy', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final service = File('lib/video_transcription_service.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    expect(camera, contains('CONDIVIDI VIDEO SOTTOTITOLATO'));
    expect(camera, contains('L’originale certificato resta invariato.'));
    expect(service, contains('captionedVideoPath'));
    expect(service, contains("'burnSubtitles'"));
    expect(scene, contains('call.method == "burnSubtitles"'));
    expect(scene, contains('AVVideoCompositionCoreAnimationTool'));
    expect(scene, contains('CATextLayer()'));
  });

  test('final refinement does not alter HCV engine contracts', () {
    final service = File('lib/video_transcription_service.dart').readAsStringSync();
    expect(service, isNot(contains('HCVEngine')));
    expect(service, isNot(contains('HCVDisplayRiskFusion')));
    expect(service, isNot(contains('setClaims(')));
  });
}
''', encoding='utf-8')

print('Final SIGILLUM visual, text-verification and derived-caption refinement applied')
