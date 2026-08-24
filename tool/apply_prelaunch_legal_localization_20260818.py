from pathlib import Path

TARGETS = {
    'lib/commercial_gate.dart',
    'lib/commercial_account_service.dart',
    'lib/commercial_profile_page.dart',
    'lib/legal_info_page.dart',
}


def read(path):
    return Path(path).read_text(encoding='utf-8')


def write(path, content):
    if path not in TARGETS:
        raise RuntimeError(f'Write outside commercial/legal allowlist blocked: {path}')
    Path(path).write_text(content, encoding='utf-8')


def replace_once(source, old, new, label):
    count = source.count(old)
    if count == 1:
        return source.replace(old, new, 1)
    if count == 0 and new in source:
        return source
    raise RuntimeError(f'{label}: expected one anchor, found {count}')


# ---------------------------------------------------------------------------
# Commercial gate: device-language default + immediate selector + localized
# pre-login/registration/billing/KYC UX. No capture/HCV engine files touched.
# ---------------------------------------------------------------------------
gate_path = 'lib/commercial_gate.dart'
gate = read(gate_path)

if "package:shared_preferences/shared_preferences.dart" not in gate:
    gate = replace_once(
        gate,
        "import 'package:in_app_purchase/in_app_purchase.dart';\n",
        "import 'package:in_app_purchase/in_app_purchase.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\n",
        'gate shared preferences import',
    )
if "import 'sigillum_localization.dart';" not in gate:
    gate = replace_once(
        gate,
        "import 'legal_info_page.dart';\n",
        "import 'legal_info_page.dart';\nimport 'sigillum_localization.dart';\n",
        'gate localization import',
    )

