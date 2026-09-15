from pathlib import Path
import re

ROOT = Path('lib')

def read(name):
    return (ROOT / name).read_text(encoding='utf-8')

def write(name, text):
    (ROOT / name).write_text(text, encoding='utf-8')

def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 occurrence, found {count}')
    return text.replace(old, new, 1)

def replace_required(text, old, new, label, count=None):
    found = text.count(old)
    if found == 0:
        raise RuntimeError(f'{label}: anchor not found')
    if count is not None and found != count:
        raise RuntimeError(f'{label}: expected {count}, found {found}')
    return text.replace(old, new)

# -----------------------------------------------------------------------------
# 1. Central copy: spelling, current BUILD113 social verification semantics.
# -----------------------------------------------------------------------------
s = read('sigillum_localization.dart')
s = replace_once(s, "name: 'Espanol'", "name: 'Español'", 'Spanish language name')

central_replacements = {
    "'identity': 'Identita'": "'identity': 'Identità'",
    "'accountSubtitle': 'Profilo, identita, KYC, sicurezza e dati.'": "'accountSubtitle': 'Profilo, identità, KYC, sicurezza e dati.'",
    "'subtitle':\n          'SIGILLUM collega foto, video e testi a HCV-ID, identita tecnica, impronta del file, certificato firmato e Registry online. Le modifiche restano rilevabili.'": "'subtitle':\n          'SIGILLUM collega foto, video e testi a HCV-ID, identità tecnica, impronta crittografica del file, certificato firmato e Registry online. Per le copie ricompresse usa fingerprint percettivi specifici per il tipo di media.'",
    "'identityStep': 'Identita'": "'identityStep': 'Identità'",
    "'checkIntegrity': 'Integrita del file e coerenza con il certificato'": "'checkIntegrity': 'Integrità del file e coerenza con il certificato'",
    "'checkSocial': 'Fingerprint per file ricompressi dai social'": "'checkSocial': 'Compatibilità di copie ricompresse: fingerprint immagine per foto; fingerprint visivo e audio per video'",
    "'socialVerifyStep3':\n          'SIGILLUM legge HCV-ID, watermark o fingerprint e recupera il certificato dal Registry.'": "'socialVerifyStep3':\n          'SIGILLUM usa HCV-ID o watermark visibile per identificare il certificato nel Registry; per una copia ricompressa verifica poi i fingerprint previsti per quel tipo di media.'",
    "'socialVerifyStep4':\n          'Se il contenuto e certificato, vedi provenienza, integrita e identita del creatore.'": "'socialVerifyStep4':\n          'Se il contenuto è certificato, vedi provenienza, integrità e identità tecnica; nei video moderni la compatibilità visiva e audio viene controllata separatamente.'",
    "'legalIntro':\n          'SIGILLUM crea una prova tecnica verificabile che collega contenuto, HCV-ID, identita tecnica del creatore, impronta del file e Registry online.'": "'legalIntro':\n          'SIGILLUM crea una prova tecnica verificabile che collega contenuto, HCV-ID, identità tecnica del creatore, impronta crittografica del file e Registry online.'",
    "'data4': 'identita tecnica del creatore, se configurata'": "'data4': 'identità tecnica del creatore, se configurata'",
    "'technicalIdentityTitle': 'Identita tecnica'": "'technicalIdentityTitle': 'Identità tecnica'",
    "'technicalIdentityHeading': 'Identita tecnica SIGILLUM'": "'technicalIdentityHeading': 'Identità tecnica SIGILLUM'",
    "'loadingTechnicalIdentity': 'Caricamento identita tecnica...'": "'loadingTechnicalIdentity': 'Caricamento identità tecnica...'",
    "'technicalIdentityLoaded': 'Identita tecnica caricata'": "'technicalIdentityLoaded': 'Identità tecnica caricata'",
    "'technicalIdentityFingerprint': 'Impronta identita tecnica'": "'technicalIdentityFingerprint': 'Impronta identità tecnica'",
    "'identityAssurance': 'Garanzia identita'": "'identityAssurance': 'Garanzia identità'",
    "'legalIdentity': 'Identita legale'": "'legalIdentity': 'Identità legale'",
    "'startKyc': 'Avvia verifica identita'": "'startKyc': 'Avvia verifica identità'",
    "'kycOpening': 'Apro la verifica identita...'": "'kycOpening': 'Apro la verifica identità...'",
    "'kycVerified': 'Identita legale verificata.'": "'kycVerified': 'Identità legale verificata.'",
    "'identityUnavailable': 'Identita non disponibile'": "'identityUnavailable': 'Identità non disponibile'",
    "'sceneAuthenticity': 'Autenticita scena'": "'sceneAuthenticity': 'Autenticità scena'",
    "'photoMode': 'MODALITA FOTO'": "'photoMode': 'MODALITÀ FOTO'",
    "'videoMode': 'MODALITA VIDEO'": "'videoMode': 'MODALITÀ VIDEO'",
    "'checkSocial': 'Fingerprint for social-media recompressed files'": "'checkSocial': 'Recompressed-copy compatibility: image fingerprint for photos; visual and audio fingerprints for videos'",
    "'socialVerifyStep3':\n          'SIGILLUM reads the HCV-ID, watermark or fingerprint and retrieves the certificate from the Registry.'": "'socialVerifyStep3':\n          'SIGILLUM uses the HCV-ID or visible watermark to identify the Registry certificate; for a recompressed copy it then checks the fingerprints required for that media type.'",
    "'socialVerifyStep4':\n          'If the content is certified, you see provenance, integrity and creator identity.'": "'socialVerifyStep4':\n          'If the content is certified, you see provenance, integrity and technical identity; modern videos verify visual and audio compatibility separately.'",
    "'checkSocial': 'Fingerprint para archivos recomprimidos por redes'": "'checkSocial': 'Compatibilidad de copias recomprimidas: huella de imagen para fotos; huellas visual y de audio para vídeos'",
    "'socialVerifyStep3':\n          'SIGILLUM lee el HCV-ID, la marca visible o el fingerprint y recupera el certificado del Registry.'": "'socialVerifyStep3':\n          'SIGILLUM usa el HCV-ID o la marca visible para identificar el certificado en Registry; después comprueba las huellas previstas para ese tipo de media si se trata de una copia recomprimida.'",
    "'socialVerifyStep4':\n          'Si el contenido esta certificado, veras procedencia, integridad e identidad del creador.'": "'socialVerifyStep4':\n          'Si el contenido está certificado, verás procedencia, integridad e identidad técnica; en los vídeos modernos se comprueba por separado la compatibilidad visual y de audio.'",
    "'checkSocial': 'Fingerprint для файлов, сжатых соцсетями'": "'checkSocial': 'Совместимость после перекодирования: отпечаток изображения для фото; визуальный и аудиоотпечатки для видео'",
    "'socialVerifyStep3':\n          'SIGILLUM считывает HCV-ID, видимую метку или fingerprint и получает сертификат из Registry.'": "'socialVerifyStep3':\n          'SIGILLUM использует HCV-ID или видимую метку для поиска сертификата в Registry; для перекодированной копии затем проверяются отпечатки, предусмотренные для этого типа медиа.'",
    "'socialVerifyStep4':\n          'Если контент сертифицирован, вы увидите происхождение, целостность и личность автора.'": "'socialVerifyStep4':\n          'Если контент сертифицирован, отображаются происхождение, целостность и техническая идентичность; в современных видео визуальная и аудиосовместимость проверяются отдельно.'",
}
for old, new in central_replacements.items():
    s = replace_once(s, old, new, f'central copy {old[:30]}')

# Add general reusable labels/errors to each language before the final recording key.
central_additions = {
'it': """      'certificateVerifiedLabel': 'CERTIFICATO VERIFICATO',
      'notVerifiedLabel': 'NON VERIFICATO',
      'hcvIdCopied': 'HCV-ID copiato',
      'socialTextCopied': 'Testo social copiato',
      'verifiedTextShare': 'Testo certificato SIGILLUM',
      'openResourceFailed': 'Impossibile aprire questa risorsa.',
      'account': 'Account',
""",
'en': """      'certificateVerifiedLabel': 'CERTIFICATE VERIFIED',
      'notVerifiedLabel': 'NOT VERIFIED',
      'hcvIdCopied': 'HCV-ID copied',
      'socialTextCopied': 'Social text copied',
      'verifiedTextShare': 'SIGILLUM certified text',
      'openResourceFailed': 'Unable to open this resource.',
      'account': 'Account',
""",
'es': """      'certificateVerifiedLabel': 'CERTIFICADO VERIFICADO',
      'notVerifiedLabel': 'NO VERIFICADO',
      'hcvIdCopied': 'HCV-ID copiado',
      'socialTextCopied': 'Texto social copiado',
      'verifiedTextShare': 'Texto certificado por SIGILLUM',
      'openResourceFailed': 'No se puede abrir este recurso.',
      'account': 'Cuenta',
""",
'ru': """      'certificateVerifiedLabel': 'СЕРТИФИКАТ ПОДТВЕРЖДЁН',
      'notVerifiedLabel': 'НЕ ПОДТВЕРЖДЕНО',
      'hcvIdCopied': 'HCV-ID скопирован',
      'socialTextCopied': 'Текст для публикации скопирован',
      'verifiedTextShare': 'Сертифицированный SIGILLUM текст',
      'openResourceFailed': 'Не удалось открыть этот ресурс.',
      'account': 'Аккаунт',
""",
}
anchors = {
'it': "      'recording': 'REGISTRAZIONE IN CORSO',\n",
'en': "      'recording': 'RECORDING',\n",
'es': "      'recording': 'GRABACIÓN EN CURSO',\n",
'ru': "      'recording': 'ИДЕТ ЗАПИСЬ',\n",
}
for lang in ('it','en','es','ru'):
    s = replace_once(s, anchors[lang], central_additions[lang] + anchors[lang], f'central addition {lang}')
write('sigillum_localization.dart', s)

# -----------------------------------------------------------------------------
# 2. Verification summary copy.
# -----------------------------------------------------------------------------
s = read('verification_ui_copy.dart')
s = replace_once(s, "'compatible': 'No determinable'", "'compatible': 'Cannot be determined'", 'English compatible grammar')
summary_replacements = {
"'derivedDetail': 'Hash diverso dall’originale certificato, ma HCV-ID e fingerprint restano compatibili.'": "'derivedDetail': 'Hash diverso dall’originale certificato, ma i controlli di compatibilità previsti per questo media sono superati. Nei video moderni fingerprint visivo e audio sono verificati separatamente.'",
"'socialOkDetail': 'Il file è diverso dall’originale certificato, ma resta collegato al certificato SIGILLUM tramite HCV-ID e fingerprint.'": "'socialOkDetail': 'Il file è diverso dall’originale certificato ma supera i controlli di compatibilità previsti. Nei video moderni vengono verificati separatamente fingerprint visivo e audio.'",
"'derivedDetail': 'The hash differs from the certified original, but HCV-ID and fingerprint remain compatible.'": "'derivedDetail': 'The hash differs from the certified original, but the compatibility checks required for this media pass. Modern videos verify visual and audio fingerprints separately.'",
"'socialOkDetail': 'The file differs from the certified original but remains linked to the SIGILLUM certificate through its HCV-ID and fingerprint.'": "'socialOkDetail': 'The file differs from the certified original but passes the required compatibility checks. Modern videos verify visual and audio fingerprints separately.'",
"'derivedDetail': 'El hash difiere del original certificado, pero el HCV-ID y la huella siguen siendo compatibles.'": "'derivedDetail': 'El hash difiere del original certificado, pero supera los controles de compatibilidad previstos para este media. En vídeos modernos se verifican por separado las huellas visual y de audio.'",
"'socialOkDetail': 'El archivo difiere del original certificado, pero sigue vinculado al certificado SIGILLUM mediante el HCV-ID y la huella.'": "'socialOkDetail': 'El archivo difiere del original certificado, pero supera los controles de compatibilidad previstos. En vídeos modernos se verifican por separado las huellas visual y de audio.'",
"'derivedDetail': 'Хэш отличается от сертифицированного оригинала, но HCV-ID и отпечаток остаются совместимыми.'": "'derivedDetail': 'Хэш отличается от сертифицированного оригинала, но файл проходит предусмотренные для этого типа медиа проверки совместимости. В современных видео визуальный и аудиоотпечатки проверяются отдельно.'",
"'socialOkDetail': 'Файл отличается от сертифицированного оригинала, но остаётся связан с сертификатом SIGILLUM через HCV-ID и отпечаток.'": "'socialOkDetail': 'Файл отличается от сертифицированного оригинала, но проходит предусмотренные проверки совместимости. В современных видео визуальный и аудиоотпечатки проверяются отдельно.'",
}
for old,new in summary_replacements.items():
    s = replace_once(s, old, new, f'verification summary {old[:25]}')

