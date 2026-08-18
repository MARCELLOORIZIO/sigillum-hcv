from pathlib import Path

PATH = Path('lib/commercial_gate.dart')
source = PATH.read_text(encoding='utf-8')

if "ValueKey('landing-visual-v2')" not in source:
    print('Approved visual landing not present; landing localization not required in this source shape')
    raise SystemExit(0)

landing_copy = r'''
const _landingVisualCopy = <String, Map<String, String>>{
  'it': {
    'tagline': 'Verifica. Condividi. Proteggi.',
    'info': 'Informazioni',
    'welcomePrefix': 'Benvenuto in ',
    'heroSubtitle': 'Verifica l’autenticità dei contenuti digitali e condividi con fiducia.',
    'verifySeconds': 'Verifica in pochi secondi',
    'scanDescription': 'Scansiona un codice SIGILLUM o inserisci l’HCV-ID per controllare foto, video, documenti e messaggi.',
    'verifyFree': 'VERIFICA CONTENUTO GRATIS',
    'secureFast': 'Sicuro, veloce, senza registrazione',
    'loginTitle': 'Accedi al tuo account',
    'loginSubtitle': 'Entra e gestisci le tue verifiche',
    'createTitle': 'Crea account',
    'createSubtitle': 'Unisciti a SIGILLUM in un attimo',
    'creatorTitle': 'Diventa creator',
    'creatorSubtitle': 'Proteggi e valorizza i tuoi contenuti',
    'trustTitle': 'Insieme costruiamo fiducia',
    'trustSubtitle': 'SIGILLUM rende il web più trasparente e verificabile.',
    'privacy': 'Privacy',
    'terms': 'Termini',
    'support': 'Supporto',
  },
  'en': {
    'tagline': 'Verify. Share. Protect.',
    'info': 'Information',
    'welcomePrefix': 'Welcome to ',
    'heroSubtitle': 'Verify the authenticity of digital content and share with confidence.',
    'verifySeconds': 'Verify in seconds',
    'scanDescription': 'Scan a SIGILLUM code or enter the HCV-ID to check photos, videos, documents and messages.',
    'verifyFree': 'VERIFY CONTENT FOR FREE',
    'secureFast': 'Secure, fast, no registration required',
    'loginTitle': 'Sign in to your account',
    'loginSubtitle': 'Access and manage your verifications',
    'createTitle': 'Create account',
    'createSubtitle': 'Join SIGILLUM in a moment',
    'creatorTitle': 'Become a creator',
    'creatorSubtitle': 'Protect and enhance the value of your content',
    'trustTitle': 'Building trust together',
    'trustSubtitle': 'SIGILLUM makes the web more transparent and verifiable.',
    'privacy': 'Privacy',
    'terms': 'Terms',
    'support': 'Support',
  },
  'es': {
    'tagline': 'Verifica. Comparte. Protege.',
    'info': 'Información',
    'welcomePrefix': 'Bienvenido a ',
    'heroSubtitle': 'Verifica la autenticidad de los contenidos digitales y compártelos con confianza.',
    'verifySeconds': 'Verifica en pocos segundos',
    'scanDescription': 'Escanea un código SIGILLUM o introduce el HCV-ID para comprobar fotos, vídeos, documentos y mensajes.',
    'verifyFree': 'VERIFICAR CONTENIDO GRATIS',
    'secureFast': 'Seguro, rápido y sin registro',
    'loginTitle': 'Accede a tu cuenta',
    'loginSubtitle': 'Entra y gestiona tus verificaciones',
    'createTitle': 'Crear cuenta',
    'createSubtitle': 'Únete a SIGILLUM en un instante',
    'creatorTitle': 'Conviértete en creator',
    'creatorSubtitle': 'Protege y da valor a tus contenidos',
    'trustTitle': 'Construimos confianza juntos',
    'trustSubtitle': 'SIGILLUM hace que la web sea más transparente y verificable.',
    'privacy': 'Privacidad',
    'terms': 'Términos',
    'support': 'Soporte',
  },
  'ru': {
    'tagline': 'Проверяйте. Делитесь. Защищайте.',
    'info': 'Информация',
    'welcomePrefix': 'Добро пожаловать в ',
    'heroSubtitle': 'Проверяйте подлинность цифрового контента и делитесь им с уверенностью.',
    'verifySeconds': 'Проверка за несколько секунд',
    'scanDescription': 'Отсканируйте код SIGILLUM или введите HCV-ID, чтобы проверить фото, видео, документы и сообщения.',
    'verifyFree': 'ПРОВЕРИТЬ КОНТЕНТ БЕСПЛАТНО',
    'secureFast': 'Безопасно, быстро, без регистрации',
    'loginTitle': 'Войти в аккаунт',
    'loginSubtitle': 'Войдите и управляйте своими проверками',
    'createTitle': 'Создать аккаунт',
    'createSubtitle': 'Присоединяйтесь к SIGILLUM за несколько мгновений',
    'creatorTitle': 'Стать creator',
    'creatorSubtitle': 'Защищайте и повышайте ценность своего контента',
    'trustTitle': 'Вместе создаём доверие',
    'trustSubtitle': 'SIGILLUM делает интернет более прозрачным и проверяемым.',
    'privacy': 'Конфиденциальность',
    'terms': 'Условия',
    'support': 'Поддержка',
  },
};
'''