copy_block = r'''
const _commercialGateCopy = <String, Map<String, String>>{
  'it': {
    'landingSubtitle': 'Verifica gratuitamente contenuti certificati oppure diventa un Creator verificato.',
    'verifyFree': 'VERIFICA CONTENUTO — GRATIS',
    'becomeCreator': 'DIVENTA CREATOR',
    'privacyTermsInfo': 'Privacy, Termini e informazioni',
    'recoverAccount': 'Recupera il tuo account',
    'loginCreator': 'Accedi al tuo account Creator',
    'createCreator': 'Crea il tuo account Creator',
    'name': 'Nome',
    'password': 'Password',
    'passwordHint': 'Almeno 12 caratteri',
    'receivedCode': 'Codice ricevuto (lascia vuoto per inviarlo)',
    'newPassword': 'Nuova password',
    'acceptTerms': 'Accetto i Termini di Servizio SIGILLUM',
    'ackPrivacy': 'Ho preso visione dell’Informativa Privacy SIGILLUM',
    'adult': 'Confermo di avere almeno 18 anni',
    'readPrivacyTerms': 'LEGGI PRIVACY E TERMINI',
    'sendCode': 'INVIA CODICE',
    'resetPassword': 'REIMPOSTA PASSWORD',
    'login': 'ACCEDI',
    'createAccount': 'CREA ACCOUNT',
    'noAccount': 'Non hai un account? CREA ACCOUNT',
    'haveAccount': 'Hai già un account? ACCEDI',
    'forgotPassword': 'PASSWORD DIMENTICATA?',
    'backToLogin': 'TORNA ALL’ACCESSO',
    'back': 'INDIETRO',
    'verifyEmailTitle': 'Verifica il tuo indirizzo email',
    'sentCodeTo': 'Abbiamo inviato un codice a',
    'sixDigitCode': 'Codice di 6 cifre',
    'confirmEmail': 'CONFERMA EMAIL',
    'newCode': 'INVIA NUOVO CODICE',
    'activateCreator': 'Attiva SIGILLUM Creator',
    'featureCert': 'Certificazione foto, video e testo',
    'featureIdentity': 'Identità verificata',
    'featureRegistry': 'Registry HCV e verifica pubblica',
    'featurePack': 'HCVPACK e coordinate opzionali',
    'productsMissing': 'I prodotti App Store non sono ancora configurati per questo account di test.',
    'storeUnavailable': 'App Store non disponibile su questo dispositivo.',
    'annual': 'ANNUALE',
    'monthly': 'MENSILE',
    'restore': 'RIPRISTINA ACQUISTI',
    'logout': 'ESCI DALL’ACCOUNT',
    'identityLastStep': 'Ultimo passaggio: verifica la tua identità',
    'identityBody': 'Per associare i certificati a un Creator reale, SIGILLUM utilizza Stripe Identity. La procedura richiede un documento valido e un controllo selfie. I documenti vengono gestiti tramite Stripe; SIGILLUM conserva lo stato della verifica e i dati tecnici minimi necessari.',
    'verifyIdentity': 'VERIFICA IDENTITÀ',
    'checkIdentity': 'HO COMPLETATO — CONTROLLA STATO',
    'privacyIdentity': 'PRIVACY E INFORMAZIONI SULLA VERIFICA',
    'validationAccount': 'Inserisci nome, email valida e una password di almeno 12 caratteri.',
    'validationConfirmations': 'Per creare un account Creator devi completare le tre conferme richieste.',
    'codeSent': 'Ti abbiamo inviato un codice di 6 cifre.',
    'enterSix': 'Inserisci il codice di 6 cifre.',
    'emailNotVerified': 'Email non ancora verificata. Ti abbiamo inviato un nuovo codice.',
    'recoverySent': 'Codice di recupero inviato. Inseriscilo qui sotto.',
    'newPasswordShort': 'La nuova password deve contenere almeno 12 caratteri.',
    'passwordUpdated': 'Password aggiornata. Ora puoi accedere.',
    'kycLinkMissing': 'Link di verifica identità non disponibile.',
    'kycOpenFailed': 'Impossibile aprire la verifica identità.',
    'kycCompleteReturn': 'Completa la verifica e poi torna in SIGILLUM.',
    'kycStillRunning': 'Verifica ancora in corso',
    'kycServerConfirm': 'La verifica identità deve essere confermata dal server prima di certificare.',
    'kycSyncFailed': 'Impossibile sincronizzare la verifica identità',
    'storeError': 'App Store non disponibile',
    'checkingSubscription': 'Verifica abbonamento con App Store...',
    'subscriptionInactive': 'L’abbonamento non risulta attivo sul server.',
    'subscriptionVerified': 'Abbonamento verificato.',
    'subscriptionFailed': 'Verifica abbonamento non riuscita',
    'purchaseFailed': 'Acquisto non completato.',
    'openResourceFailed': 'Impossibile aprire questa risorsa.',
  },
  'en': {
    'landingSubtitle': 'Verify certified content for free or become a verified Creator.',
    'verifyFree': 'VERIFY CONTENT — FREE',
    'becomeCreator': 'BECOME A CREATOR',
    'privacyTermsInfo': 'Privacy, Terms and information',
    'recoverAccount': 'Recover your account',
    'loginCreator': 'Sign in to your Creator account',
    'createCreator': 'Create your Creator account',
    'name': 'Name',
    'password': 'Password',
    'passwordHint': 'At least 12 characters',
    'receivedCode': 'Received code (leave blank to send it)',
    'newPassword': 'New password',
    'acceptTerms': 'I accept the SIGILLUM Terms of Service',
    'ackPrivacy': 'I have read the SIGILLUM Privacy Policy',
    'adult': 'I confirm that I am at least 18 years old',
    'readPrivacyTerms': 'READ PRIVACY AND TERMS',
    'sendCode': 'SEND CODE',
    'resetPassword': 'RESET PASSWORD',
    'login': 'SIGN IN',
    'createAccount': 'CREATE ACCOUNT',
    'noAccount': 'No account? CREATE ACCOUNT',
    'haveAccount': 'Already have an account? SIGN IN',
    'forgotPassword': 'FORGOT PASSWORD?',
    'backToLogin': 'BACK TO SIGN IN',
    'back': 'BACK',
    'verifyEmailTitle': 'Verify your email address',
    'sentCodeTo': 'We sent a code to',
    'sixDigitCode': '6-digit code',
    'confirmEmail': 'CONFIRM EMAIL',
    'newCode': 'SEND NEW CODE',
    'activateCreator': 'Activate SIGILLUM Creator',
    'featureCert': 'Photo, video and text certification',
    'featureIdentity': 'Verified identity',
    'featureRegistry': 'HCV Registry and public verification',
    'featurePack': 'HCVPACK and optional coordinates',
    'productsMissing': 'App Store products are not yet configured for this test account.',
    'storeUnavailable': 'App Store is unavailable on this device.',
    'annual': 'ANNUAL',
    'monthly': 'MONTHLY',
    'restore': 'RESTORE PURCHASES',
    'logout': 'LOG OUT',
    'identityLastStep': 'Final step: verify your identity',
    'identityBody': 'To link certificates to a real Creator, SIGILLUM uses Stripe Identity. The process requires a valid identity document and a selfie check. Documents are handled through Stripe; SIGILLUM stores the verification status and the minimum technical data required.',
    'verifyIdentity': 'VERIFY IDENTITY',
    'checkIdentity': 'COMPLETED — CHECK STATUS',
    'privacyIdentity': 'PRIVACY AND IDENTITY VERIFICATION INFORMATION',
    'validationAccount': 'Enter your name, a valid email address and a password of at least 12 characters.',
    'validationConfirmations': 'Complete all three confirmations to create a Creator account.',
    'codeSent': 'We sent you a 6-digit code.',
    'enterSix': 'Enter the 6-digit code.',
    'emailNotVerified': 'Email not verified yet. We sent you a new code.',
    'recoverySent': 'Recovery code sent. Enter it below.',
    'newPasswordShort': 'The new password must contain at least 12 characters.',
    'passwordUpdated': 'Password updated. You can now sign in.',
    'kycLinkMissing': 'Identity verification link is unavailable.',
    'kycOpenFailed': 'Unable to open identity verification.',
    'kycCompleteReturn': 'Complete verification and then return to SIGILLUM.',
    'kycStillRunning': 'Verification still in progress',
    'kycServerConfirm': 'Identity verification must be confirmed by the server before certification.',
    'kycSyncFailed': 'Unable to synchronize identity verification',
    'storeError': 'App Store unavailable',
    'checkingSubscription': 'Checking subscription with App Store...',
    'subscriptionInactive': 'The subscription is not active on the server.',
    'subscriptionVerified': 'Subscription verified.',
    'subscriptionFailed': 'Subscription verification failed',
    'purchaseFailed': 'Purchase not completed.',
    'openResourceFailed': 'Unable to open this resource.',
  },
  'es': {
    'landingSubtitle': 'Verifica gratuitamente contenido certificado o conviértete en un Creator verificado.',
    'verifyFree': 'VERIFICAR CONTENIDO — GRATIS',
    'becomeCreator': 'CONVERTIRSE EN CREATOR',
    'privacyTermsInfo': 'Privacidad, Términos e información',
    'recoverAccount': 'Recupera tu cuenta',
    'loginCreator': 'Accede a tu cuenta Creator',
    'createCreator': 'Crea tu cuenta Creator',
    'name': 'Nombre',
    'password': 'Contraseña',
    'passwordHint': 'Al menos 12 caracteres',
    'receivedCode': 'Código recibido (déjalo vacío para enviarlo)',
    'newPassword': 'Nueva contraseña',
    'acceptTerms': 'Acepto los Términos de Servicio de SIGILLUM',
    'ackPrivacy': 'He leído la Política de Privacidad de SIGILLUM',
    'adult': 'Confirmo que tengo al menos 18 años',
    'readPrivacyTerms': 'LEER PRIVACIDAD Y TÉRMINOS',
    'sendCode': 'ENVIAR CÓDIGO',
    'resetPassword': 'RESTABLECER CONTRASEÑA',
    'login': 'ACCEDER',
    'createAccount': 'CREAR CUENTA',
    'noAccount': '¿No tienes cuenta? CREAR CUENTA',
    'haveAccount': '¿Ya tienes cuenta? ACCEDER',
    'forgotPassword': '¿OLVIDASTE LA CONTRASEÑA?',
    'backToLogin': 'VOLVER AL ACCESO',
    'back': 'ATRÁS',
    'verifyEmailTitle': 'Verifica tu dirección de correo electrónico',
    'sentCodeTo': 'Hemos enviado un código a',
    'sixDigitCode': 'Código de 6 dígitos',
    'confirmEmail': 'CONFIRMAR EMAIL',
    'newCode': 'ENVIAR NUEVO CÓDIGO',
    'activateCreator': 'Activar SIGILLUM Creator',
    'featureCert': 'Certificación de fotos, vídeos y textos',
    'featureIdentity': 'Identidad verificada',
    'featureRegistry': 'Registry HCV y verificación pública',
    'featurePack': 'HCVPACK y coordenadas opcionales',
    'productsMissing': 'Los productos de App Store aún no están configurados para esta cuenta de prueba.',
    'storeUnavailable': 'App Store no está disponible en este dispositivo.',
    'annual': 'ANUAL',
    'monthly': 'MENSUAL',
    'restore': 'RESTAURAR COMPRAS',
    'logout': 'CERRAR SESIÓN',
    'identityLastStep': 'Último paso: verifica tu identidad',
    'identityBody': 'Para vincular los certificados a un Creator real, SIGILLUM utiliza Stripe Identity. El proceso requiere un documento de identidad válido y una comprobación mediante selfie. Los documentos se gestionan a través de Stripe; SIGILLUM conserva el estado de verificación y los datos técnicos mínimos necesarios.',
    'verifyIdentity': 'VERIFICAR IDENTIDAD',
    'checkIdentity': 'HE TERMINADO — COMPROBAR ESTADO',
    'privacyIdentity': 'PRIVACIDAD E INFORMACIÓN SOBRE LA VERIFICACIÓN',
    'validationAccount': 'Introduce tu nombre, un email válido y una contraseña de al menos 12 caracteres.',
    'validationConfirmations': 'Completa las tres confirmaciones para crear una cuenta Creator.',
    'codeSent': 'Te hemos enviado un código de 6 dígitos.',
    'enterSix': 'Introduce el código de 6 dígitos.',
    'emailNotVerified': 'El email aún no está verificado. Te hemos enviado un nuevo código.',
    'recoverySent': 'Código de recuperación enviado. Introdúcelo abajo.',
    'newPasswordShort': 'La nueva contraseña debe contener al menos 12 caracteres.',
    'passwordUpdated': 'Contraseña actualizada. Ya puedes acceder.',
    'kycLinkMissing': 'El enlace de verificación de identidad no está disponible.',
    'kycOpenFailed': 'No se puede abrir la verificación de identidad.',
    'kycCompleteReturn': 'Completa la verificación y vuelve a SIGILLUM.',
    'kycStillRunning': 'La verificación sigue en curso',
    'kycServerConfirm': 'La verificación de identidad debe ser confirmada por el servidor antes de certificar.',
    'kycSyncFailed': 'No se puede sincronizar la verificación de identidad',
    'storeError': 'App Store no disponible',
    'checkingSubscription': 'Verificando la suscripción con App Store...',
    'subscriptionInactive': 'La suscripción no está activa en el servidor.',
    'subscriptionVerified': 'Suscripción verificada.',
    'subscriptionFailed': 'Error al verificar la suscripción',
    'purchaseFailed': 'Compra no completada.',
    'openResourceFailed': 'No se puede abrir este recurso.',
  },
  'ru': {
    'landingSubtitle': 'Бесплатно проверяйте сертифицированный контент или станьте верифицированным Creator.',
    'verifyFree': 'ПРОВЕРИТЬ КОНТЕНТ — БЕСПЛАТНО',
    'becomeCreator': 'СТАТЬ CREATOR',
    'privacyTermsInfo': 'Конфиденциальность, Условия и информация',
    'recoverAccount': 'Восстановление аккаунта',
    'loginCreator': 'Войти в аккаунт Creator',
    'createCreator': 'Создать аккаунт Creator',
    'name': 'Имя',
    'password': 'Пароль',
    'passwordHint': 'Не менее 12 символов',
    'receivedCode': 'Полученный код (оставьте пустым, чтобы отправить)',
    'newPassword': 'Новый пароль',
    'acceptTerms': 'Я принимаю Условия использования SIGILLUM',
    'ackPrivacy': 'Я ознакомился с Политикой конфиденциальности SIGILLUM',
    'adult': 'Подтверждаю, что мне исполнилось 18 лет',
    'readPrivacyTerms': 'ПРОЧИТАТЬ ПОЛИТИКУ И УСЛОВИЯ',
    'sendCode': 'ОТПРАВИТЬ КОД',
    'resetPassword': 'СБРОСИТЬ ПАРОЛЬ',
    'login': 'ВОЙТИ',
    'createAccount': 'СОЗДАТЬ АККАУНТ',
    'noAccount': 'Нет аккаунта? СОЗДАТЬ АККАУНТ',
    'haveAccount': 'Уже есть аккаунт? ВОЙТИ',
    'forgotPassword': 'ЗАБЫЛИ ПАРОЛЬ?',
    'backToLogin': 'НАЗАД К ВХОДУ',
    'back': 'НАЗАД',
    'verifyEmailTitle': 'Подтвердите адрес электронной почты',
    'sentCodeTo': 'Мы отправили код на',
    'sixDigitCode': '6-значный код',
    'confirmEmail': 'ПОДТВЕРДИТЬ EMAIL',
    'newCode': 'ОТПРАВИТЬ НОВЫЙ КОД',
    'activateCreator': 'Активировать SIGILLUM Creator',
    'featureCert': 'Сертификация фото, видео и текста',
    'featureIdentity': 'Подтверждённая личность',
    'featureRegistry': 'Registry HCV и публичная проверка',
    'featurePack': 'HCVPACK и дополнительные координаты',
    'productsMissing': 'Продукты App Store ещё не настроены для этого тестового аккаунта.',
    'storeUnavailable': 'App Store недоступен на этом устройстве.',
    'annual': 'ГОДОВАЯ',
    'monthly': 'МЕСЯЧНАЯ',
    'restore': 'ВОССТАНОВИТЬ ПОКУПКИ',
    'logout': 'ВЫЙТИ ИЗ АККАУНТА',
    'identityLastStep': 'Последний шаг: подтвердите личность',
    'identityBody': 'Чтобы связать сертификаты с реальным Creator, SIGILLUM использует Stripe Identity. Процедура требует действительного документа и проверки селфи. Документы обрабатываются через Stripe; SIGILLUM хранит статус проверки и минимально необходимые технические данные.',
    'verifyIdentity': 'ПОДТВЕРДИТЬ ЛИЧНОСТЬ',
    'checkIdentity': 'ЗАВЕРШЕНО — ПРОВЕРИТЬ СТАТУС',
    'privacyIdentity': 'КОНФИДЕНЦИАЛЬНОСТЬ И ИНФОРМАЦИЯ О ПРОВЕРКЕ',
    'validationAccount': 'Введите имя, корректный email и пароль длиной не менее 12 символов.',
    'validationConfirmations': 'Для создания аккаунта Creator выполните все три подтверждения.',
    'codeSent': 'Мы отправили вам 6-значный код.',
    'enterSix': 'Введите 6-значный код.',
    'emailNotVerified': 'Email ещё не подтверждён. Мы отправили новый код.',
    'recoverySent': 'Код восстановления отправлен. Введите его ниже.',
    'newPasswordShort': 'Новый пароль должен содержать не менее 12 символов.',
    'passwordUpdated': 'Пароль обновлён. Теперь можно войти.',
    'kycLinkMissing': 'Ссылка для проверки личности недоступна.',
    'kycOpenFailed': 'Не удалось открыть проверку личности.',
    'kycCompleteReturn': 'Завершите проверку и вернитесь в SIGILLUM.',
    'kycStillRunning': 'Проверка ещё выполняется',
    'kycServerConfirm': 'Перед сертификацией сервер должен подтвердить проверку личности.',
    'kycSyncFailed': 'Не удалось синхронизировать проверку личности',
    'storeError': 'App Store недоступен',
    'checkingSubscription': 'Проверка подписки через App Store...',
    'subscriptionInactive': 'Подписка не активна на сервере.',
    'subscriptionVerified': 'Подписка подтверждена.',
    'subscriptionFailed': 'Ошибка проверки подписки',
    'purchaseFailed': 'Покупка не завершена.',
    'openResourceFailed': 'Не удалось открыть ресурс.',
  },
};
'''