# HCVPACK neutral verified label.
verify_add = {
'it': "      'packVerifiedResult': 'HCVPACK VERIFICATO',\n",
'en': "      'packVerifiedResult': 'HCVPACK VERIFIED',\n",
'es': "      'packVerifiedResult': 'HCVPACK VERIFICADO',\n",
'ru': "      'packVerifiedResult': 'HCVPACK ПОДТВЕРЖДЁН',\n",
}
verify_anchor = {
'it': "      'verificationComplete': 'Verifica completata',\n",
'en': "      'verificationComplete': 'Verification complete',\n",
'es': "      'verificationComplete': 'Verificación completada',\n",
'ru': "      'verificationComplete': 'Проверка завершена',\n",
}
for lang in verify_add:
    s = replace_once(s, verify_anchor[lang], verify_add[lang] + verify_anchor[lang], f'pack verified {lang}')
write('verification_ui_copy.dart', s)

# -----------------------------------------------------------------------------
# 3. Camera copy and stale manual-motion wording.
# -----------------------------------------------------------------------------
s = read('camera_ui_copy.dart')
for old,new in {
"'physicalProbe': 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'":"'physicalProbe': 'CONTROLLO AUTOMATICO DELLA SCENA...'",
"'humanVerified': 'HUMAN VERIFIED'":"'humanVerified': 'CERTIFICAZIONE COMPLETATA'",
"'physicalProbe': 'MOVE THE PHONE SLIGHTLY SIDEWAYS...'":"'physicalProbe': 'AUTOMATIC SCENE CHECK...'",
"'physicalProbe': 'MUEVE LIGERAMENTE EL TELÉFONO LATERALMENTE...'":"'physicalProbe': 'COMPROBACIÓN AUTOMÁTICA DE LA ESCENA...'",
"'physicalProbe': 'СЛЕГКА ПЕРЕМЕЩАЙТЕ ТЕЛЕФОН В СТОРОНУ...'":"'physicalProbe': 'АВТОМАТИЧЕСКАЯ ПРОВЕРКА СЦЕНЫ...'",
}.items():
    if old in s:
        s = s.replace(old,new)
# humanVerified occurs four times with same value: replace all deliberately.
s = replace_required(s, "'humanVerified': 'HUMAN VERIFIED'", "'humanVerified': 'CERTIFICATION_COMPLETE_PLACEHOLDER'", 'human verified placeholders', count=4)
# assign each occurrence by language order.
vals = ['CERTIFICAZIONE COMPLETATA','CERTIFICATION COMPLETE','CERTIFICACIÓN COMPLETADA','СЕРТИФИКАЦИЯ ЗАВЕРШЕНА']
for val in vals:
    s = s.replace("'humanVerified': 'CERTIFICATION_COMPLETE_PLACEHOLDER'", f"'humanVerified': '{val}'", 1)
write('camera_ui_copy.dart', s)

s = read('camera_ui_extended_copy.dart')
# Replace all four old parallax/movement instructions with non-manual retry wording.
repls = {
"'parallaxRequired':\n          'MOVIMENTO INSUFFICIENTE — MUOVI IL TELEFONO LATERALMENTE E RIPROVA'":"'parallaxRequired':\n          'CONTROLLO SCENA NON CONCLUSIVO — RIPROVA'",
"'parallaxRequired':\n          'NOT ENOUGH MOVEMENT — MOVE THE PHONE SIDEWAYS AND TRY AGAIN'":"'parallaxRequired':\n          'SCENE CHECK INCONCLUSIVE — TRY AGAIN'",
"'parallaxRequired':\n          'MOVIMIENTO INSUFICIENTE — MUEVE EL TELÉFONO LATERALMENTE Y VUELVE A INTENTARLO'":"'parallaxRequired':\n          'COMPROBACIÓN DE ESCENA NO CONCLUYENTE — INTÉNTALO DE NUEVO'",
"'parallaxRequired':\n          'НЕДОСТАТОЧНО ДВИЖЕНИЯ — ПЕРЕМЕСТИТЕ ТЕЛЕФОН В СТОРОНУ И ПОВТОРИТЕ'":"'parallaxRequired':\n          'ПРОВЕРКА СЦЕНЫ НЕОДНОЗНАЧНА — ПОВТОРИТЕ'",
}
for old,new in repls.items():
    if old in s:
        s=s.replace(old,new)
# add dialog/back keys after subtitlesCreated per language.
ext_add = {
"      'subtitlesCreated': 'Sottotitoli creati.',\n":"      'subtitlesCreated': 'Sottotitoli creati.',\n      'captionedCreatedTitle': 'Video sottotitolato creato',\n      'backToCamera': 'TORNA ALLA CAMERA',\n",
"      'subtitlesCreated': 'Subtitles created.',\n":"      'subtitlesCreated': 'Subtitles created.',\n      'captionedCreatedTitle': 'Captioned video created',\n      'backToCamera': 'BACK TO CAMERA',\n",
"      'subtitlesCreated': 'Subtítulos creados.',\n":"      'subtitlesCreated': 'Subtítulos creados.',\n      'captionedCreatedTitle': 'Vídeo subtitulado creado',\n      'backToCamera': 'VOLVER A LA CÁMARA',\n",
"      'subtitlesCreated': 'Субтитры созданы.',\n":"      'subtitlesCreated': 'Субтитры созданы.',\n      'captionedCreatedTitle': 'Видео с субтитрами создано',\n      'backToCamera': 'НАЗАД К КАМЕРЕ',\n",
}
for old,new in ext_add.items():
    s=replace_once(s,old,new,f'extended copy add {old[:20]}')
write('camera_ui_extended_copy.dart',s)

s=read('camera_page.dart')
s=replace_once(s,"title: const Text('Video sottotitolato creato'),","title: Text(_c('captionedCreatedTitle')),",'caption dialog title')
s=replace_once(s,"label: const Text('TORNA ALLA CAMERA'),","label: Text(_c('backToCamera')),",'back camera label')
write('camera_page.dart',s)

# -----------------------------------------------------------------------------
# 4. Quick guide: current automatic capture workflow in all languages.
# -----------------------------------------------------------------------------
s=read('sigillum_quick_guide_page.dart')
qrepl={
"'Nella schermata camera, prima di scattare o avviare il video, puoi scegliere se aggiungere oppure no le coordinate GPS. Puoi inoltre usare il flash e regolare lo zoom. Durante il controllo della scena muovi leggermente il telefono come indicato; quando compare PROSEGUI torna all’inquadratura desiderata e, per il video, premi REC.'":"'Nella schermata camera, prima di scattare o avviare il video, puoi scegliere se aggiungere oppure no le coordinate GPS. Puoi inoltre usare il flash e regolare lo zoom. SIGILLUM esegue automaticamente i controlli tecnici della scena quando previsti: non è richiesto alcun movimento manuale. Quando la camera è pronta, inquadra e scatta oppure, per il video, premi REC.'",
"'On the camera screen, before taking a photo or starting a video, you can choose whether to include GPS coordinates. You can also use the flash and adjust zoom. During the scene check, move the phone slightly as instructed; when CONTINUE appears, return to your preferred framing and, for video, tap REC.'":"'On the camera screen, before taking a photo or starting a video, you can choose whether to include GPS coordinates. You can also use the flash and adjust zoom. SIGILLUM runs the required technical scene checks automatically: no manual phone movement is required. When the camera is ready, compose and capture or, for video, tap REC.'",
"'En la pantalla de cámara, antes de hacer una foto o iniciar un vídeo, puedes elegir si incluir o no las coordenadas GPS. También puedes usar el flash y ajustar el zoom. Durante el control de la escena mueve ligeramente el teléfono como se indica; cuando aparezca CONTINUAR vuelve al encuadre deseado y, para vídeo, pulsa REC.'":"'En la pantalla de cámara, antes de hacer una foto o iniciar un vídeo, puedes elegir si incluir o no las coordenadas GPS. También puedes usar el flash y ajustar el zoom. SIGILLUM ejecuta automáticamente los controles técnicos de la escena cuando son necesarios: no se requiere mover manualmente el teléfono. Cuando la cámara esté lista, encuadra y captura o, para vídeo, pulsa REC.'",
"'На экране камеры перед съемкой фото или запуском видео можно выбрать, добавлять ли GPS-координаты. Также можно использовать вспышку и менять зум. Во время проверки сцены слегка перемещайте телефон по инструкции; когда появится ПРОДОЛЖИТЬ, вернитесь к нужному кадру и для видео нажмите REC.'":"'На экране камеры перед съемкой фото или запуском видео можно выбрать, добавлять ли GPS-координаты. Также можно использовать вспышку и менять зум. SIGILLUM автоматически выполняет необходимые технические проверки сцены: вручную перемещать телефон не требуется. Когда камера готова, выберите кадр и снимайте либо для видео нажмите REC.'",
}
for old,new in qrepl.items(): s=replace_once(s,old,new,'quick guide workflow')
write('sigillum_quick_guide_page.dart',s)

# -----------------------------------------------------------------------------
# 5. Commercial/account/legal hard-coded production messages.
# -----------------------------------------------------------------------------
s=read('commercial_gate.dart')
# Add four keys in each local map before openResourceFailed.
cg_add={
"      'openResourceFailed': 'Impossibile aprire questa risorsa.',\n":"      'accountExists': 'Questa email è già associata a un account. Accedi oppure usa Password dimenticata.',\n      'accountNotFoundCreate': 'Non esiste un account con questa email. Puoi crearne uno nuovo.',\n      'kycProcessingNotice': 'La verifica è stata inviata a Stripe. Attendi l’esito prima di avviare altre procedure.',\n      'refreshVerification': 'AGGIORNA STATO VERIFICA',\n      'openResourceFailed': 'Impossibile aprire questa risorsa.',\n",
"      'openResourceFailed': 'Unable to open this resource.',\n":"      'accountExists': 'This email is already linked to an account. Sign in or use Forgot password.',\n      'accountNotFoundCreate': 'No account exists with this email. You can create a new one.',\n      'kycProcessingNotice': 'The verification was submitted to Stripe. Wait for the result before starting another procedure.',\n      'refreshVerification': 'REFRESH VERIFICATION STATUS',\n      'openResourceFailed': 'Unable to open this resource.',\n",
"      'openResourceFailed': 'No se puede abrir este recurso.',\n":"      'accountExists': 'Este correo ya está asociado a una cuenta. Inicia sesión o usa ¿Olvidaste la contraseña?.',\n      'accountNotFoundCreate': 'No existe una cuenta con este correo. Puedes crear una nueva.',\n      'kycProcessingNotice': 'La verificación se envió a Stripe. Espera el resultado antes de iniciar otro procedimiento.',\n      'refreshVerification': 'ACTUALIZAR ESTADO DE VERIFICACIÓN',\n      'openResourceFailed': 'No se puede abrir este recurso.',\n",
"      'openResourceFailed': 'Не удалось открыть этот ресурс.',\n":"      'accountExists': 'Этот email уже связан с аккаунтом. Войдите или используйте восстановление пароля.',\n      'accountNotFoundCreate': 'Аккаунта с этим email нет. Можно создать новый.',\n      'kycProcessingNotice': 'Проверка отправлена в Stripe. Дождитесь результата перед запуском новой процедуры.',\n      'refreshVerification': 'ОБНОВИТЬ СТАТУС ПРОВЕРКИ',\n      'openResourceFailed': 'Не удалось открыть этот ресурс.',\n",
}
for old,new in cg_add.items(): s=replace_once(s,old,new,'commercial map add')
s=replace_once(s,"_message = 'Questa email è già associata a un account. Accedi oppure usa Password dimenticata.';","_message = _t('accountExists');",'account exists copy')
s=replace_once(s,"_message = 'Non esiste un account con questa email. Puoi crearne uno nuovo.';","_message = _t('accountNotFoundCreate');",'account not found copy')
s=replace_once(s,"          const Text(\n            'La verifica è stata inviata a Stripe. Attendi l’esito prima di avviare altre procedure.',","          Text(\n            _t('kycProcessingNotice'),",'kyc processing copy')
s=replace_once(s,"          child: const Text('AGGIORNA STATO VERIFICA'),","          child: Text(_t('refreshVerification')),",'refresh kyc copy')
write('commercial_gate.dart',s)

