from pathlib import Path
import re

path = Path('lib/commercial_gate.dart')
source = path.read_text(encoding='utf-8')

# The landing page needs to bypass the compact auth scaffold so the approved
# light-blue gradient can cover the whole screen. This touches presentation
# only; capture/HCV/Registry code is not involved.
creator_anchor = """    if (_stage == _GateStage.creator) {
      return UserHomePage(onSessionInvalidated: _onSessionInvalidated);
    }
"""
landing_bypass = creator_anchor + """    if (_stage == _GateStage.landing) {
      return Scaffold(body: _landing());
    }
"""
if "return Scaffold(body: _landing());" not in source:
    if source.count(creator_anchor) != 1:
        raise RuntimeError(
            f'landing scaffold anchor: expected 1, found {source.count(creator_anchor)}'
        )
    source = source.replace(creator_anchor, landing_bypass, 1)

brand_pattern = re.compile(
    r"  Widget _brand\(\{String\? subtitle\}\) \{.*?\n  \}\n\n  Widget _landing\(\)",
    re.S,
)
brand_replacement = r'''  Widget _sigillumMark({double size = 58}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7645D9), Color(0xFF1FC7D4)],
        ),
        borderRadius: BorderRadius.circular(size * 0.30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x247645D9),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.verified_user_rounded,
        size: size * 0.62,
        color: Colors.white,
      ),
    );
  }

  Widget _brand({String? subtitle}) {
    return Column(
      children: [
        _sigillumMark(size: 66),
        const SizedBox(height: 16),
        const Text(
          'SIGILLUM',
          style: TextStyle(
            color: SigillumTheme.ink,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle ?? 'Human Content Verification',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SigillumTheme.muted,
            fontSize: 16,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _landingAction({
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
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE7E3EB)),
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
                width: 54,
                height: 54,
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
                        height: 1.25,
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

  Widget _landing()'''
source, count = brand_pattern.subn(brand_replacement, source, count=1)
if count != 1 and 'Widget _landingAction({' not in source:
    raise RuntimeError('approved landing brand/action anchor missing')

landing_pattern = re.compile(
    r"  Widget _landing\(\) \{.*?\n  \}\n\n  Widget _auth\(\)",
    re.S,
)
landing_replacement = r'''  Widget _landing() {
    return Container(
      key: const ValueKey('landing-visual-v2'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: double.infinity),
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
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _sigillumMark(size: 52),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIGILLUM',
                              style: TextStyle(
                                color: SigillumTheme.ink,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Verifica. Condividi. Proteggi.',
                              style: TextStyle(
                                color: SigillumTheme.accentAlt,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _openLegal,
                        tooltip: 'Informazioni',
                        icon: const Icon(Icons.help_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: SigillumTheme.ink,
                        fontSize: 34,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                      children: [
                        const TextSpan(text: 'Benvenuto in '),
                        TextSpan(
                          text: 'SIGILLUM!',
                          style: TextStyle(color: SigillumTheme.accentAlt),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Verifica l’autenticità dei contenuti digitali e condividi con fiducia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SigillumTheme.ink,
                      fontSize: 17,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE7E3EB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x15280D5F),
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Verifica in pochi secondi',
                          style: TextStyle(
                            color: SigillumTheme.ink,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scansiona un codice SIGILLUM o inserisci l’HCV-ID per controllare foto, video, documenti e messaggi.',
                          style: TextStyle(
                            color: SigillumTheme.ink,
                            fontSize: 15.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 148,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.rotate(
                                angle: 0.08,
                                child: Container(
                                  width: 102,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFE8E0FF), Color(0xFFC6F5F8)],
                                    ),
                                    borderRadius: BorderRadius.circular(27),
                                    border: Border.all(
                                      color: const Color(0xFF9C7DE8),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.verified_user_rounded,
                                      size: 52,
                                      color: Color(0xFF1FC7D4),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 18,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD7F7FA),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x251FC7D4),
                                        blurRadius: 12,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'ID SIGILLUM\nF80B0A573FBB4940',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF280D5F),
                                      fontSize: 10.5,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 24,
                                bottom: 22,
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Color(0xFF1FC7D4),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 31,
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 36,
                                bottom: 20,
                                child: Icon(
                                  Icons.image_rounded,
                                  color: Color(0xFF9C7DE8),
                                  size: 34,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        FilledButton.icon(
                          onPressed: _openVerify,
                          icon: const Icon(Icons.center_focus_strong_rounded),
                          label: const Text('VERIFICA CONTENUTO GRATIS'),
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.security_rounded,
                              size: 18,
                              color: SigillumTheme.accentAlt,
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Sicuro, veloce, senza registrazione',
                                style: TextStyle(
                                  color: SigillumTheme.muted,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _landingAction(
                    icon: Icons.login_rounded,
                    title: 'Accedi al tuo account',
                    subtitle: 'Entra e gestisci le tue verifiche',
                    accent: const Color(0xFF7645D9),
                    onTap: () => setState(() {
                      _loginMode = true;
                      _forgotMode = false;
                      _stage = _GateStage.auth;
                    }),
                  ),
                  const SizedBox(height: 11),
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
                  const SizedBox(height: 11),
                  _landingAction(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Diventa creator',
                    subtitle: 'Proteggi e valorizza i tuoi contenuti',
                    accent: const Color(0xFFFFB237),
                    onTap: () => setState(() {
                      _loginMode = false;
                      _forgotMode = false;
                      _stage = _GateStage.auth;
                    }),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF3EEFF), Color(0xFFEAFBFF)],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFFE7E3EB)),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 27,
                          backgroundColor: Color(0xFFE6DDFF),
                          child: Icon(
                            Icons.handshake_outlined,
                            size: 31,
                            color: Color(0xFF7645D9),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Insieme costruiamo fiducia',
                                style: TextStyle(
                                  color: SigillumTheme.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'SIGILLUM rende il web più trasparente e verificabile.',
                                style: TextStyle(
                                  color: SigillumTheme.muted,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      TextButton.icon(
                        onPressed: _openLegal,
                        icon: const Icon(Icons.shield_outlined, size: 18),
                        label: const Text('Privacy'),
                      ),
                      TextButton.icon(
                        onPressed: _openLegal,
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Termini'),
                      ),
                      TextButton.icon(
                        onPressed: _openLegal,
                        icon: const Icon(Icons.support_agent_rounded, size: 18),
                        label: const Text('Supporto'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _auth()'''
source, count = landing_pattern.subn(landing_replacement, source, count=1)
if count != 1 and "ValueKey('landing-visual-v2')" not in source:
    raise RuntimeError('approved landing composition anchor missing')

required = [
    "ValueKey('landing-visual-v2')",
    'Benvenuto in ',
    'Verifica in pochi secondi',
    'VERIFICA CONTENUTO GRATIS',
    'Accedi al tuo account',
    'Crea account',
    'Diventa creator',
    'Insieme costruiamo fiducia',
    'Color(0xFFEAFBFF)',
    'Color(0xFF7645D9)',
    'Color(0xFF1FC7D4)',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'landing visual token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Approved SIGILLUM landing composition applied without capture/HCV changes')