if 'const _commercialGateCopy' not in gate:
    gate = replace_once(
        gate,
        "enum _GateStage {\n",
        copy_block + "\nenum _GateStage {\n",
        'gate translation block',
    )

state_anchor = "  String _message = '';\n  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;\n"
state_new = "  String _message = '';\n  String _languageCode = SigillumCopy.initialLanguageCode();\n  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;\n"
if '_languageCode = SigillumCopy.initialLanguageCode()' not in gate:
    gate = replace_once(gate, state_anchor, state_new, 'gate language state')

bootstrap_anchor = "  Future<void> _bootstrap() async {\n    try {\n"
bootstrap_new = "  Future<void> _bootstrap() async {\n    await _loadLanguage();\n    try {\n"
if 'await _loadLanguage();' not in gate:
    gate = replace_once(gate, bootstrap_anchor, bootstrap_new, 'gate bootstrap language')

helpers = r'''
  String _t(String key) =>
      (_commercialGateCopy[_languageCode] ?? _commercialGateCopy['en']!)[key] ??
      _commercialGateCopy['en']![key] ??
      key;

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('sigillum_language');
    final resolved = saved == null || saved.isEmpty
        ? SigillumCopy.initialLanguageCode()
        : SigillumCopy.language(saved).code;
    if (!mounted) return;
    setState(() => _languageCode = resolved);
  }

  Future<void> _setLanguage(String code) async {
    final resolved = SigillumCopy.language(code).code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sigillum_language', resolved);
    if (!mounted) return;
    setState(() {
      _languageCode = resolved;
      _message = '';
    });
  }

  Widget _languageSelector() {
    final language = SigillumCopy.language(_languageCode);
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<String>(
        tooltip: language.name,
        initialValue: _languageCode,
        onSelected: _setLanguage,
        itemBuilder: (context) => [
          for (final item in SigillumCopy.languages)
            PopupMenuItem(value: item.code, child: Text(item.name)),
        ],
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x667E9189)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            language.shortName,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  String _localizedError(Object error) {
    if (error is CommercialAccountException) {
      const codeToKey = <String, String>{
        'EMAIL_NON_VALIDA': 'validationAccount',
        'PASSWORD_NON_VALIDA': 'validationAccount',
        'NUOVA_PASSWORD_NON_VALIDA': 'newPasswordShort',
        'TERMINI_NON_ACCETTATI': 'validationConfirmations',
        'MAGGIORENNE_RICHIESTO': 'validationConfirmations',
        'EMAIL_NON_VERIFICATA': 'emailNotVerified',
        'ABBONAMENTO_NON_ATTIVO': 'subscriptionInactive',
      };
      final key = error.code == null ? null : codeToKey[error.code!];
      if (key != null) return _t(key);
    }
    return error.toString();
  }

'''
if 'Widget _languageSelector()' not in gate:
    gate = replace_once(
        gate,
        "  Future<void> _bootstrap() async {\n",
        helpers + "  Future<void> _bootstrap() async {\n",
        'gate helper insertion',
    )