s=read('commercial_profile_page.dart')
# Add local key near known subscription label per language by generic anchors.
profile_add={
"      'manageSubscription': 'GESTISCI ABBONAMENTO APPLE',\n":"      'manageSubscription': 'GESTISCI ABBONAMENTO APPLE',\n      'subscriptionOpenFailed': 'Impossibile aprire la gestione abbonamento.',\n",
"      'manageSubscription': 'MANAGE APPLE SUBSCRIPTION',\n":"      'manageSubscription': 'MANAGE APPLE SUBSCRIPTION',\n      'subscriptionOpenFailed': 'Unable to open subscription management.',\n",
"      'manageSubscription': 'GESTIONAR SUSCRIPCIÓN APPLE',\n":"      'manageSubscription': 'GESTIONAR SUSCRIPCIÓN APPLE',\n      'subscriptionOpenFailed': 'No se puede abrir la gestión de la suscripción.',\n",
"      'manageSubscription': 'УПРАВЛЕНИЕ ПОДПИСКОЙ APPLE',\n":"      'manageSubscription': 'УПРАВЛЕНИЕ ПОДПИСКОЙ APPLE',\n      'subscriptionOpenFailed': 'Не удалось открыть управление подпиской.',\n",
}
for old,new in profile_add.items():
    if old in s: s=replace_once(s,old,new,'profile subscription copy')
s=s.replace("'Impossibile aprire la gestione abbonamento.'","_t('subscriptionOpenFailed')")
write('commercial_profile_page.dart',s)

s=read('legal_info_page.dart')
s=replace_once(s,"const SnackBar(content: Text('Impossibile aprire questa risorsa.'))","SnackBar(content: Text(_t('openResourceFailed')))",'legal open failure')
write('legal_info_page.dart',s)

s=read('user_home_page.dart')
s=replace_once(s,"tooltip: 'Account',","tooltip: _t('account'),",'account tooltip')
write('user_home_page.dart',s)

# -----------------------------------------------------------------------------
# 6. Text certification: neutral verified wording and localized share/snackbars.
# -----------------------------------------------------------------------------
s=read('text_cert_page.dart')
s=replace_once(s,".showSnackBar(const SnackBar(content: Text('HCV-ID copiato')));",".showSnackBar(SnackBar(content: Text(_t('hcvIdCopied'))));",'text hcv copied')
s=replace_once(s,".showSnackBar(const SnackBar(content: Text('Testo social copiato')));",".showSnackBar(SnackBar(content: Text(_t('socialTextCopied'))));",'text social copied')
s=replace_once(s,"? 'Testo verificato SIGILLUM'\n        : 'Testo verificato SIGILLUM\\n$hcvId';","? _t('verifiedTextShare')\n        : '${_t('verifiedTextShare')}\\n$hcvId';",'text share copy')
s=replace_once(s,"isValid ? 'HUMAN VERIFIED' : 'NOT VERIFIED',","isValid ? _t('certificateVerifiedLabel') : _t('notVerifiedLabel'),",'text verified badge')
write('text_cert_page.dart',s)

# -----------------------------------------------------------------------------
# 7. HCVPACK player and legacy video pages: remove visible HUMAN VERIFIED.
# -----------------------------------------------------------------------------
s=read('hcvpack_player_page.dart')
s=replace_once(s,'result = "HUMAN VERIFIED";','result = "HCVPACK_VERIFIED";','pack result token')
s=replace_once(s,'return result == "HUMAN VERIFIED";','return result == "HCVPACK_VERIFIED";','pack verified predicate')
s=replace_once(s,'isVerified ? "HUMAN VERIFIED" : "NOT VERIFIED",',"isVerified ? _v('packVerifiedResult') : _t('notVerifiedLabel'),",'pack visible badge')
s=replace_once(s,'            result ?? "",','            status,','pack visible detail')
write('hcvpack_player_page.dart',s)

# Video verify pages already carry languageCode; use neutral localized labels.
for name in ('video_verify_page.dart','video_player_verify_page.dart'):
    s=read(name)
    s=s.replace('result = "HUMAN VERIFIED ✔";','result = "CERTIFICATE_VERIFIED";')
    s=s.replace('return result == "HUMAN VERIFIED ✔";','return result == "CERTIFICATE_VERIFIED";')
    s=s.replace('result = "HUMAN VERIFIED";','result = "CERTIFICATE_VERIFIED";')
    s=s.replace('return result == "HUMAN VERIFIED";','return result == "CERTIFICATE_VERIFIED";')
    s=s.replace('text = "HUMAN VERIFIED";','text = _t(\'certificateVerifiedLabel\');')
    s=s.replace('"HUMAN VERIFIED ✔"','_t(\'certificateVerifiedLabel\')')
    s=s.replace('"HUMAN VERIFIED"','_t(\'certificateVerifiedLabel\')')
    s=s.replace('"NOT VERIFIED"','_t(\'notVerifiedLabel\')')
    write(name,s)