if 'const _landingVisualCopy' not in source:
    marker = '\nenum _GateStage {'
    if source.count(marker) != 1:
        raise RuntimeError('landing copy insertion boundary missing')
    source = source.replace(marker, '\n' + landing_copy + marker, 1)

if 'String _lv(String key)' not in source:
    anchor = '  Future<void> _loadLanguage() async {\n'
    helper = """  String _lv(String key) =>
      (_landingVisualCopy[_languageCode] ?? _landingVisualCopy['en']!)[key] ??
      _landingVisualCopy['en']![key] ??
      key;

"""
    if source.count(anchor) != 1:
        raise RuntimeError('landing translation helper anchor missing')
    source = source.replace(anchor, helper + anchor, 1)

# Put the selector at the top of the first page, before any account action.
first_page_anchor = """            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
"""
first_page_new = """            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _languageSelector(),
                  const SizedBox(height: 10),
                  Row(
"""
if '_languageSelector(),\n                  const SizedBox(height: 10),\n                  Row(' not in source:
    if source.count(first_page_anchor) != 1:
        raise RuntimeError('first-page language selector anchor missing')
    source = source.replace(first_page_anchor, first_page_new, 1)

replacements = {
    "                      const Expanded(\n                        child: Column(": "                      Expanded(\n                        child: Column(",
    "                              'Verifica. Condividi. Proteggi.',": "                              _lv('tagline'),",
    "                        tooltip: 'Informazioni',": "                        tooltip: _lv('info'),",
    "                        const TextSpan(text: 'Benvenuto in '),": "                        TextSpan(text: _lv('welcomePrefix')),",
    "                  const Text(\n                    'Verifica l’autenticità dei contenuti digitali e condividi con fiducia.',": "                  Text(\n                    _lv('heroSubtitle'),",
    "                        const Text(\n                          'Verifica in pochi secondi',": "                        Text(\n                          _lv('verifySeconds'),",
    "                        const Text(\n                          'Scansiona un codice SIGILLUM o inserisci l’HCV-ID per controllare foto, video, documenti e messaggi.',": "                        Text(\n                          _lv('scanDescription'),",
    "                          label: const Text('VERIFICA CONTENUTO GRATIS'),": "                          label: Text(_lv('verifyFree')) ,",
    "                        const Row(\n                          mainAxisAlignment: MainAxisAlignment.center,": "                        Row(\n                          mainAxisAlignment: MainAxisAlignment.center,",
    "                                'Sicuro, veloce, senza registrazione',": "                                _lv('secureFast'),",
    "                    title: 'Accedi al tuo account',": "                    title: _lv('loginTitle'),",
    "                    subtitle: 'Entra e gestisci le tue verifiche',": "                    subtitle: _lv('loginSubtitle'),",
    "                    title: 'Crea account',": "                    title: _lv('createTitle'),",
    "                    subtitle: 'Unisciti a SIGILLUM in un attimo',": "                    subtitle: _lv('createSubtitle'),",
    "                    title: 'Diventa creator',": "                    title: _lv('creatorTitle'),",
    "                    subtitle: 'Proteggi e valorizza i tuoi contenuti',": "                    subtitle: _lv('creatorSubtitle'),",
    "                    child: const Row(\n                      children: [\n                        CircleAvatar(": "                    child: Row(\n                      children: [\n                        const CircleAvatar(",
    "                                'Insieme costruiamo fiducia',": "                                _lv('trustTitle'),",
    "                                'SIGILLUM rende il web più trasparente e verificabile.',": "                                _lv('trustSubtitle'),",
    "                        label: const Text('Privacy'),": "                        label: Text(_lv('privacy')) ,",
    "                        label: const Text('Termini'),": "                        label: Text(_lv('terms')) ,",
    "                        label: const Text('Supporto'),": "                        label: Text(_lv('support')) ,",
}
for old, new in replacements.items():
    if old in source:
        source = source.replace(old, new, 1)