# Localized dynamic messages / functional propagation.
replacements = {
    "_message =\n                'La verifica identità deve essere confermata dal server prima di certificare.';": "_message = _t('kycServerConfirm');",
    "_message = 'Impossibile sincronizzare la verifica identità: $error';": "_message = \"${_t('kycSyncFailed')}: $error\";",
    "_message = 'App Store non disponibile: $error';": "_message = \"${_t('storeError')}: $error\";",
    "_message = 'Verifica abbonamento con App Store...';": "_message = _t('checkingSubscription');",
    "'L’abbonamento non risulta attivo sul server.'": "_t('subscriptionInactive')",
    "setState(() => _message = 'Abbonamento verificato.');": "setState(() => _message = _t('subscriptionVerified'));",
    "() => _message = 'Verifica abbonamento non riuscita: $error'": "() => _message = \"${_t('subscriptionFailed')}: $error\"",
    "purchase.error?.message ?? 'Acquisto non completato.'": "purchase.error?.message ?? _t('purchaseFailed')",
    "if (mounted) setState(() => _message = error.toString());": "if (mounted) setState(() => _message = _localizedError(error));",
    "'Inserisci nome, email valida e una password di almeno 12 caratteri.'": "_t('validationAccount')",
    "'Per creare un account Creator devi completare le tre conferme richieste.'": "_t('validationConfirmations')",
    "adultConfirmed: _adult,\n      );": "adultConfirmed: _adult,\n        languageCode: _languageCode,\n      );",
    "_message = 'Ti abbiamo inviato un codice di 6 cifre.';": "_message = _t('codeSent');",
    "setState(() => _message = 'Inserisci il codice di 6 cifre.');": "setState(() => _message = _t('enterSix'));",
    "await _account.resendEmailCode(_email.text);": "await _account.resendEmailCode(_email.text, languageCode: _languageCode);",
    "'Email non ancora verificata. Ti abbiamo inviato un nuovo codice.'": "_t('emailNotVerified')",
    "await _account.forgotPassword(_email.text);": "await _account.forgotPassword(_email.text, languageCode: _languageCode);",
    "_message = 'Codice di recupero inviato. Inseriscilo qui sotto.'": "_message = _t('recoverySent')",
    "'La nuova password deve contenere almeno 12 caratteri.'": "_t('newPasswordShort')",
    "_message = 'Password aggiornata. Ora puoi accedere.';": "_message = _t('passwordUpdated');",
    "throw StateError('Link di verifica identità non disponibile.');": "throw StateError(_t('kycLinkMissing'));",
    "throw StateError('Impossibile aprire la verifica identità.');": "throw StateError(_t('kycOpenFailed'));",
    "() => _message = 'Completa la verifica e poi torna in SIGILLUM.'": "() => _message = _t('kycCompleteReturn')",
    "'Verifica ancora in corso: ${result['status'] ?? 'unknown'}'": "\"${_t('kycStillRunning')}: ${result['status'] ?? 'unknown'}\"",
    "MaterialPageRoute(builder: (_) => const ImportPage(languageCode: 'it'))": "MaterialPageRoute(builder: (_) => ImportPage(languageCode: _languageCode))",
    "builder: (_) => const LegalInfoPage(languageCode: 'it')": "builder: (_) => LegalInfoPage(languageCode: _languageCode)",
}
for old, new in replacements.items():
    if old in gate:
        gate = gate.replace(old, new)