# -----------------------------------------------------------------------------
# 8. Registry page detailed multilingual copy.
# -----------------------------------------------------------------------------
registry_copy = r'''class RegistryVerifyCopy {
  const RegistryVerifyCopy._();

  static String t(String languageCode, String key) {
    final code = languageCode.toLowerCase().split('-').first;
    return (_copy[code] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _copy = {
    'it': {
      'quickCheck': 'Controllo rapido SIGILLUM in corso...',
      'fileUnavailable': 'File ricevuto ma non accessibile. Riprova da Verifica contenuto.',
      'notCertified': 'Contenuto non certificato SIGILLUM.',
      'idDetectedAuto': 'HCV-ID rilevato. Verifica Registry automatica...',
      'autoIncomplete': 'Verifica automatica non completata. Il formato non è leggibile automaticamente: inserisci HCV-ID e premi VERIFICA DAL REGISTRY.',
      'iosImportFailed': 'File selezionato ma non importabile su iOS.',
      'selectOriginalNotPack': 'Seleziona il file ORIGINALE da verificare, non un file .hcv o .hcvpack.',
      'ocrDetectedMedia': 'HCV-ID rilevato nel media.',
      'idDetectedPressVerify': 'HCV-ID rilevato. Ora premi VERIFICA DAL REGISTRY.',
      'fileSelectedPressVerify': 'File selezionato. Se disponibile, inserisci o rileva HCV-ID e premi VERIFICA DAL REGISTRY.',
      'enterId': 'Inserisci HCV-ID.',
      'selectOriginal': 'Seleziona il file originale da verificare.',
      'downloadingCertificate': 'Recupero del certificato dal Registry HCV...',
      'signatureInvalid': 'Il certificato è stato recuperato, ma la firma crittografica non è valida.',
      'bindingMissing': 'Il certificato non contiene un collegamento valido al contenuto.',
      'mediaMissing': 'File media non trovato.',
      'forensicStatus': 'ORIGINALE CERTIFICATO VERIFICATO\nIl file è identico all’originale certificato. Hash SHA-256 corrispondente.',
      'socialTextStatus': 'CONTENUTO CERTIFICATO COMPATIBILE\nIl testo pubblicato contiene il footer SIGILLUM/HCV-ID e il contenuto certificato corrisponde, anche se il file non è identico byte per byte.',
      'genericDerived': 'CONTENUTO CERTIFICATO COMPATIBILE\nIl file è diverso dall’originale certificato ma supera i controlli di compatibilità disponibili per questo tipo di media.',
      'audioMismatchDetected': 'HCV-ID e fingerprint visivo sono compatibili, ma il fingerprint audio non corrisponde. Possibile audio sostituito, rimosso o alterato oltre la tolleranza di ricompressione.',
      'audioMismatchProvided': 'HCV-ID inserito e fingerprint visivo compatibile, ma il fingerprint audio non corrisponde. La traccia audio certificata non è verificata.',
      'videoBothDetected': 'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID rilevato; certificato Registry valido; fingerprint visivo e fingerprint audio compatibili dopo ricompressione.',
      'videoBothProvided': 'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID inserito; certificato Registry valido; fingerprint visivo e fingerprint audio compatibili dopo ricompressione.',
      'videoLegacyAudioDetected': 'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID rilevato e fingerprint visivo compatibile. Certificato legacy precedente al fingerprint audio.',
      'videoLegacyAudioProvided': 'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID inserito e fingerprint visivo compatibile. Certificato legacy precedente al fingerprint audio.',
      'videoLegacyLimitedDetected': 'CERTIFICATO LEGACY IDENTIFICATO\nHCV-ID rilevato e certificato Registry valido, ma il certificato non contiene il moderno fingerprint visivo. La compatibilità del media non può essere confermata con la stessa forza delle versioni attuali.',
      'videoLegacyLimitedProvided': 'CERTIFICATO LEGACY IDENTIFICATO\nHCV-ID inserito e certificato Registry valido, ma il certificato non contiene il moderno fingerprint visivo. La compatibilità del media non può essere confermata con la stessa forza delle versioni attuali.',
      'videoMismatchDetected': 'HCV-ID rilevato nel video, ma il fingerprint visivo non corrisponde al contenuto certificato. Possibile HCV-ID sovrapposto a un video diverso.',
      'videoMismatchProvided': 'HCV-ID inserito, ma il fingerprint visivo non corrisponde. Il video selezionato non è compatibile con quel certificato.',
      'photoCompatibleDetected': 'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID rilevato; certificato Registry valido; fingerprint immagine compatibile dopo ricompressione.',
      'photoCompatibleProvided': 'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID inserito; certificato Registry valido; fingerprint immagine compatibile dopo ricompressione.',
      'photoLegacyDetected': 'CERTIFICATO LEGACY IDENTIFICATO\nHCV-ID rilevato e certificato Registry valido. Il certificato è precedente al moderno fingerprint immagine: la verifica della copia è meno forte.',
      'photoLegacyProvided': 'CERTIFICATO LEGACY IDENTIFICATO\nHCV-ID inserito e certificato Registry valido. Il certificato è precedente al moderno fingerprint immagine: la verifica della copia è meno forte.',
      'photoMismatchDetected': 'HCV-ID rilevato nella foto, ma il fingerprint immagine non corrisponde. Possibile HCV-ID sovrapposto a una foto diversa.',
      'photoMismatchProvided': 'HCV-ID inserito, ma il fingerprint immagine non corrisponde. La foto selezionata non è compatibile con quel certificato.',
      'idNotDetected': 'HCV-ID valido nel Registry, ma non rilevato automaticamente nel file selezionato. La corrispondenza del media non è verificata.',
      'sceneWarning': 'ATTENZIONE: segnali tecnici coerenti con una possibile ripresa da schermo ({risk}). Il media resta collegato al certificato, ma la scena non va interpretata come ripresa diretta della realtà.',
      'registryNotFoundDetail': 'Certificato non presente nel Registry. Questo non dimostra una modifica del file: la pubblicazione online potrebbe essere ancora in attesa.',
      'registryUnavailableDetail': 'Registry temporaneamente non raggiungibile. Il file locale non viene considerato invalido; riprova quando la connessione è disponibile.',
      'registryInvalidResponse': 'Risposta Registry non utilizzabile: {error}',
      'invalidLocalCertificate': 'Certificato locale non valido: {error}',
      'unexpectedRegistryError': 'Errore imprevisto durante la verifica Registry: {error}',
      'contentType': 'Tipo',
      'techHcvTrust': 'Fiducia HCV', 'techLiveTrust': 'Fiducia cattura live', 'techSceneAuthenticity': 'Autenticità scena', 'techSyntheticRisk': 'Rischio sintetico', 'techAiProof': 'Livello prova AI',
      'techDisplayFusion': 'FUSIONE RISCHIO DISPLAY', 'techDecision': 'Decisione', 'techRisk': 'Rischio', 'techScore': 'Punteggio',
      'techPassive': 'ANALISI PASSIVA VIDEO/IMMAGINE', 'techSegments': 'Segmenti analizzati', 'techWorstSecond': 'Secondo peggiore', 'techLocalFlicker': 'Flicker temporale locale', 'techRefreshBand': 'Bande di refresh', 'techPixelGrid': 'Uniformità griglia pixel',
      'techLiveProbe': 'PROBE LIVE SCHERMO', 'techAnalysisStatus': 'Stato analisi', 'techFrames': 'Frame analizzati', 'techReason': 'Motivo', 'techError': 'Errore', 'techFineStripe': 'Strisce fini', 'techFineGrid': 'Griglia fine', 'techMoireFrequency': 'Frequenza moiré', 'techDynamicChallenge': 'Challenge dinamica', 'techPersistentPattern': 'Pattern persistente', 'techOpticalTrace': 'Traccia ottica corroborata', 'techMoireTrace': 'Traccia moiré', 'techDynamicTrace': 'Traccia challenge schermo', 'techUncorroborated': 'Pattern display non corroborato',
      'techMl': 'ML RIPRESA DA SCHERMO', 'techModelSource': 'Origine modello', 'techModelVersion': 'Versione modello', 'techRuntime': 'Runtime TFLite', 'techModelSha': 'SHA-256 modello', 'techPredictedClass': 'Classe prevista', 'techConfidence': 'Confidenza prevista', 'techScreenProbability': 'Probabilità schermo', 'techMlDecision': 'Decisione ML',
    },
    'en': {
      'quickCheck': 'Quick SIGILLUM check in progress...', 'fileUnavailable': 'The received file is not accessible. Try again from Verify content.', 'notCertified': 'Content not certified by SIGILLUM.', 'idDetectedAuto': 'HCV-ID detected. Automatic Registry verification...', 'autoIncomplete': 'Automatic verification was not completed. The format cannot be read automatically: enter the HCV-ID and press VERIFY FROM REGISTRY.', 'iosImportFailed': 'The selected file cannot be imported on iOS.', 'selectOriginalNotPack': 'Select the ORIGINAL file to verify, not a .hcv or .hcvpack file.', 'ocrDetectedMedia': 'HCV-ID detected in the media.', 'idDetectedPressVerify': 'HCV-ID detected. Now press VERIFY FROM REGISTRY.', 'fileSelectedPressVerify': 'File selected. If available, enter or detect the HCV-ID and press VERIFY FROM REGISTRY.', 'enterId': 'Enter the HCV-ID.', 'selectOriginal': 'Select the original file to verify.', 'downloadingCertificate': 'Retrieving the certificate from the HCV Registry...', 'signatureInvalid': 'The certificate was retrieved, but its cryptographic signature is invalid.', 'bindingMissing': 'The certificate does not contain a valid content binding.', 'mediaMissing': 'Media file not found.',
      'forensicStatus': 'CERTIFIED ORIGINAL VERIFIED\nThe file is identical to the certified original. SHA-256 hash matches.', 'socialTextStatus': 'CERTIFIED COMPATIBLE CONTENT\nThe published text includes the SIGILLUM/HCV-ID footer and the certified content matches, although the file is not byte-for-byte identical.', 'genericDerived': 'CERTIFIED COMPATIBLE CONTENT\nThe file differs from the certified original but passes the compatibility checks available for this media type.',
      'audioMismatchDetected': 'The HCV-ID and visual fingerprint are compatible, but the audio fingerprint does not match. Audio may have been replaced, removed, or altered beyond recompression tolerance.', 'audioMismatchProvided': 'The entered HCV-ID and visual fingerprint are compatible, but the audio fingerprint does not match. The certified audio track is not verified.', 'videoBothDetected': 'CERTIFIED COMPATIBLE CONTENT\nHCV-ID detected; Registry certificate valid; visual and audio fingerprints compatible after recompression.', 'videoBothProvided': 'CERTIFIED COMPATIBLE CONTENT\nHCV-ID entered; Registry certificate valid; visual and audio fingerprints compatible after recompression.', 'videoLegacyAudioDetected': 'CERTIFIED COMPATIBLE CONTENT\nHCV-ID detected and visual fingerprint compatible. Legacy certificate predates audio fingerprinting.', 'videoLegacyAudioProvided': 'CERTIFIED COMPATIBLE CONTENT\nHCV-ID entered and visual fingerprint compatible. Legacy certificate predates audio fingerprinting.', 'videoLegacyLimitedDetected': 'LEGACY CERTIFICATE IDENTIFIED\nHCV-ID detected and Registry certificate valid, but the certificate does not contain the modern visual fingerprint. Media compatibility cannot be confirmed as strongly as with current certificates.', 'videoLegacyLimitedProvided': 'LEGACY CERTIFICATE IDENTIFIED\nHCV-ID entered and Registry certificate valid, but the certificate does not contain the modern visual fingerprint. Media compatibility cannot be confirmed as strongly as with current certificates.', 'videoMismatchDetected': 'HCV-ID detected in the video, but the visual fingerprint does not match the certified content. The HCV-ID may have been overlaid on a different video.', 'videoMismatchProvided': 'HCV-ID entered, but the visual fingerprint does not match. The selected video is not compatible with that certificate.', 'photoCompatibleDetected': 'CERTIFIED COMPATIBLE CONTENT\nHCV-ID detected; Registry certificate valid; image fingerprint compatible after recompression.', 'photoCompatibleProvided': 'CERTIFIED COMPATIBLE CONTENT\nHCV-ID entered; Registry certificate valid; image fingerprint compatible after recompression.', 'photoLegacyDetected': 'LEGACY CERTIFICATE IDENTIFIED\nHCV-ID detected and Registry certificate valid. The certificate predates modern image fingerprinting, so verification of the copy is weaker.', 'photoLegacyProvided': 'LEGACY CERTIFICATE IDENTIFIED\nHCV-ID entered and Registry certificate valid. The certificate predates modern image fingerprinting, so verification of the copy is weaker.', 'photoMismatchDetected': 'HCV-ID detected in the photo, but the image fingerprint does not match. The HCV-ID may have been overlaid on a different photo.', 'photoMismatchProvided': 'HCV-ID entered, but the image fingerprint does not match. The selected photo is not compatible with that certificate.', 'idNotDetected': 'The HCV-ID is valid in the Registry but was not detected automatically in the selected file. Media correspondence is not verified.', 'sceneWarning': 'WARNING: technical signals are consistent with a possible screen replay ({risk}). The media remains linked to the certificate, but the scene should not be interpreted as a direct capture of reality.', 'registryNotFoundDetail': 'Certificate not found in the Registry. This does not prove the file was modified; online publication may still be pending.', 'registryUnavailableDetail': 'The Registry is temporarily unavailable. The local file is not treated as invalid; try again when the connection is available.', 'registryInvalidResponse': 'Unusable Registry response: {error}', 'invalidLocalCertificate': 'Invalid local certificate: {error}', 'unexpectedRegistryError': 'Unexpected Registry verification error: {error}', 'contentType': 'Type',
      'techHcvTrust': 'HCV trust', 'techLiveTrust': 'Live capture trust', 'techSceneAuthenticity': 'Scene authenticity', 'techSyntheticRisk': 'Synthetic risk', 'techAiProof': 'AI proof level', 'techDisplayFusion': 'DISPLAY FUSION', 'techDecision': 'Decision', 'techRisk': 'Risk', 'techScore': 'Score', 'techPassive': 'PASSIVE VIDEO/IMAGE ANALYSIS', 'techSegments': 'Segments analyzed', 'techWorstSecond': 'Worst segment second', 'techLocalFlicker': 'Local temporal flicker', 'techRefreshBand': 'Refresh band', 'techPixelGrid': 'Pixel-grid uniformity', 'techLiveProbe': 'LIVE SCREEN PROBE', 'techAnalysisStatus': 'Analysis status', 'techFrames': 'Frames analyzed', 'techReason': 'Reason', 'techError': 'Error', 'techFineStripe': 'Fine stripe', 'techFineGrid': 'Fine grid', 'techMoireFrequency': 'Moiré frequency', 'techDynamicChallenge': 'Dynamic challenge', 'techPersistentPattern': 'Persistent pattern', 'techOpticalTrace': 'Optical corroborated trace', 'techMoireTrace': 'Moiré trace', 'techDynamicTrace': 'Dynamic screen challenge trace', 'techUncorroborated': 'Uncorroborated display pattern', 'techMl': 'ML SCREEN REPLAY', 'techModelSource': 'Model source', 'techModelVersion': 'Model version', 'techRuntime': 'TFLite runtime', 'techModelSha': 'Model SHA-256', 'techPredictedClass': 'Predicted class', 'techConfidence': 'Predicted confidence', 'techScreenProbability': 'Screen probability', 'techMlDecision': 'ML decision',
    },
    'es': {
      'quickCheck': 'Comprobación rápida de SIGILLUM en curso...', 'fileUnavailable': 'El archivo recibido no es accesible. Inténtalo de nuevo desde Verificar contenido.', 'notCertified': 'Contenido no certificado por SIGILLUM.', 'idDetectedAuto': 'HCV-ID detectado. Verificación automática en Registry...', 'autoIncomplete': 'No se completó la verificación automática. El formato no se puede leer automáticamente: introduce el HCV-ID y pulsa VERIFICAR EN REGISTRY.', 'iosImportFailed': 'El archivo seleccionado no se puede importar en iOS.', 'selectOriginalNotPack': 'Selecciona el archivo ORIGINAL que quieres verificar, no un archivo .hcv o .hcvpack.', 'ocrDetectedMedia': 'HCV-ID detectado en el media.', 'idDetectedPressVerify': 'HCV-ID detectado. Ahora pulsa VERIFICAR EN REGISTRY.', 'fileSelectedPressVerify': 'Archivo seleccionado. Si está disponible, introduce o detecta el HCV-ID y pulsa VERIFICAR EN REGISTRY.', 'enterId': 'Introduce el HCV-ID.', 'selectOriginal': 'Selecciona el archivo original que quieres verificar.', 'downloadingCertificate': 'Recuperando el certificado del Registry HCV...', 'signatureInvalid': 'Se recuperó el certificado, pero su firma criptográfica no es válida.', 'bindingMissing': 'El certificado no contiene un vínculo válido con el contenido.', 'mediaMissing': 'Archivo media no encontrado.',
      'forensicStatus': 'ORIGINAL CERTIFICADO VERIFICADO\nEl archivo es idéntico al original certificado. El hash SHA-256 coincide.', 'socialTextStatus': 'CONTENIDO CERTIFICADO COMPATIBLE\nEl texto publicado incluye el pie SIGILLUM/HCV-ID y coincide con el contenido certificado, aunque el archivo no sea idéntico byte por byte.', 'genericDerived': 'CONTENIDO CERTIFICADO COMPATIBLE\nEl archivo difiere del original certificado, pero supera los controles de compatibilidad disponibles para este tipo de media.', 'audioMismatchDetected': 'El HCV-ID y la huella visual son compatibles, pero la huella de audio no coincide. El audio puede haber sido sustituido, eliminado o modificado más allá de la tolerancia de recompresión.', 'audioMismatchProvided': 'El HCV-ID introducido y la huella visual son compatibles, pero la huella de audio no coincide. La pista de audio certificada no está verificada.', 'videoBothDetected': 'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID detectado; certificado Registry válido; huellas visual y de audio compatibles tras la recompresión.', 'videoBothProvided': 'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID introducido; certificado Registry válido; huellas visual y de audio compatibles tras la recompresión.', 'videoLegacyAudioDetected': 'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID detectado y huella visual compatible. Certificado legacy anterior a la huella de audio.', 'videoLegacyAudioProvided': 'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID introducido y huella visual compatible. Certificado legacy anterior a la huella de audio.', 'videoLegacyLimitedDetected': 'CERTIFICADO LEGACY IDENTIFICADO\nHCV-ID detectado y certificado Registry válido, pero el certificado no contiene la huella visual moderna. La compatibilidad del media no puede confirmarse con la misma fuerza que en los certificados actuales.', 'videoLegacyLimitedProvided': 'CERTIFICADO LEGACY IDENTIFICADO\nHCV-ID introducido y certificado Registry válido, pero el certificado no contiene la huella visual moderna. La compatibilidad del media no puede confirmarse con la misma fuerza que en los certificados actuales.', 'videoMismatchDetected': 'HCV-ID detectado en el vídeo, pero la huella visual no coincide con el contenido certificado. Es posible que el HCV-ID se haya superpuesto a otro vídeo.', 'videoMismatchProvided': 'HCV-ID introducido, pero la huella visual no coincide. El vídeo seleccionado no es compatible con ese certificado.', 'photoCompatibleDetected': 'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID detectado; certificado Registry válido; huella de imagen compatible tras la recompresión.', 'photoCompatibleProvided': 'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID introducido; certificado Registry válido; huella de imagen compatible tras la recompresión.', 'photoLegacyDetected': 'CERTIFICADO LEGACY IDENTIFICADO\nHCV-ID detectado y certificado Registry válido. El certificado es anterior a la huella de imagen moderna, por lo que la verificación de la copia es menos fuerte.', 'photoLegacyProvided': 'CERTIFICADO LEGACY IDENTIFICADO\nHCV-ID introducido y certificado Registry válido. El certificado es anterior a la huella de imagen moderna, por lo que la verificación de la copia es menos fuerte.', 'photoMismatchDetected': 'HCV-ID detectado en la foto, pero la huella de imagen no coincide. Es posible que el HCV-ID se haya superpuesto a otra foto.', 'photoMismatchProvided': 'HCV-ID introducido, pero la huella de imagen no coincide. La foto seleccionada no es compatible con ese certificado.', 'idNotDetected': 'El HCV-ID es válido en Registry, pero no se detectó automáticamente en el archivo seleccionado. La correspondencia del media no está verificada.', 'sceneWarning': 'ATENCIÓN: las señales técnicas son compatibles con una posible captura de pantalla ({risk}). El media sigue vinculado al certificado, pero la escena no debe interpretarse como una captura directa de la realidad.', 'registryNotFoundDetail': 'Certificado no encontrado en Registry. Esto no demuestra que el archivo haya sido modificado; la publicación en línea puede seguir pendiente.', 'registryUnavailableDetail': 'Registry no está disponible temporalmente. El archivo local no se considera inválido; inténtalo de nuevo cuando haya conexión.', 'registryInvalidResponse': 'Respuesta de Registry no utilizable: {error}', 'invalidLocalCertificate': 'Certificado local no válido: {error}', 'unexpectedRegistryError': 'Error inesperado durante la verificación de Registry: {error}', 'contentType': 'Tipo',
      'techHcvTrust': 'Confianza HCV', 'techLiveTrust': 'Confianza de captura live', 'techSceneAuthenticity': 'Autenticidad de escena', 'techSyntheticRisk': 'Riesgo sintético', 'techAiProof': 'Nivel de prueba AI', 'techDisplayFusion': 'FUSIÓN DE RIESGO DE PANTALLA', 'techDecision': 'Decisión', 'techRisk': 'Riesgo', 'techScore': 'Puntuación', 'techPassive': 'ANÁLISIS PASIVO DE VÍDEO/IMAGEN', 'techSegments': 'Segmentos analizados', 'techWorstSecond': 'Peor segundo', 'techLocalFlicker': 'Parpadeo temporal local', 'techRefreshBand': 'Banda de refresco', 'techPixelGrid': 'Uniformidad de rejilla de píxeles', 'techLiveProbe': 'PROBE LIVE DE PANTALLA', 'techAnalysisStatus': 'Estado del análisis', 'techFrames': 'Frames analizados', 'techReason': 'Motivo', 'techError': 'Error', 'techFineStripe': 'Franjas finas', 'techFineGrid': 'Rejilla fina', 'techMoireFrequency': 'Frecuencia moiré', 'techDynamicChallenge': 'Challenge dinámico', 'techPersistentPattern': 'Patrón persistente', 'techOpticalTrace': 'Traza óptica corroborada', 'techMoireTrace': 'Traza moiré', 'techDynamicTrace': 'Traza de challenge de pantalla', 'techUncorroborated': 'Patrón de pantalla no corroborado', 'techMl': 'ML CAPTURA DE PANTALLA', 'techModelSource': 'Origen del modelo', 'techModelVersion': 'Versión del modelo', 'techRuntime': 'Runtime TFLite', 'techModelSha': 'SHA-256 del modelo', 'techPredictedClass': 'Clase prevista', 'techConfidence': 'Confianza prevista', 'techScreenProbability': 'Probabilidad de pantalla', 'techMlDecision': 'Decisión ML',
    },
    'ru': {
      'quickCheck': 'Выполняется быстрая проверка SIGILLUM...', 'fileUnavailable': 'Полученный файл недоступен. Повторите через Проверку контента.', 'notCertified': 'Контент не сертифицирован SIGILLUM.', 'idDetectedAuto': 'HCV-ID обнаружен. Автоматическая проверка Registry...', 'autoIncomplete': 'Автоматическая проверка не завершена. Формат нельзя прочитать автоматически: введите HCV-ID и нажмите ПРОВЕРИТЬ В REGISTRY.', 'iosImportFailed': 'Выбранный файл нельзя импортировать в iOS.', 'selectOriginalNotPack': 'Выберите ОРИГИНАЛЬНЫЙ файл для проверки, а не .hcv или .hcvpack.', 'ocrDetectedMedia': 'HCV-ID обнаружен в медиа.', 'idDetectedPressVerify': 'HCV-ID обнаружен. Теперь нажмите ПРОВЕРИТЬ В REGISTRY.', 'fileSelectedPressVerify': 'Файл выбран. Если возможно, введите или определите HCV-ID и нажмите ПРОВЕРИТЬ В REGISTRY.', 'enterId': 'Введите HCV-ID.', 'selectOriginal': 'Выберите оригинальный файл для проверки.', 'downloadingCertificate': 'Получение сертификата из HCV Registry...', 'signatureInvalid': 'Сертификат получен, но его криптографическая подпись недействительна.', 'bindingMissing': 'Сертификат не содержит действительной привязки к контенту.', 'mediaMissing': 'Медиафайл не найден.',
      'forensicStatus': 'СЕРТИФИЦИРОВАННЫЙ ОРИГИНАЛ ПОДТВЕРЖДЁН\nФайл идентичен сертифицированному оригиналу. SHA-256 совпадает.', 'socialTextStatus': 'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nОпубликованный текст содержит подпись SIGILLUM/HCV-ID и соответствует сертифицированному содержанию, хотя файл не идентичен побайтно.', 'genericDerived': 'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nФайл отличается от сертифицированного оригинала, но проходит доступные для этого типа медиа проверки совместимости.', 'audioMismatchDetected': 'HCV-ID и визуальный отпечаток совместимы, но аудиоотпечаток не совпадает. Аудио могло быть заменено, удалено или изменено сверх допустимого при перекодировании.', 'audioMismatchProvided': 'Введённый HCV-ID и визуальный отпечаток совместимы, но аудиоотпечаток не совпадает. Сертифицированная аудиодорожка не подтверждена.', 'videoBothDetected': 'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID обнаружен; сертификат Registry действителен; визуальный и аудиоотпечатки совместимы после перекодирования.', 'videoBothProvided': 'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID введён; сертификат Registry действителен; визуальный и аудиоотпечатки совместимы после перекодирования.', 'videoLegacyAudioDetected': 'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID обнаружен, визуальный отпечаток совместим. Legacy-сертификат создан до внедрения аудиоотпечатка.', 'videoLegacyAudioProvided': 'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID введён, визуальный отпечаток совместим. Legacy-сертификат создан до внедрения аудиоотпечатка.', 'videoLegacyLimitedDetected': 'ОПРЕДЕЛЁН LEGACY-СЕРТИФИКАТ\nHCV-ID обнаружен и сертификат Registry действителен, но современного визуального отпечатка в сертификате нет. Совместимость медиа нельзя подтвердить с той же силой, что для текущих сертификатов.', 'videoLegacyLimitedProvided': 'ОПРЕДЕЛЁН LEGACY-СЕРТИФИКАТ\nHCV-ID введён и сертификат Registry действителен, но современного визуального отпечатка в сертификате нет. Совместимость медиа нельзя подтвердить с той же силой, что для текущих сертификатов.', 'videoMismatchDetected': 'HCV-ID обнаружен в видео, но визуальный отпечаток не совпадает с сертифицированным контентом. HCV-ID мог быть наложен на другое видео.', 'videoMismatchProvided': 'HCV-ID введён, но визуальный отпечаток не совпадает. Выбранное видео несовместимо с этим сертификатом.', 'photoCompatibleDetected': 'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID обнаружен; сертификат Registry действителен; отпечаток изображения совместим после перекодирования.', 'photoCompatibleProvided': 'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID введён; сертификат Registry действителен; отпечаток изображения совместим после перекодирования.', 'photoLegacyDetected': 'ОПРЕДЕЛЁН LEGACY-СЕРТИФИКАТ\nHCV-ID обнаружен и сертификат Registry действителен. Сертификат создан до внедрения современного отпечатка изображения, поэтому проверка копии слабее.', 'photoLegacyProvided': 'ОПРЕДЕЛЁН LEGACY-СЕРТИФИКАТ\nHCV-ID введён и сертификат Registry действителен. Сертификат создан до внедрения современного отпечатка изображения, поэтому проверка копии слабее.', 'photoMismatchDetected': 'HCV-ID обнаружен на фото, но отпечаток изображения не совпадает. HCV-ID мог быть наложен на другое фото.', 'photoMismatchProvided': 'HCV-ID введён, но отпечаток изображения не совпадает. Выбранное фото несовместимо с этим сертификатом.', 'idNotDetected': 'HCV-ID действителен в Registry, но автоматически не обнаружен в выбранном файле. Соответствие медиа не подтверждено.', 'sceneWarning': 'ВНИМАНИЕ: технические сигналы соответствуют возможной съёмке с экрана ({risk}). Медиа остаётся связано с сертификатом, но сцену не следует считать прямой съёмкой реальности.', 'registryNotFoundDetail': 'Сертификат не найден в Registry. Это не доказывает изменение файла: онлайн-публикация может ещё ожидать завершения.', 'registryUnavailableDetail': 'Registry временно недоступен. Локальный файл не считается недействительным; повторите при наличии соединения.', 'registryInvalidResponse': 'Непригодный ответ Registry: {error}', 'invalidLocalCertificate': 'Недействительный локальный сертификат: {error}', 'unexpectedRegistryError': 'Неожиданная ошибка проверки Registry: {error}', 'contentType': 'Тип',
      'techHcvTrust': 'Доверие HCV', 'techLiveTrust': 'Доверие live-захвату', 'techSceneAuthenticity': 'Подлинность сцены', 'techSyntheticRisk': 'Синтетический риск', 'techAiProof': 'Уровень AI-доказательства', 'techDisplayFusion': 'ОБЪЕДИНЕНИЕ РИСКА ЭКРАНА', 'techDecision': 'Решение', 'techRisk': 'Риск', 'techScore': 'Оценка', 'techPassive': 'ПАССИВНЫЙ АНАЛИЗ ВИДЕО/ИЗОБРАЖЕНИЯ', 'techSegments': 'Проанализированные сегменты', 'techWorstSecond': 'Худшая секунда', 'techLocalFlicker': 'Локальное временное мерцание', 'techRefreshBand': 'Полосы обновления', 'techPixelGrid': 'Однородность пиксельной сетки', 'techLiveProbe': 'LIVE-ПРОВЕРКА ЭКРАНА', 'techAnalysisStatus': 'Статус анализа', 'techFrames': 'Проанализированные кадры', 'techReason': 'Причина', 'techError': 'Ошибка', 'techFineStripe': 'Тонкие полосы', 'techFineGrid': 'Тонкая сетка', 'techMoireFrequency': 'Частота муара', 'techDynamicChallenge': 'Динамическая проверка', 'techPersistentPattern': 'Устойчивый паттерн', 'techOpticalTrace': 'Подтверждённый оптический след', 'techMoireTrace': 'След муара', 'techDynamicTrace': 'След динамической проверки экрана', 'techUncorroborated': 'Неподтверждённый экранный паттерн', 'techMl': 'ML СЪЁМКА С ЭКРАНА', 'techModelSource': 'Источник модели', 'techModelVersion': 'Версия модели', 'techRuntime': 'Среда TFLite', 'techModelSha': 'SHA-256 модели', 'techPredictedClass': 'Предсказанный класс', 'techConfidence': 'Уверенность', 'techScreenProbability': 'Вероятность экрана', 'techMlDecision': 'Решение ML',
    },
  };
}
'''
(ROOT/'registry_verify_copy.dart').write_text(registry_copy,encoding='utf-8')

