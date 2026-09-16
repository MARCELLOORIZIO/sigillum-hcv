from pathlib import Path

path = Path('.github/scripts/build113_copy_complete_patch.py')
text = path.read_text(encoding='utf-8')

# Align stale source anchors in the materializer with the actual BUILD113 source.
text = text.replace(
    "'socialVerifyStep4':\\n          'Если контент сертифицирован, вы увидите происхождение, целостность и личность автора.'",
    "'socialVerifyStep4':\\n          'Если контент сертифицирован, вы увидите происхождение, целостность и идентичность автора.'",
)
text = text.replace(
    "'es': \"      'recording': 'GRABACIÓN EN CURSO',\\n\"",
    "'es': \"      'recording': 'GRABANDO',\\n\"",
)
# BUILD113 source uses slightly different Spanish/Russian manual-probe strings.
text = text.replace(
    "'physicalProbe': 'MUEVE LIGERAMENTE EL TELÉFONO LATERALMENTE...'",
    "'physicalProbe': 'MUEVE LIGERAMENTE EL TELÉFONO HACIA UN LADO...'",
)
text = text.replace(
    "'physicalProbe': 'СЛЕГКА ПЕРЕМЕЩАЙТЕ ТЕЛЕФОН В СТОРОНУ...'",
    "'physicalProbe': 'СЛЕГКА ПЕРЕМЕСТИТЕ ТЕЛЕФОН В СТОРОНУ...'",
)

# Avoid consuming HUMAN VERIFIED before the deliberate four-language block.
text = text.replace(
    '"\'humanVerified\': \'HUMAN VERIFIED\'":"\'humanVerified\': \'CERTIFICAZIONE COMPLETATA\'",\n',
    '',
)

# The English phrase appears in more than one copy map; update all expected hits.
text = text.replace(
    "s = replace_once(s, \"'compatible': 'No determinable'\", \"'compatible': 'Cannot be determined'\", 'English compatible grammar')",
    "s = replace_required(s, \"'compatible': 'No determinable'\", \"'compatible': 'Cannot be determined'\", 'English compatible grammar', count=2)",
)

# Localizing Lab snackbars/input decorations makes their widgets non-const.
text = text.replace(
    "s=s.replace('const Text(_l(', 'Text(_l(')\nwrite('screen_replay_diagnostics_page.dart',s)",
    "s=s.replace('const Text(_l(', 'Text(_l(')\ns=s.replace('const SnackBar(content: Text(_l(', 'SnackBar(content: Text(_l(')\nwrite('screen_replay_diagnostics_page.dart',s)",
)
text = text.replace(
    "s=s.replace('const Text(_l(', 'Text(_l(')\nwrite('screen_replay_calibration_page.dart',s)",
    "s=s.replace('const Text(_l(', 'Text(_l(')\ns=s.replace('const SnackBar(content: Text(_l(', 'SnackBar(content: Text(_l(')\ns=s.replace('decoration: const InputDecoration(\\n                      labelText: _l(', 'decoration: InputDecoration(\\n                      labelText: _l(')\nwrite('screen_replay_calibration_page.dart',s)",
)