# Registration service parameter should be present exactly once after patching.
if 'languageCode: _languageCode' not in gate:
    raise RuntimeError('gate registration language propagation missing')

# Make the language selector visible from the very first interactive screen.
brand_anchor = "  Widget _brand({String? subtitle}) {\n    return Column(\n      children: [\n        Container("
brand_new = "  Widget _brand({String? subtitle}) {\n    return Column(\n      children: [\n        _languageSelector(),\n        const SizedBox(height: 14),\n        Container("
if '_languageSelector(),\n        const SizedBox(height: 14),' not in gate:
    gate = replace_once(gate, brand_anchor, brand_new, 'gate first-page language selector')

# Static UI strings.
ui_replacements = {
    "'Verifica gratuitamente contenuti certificati oppure diventa un Creator verificato.'": "_t('landingSubtitle')",
    "const Text('VERIFICA CONTENUTO — GRATIS')": "Text(_t('verifyFree'))",
    "const Text('DIVENTA CREATOR')": "Text(_t('becomeCreator'))",
    "const Text('Privacy, Termini e informazioni')": "Text(_t('privacyTermsInfo'))",
    "'Recupera il tuo account'": "_t('recoverAccount')",
    "'Accedi al tuo account Creator'": "_t('loginCreator')",
    "'Crea il tuo account Creator'": "_t('createCreator')",
    "labelText: 'Nome'": "labelText: _t('name')",
    "labelText: 'Password'": "labelText: _t('password')",
    "helperText: 'Almeno 12 caratteri'": "helperText: _t('passwordHint')",
    "labelText: 'Codice ricevuto (lascia vuoto per inviarlo)'": "labelText: _t('receivedCode')",
    "labelText: 'Nuova password'": "labelText: _t('newPassword')",
    "const Text('Accetto i Termini di Servizio')": "Text(_t('acceptTerms'))",
    "const Text('Ho preso visione dell’Informativa Privacy')": "Text(_t('ackPrivacy'))",
    "const Text('Confermo di avere almeno 18 anni')": "Text(_t('adult'))",
    "const Text('LEGGI PRIVACY E TERMINI')": "Text(_t('readPrivacyTerms'))",
    "'INVIA CODICE'": "_t('sendCode')",
    "'REIMPOSTA PASSWORD'": "_t('resetPassword')",
    "'ACCEDI'": "_t('login')",
    "'CREA ACCOUNT'": "_t('createAccount')",
    "'Non hai un account? CREA ACCOUNT'": "_t('noAccount')",
    "'Hai già un account? ACCEDI'": "_t('haveAccount')",
    "const Text('PASSWORD DIMENTICATA?')": "Text(_t('forgotPassword'))",
    "const Text('TORNA ALL’ACCESSO')": "Text(_t('backToLogin'))",
    "const Text('INDIETRO')": "Text(_t('back'))",
    "'Verifica il tuo indirizzo email'": "_t('verifyEmailTitle')",
    "Text('Abbiamo inviato un codice a ${_email.text}.'": "Text(\"${_t('sentCodeTo')} ${_email.text}.\"",
    "labelText: 'Codice di 6 cifre'": "labelText: _t('sixDigitCode')",
    "const Text('CONFERMA EMAIL')": "Text(_t('confirmEmail'))",
    "const Text('INVIA NUOVO CODICE')": "Text(_t('newCode'))",
    "'Attiva SIGILLUM Creator'": "_t('activateCreator')",
    "const _Feature(text: 'Certificazione foto, video e testo')": "_Feature(text: _t('featureCert'))",
    "const _Feature(text: 'Identità verificata')": "_Feature(text: _t('featureIdentity'))",
    "const _Feature(text: 'Registry HCV e verifica pubblica')": "_Feature(text: _t('featureRegistry'))",
    "const _Feature(text: 'HCVPACK e coordinate opzionali')": "_Feature(text: _t('featurePack'))",
    "'I prodotti App Store non sono ancora configurati per questo account di test.'": "_t('productsMissing')",
    "'App Store non disponibile su questo dispositivo.'": "_t('storeUnavailable')",
    "'ANNUALE'": "_t('annual')",
    "'MENSILE'": "_t('monthly')",
    "const Text('RIPRISTINA ACQUISTI')": "Text(_t('restore'))",
    "const Text('ESCI DALL’ACCOUNT')": "Text(_t('logout'))",
    "'Ultimo passaggio: verifica la tua identità'": "_t('identityLastStep')",
    "const Text(\n          'Per associare i certificati a un Creator reale, SIGILLUM utilizza Stripe Identity. La procedura richiede un documento valido e un controllo selfie. I documenti vengono gestiti tramite Stripe; SIGILLUM conserva lo stato della verifica e i dati tecnici minimi necessari.',": "Text(\n          _t('identityBody'),",
    "const Text('VERIFICA IDENTITÀ')": "Text(_t('verifyIdentity'))",
    "const Text('HO COMPLETATO — CONTROLLA STATO')": "Text(_t('checkIdentity'))",
    "const Text('PRIVACY E INFORMAZIONI SULLA VERIFICA')": "Text(_t('privacyIdentity'))",
}
for old, new in ui_replacements.items():
    gate = gate.replace(old, new)