s=read('registry_verify_page.dart')
s=replace_once(s,"import 'verification_ui_copy.dart';","import 'verification_ui_copy.dart';\nimport 'registry_verify_copy.dart';",'registry copy import')
s=replace_once(s,"  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);","  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);\n  String _r(String key) => RegistryVerifyCopy.t(widget.languageCode, key);",'registry copy helper')
# direct status replacements
simple={
"status = 'Controllo rapido SIGILLUM in corso...';":"status = _r('quickCheck');",
"status = 'File ricevuto ma non accessibile. Riprova da Verifica contenuto.';":"status = _r('fileUnavailable');",
"status = 'Contenuto non certificato SIGILLUM.';":"status = _r('notCertified');",
"status = 'HCV-ID rilevato. Verifica Registry automatica...';":"status = _r('idDetectedAuto');",
"status = 'Verifica automatica non completata. Il file e arrivato con un formato non leggibile automaticamente: inserisci HCV-ID e premi VERIFICA DA REGISTRY.';":"status = _r('autoIncomplete');",
"status = 'File selezionato ma non importabile su iOS';":"status = _r('iosImportFailed');",
"status = 'Qui devi selezionare il file ORIGINALE (mp4, jpg, pdf, txt, audio), NON .hcv o .hcvpack';":"status = _r('selectOriginalNotPack');",
"status = 'HCV-ID rilevato via OCR nel media';":"status = _r('ocrDetectedMedia');",
"status = 'HCV-ID rilevato via OCR';":"status = _r('ocrDetectedMedia');",
"? 'HCV-ID rilevato. Ora premi VERIFICA DA REGISTRY'":"? _r('idDetectedPressVerify')",
": 'File selezionato. Se disponibile, inserisci o rileva HCV-ID e premi VERIFICA DA REGISTRY.';":": _r('fileSelectedPressVerify');",
"status = 'Inserisci HCV-ID';":"status = _r('enterId');",
"status = 'Seleziona il file originale da verificare';":"status = _r('selectOriginal');",
"status = 'Scaricamento certificato dal Registry HCV...';":"status = _r('downloadingCertificate');",
"status = 'Certificato scaricato ma firma crittografica NON valida';":"status = _r('signatureInvalid');",
"status = 'Certificato senza content binding';":"status = _r('bindingMissing');",
"status = 'File media non trovato';":"status = _r('mediaMissing');",
}
for old,new in simple.items(): s=replace_once(s,old,new,f'registry status {old[:30]}')