# VideoPlayerVerifyPage is older and Italian-only. Add languageCode and localize
# its user-facing shell before the generic neutral-verdict rewrite.
video_anchor = "# Video verify pages already carry languageCode; use neutral localized labels.\nfor name in ('video_verify_page.dart','video_player_verify_page.dart'):"
video_prep = '''# VideoPlayerVerifyPage is older and does not yet carry languageCode.
s=read('video_player_verify_page.dart')
s=replace_once(s,"import 'hcv_logo_badge.dart';","import 'hcv_logo_badge.dart';\\nimport 'sigillum_localization.dart';",'video player localization import')
s=replace_once(s,"class VideoPlayerVerifyPage extends StatefulWidget {\\n  const VideoPlayerVerifyPage({super.key});","class VideoPlayerVerifyPage extends StatefulWidget {\\n  const VideoPlayerVerifyPage({super.key, this.languageCode = 'it'});\\n  final String languageCode;",'video player language prop')
s=replace_once(s,"class _VideoPlayerVerifyPageState extends State<VideoPlayerVerifyPage> {\\n  final verifier = HCVVerifier();","class _VideoPlayerVerifyPageState extends State<VideoPlayerVerifyPage> {\\n  final verifier = HCVVerifier();\\n  String _t(String key) => SigillumCopy.t(widget.languageCode, key);",'video player translation helper')
s=s.replace('title: const Text(\"SIGILLUM Player\")',"title: Text(_t('videoPlayerTitle'))")
s=s.replace('? const Text(\"Seleziona un video\")',"? Text(_t('selectVideoPrompt'))")
s=s.replace('child: const Text(\"CARICA VIDEO\")',"child: Text(_t('loadVideo'))")
s=s.replace('child: const Text(\"CARICA HCV\")',"child: Text(_t('loadHcv'))")
s=s.replace('String status = \"Seleziona video\";',"String status = '';" )
s=s.replace('status = \"Video caricato\";',"status = _t('videoLoaded');")
s=s.replace('status = \"Certificato caricato\";',"status = _t('certificateLoaded');")
s=s.replace('status = \"Verifica...\";',"status = _t('verifying');")
s=s.replace('status = \"Nessun certificato\";',"status = _t('noCertificate');")
s=s.replace('status = \"Certificato non valido\";',"status = _t('invalidCertificate');")
s=s.replace('status = \"HCV non compatibile\";',"status = _t('hcvNotCompatible');")
s=s.replace('status = \"Video modificato\";',"status = _t('videoModified');")
write('video_player_verify_page.dart',s)

# Video verify pages use neutral localized labels.
for name in ('video_verify_page.dart','video_player_verify_page.dart'):'''
if video_anchor not in text:
    raise RuntimeError('legacy video localization anchor missing')
text = text.replace(video_anchor, video_prep, 1)

# Additional strings required by the old VideoPlayerVerifyPage.
central_anchor = "# -----------------------------------------------------------------------------\n# 2. Camera copy: neutral result labels; remove manual movement language."
central_insert = '''s=read('sigillum_localization.dart')
for anchor, addition in [
    ("      'audioTrust': 'Fiducia audio',\\n", "      'videoPlayerTitle': 'Player SIGILLUM',\\n      'selectVideoPrompt': 'Seleziona un video',\\n      'loadVideo': 'CARICA VIDEO',\\n      'loadHcv': 'CARICA HCV',\\n      'videoLoaded': 'Video caricato',\\n      'certificateLoaded': 'Certificato caricato',\\n      'noCertificate': 'Nessun certificato',\\n      'invalidCertificate': 'Certificato non valido',\\n      'hcvNotCompatible': 'HCV non compatibile con questo video',\\n      'videoModified': 'Video modificato',\\n"),
    ("      'audioTrust': 'Audio trust',\\n", "      'videoPlayerTitle': 'SIGILLUM Player',\\n      'selectVideoPrompt': 'Select a video',\\n      'loadVideo': 'LOAD VIDEO',\\n      'loadHcv': 'LOAD HCV',\\n      'videoLoaded': 'Video loaded',\\n      'certificateLoaded': 'Certificate loaded',\\n      'noCertificate': 'No certificate selected',\\n      'invalidCertificate': 'Invalid certificate',\\n      'hcvNotCompatible': 'HCV is not compatible with this video',\\n      'videoModified': 'Video has been modified',\\n"),
    ("      'audioTrust': 'Confianza audio',\\n", "      'videoPlayerTitle': 'Reproductor SIGILLUM',\\n      'selectVideoPrompt': 'Selecciona un vídeo',\\n      'loadVideo': 'CARGAR VÍDEO',\\n      'loadHcv': 'CARGAR HCV',\\n      'videoLoaded': 'Vídeo cargado',\\n      'certificateLoaded': 'Certificado cargado',\\n      'noCertificate': 'No se ha seleccionado un certificado',\\n      'invalidCertificate': 'Certificado no válido',\\n      'hcvNotCompatible': 'El HCV no es compatible con este vídeo',\\n      'videoModified': 'El vídeo ha sido modificado',\\n"),
    ("      'audioTrust': 'Доверие к аудио',\\n", "      'videoPlayerTitle': 'Проигрыватель SIGILLUM',\\n      'selectVideoPrompt': 'Выберите видео',\\n      'loadVideo': 'ЗАГРУЗИТЬ ВИДЕО',\\n      'loadHcv': 'ЗАГРУЗИТЬ HCV',\\n      'videoLoaded': 'Видео загружено',\\n      'certificateLoaded': 'Сертификат загружен',\\n      'noCertificate': 'Сертификат не выбран',\\n      'invalidCertificate': 'Недействительный сертификат',\\n      'hcvNotCompatible': 'HCV не соответствует этому видео',\\n      'videoModified': 'Видео было изменено',\\n"),
]:
    if anchor not in s:
        raise RuntimeError(f'central legacy-video anchor missing: {anchor!r}')
    s=s.replace(anchor, addition + anchor, 1)
write('sigillum_localization.dart',s)

''' + central_anchor
if central_anchor not in text:
    raise RuntimeError('central copy insertion anchor missing')