# Resend button call can also appear in the email-verification view.
gate = gate.replace(
    "_account.resendEmailCode(_email.text)",
    "_account.resendEmailCode(_email.text, languageCode: _languageCode)",
)

for forbidden in [
    "const ImportPage(languageCode: 'it')",
    "const LegalInfoPage(languageCode: 'it')",
]:
    if forbidden in gate:
        raise RuntimeError(f'hardcoded Italian route remains: {forbidden}')

for required in [
    'SigillumCopy.initialLanguageCode()',
    "prefs.setString('sigillum_language'",
    'Widget _languageSelector()',
    'languageCode: _languageCode',
    "_t('landingSubtitle')",
]:
    if required not in gate:
        raise RuntimeError(f'localized commercial gate token missing: {required}')

write(gate_path, gate)


# ---------------------------------------------------------------------------
# Commercial account transport: carry selected language for legal acceptance
# and transactional emails. Server remains authoritative for versions/hashes.
# ---------------------------------------------------------------------------
account_path = 'lib/commercial_account_service.dart'
account = read(account_path)
account = account.replace("static const termsVersion = '2026-08-11';", "static const termsVersion = '2026-08-18';")
account = account.replace("static const privacyVersion = '2026-08-11';", "static const privacyVersion = '2026-08-18';")