# Replace markVerified clean statuses and media-specific detailed statuses.
s=replace_once(s,"'FORENSIC VERIFIED OK\\nFile identico all originale certificato. Hash SHA-256 corrispondente.',","_r('forensicStatus'),",'forensic status')
s=replace_once(s,"'SOCIAL VERIFIED OK\\nTesto originale verificato. Il post contiene footer SIGILLUM/HCV-ID, quindi il file non e identico byte-per-byte ma il contenuto certificato corrisponde.',","_r('socialTextStatus'),",'social text status')
s=replace_once(s,"status = 'SOCIAL VERIFIED OK\\nHash non identico al file certificato. HCV-ID e certificato Registry sono validi; la causa della differenza non e determinabile automaticamente.';","status = _r('genericDerived');",'generic derived status')
status_repls={
"? 'HCV-ID e fingerprint video compatibili, ma il fingerprint audio non corrisponde al contenuto certificato. Possibile audio sostituito, rimosso o alterato oltre la tolleranza di ricompressione.'":"? _r('audioMismatchDetected')",
": 'HCV-ID inserito e fingerprint video compatibile, ma il fingerprint audio non corrisponde al contenuto certificato. Il video selezionato non verifica la traccia audio certificata.';":": _r('audioMismatchProvided');",
"? 'SOCIAL VERIFIED OK\\nHCV-ID rilevato nel video, certificato Registry valido, fingerprint video compatibile e fingerprint audio compatibile dopo ricompressione.'":"? _r('videoBothDetected')",
": 'SOCIAL VERIFIED OK\\nHCV-ID inserito, certificato Registry valido, fingerprint video compatibile e fingerprint audio compatibile dopo ricompressione.')":": _r('videoBothProvided'))",
"? 'SOCIAL VERIFIED OK\\nHCV-ID rilevato nel video e fingerprint video compatibile. Certificato legacy precedente al fingerprint audio.'":"? _r('videoLegacyAudioDetected')",
": 'SOCIAL VERIFIED OK\\nHCV-ID inserito e fingerprint video compatibile. Certificato legacy precedente al fingerprint audio.'),":": _r('videoLegacyAudioProvided')),",
"? 'SOCIAL VERIFIED OK\\nHCV-ID rilevato nel media e certificato Registry valido. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.'":"? _r('videoLegacyLimitedDetected')",
": 'SOCIAL VERIFIED OK\\nHCV-ID inserito e certificato Registry valido. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.',":": _r('videoLegacyLimitedProvided'),",
"? 'HCV-ID rilevato nel video, ma il fingerprint social non corrisponde al contenuto certificato. Possibile ID sovrapposto a un video diverso.'":"? _r('videoMismatchDetected')",
": 'HCV-ID inserito, ma il fingerprint social non corrisponde al contenuto certificato. Il video selezionato non risulta compatibile con quel certificato.';":": _r('videoMismatchProvided');",
"? 'SOCIAL VERIFIED OK\\nHCV-ID rilevato nella foto, certificato Registry valido e fingerprint immagine compatibile. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.'":"? _r('photoCompatibleDetected')",
": 'SOCIAL VERIFIED OK\\nHCV-ID inserito, certificato Registry valido e fingerprint immagine compatibile. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.',":": _r('photoCompatibleProvided'),",
"? 'SOCIAL VERIFIED OK\\nHCV-ID rilevato nella foto e certificato Registry valido. Foto legacy senza fingerprint immagine: verifica social meno forte.'":"? _r('photoLegacyDetected')",
": 'SOCIAL VERIFIED OK\\nHCV-ID inserito e certificato Registry valido. Foto legacy senza fingerprint immagine: verifica social meno forte.',":": _r('photoLegacyProvided'),",
"? 'HCV-ID rilevato nella foto, ma il fingerprint immagine non corrisponde al contenuto certificato. Possibile ID sovrapposto a una foto diversa.'":"? _r('photoMismatchDetected')",
": 'HCV-ID inserito, ma il fingerprint immagine non corrisponde al contenuto certificato. La foto selezionata non risulta compatibile con quel certificato.';":": _r('photoMismatchProvided');",
"status = 'HCV-ID valido nel Registry, ma non rilevato automaticamente nel file selezionato. Verifica social non conclusiva.';":"status = _r('idNotDetected');",
}
for old,new in status_repls.items():
    if old in s: s=replace_once(s,old,new,f'registry media status {old[:30]}')
# Generic hcvId detected media fallback appears once after photo branches.
s=s.replace("'SOCIAL VERIFIED OK\\nHCV-ID rilevato nel media e certificato Registry valido. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.',","_r('genericDerived'),")
# scene warning block
old_scene="""status =
                '$cleanStatus\\n\\n'
                'ATTENZIONE: possibile ripresa di uno schermo rilevata '
                '($screenReplayRisk). Il media è collegato al certificato, '
                'ma la scena non va trattata come ripresa diretta della realtà.';"""
new_scene="""status = '$cleanStatus\\n\\n${_r('sceneWarning').replaceAll('{risk}', screenReplayRisk ?? '-')}';"""
s=replace_once(s,old_scene,new_scene,'scene warning localization')
# registry exception statuses
s=replace_once(s,"status = 'Certificato non presente nel Registry. Questo non dimostra che il file sia stato modificato: la pubblicazione online potrebbe essere ancora in attesa.';","status = _r('registryNotFoundDetail');",'registry not found detail')
s=replace_once(s,"status = 'Registry temporaneamente non raggiungibile. Il file locale non viene considerato invalido; riprova quando la connessione e disponibile.';","status = _r('registryUnavailableDetail');",'registry unavailable detail')
s=replace_once(s,"status = 'Risposta Registry non utilizzabile: ${e.message}';","status = _r('registryInvalidResponse').replaceAll('{error}', e.message);",'registry invalid response')
s=replace_once(s,"status = 'Certificato locale non valido: ${e.message}';","status = _r('invalidLocalCertificate').replaceAll('{error}', e.message);",'invalid local cert')
s=replace_once(s,"status = 'Errore imprevisto durante la verifica Registry: $e';","status = _r('unexpectedRegistryError').replaceAll('{error}', e.toString());",'registry unexpected error')
# Public content type label
s=replace_once(s,"'Type: ${contentType ?? '-'}',","'${_r('contentType')}: ${contentType ?? '-'}',",'content type label')

# Localize technical diagnostics labels by replacing the whole getter.
pattern=re.compile(r"  String get _fullTechnicalDiagnostics \{.*?\n  \}\n\n  @override",re.S)
m=pattern.search(s)
if not m: raise RuntimeError('technical diagnostics getter not found')
getter=r'''  String get _fullTechnicalDiagnostics {
    final ml = _signedMlDiagnostics;
    return '${_r('techHcvTrust')}: ${_diagnosticValue(hcvTrustLevel)}\n'
        '${_r('techLiveTrust')}: ${_diagnosticValue(liveCaptureTrust)}\n'
        '${_r('techSceneAuthenticity')}: ${_diagnosticValue(sceneAuthenticity)}\n'
        '${_r('techSyntheticRisk')}: ${_diagnosticValue(syntheticRisk)}\n'
        '${_r('techAiProof')}: ${_diagnosticValue(aiProofLevel)}\n'
        '\n${_r('techDisplayFusion')}\n'
        '${_r('techDecision')}: ${_diagnosticValue(displayRiskDecision)}\n'
        '${_r('techRisk')}: ${_diagnosticValue(screenReplayRisk)}\n'
        '${_r('techScore')}: ${_diagnosticValue(screenReplayRiskScore)}\n'
        '\n${_r('techPassive')}\n'
        '${_r('techSegments')}: ${_diagnosticValue(screenReplaySegmentsAnalyzed)}\n'
        '${_r('techWorstSecond')}: ${_diagnosticValue(screenReplayWorstSecond)}\n'
        '${_r('techLocalFlicker')}: ${_diagnosticValue(localTemporalFlickerScore)}\n'
        '${_r('techRefreshBand')}: ${_diagnosticValue(refreshBandScore)}\n'
        '${_r('techPixelGrid')}: ${_diagnosticValue(pixelGridUniformityScore)}\n'
        '\n${_r('techLiveProbe')}\n'
        '${_r('techAnalysisStatus')}: ${_diagnosticValue(liveProbeAnalysisStatus)}\n'
        '${_r('techFrames')}: ${_diagnosticValue(liveProbeFrames)}\n'
        '${_r('techRisk')}: ${_diagnosticValue(liveProbeRisk)}\n'
        '${_r('techReason')}: ${_diagnosticValue(liveProbeReason)}\n'
        '${_r('techError')}: ${_diagnosticValue(liveProbeError)}\n'
        '${_r('techLocalFlicker')}: ${_diagnosticValue(liveProbeLocalFlickerScore)}\n'
        '${_r('techRefreshBand')}: ${_diagnosticValue(liveProbeRefreshBandScore)}\n'
        '${_r('techFineStripe')}: ${_diagnosticValue(liveProbeFineStripeScore)}\n'
        '${_r('techFineGrid')}: ${_diagnosticValue(liveProbeFineGridScore)}\n'
        '${_r('techMoireFrequency')}: ${_diagnosticValue(liveProbeMoireFrequencyScore)}\n'
        '${_r('techDynamicChallenge')}: ${_diagnosticValue(liveProbeDynamicChallengeScore)}\n'
        '${_r('techPersistentPattern')}: ${_diagnosticValue(liveProbePersistentPatternScore)}\n'
        '${_r('techOpticalTrace')}: ${_diagnosticValue(liveProbeOpticalCorroboratedTrace)}\n'
        '${_r('techMoireTrace')}: ${_diagnosticValue(liveProbeMoireFrequencyTrace)}\n'
        '${_r('techDynamicTrace')}: ${_diagnosticValue(liveProbeDynamicScreenChallengeTrace)}\n'
        '${_r('techUncorroborated')}: ${_diagnosticValue(liveProbeUncorroboratedDisplayPattern)}\n'
        '\n${_r('techMl')}\n'
        '${_r('techAnalysisStatus')}: ${_diagnosticValue(ml?['analysisStatus'])}\n'
        '${_r('techModelSource')}: ${_diagnosticValue(ml?['modelSource'])}\n'
        '${_r('techModelVersion')}: ${_diagnosticValue(ml?['modelVersion'])}\n'
        '${_r('techRuntime')}: ${_diagnosticValue(ml?['tfliteRuntimeVersion'])}\n'
        '${_r('techModelSha')}: ${_diagnosticValue(ml?['modelSha256'])}\n'
        '${_r('techPredictedClass')}: ${_diagnosticValue(ml?['predictedClass'])}\n'
        '${_r('techConfidence')}: ${_diagnosticValue(ml?['predictedClassConfidence'])}\n'
        '${_r('techScreenProbability')}: ${_diagnosticValue(ml?['screenProbability'])}\n'
        '${_r('techRisk')}: ${_diagnosticValue(ml?['screenReplayRisk'])}\n'
        '${_r('techScore')}: ${_diagnosticValue(ml?['screenReplayRiskScore'])}\n'
        '${_r('techMlDecision')}: ${_diagnosticValue(ml?['displayRiskDecision'])}\n'
        '${_r('techReason')}: ${_diagnosticValue(ml?['reason'])}\n'
        '${_r('techError')}: ${_diagnosticValue(ml?['error'])}';
  }

  @override'''
s=s[:m.start()]+getter+s[m.end():]
write('registry_verify_page.dart',s)