# Once dynamic text is introduced, keep immutable style objects const while the
# surrounding Text/Row widgets remain non-const.
source = source.replace("style: TextStyle(\n                              color: SigillumTheme.accentAlt,", "style: const TextStyle(\n                              color: SigillumTheme.accentAlt,")
source = source.replace("style: TextStyle(\n                      color: SigillumTheme.ink,\n                      fontSize: 17,", "style: const TextStyle(\n                      color: SigillumTheme.ink,\n                      fontSize: 17,")
source = source.replace("style: TextStyle(\n                            color: SigillumTheme.ink,\n                            fontSize: 23,", "style: const TextStyle(\n                            color: SigillumTheme.ink,\n                            fontSize: 23,")
source = source.replace("style: TextStyle(\n                            color: SigillumTheme.ink,\n                            fontSize: 15.5,", "style: const TextStyle(\n                            color: SigillumTheme.ink,\n                            fontSize: 15.5,")
source = source.replace("style: TextStyle(\n                                  color: SigillumTheme.muted,\n                                  fontSize: 13.5,", "style: const TextStyle(\n                                  color: SigillumTheme.muted,\n                                  fontSize: 13.5,")
source = source.replace("style: TextStyle(\n                                  color: SigillumTheme.ink,\n                                  fontSize: 17,", "style: const TextStyle(\n                                  color: SigillumTheme.ink,\n                                  fontSize: 17,")
source = source.replace("style: TextStyle(\n                                  color: SigillumTheme.muted,\n                                  fontSize: 14,", "style: const TextStyle(\n                                  color: SigillumTheme.muted,\n                                  fontSize: 14,")

for required in [
    'const _landingVisualCopy',
    "'es': {",
    "'ru': {",
    'String _lv(String key)',
    "_lv('welcomePrefix')",
    "_lv('heroSubtitle')",
    "_lv('verifySeconds')",
    "_lv('loginTitle')",
    "_lv('trustTitle')",
    "_lv('support')",
]:
    if required not in source:
        raise RuntimeError(f'localized approved landing token missing: {required}')

# No Italian-only visible copy from the approved landing may remain. Italian
# strings remain only inside the translation dictionary, not as UI literals.
landing_start = source.index("ValueKey('landing-visual-v2')")
for forbidden in [
    "'Verifica. Condividi. Proteggi.'",
    "'Benvenuto in '",
    "'Verifica l’autenticità dei contenuti digitali e condividi con fiducia.'",
    "'Verifica in pochi secondi'",
    "'Accedi al tuo account'",
    "'Crea account'",
    "'Diventa creator'",
    "'Insieme costruiamo fiducia'",
]:
    if forbidden in source[landing_start:]:
        raise RuntimeError(f'Italian-only approved landing copy remains: {forbidden}')

PATH.write_text(source, encoding='utf-8')

# The pre-existing visual contract is generated before localization. Update only
# its landing assertions so it verifies the same approved visual shell through
# dynamic language keys instead of requiring Italian literals.
test_path = Path('test/prelaunch_visual_caption_refinement_contract_test.dart')
if test_path.exists():
    test = test_path.read_text(encoding='utf-8')
    test = test.replace(
        "expect(gate, contains(\"title: 'Accedi al tuo account'\"));",
        "expect(gate, contains(\"title: _lv('loginTitle')\"));",
    )
    test = test.replace(
        "expect(gate, contains(\"title: 'Diventa creator'\"));",
        "expect(gate, contains(\"title: _lv('creatorTitle')\"));",
    )
    test = test.replace(
        "expect(gate, isNot(contains(\"title: 'Crea account'\")));",
        "expect(gate, isNot(contains(\"title: _lv('createTitle')\")));",
    )
    test_path.write_text(test, encoding='utf-8')

print('Approved first-launch landing localized in IT/EN/ES/RU; visual contract updated and HCV/capture untouched')
