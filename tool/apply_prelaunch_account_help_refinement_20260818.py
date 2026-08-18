from pathlib import Path
import re


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


gate_path = Path('lib/commercial_gate.dart')
gate = gate_path.read_text(encoding='utf-8')

if "import 'recent_account_service.dart';" not in gate:
    gate = replace_once(
        gate,
        "import 'legal_info_page.dart';\n",
        "import 'legal_info_page.dart';\nimport 'recent_account_service.dart';\nimport 'sigillum_quick_guide_page.dart';\n",
        'commercial guide/recent-account imports',
    )

field_anchor = "  final CommercialAccountService _account = const CommercialAccountService();\n"
if 'final RecentAccountService _recentAccountService' not in gate:
    gate = replace_once(
        gate,
        field_anchor,
        field_anchor + """  final RecentAccountService _recentAccountService = const RecentAccountService();
  List<String> _recentEmails = const [];
""",
        'recent account state',
    )

init_anchor = """    CommercialBillingService.instance.startListening();
    _purchaseSub =
        CommercialBillingService.instance.purchases.listen(_onPurchases);
    _bootstrap();
"""
if 'Future.microtask(_loadRecentAccounts);' not in gate:
    gate = replace_once(
        gate,
        init_anchor,
        """    CommercialBillingService.instance.startListening();
    _purchaseSub =
        CommercialBillingService.instance.purchases.listen(_onPurchases);
    Future.microtask(_loadRecentAccounts);
    _bootstrap();
""",
        'recent account bootstrap',
    )

methods = r'''  Future<void> _loadRecentAccounts() async {
    final accounts = await _recentAccountService.load();
    if (!mounted) return;
    setState(() => _recentEmails = accounts);
  }

  Future<void> _rememberCurrentEmail() async {
    final accounts = await _recentAccountService.remember(_email.text);
    if (!mounted) return;
    setState(() => _recentEmails = accounts);
  }

  Future<void> _forgetRecentEmail(String email) async {
    final accounts = await _recentAccountService.forget(email);
    if (!mounted) return;
    setState(() {
      _recentEmails = accounts;
      if (_email.text.trim().toLowerCase() == email.toLowerCase()) {
        _email.clear();
        _password.clear();
      }
    });
  }

  void _useRecentEmail(String email) {
    TextInput.finishAutofillContext(shouldSave: false);
    setState(() {
      _loginMode = true;
      _forgotMode = false;
      _email.text = email;
      _password.clear();
      _message = '';
    });
  }

  void _openQuickGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SigillumQuickGuidePage(languageCode: 'it'),
      ),
    );
  }

  Widget _recentAccountPicker() {
    if (!_loginMode || _forgotMode || _recentEmails.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SigillumTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Account usati su questo iPhone',
            style: TextStyle(
              color: SigillumTheme.ink,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final email in _recentEmails)
                InputChip(
                  avatar: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text(email),
                  onPressed: () => _useRecentEmail(email),
                  onDeleted: () => _forgetRecentEmail(email),
                  deleteIcon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Scegli prima l’account. Se iOS mostra una sola password, tocca Password/chiave sulla tastiera e seleziona l’altra credenziale salvata.',
            style: TextStyle(
              color: SigillumTheme.muted,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

'''
if 'Widget _recentAccountPicker()' not in gate:
    gate = replace_once(
        gate,
        '  Future<void> _bootstrap() async {\n',
        methods + '  Future<void> _bootstrap() async {\n',
        'recent account methods',
    )

# Remember the username only after a real successful login.
gate = gate.replace(
    "      _applyEnvelope(envelope);\n      TextInput.finishAutofillContext(shouldSave: true);",
    "      _applyEnvelope(envelope);\n      await _rememberCurrentEmail();\n      TextInput.finishAutofillContext(shouldSave: true);",
)
gate = gate.replace(
    "        _applyEnvelope(envelope);\n        TextInput.finishAutofillContext(shouldSave: true);",
    "        _applyEnvelope(envelope);\n        await _rememberCurrentEmail();\n        TextInput.finishAutofillContext(shouldSave: true);",
)

email_anchor = """        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
"""
if '_recentAccountPicker(),' not in gate:
    gate = replace_once(
        gate,
        email_anchor,
        """        if (_loginMode && !_forgotMode && _recentEmails.isNotEmpty) ...[
          _recentAccountPicker(),
          const SizedBox(height: 14),
        ],
""" + email_anchor,
        'recent account picker placement',
    )

# The permanent question-mark button opens the quick workflow guide.
gate = gate.replace(
    "onPressed: _openLegal,\n                        tooltip: 'Informazioni',\n                        icon: const Icon(Icons.help_outline_rounded),",
    "onPressed: _openQuickGuide,\n                        tooltip: 'Come si usa',\n                        icon: const Icon(Icons.help_outline_rounded),",
    1,
)

# Explicit landing action below Creator.
if "title: 'Come si usa SIGILLUM'" not in gate:
    pattern = re.compile(
        r"(                  _landingAction\(\n                    icon: Icons\.auto_awesome_rounded,\n                    title: 'Diventa creator',.*?\n                  \),)\n                  const SizedBox\(height: 16\),",
        re.S,
    )
    gate, count = pattern.subn(
        r"\1\n                  const SizedBox(height: 11),\n                  _landingAction(\n                    icon: Icons.help_center_rounded,\n                    title: 'Come si usa SIGILLUM',\n                    subtitle: 'Guida rapida: camera, file, verifica e sottotitoli',\n                    accent: const Color(0xFF31D0AA),\n                    onTap: _openQuickGuide,\n                  ),\n                  const SizedBox(height: 16),",
        gate,
        count=1,
    )
    if count != 1:
        raise RuntimeError('landing quick-guide action anchor missing')

for token in [
    'RecentAccountService',
    'Account usati su questo iPhone',
    "title: 'Come si usa SIGILLUM'",
    'SigillumQuickGuidePage',
    'await _rememberCurrentEmail()',
]:
    if token not in gate:
        raise RuntimeError(f'commercial usability token missing: {token}')

gate_path.write_text(gate, encoding='utf-8')

home_path = Path('lib/user_home_page.dart')
home = home_path.read_text(encoding='utf-8')
if "import 'sigillum_quick_guide_page.dart';" not in home:
    home = replace_once(
        home,
        "import 'sigillum_theme.dart';\n",
        "import 'sigillum_theme.dart';\nimport 'sigillum_quick_guide_page.dart';\n",
        'creator guide import',
    )

info_anchor = "                    _PrimaryAction(icon: Icons.info_outline_rounded, title: _t('infoTitle'), subtitle: _t('infoSubtitle'), accent: SigillumTheme.accentAlt, onPressed: () => _open(LegalInfoPage(languageCode: languageCode))),"
if 'Quick guide to camera, files, verification and captions' not in home:
    guide_action = r'''                    _PrimaryAction(
                      icon: Icons.help_center_rounded,
                      title: languageCode.toLowerCase().startsWith('it') ? 'Come si usa SIGILLUM' : 'How to use SIGILLUM',
                      subtitle: languageCode.toLowerCase().startsWith('it') ? 'Guida rapida a camera, file, verifica e sottotitoli' : 'Quick guide to camera, files, verification and captions',
                      accent: SigillumTheme.verified,
                      onPressed: () => _open(SigillumQuickGuidePage(languageCode: languageCode)),
                    ),
                    const SizedBox(height: 12),
'''
    home = replace_once(home, info_anchor, guide_action + info_anchor, 'creator guide action')

home_path.write_text(home, encoding='utf-8')
print('SIGILLUM recent-account selector and quick-guide wiring applied')