# -----------------------------------------------------------------------------
# 9. Lab edition multilingual shell and diagnostics/calibration copy.
# -----------------------------------------------------------------------------
lab_copy=r'''class LabUiCopy {
  const LabUiCopy._();
  static String t(String languageCode, String key) {
    final code = languageCode.toLowerCase().split('-').first;
    return (_copy[code] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;
  }
  static const _copy = {
    'it': {
      'title':'HCV Verify','subtitle':'Human Content Verification','tagline':'Crea contenuti verificabili con controlli su integrità, cattura live, Registry, fingerprint social e rischio schermo.','createVideo':'CREA VIDEO VERIFICABILE','createVideoSub':'Registra un video e genera HCV-ID','verifyVideo':'VERIFICA VIDEO CON HCV-ID','verifyVideoSub':'Seleziona un video e verifica dal Registry','import':'IMPORTA FILE HCV','importSub':'Apri .hcv, .hcvpack o file ricevuti','openPack':'APRI HCVPACK','openPackSub':'Verifica un pacchetto completo offline','certText':'CERTIFICA TESTO','certTextSub':'Crea un testo verificabile con HCV','identity':'IDENTITÀ CREATOR','identitySub':'Imposta nome e identità del creator','diagnostics':'DIAGNOSTICA SCHERMO','diagnosticsSub':'Raccogli sessioni test e leggi i valori tecnici','training':'AUTO TRAINING ML','trainingSub':'Raccogli campioni, conferma label ed esporta ZIP','how':'COME FUNZIONA','howSub':'Spiegazione semplice del sistema','infoTitle':'Come funziona HCV','infoBody':'HCV crea una prova tecnica verificabile per un contenuto. Alla creazione SIGILLUM associa contenuto, HCV-ID, certificato firmato e, quando previsto, HCVPACK. La verifica combina integrità del file, cattura live, Registry, fingerprint per copie ricompresse e analisi del rischio di ripresa da schermo. Per i video moderni la compatibilità visiva e audio viene verificata separatamente. Un esito positivo attesta i controlli tecnici eseguiti e non prova da solo la verità sostanziale della scena.','diagInitial':'Seleziona una foto o un video di test.','diagRunning':'Analisi in corso...','diagComplete':'Analisi completata.','diagCopied':'Report copiato','diagSessionCopied':'Report sessione copiato','diagTitle':'Diagnostica schermo','diagSelect':'SELEZIONA FOTO O VIDEO','save':'SALVA','share':'CONDIVIDI','reset':'AZZERA SESSIONE','copyReport':'COPIA REPORT','calInitial':'Scegli la classe ML e avvia il test.','cameraUnavailable':'Camera non disponibile.','cameraReady':'Camera pronta.','sampleDiscarded':'Campione scartato: nessuna label confermata.','manifestCopied':'Manifest copiato','zipShareOpened':'Condivisione ZIP aperta.','trainerServer':'Server AI Trainer','endpoint':'Endpoint','default':'PREDEFINITO','installingModel':'Installazione modello locale...','modelRestored':'Ripristinato modello incluso nell’app.','confirmLabel':'Conferma label ML','correctLabel':'Label corretta','discard':'SCARTA','confirm':'CONFERMA','autoTraining':'Auto Training ML','aiServer':'AI SERVER','modelZip':'MODELLO ZIP','useBundled':'USA MODELLO INCLUSO NELL APP','copyManifest':'COPIA MANIFEST','zip':'ZIP','shareZip':'CONDIVIDI ZIP','saveManifest':'SALVA SOLO MANIFEST'},
    'en': {
      'title':'HCV Verify','subtitle':'Human Content Verification','tagline':'Create verifiable content with file-integrity, live-capture, Registry, social-fingerprint and screen-replay checks.','createVideo':'CREATE VERIFIABLE VIDEO','createVideoSub':'Record a video and generate an HCV-ID','verifyVideo':'VERIFY VIDEO WITH HCV-ID','verifyVideoSub':'Select a video and verify it from the Registry','import':'IMPORT HCV FILE','importSub':'Open .hcv, .hcvpack or received files','openPack':'OPEN HCVPACK','openPackSub':'Verify a complete package offline','certText':'CERTIFY TEXT','certTextSub':'Create verifiable text with HCV','identity':'CREATOR IDENTITY','identitySub':'Set creator name and identity','diagnostics':'SCREEN DIAGNOSTICS','diagnosticsSub':'Collect test sessions and inspect technical values','training':'ML AUTO TRAINING','trainingSub':'Collect samples, confirm labels and export ZIP','how':'HOW IT WORKS','howSub':'Simple explanation of the system','infoTitle':'How HCV works','infoBody':'HCV creates verifiable technical evidence for content. When content is created, SIGILLUM associates the content, HCV-ID, signed certificate and, where applicable, HCVPACK. Verification combines file integrity, live capture, Registry, fingerprints for recompressed copies and screen-replay risk analysis. Modern videos verify visual and audio compatibility separately. A positive result attests the technical checks performed and does not by itself prove the substantive truth of the scene.','diagInitial':'Select a test photo or video.','diagRunning':'Analysis in progress...','diagComplete':'Analysis complete.','diagCopied':'Report copied','diagSessionCopied':'Session report copied','diagTitle':'Screen diagnostics','diagSelect':'SELECT PHOTO OR VIDEO','save':'SAVE','share':'SHARE','reset':'RESET SESSION','copyReport':'COPY REPORT','calInitial':'Choose the ML class and start the test.','cameraUnavailable':'Camera unavailable.','cameraReady':'Camera ready.','sampleDiscarded':'Sample discarded: no label confirmed.','manifestCopied':'Manifest copied','zipShareOpened':'ZIP sharing opened.','trainerServer':'AI Trainer server','endpoint':'Endpoint','default':'DEFAULT','installingModel':'Installing local model...','modelRestored':'Bundled app model restored.','confirmLabel':'Confirm ML label','correctLabel':'Correct label','discard':'DISCARD','confirm':'CONFIRM','autoTraining':'ML Auto Training','aiServer':'AI SERVER','modelZip':'MODEL ZIP','useBundled':'USE MODEL BUNDLED WITH APP','copyManifest':'COPY MANIFEST','zip':'ZIP','shareZip':'SHARE ZIP','saveManifest':'SAVE MANIFEST ONLY'},
    'es': {
      'title':'HCV Verify','subtitle':'Human Content Verification','tagline':'Crea contenido verificable con controles de integridad, captura live, Registry, huellas para redes y riesgo de pantalla.','createVideo':'CREAR VÍDEO VERIFICABLE','createVideoSub':'Graba un vídeo y genera un HCV-ID','verifyVideo':'VERIFICAR VÍDEO CON HCV-ID','verifyVideoSub':'Selecciona un vídeo y verifícalo en Registry','import':'IMPORTAR ARCHIVO HCV','importSub':'Abre .hcv, .hcvpack o archivos recibidos','openPack':'ABRIR HCVPACK','openPackSub':'Verifica un paquete completo sin conexión','certText':'CERTIFICAR TEXTO','certTextSub':'Crea texto verificable con HCV','identity':'IDENTIDAD CREATOR','identitySub':'Configura nombre e identidad del creator','diagnostics':'DIAGNÓSTICO DE PANTALLA','diagnosticsSub':'Recoge sesiones de prueba y consulta valores técnicos','training':'AUTO TRAINING ML','trainingSub':'Recoge muestras, confirma etiquetas y exporta ZIP','how':'CÓMO FUNCIONA','howSub':'Explicación sencilla del sistema','infoTitle':'Cómo funciona HCV','infoBody':'HCV crea una prueba técnica verificable para un contenido. Al crearlo, SIGILLUM asocia contenido, HCV-ID, certificado firmado y, cuando corresponde, HCVPACK. La verificación combina integridad del archivo, captura live, Registry, huellas para copias recomprimidas y análisis del riesgo de captura de pantalla. En vídeos modernos se verifica por separado la compatibilidad visual y de audio. Un resultado positivo acredita los controles técnicos realizados y no demuestra por sí solo la verdad sustantiva de la escena.','diagInitial':'Selecciona una foto o un vídeo de prueba.','diagRunning':'Análisis en curso...','diagComplete':'Análisis completado.','diagCopied':'Informe copiado','diagSessionCopied':'Informe de sesión copiado','diagTitle':'Diagnóstico de pantalla','diagSelect':'SELECCIONAR FOTO O VÍDEO','save':'GUARDAR','share':'COMPARTIR','reset':'REINICIAR SESIÓN','copyReport':'COPIAR INFORME','calInitial':'Elige la clase ML e inicia la prueba.','cameraUnavailable':'Cámara no disponible.','cameraReady':'Cámara lista.','sampleDiscarded':'Muestra descartada: no se confirmó ninguna etiqueta.','manifestCopied':'Manifest copiado','zipShareOpened':'Se abrió la compartición del ZIP.','trainerServer':'Servidor AI Trainer','endpoint':'Endpoint','default':'PREDETERMINADO','installingModel':'Instalando modelo local...','modelRestored':'Se restauró el modelo incluido en la app.','confirmLabel':'Confirmar etiqueta ML','correctLabel':'Etiqueta correcta','discard':'DESCARTAR','confirm':'CONFIRMAR','autoTraining':'Auto Training ML','aiServer':'SERVIDOR AI','modelZip':'MODELO ZIP','useBundled':'USAR MODELO INCLUIDO EN LA APP','copyManifest':'COPIAR MANIFEST','zip':'ZIP','shareZip':'COMPARTIR ZIP','saveManifest':'GUARDAR SOLO MANIFEST'},
    'ru': {
      'title':'HCV Verify','subtitle':'Human Content Verification','tagline':'Создавайте проверяемый контент с контролем целостности, live-захвата, Registry, отпечатков после перекодирования и риска съёмки с экрана.','createVideo':'СОЗДАТЬ ПРОВЕРЯЕМОЕ ВИДЕО','createVideoSub':'Запишите видео и создайте HCV-ID','verifyVideo':'ПРОВЕРИТЬ ВИДЕО ПО HCV-ID','verifyVideoSub':'Выберите видео и проверьте его через Registry','import':'ИМПОРТИРОВАТЬ HCV','importSub':'Открыть .hcv, .hcvpack или полученные файлы','openPack':'ОТКРЫТЬ HCVPACK','openPackSub':'Проверить полный пакет офлайн','certText':'СЕРТИФИЦИРОВАТЬ ТЕКСТ','certTextSub':'Создать проверяемый текст с HCV','identity':'ИДЕНТИЧНОСТЬ CREATOR','identitySub':'Настроить имя и идентичность creator','diagnostics':'ДИАГНОСТИКА ЭКРАНА','diagnosticsSub':'Собрать тестовые сессии и посмотреть технические значения','training':'АВТООБУЧЕНИЕ ML','trainingSub':'Собрать образцы, подтвердить метки и экспортировать ZIP','how':'КАК ЭТО РАБОТАЕТ','howSub':'Простое объяснение системы','infoTitle':'Как работает HCV','infoBody':'HCV создаёт проверяемое техническое свидетельство для контента. При создании SIGILLUM связывает контент, HCV-ID, подписанный сертификат и, когда предусмотрено, HCVPACK. Проверка объединяет целостность файла, live-захват, Registry, отпечатки перекодированных копий и анализ риска съёмки с экрана. В современных видео визуальная и аудиосовместимость проверяются отдельно. Положительный результат подтверждает выполненные технические проверки и сам по себе не доказывает фактическую истинность сцены.','diagInitial':'Выберите тестовое фото или видео.','diagRunning':'Выполняется анализ...','diagComplete':'Анализ завершён.','diagCopied':'Отчёт скопирован','diagSessionCopied':'Отчёт сессии скопирован','diagTitle':'Диагностика экрана','diagSelect':'ВЫБРАТЬ ФОТО ИЛИ ВИДЕО','save':'СОХРАНИТЬ','share':'ПОДЕЛИТЬСЯ','reset':'СБРОСИТЬ СЕССИЮ','copyReport':'КОПИРОВАТЬ ОТЧЁТ','calInitial':'Выберите класс ML и запустите тест.','cameraUnavailable':'Камера недоступна.','cameraReady':'Камера готова.','sampleDiscarded':'Образец отклонён: метка не подтверждена.','manifestCopied':'Manifest скопирован','zipShareOpened':'Открыто меню отправки ZIP.','trainerServer':'Сервер AI Trainer','endpoint':'Endpoint','default':'ПО УМОЛЧАНИЮ','installingModel':'Установка локальной модели...','modelRestored':'Восстановлена модель, встроенная в приложение.','confirmLabel':'Подтвердить метку ML','correctLabel':'Правильная метка','discard':'ОТКЛОНИТЬ','confirm':'ПОДТВЕРДИТЬ','autoTraining':'Автообучение ML','aiServer':'AI СЕРВЕР','modelZip':'ZIP МОДЕЛИ','useBundled':'ИСПОЛЬЗОВАТЬ ВСТРОЕННУЮ МОДЕЛЬ','copyManifest':'КОПИРОВАТЬ MANIFEST','zip':'ZIP','shareZip':'ПОДЕЛИТЬСЯ ZIP','saveManifest':'СОХРАНИТЬ ТОЛЬКО MANIFEST'},
  };
}
'''
(ROOT/'lab_ui_copy.dart').write_text(lab_copy,encoding='utf-8')