account = replace_once(
    account,
    "    required bool acknowledgePrivacy,\n    required bool adultConfirmed,\n  }) async {",
    "    required bool acknowledgePrivacy,\n    required bool adultConfirmed,\n    required String languageCode,\n  }) async {",
    'register language argument',
)
account = replace_once(
    account,
    "        'adultConfirmed': adultConfirmed,\n        'termsVersion': termsVersion,",
    "        'adultConfirmed': adultConfirmed,\n        'languageCode': languageCode,\n        'termsVersion': termsVersion,",
    'register language body',
)

account = replace_once(
    account,
    "  Future<void> resendEmailCode(String email) async {\n    await _request(\n      'POST',\n      '/api/auth/resend-email-code',\n      body: {'email': email.trim()},\n    );\n  }",
    "  Future<void> resendEmailCode(\n    String email, {\n    required String languageCode,\n  }) async {\n    await _request(\n      'POST',\n      '/api/auth/resend-email-code',\n      body: {'email': email.trim(), 'languageCode': languageCode},\n    );\n  }",
    'resend language body',
)
account = replace_once(
    account,
    "  Future<void> forgotPassword(String email) async {\n    await _request(\n      'POST',\n      '/api/auth/password/forgot',\n      body: {'email': email.trim()},\n    );\n  }",
    "  Future<void> forgotPassword(\n    String email, {\n    required String languageCode,\n  }) async {\n    await _request(\n      'POST',\n      '/api/auth/password/forgot',\n      body: {'email': email.trim(), 'languageCode': languageCode},\n    );\n  }",
    'forgot language body',
)
for required in ["'languageCode': languageCode", "termsVersion = '2026-08-18'", "privacyVersion = '2026-08-18'"]:
    if required not in account:
        raise RuntimeError(f'commercial account localization token missing: {required}')
write(account_path, account)


# ---------------------------------------------------------------------------
# Legal links: propagate the selected language to every web legal page.
# Support becomes a real localized page instead of a hard-coded mailto action.
# ---------------------------------------------------------------------------
legal_path = 'lib/legal_info_page.dart'
legal = read(legal_path)
old_urls = """  static String get privacyUrl => '$_apiBase/privacy';
  static String get termsUrl => '$_apiBase/terms';
  static const supportUrl = 'mailto:marcelloorizio@legalmail.it';
  static String get deleteDataUrl => '$_apiBase/delete-data';

  final String languageCode;
"""
new_urls = """  final String languageCode;

  String get _encodedLanguage => Uri.encodeQueryComponent(languageCode);
  String get privacyUrl => '$_apiBase/privacy?lang=$_encodedLanguage';
  String get termsUrl => '$_apiBase/terms?lang=$_encodedLanguage';
  String get supportUrl => '$_apiBase/support?lang=$_encodedLanguage';
  String get deleteDataUrl => '$_apiBase/delete-data?lang=$_encodedLanguage';
"""
if "privacy?lang=$_encodedLanguage" not in legal:
    legal = replace_once(legal, old_urls, new_urls, 'legal localized URLs')