text = text.replace(central_anchor, central_insert, 1)

# The original CommercialGate helper anchored additions to openResourceFailed,
# whose wording differs slightly by language. Anchor to purchaseFailed instead.
old_loop = "for old,new in cg_add.items(): s=replace_once(s,old,new,'commercial map add')"
new_loop = '''# Insert the four new CommercialGate keys using stable per-language anchors.
for anchor, addition in [
    ("    'purchaseFailed': 'Acquisto non completato.',\\n", "    'accountExists': 'Questa email è già associata a un account. Accedi oppure usa Password dimenticata.',\\n    'accountNotFoundCreate': 'Non esiste un account con questa email. Puoi crearne uno nuovo.',\\n    'kycProcessingNotice': 'La verifica è stata inviata a Stripe. Attendi l’esito prima di avviare altre procedure.',\\n    'refreshVerification': 'AGGIORNA STATO VERIFICA',\\n"),
    ("    'purchaseFailed': 'Purchase not completed.',\\n", "    'accountExists': 'This email is already linked to an account. Sign in or use Forgot password.',\\n    'accountNotFoundCreate': 'No account exists with this email. You can create a new one.',\\n    'kycProcessingNotice': 'The verification was submitted to Stripe. Wait for the result before starting another procedure.',\\n    'refreshVerification': 'REFRESH VERIFICATION STATUS',\\n"),
    ("    'purchaseFailed': 'Compra no completada.',\\n", "    'accountExists': 'Este correo ya está asociado a una cuenta. Inicia sesión o usa ¿Olvidaste la contraseña?.',\\n    'accountNotFoundCreate': 'No existe una cuenta con este correo. Puedes crear una nueva.',\\n    'kycProcessingNotice': 'La verificación se envió a Stripe. Espera el resultado antes de iniciar otro procedimiento.',\\n    'refreshVerification': 'ACTUALIZAR ESTADO DE VERIFICACIÓN',\\n"),
    ("    'purchaseFailed': 'Покупка не завершена.',\\n", "    'accountExists': 'Этот email уже связан с аккаунтом. Войдите или используйте восстановление пароля.',\\n    'accountNotFoundCreate': 'Аккаунта с этим email нет. Можно создать новый.',\\n    'kycProcessingNotice': 'Проверка отправлена в Stripe. Дождитесь результата перед запуском новой процедуры.',\\n    'refreshVerification': 'ОБНОВИТЬ СТАТУС ПРОВЕРКИ',\\n"),
]:
    if anchor not in s:
        raise RuntimeError(f'commercial purchase anchor missing: {anchor!r}')
    s = s.replace(anchor, addition + anchor, 1)'''
if old_loop not in text:
    raise RuntimeError('commercial loop rewrite anchor missing')
text = text.replace(old_loop, new_loop, 1)

path.write_text(text, encoding='utf-8')
print('BUILD113 copy materializer prepared')