# HomePage Lab: introduce language state, localized copy and language menu; pass language to pages that support it.
s=read('home_page.dart')
s=replace_once(s,"import 'text_cert_page.dart';","import 'text_cert_page.dart';\nimport 'sigillum_localization.dart';\nimport 'lab_ui_copy.dart';",'lab imports')
s=replace_once(s,"  String? _lastOpenedSharedPath;","  String? _lastOpenedSharedPath;\n  String languageCode = SigillumCopy.initialLanguageCode();\n  String _l(String key) => LabUiCopy.t(languageCode, key);",'lab language state')
s=s.replace("RegistryVerifyPage(\n            initialMediaPath: path,\n          )","RegistryVerifyPage(\n            initialMediaPath: path,\n            languageCode: languageCode,\n          )")
# Replace _openInfo function wholesale.
pat=re.compile(r"  void _openInfo\(\) \{.*?\n  \}\n\n  @override",re.S)
m=pat.search(s)
if not m: raise RuntimeError('home _openInfo not found')
info="""  void _openInfo() {
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

  @override"""
s=s[:m.start()]+info+s[m.end():]
# Replace AppBar/title/tagline/buttons by exact common strings.
s=s.replace('title: const Text("HCV Verify"),',"title: Text(_l('title')),\n        actions: [\n          PopupMenuButton<String>(\n            tooltip: SigillumCopy.language(languageCode).name,\n            onSelected: (value) => setState(() => languageCode = value),\n            itemBuilder: (_) => [\n              for (final item in SigillumCopy.languages)\n                PopupMenuItem(value: item.code, child: Text(item.name)),\n            ],\n            child: Padding(\n              padding: const EdgeInsets.symmetric(horizontal: 14),\n              child: Center(child: Text(SigillumCopy.language(languageCode).shortName)),\n            ),\n          ),\n        ],")
s=s.replace('const Text(\n                "Human Content Verification",','Text(\n                _l(\'subtitle\'),')
s=s.replace('const Padding(\n                padding: EdgeInsets.symmetric(horizontal: 32),\n                child: Text(\n                  "Crea contenuti verificabili con controlli su integrita, cattura live, Registry, social fingerprint e rischio schermo.",','Padding(\n                padding: const EdgeInsets.symmetric(horizontal: 32),\n                child: Text(\n                  _l(\'tagline\'),')
button_map={
'"CREA VIDEO VERIFICABILE"':"_l('createVideo')",'"Registra un video e genera HCV-ID"':"_l('createVideoSub')",'"VERIFICA VIDEO CON HCV-ID"':"_l('verifyVideo')",'"Seleziona un MP4 e verifica dal Registry"':"_l('verifyVideoSub')",'"IMPORTA FILE HCV"':"_l('import')",'"Apri .hcv, .hcvpack o file ricevuti"':"_l('importSub')",'"APRI HCVPACK"':"_l('openPack')",'"Verifica un pacchetto completo offline"':"_l('openPackSub')",'"CERTIFICA TESTO"':"_l('certText')",'"Crea un testo verificabile con HCV"':"_l('certTextSub')",'"IDENTITA CREATOR"':"_l('identity')",'"Imposta nome e identita del creatore"':"_l('identitySub')",'"DIAGNOSTICA SCHERMO"':"_l('diagnostics')",'"Raccogli sessioni test e leggi i valori tecnici"':"_l('diagnosticsSub')",'"AUTO TRAINING ML"':"_l('training')",'"Raccogli campioni, conferma label ed esporta ZIP"':"_l('trainingSub')",'"COME FUNZIONA"':"_l('how')",'"Spiegazione semplice del sistema"':"_l('howSub')",
}
for old,new in button_map.items(): s=s.replace(old,new)
s=s.replace('onPressed: () => _open(const CameraPage()),',"onPressed: () => _open(CameraPage(languageCode: languageCode)),")
s=s.replace('onPressed: () => _open(const RegistryVerifyPage()),',"onPressed: () => _open(RegistryVerifyPage(languageCode: languageCode)),")
s=s.replace('onPressed: () => _open(const HCVPackPlayerPage()),',"onPressed: () => _open(HCVPackPlayerPage(languageCode: languageCode)),")
s=s.replace('onPressed: () => _open(const TextCertPage()),',"onPressed: () => _open(TextCertPage(languageCode: languageCode)),")
s=s.replace('onPressed: () => _open(const IdentityPage()),',"onPressed: () => _open(IdentityPage(languageCode: languageCode)),")
s=s.replace('onPressed: () => _open(const ScreenReplayDiagnosticsPage()),',"onPressed: () => _open(ScreenReplayDiagnosticsPage(languageCode: languageCode)),")
s=s.replace('onPressed: () => _open(const ScreenReplayCalibrationPage()),',"onPressed: () => _open(ScreenReplayCalibrationPage(languageCode: languageCode)),")
write('home_page.dart',s)

# Diagnostics page languageCode + LabUiCopy and known user-facing strings.
s=read('screen_replay_diagnostics_page.dart')
s=replace_once(s,"import 'hcv_ml_screen_replay_classifier.dart';","import 'hcv_ml_screen_replay_classifier.dart';\nimport 'lab_ui_copy.dart';",'diag lab import')
s=replace_once(s,"class ScreenReplayDiagnosticsPage extends StatefulWidget {\n  const ScreenReplayDiagnosticsPage({super.key});","class ScreenReplayDiagnosticsPage extends StatefulWidget {\n  const ScreenReplayDiagnosticsPage({super.key, this.languageCode = 'it'});\n  final String languageCode;",'diag language prop')
s=replace_once(s,"  bool loading = false;\n  String status = 'Seleziona una foto o un video di test.';","  bool loading = false;\n  String _l(String key) => LabUiCopy.t(widget.languageCode, key);\n  late String status;",'diag status init field')
s=replace_once(s,"  Future<void> pickAndAnalyze() async {","  @override\n  void initState() {\n    super.initState();\n    status = _l('diagInitial');\n  }\n\n  Future<void> pickAndAnalyze() async {",'diag initState')
for old,key in [("'Analisi in corso...'",'diagRunning'),("'Analisi completata.'",'diagComplete'),("'Report copiato'",'diagCopied'),("'Report sessione copiato'",'diagSessionCopied'),("'Diagnostica schermo'",'diagTitle'),("'SELEZIONA FOTO O VIDEO'",'diagSelect'),("'SALVA'",'save'),("'CONDIVIDI'",'share'),("'AZZERA SESSIONE'",'reset'),("'COPIA REPORT'",'copyReport')]:
    s=s.replace(old,f"_l('{key}')")
# remove const where dynamic Text introduced
s=s.replace('const Text(_l(', 'Text(_l(')
write('screen_replay_diagnostics_page.dart',s)

# Calibration page languageCode + LabUiCopy and known user-facing strings.
s=read('screen_replay_calibration_page.dart')
s=replace_once(s,"import 'hcv_ml_screen_replay_classifier.dart';","import 'hcv_ml_screen_replay_classifier.dart';\nimport 'lab_ui_copy.dart';",'cal lab import')
s=replace_once(s,"class ScreenReplayCalibrationPage extends StatefulWidget {\n  const ScreenReplayCalibrationPage({super.key});","class ScreenReplayCalibrationPage extends StatefulWidget {\n  const ScreenReplayCalibrationPage({super.key, this.languageCode = 'it'});\n  final String languageCode;",'cal language prop')
s=replace_once(s,"  String selectedLabel = 'SCREEN_MONITOR';\n  int autoSampleCount = 5;\n  String status = 'Scegli la classe ML e avvia il test.';","  String selectedLabel = 'SCREEN_MONITOR';\n  int autoSampleCount = 5;\n  String _l(String key) => LabUiCopy.t(widget.languageCode, key);\n  late String status;",'cal status field')
s=replace_once(s,"    loadTrainerSettings();\n    initCamera();","    status = _l('calInitial');\n    loadTrainerSettings();\n    initCamera();",'cal init status')
cal_repls=[("'Camera non disponibile.'",'cameraUnavailable'),("'Camera pronta.'",'cameraReady'),("'Campione scartato: nessuna label confermata.'",'sampleDiscarded'),("'Manifest copiato'",'manifestCopied'),("'Condivisione ZIP aperta.'",'zipShareOpened'),("'Server AI Trainer'",'trainerServer'),("'Endpoint'",'endpoint'),("'PREDEFINITO'",'default'),("'Installazione modello locale...'",'installingModel'),("'Ripristinato modello incluso nell’app.'",'modelRestored'),("'Conferma label ML'",'confirmLabel'),("'Label corretta'",'correctLabel'),("'SCARTA'",'discard'),("'CONFERMA'",'confirm'),("'Auto Training ML'",'autoTraining'),("'AI SERVER'",'aiServer'),("'MODELLO ZIP'",'modelZip'),("\"USA MODELLO INCLUSO NELL'APP\"",'useBundled'),("'COPIA MANIFEST'",'copyManifest'),("'ZIP'",'zip'),("'CONDIVIDI ZIP'",'shareZip'),("'SALVA SOLO MANIFEST'",'saveManifest')]
for old,key in cal_repls: s=s.replace(old,f"_l('{key}')")
s=s.replace('const Text(_l(', 'Text(_l(')
write('screen_replay_calibration_page.dart',s)

# -----------------------------------------------------------------------------
# 10. Contract test for all corrected findings.
# -----------------------------------------------------------------------------
test=Path('test/build113_copy_localization_contract_test.dart')
test.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/sigillum_localization.dart';
import 'package:sigillum_iphone/verification_ui_copy.dart';
import 'package:sigillum_iphone/registry_verify_copy.dart';
import 'package:sigillum_iphone/lab_ui_copy.dart';

void main() {
  const languages = ['it', 'en', 'es', 'ru'];

  test('BUILD113 public copy exposes all four languages with current semantics', () {
    expect(SigillumCopy.languages.map((e) => e.code).toList(), languages);
    expect(SigillumCopy.language('es').name, 'Español');
    for (final language in languages) {
      expect(SigillumCopy.t(language, 'checkSocial'), isNotEmpty);
      expect(VerificationUiCopy.t(language, 'derivedDetail'), isNotEmpty);
      expect(RegistryVerifyCopy.t(language, 'audioMismatchDetected'), isNotEmpty);
      expect(RegistryVerifyCopy.t(language, 'videoBothDetected'), isNotEmpty);
      expect(LabUiCopy.t(language, 'diagTitle'), isNotEmpty);
    }
    expect(VerificationUiCopy.t('en', 'compatible'), 'Cannot be determined');
  });

  test('visible production verdicts no longer claim HUMAN VERIFIED', () {
    const files = [
      'lib/camera_ui_copy.dart',
      'lib/hcvpack_player_page.dart',
      'lib/text_cert_page.dart',
      'lib/video_player_verify_page.dart',
      'lib/video_verify_page.dart',
      'lib/home_page.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('HUMAN VERIFIED'), isFalse, reason: path);
    }
  });

  test('quick guide and camera copy contain no manual movement instruction', () {
    final source = '${File('lib/sigillum_quick_guide_page.dart').readAsStringSync()}\n'
        '${File('lib/camera_ui_copy.dart').readAsStringSync()}\n'
        '${File('lib/camera_ui_extended_copy.dart').readAsStringSync()}';
    for (final stale in [
      'muovi leggermente',
      'move the phone slightly',
      'mueve ligeramente',
      'слегка перемещ',
      'MUOVI IL TELEFONO LATERALMENTE',
      'MOVE THE PHONE SIDEWAYS',
    ]) {
      expect(source.toLowerCase().contains(stale.toLowerCase()), isFalse,
          reason: stale);
    }
  });

  test('registry user statuses use multilingual copy for BUILD113 audio axis', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains("_r('videoBothDetected')"));
    expect(source, contains("_r('audioMismatchDetected')"));
    expect(source, contains("_r('techHcvTrust')"));
    expect(source.contains('fingerprint audio non corrisponde al contenuto certificato'), isFalse);
  });
}
''',encoding='utf-8')

print('BUILD113 complete UI copy/localization patch materialized')