# Remove duplicate final languageCode if a formatting variant left it behind.
legal = legal.replace("\n  final String languageCode;\n\n  String _t", "\n\n  String _t", 1) if legal.count('final String languageCode;') > 1 else legal

for required in ['/privacy?lang=', '/terms?lang=', '/support?lang=', '/delete-data?lang=']:
    if required not in legal:
        raise RuntimeError(f'localized legal URL missing: {required}')
write(legal_path, legal)


# ---------------------------------------------------------------------------
# Profile page: add Spanish and Russian copy without changing profile logic.
# ---------------------------------------------------------------------------
profile_path = 'lib/commercial_profile_page.dart'
profile = read(profile_path)
extra_profile = r'''
  static const Map<String, Map<String, String>> _extraCopy = {
    'es': {
      'title': 'Cuenta', 'identity': 'Identidad', 'verified': 'Verificada',
      'notVerified': 'No verificada', 'subscription': 'Suscripción',
      'active': 'Activa', 'inactive': 'Inactiva', 'profile': 'Perfil',
      'name': 'Nombre', 'email': 'Email', 'language': 'Idioma',
      'save': 'GUARDAR PERFIL', 'security': 'Seguridad',
      'devices': 'DISPOSITIVOS CONECTADOS', 'password': 'CAMBIAR CONTRASEÑA',
      'manageSubscription': 'GESTIONAR SUSCRIPCIÓN',
      'privacy': 'Privacidad y condiciones',
      'legal': 'PRIVACIDAD, TÉRMINOS E INFORMACIÓN',
      'logout': 'CERRAR SESIÓN', 'delete': 'ELIMINAR CUENTA',
      'currentPassword': 'Contraseña actual', 'newPassword': 'Nueva contraseña',
      'cancel': 'CANCELAR', 'confirm': 'CONFIRMAR',
      'deleteTitle': 'Eliminar cuenta',
      'deleteBody': 'Introduce tu contraseña para eliminar definitivamente la cuenta. Los registros técnicos de certificados ya emitidos pueden permanecer minimizados para preservar su verificabilidad.',
      'saved': 'Perfil actualizado.', 'passwordChanged': 'Contraseña actualizada.',
      'noDevices': 'No hay dispositivos disponibles.',
      'thisDevice': 'Este dispositivo', 'lastSeen': 'Último acceso',
    },
    'ru': {
      'title': 'Аккаунт', 'identity': 'Личность', 'verified': 'Подтверждена',
      'notVerified': 'Не подтверждена', 'subscription': 'Подписка',
      'active': 'Активна', 'inactive': 'Неактивна', 'profile': 'Профиль',
      'name': 'Имя', 'email': 'Email', 'language': 'Язык',
      'save': 'СОХРАНИТЬ ПРОФИЛЬ', 'security': 'Безопасность',
      'devices': 'ПОДКЛЮЧЁННЫЕ УСТРОЙСТВА', 'password': 'ИЗМЕНИТЬ ПАРОЛЬ',
      'manageSubscription': 'УПРАВЛЕНИЕ ПОДПИСКОЙ',
      'privacy': 'Конфиденциальность и условия',
      'legal': 'КОНФИДЕНЦИАЛЬНОСТЬ, УСЛОВИЯ И ИНФОРМАЦИЯ',
      'logout': 'ВЫЙТИ ИЗ АККАУНТА', 'delete': 'УДАЛИТЬ АККАУНТ',
      'currentPassword': 'Текущий пароль', 'newPassword': 'Новый пароль',
      'cancel': 'ОТМЕНА', 'confirm': 'ПОДТВЕРДИТЬ',
      'deleteTitle': 'Удалить аккаунт',
      'deleteBody': 'Введите пароль, чтобы окончательно удалить аккаунт. Технические записи уже выпущенных сертификатов могут сохраняться в минимизированном виде для поддержания возможности проверки.',
      'saved': 'Профиль обновлён.', 'passwordChanged': 'Пароль обновлён.',
      'noDevices': 'Нет доступных устройств.',
      'thisDevice': 'Это устройство', 'lastSeen': 'Последний вход',
    },
  };

'''
old_t = """  String _t(String key) =>
      (_copy[_languageCode] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;
"""
new_t = extra_profile + """  String _t(String key) =>
      (_copy[_languageCode] ?? _extraCopy[_languageCode] ?? _copy['en']!)[key] ??
      _copy['en']![key] ??
      key;
"""
if '_extraCopy' not in profile:
    profile = replace_once(profile, old_t, new_t, 'profile ES/RU copy')
if "'es':" not in profile or "'ru':" not in profile:
    raise RuntimeError('profile Spanish/Russian localization missing')
write(profile_path, profile)

print('Applied isolated SIGILLUM multilingual onboarding/legal patch; HCV engine untouched')
