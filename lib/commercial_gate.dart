import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'commercial_account_service.dart';
import 'commercial_billing_service.dart';
import 'hcv_identity.dart';
import 'import_page.dart';
import 'legal_info_page.dart';
import 'sigillum_localization.dart';
import 'recent_account_service.dart';
import 'sigillum_quick_guide_page.dart';
import 'sigillum_theme.dart';
import 'user_home_page.dart';

class CommercialGate extends StatefulWidget {
  const CommercialGate({super.key});

  @override
  State<CommercialGate> createState() => _CommercialGateState();
}

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
    'weekly': '7 GIORNI',
    'restore': 'RIPRISTINA ACQUISTI',
    'logout': 'ESCI DALL’ACCOUNT',
    'identityLastStep': 'Ultimo passaggio: verifica la tua identità',
    'identityBody': 'Per associare i certificati a un Creator reale, SIGILLUM utilizza Stripe Identity. La procedura richiede un documento valido e un controllo selfie. I documenti vengono gestiti tramite Stripe; SIGILLUM conserva lo stato della verifica e i dati tecnici minimi necessari.',
    'verifyIdentity': 'VERIFICA IDENTITÀ',
    'checkIdentity': 'HO COMPLETATO — CONTROLLA STATO',
    'privacyIdentity': 'PRIVACY E INFORMAZIONI SULLA VERIFICA',
    'validationAccount':
        'Inserisci nome, email valida e una password di almeno 12 caratteri.',
    'validationConfirmations': 'Per creare un account Creator devi completare le tre conferme richieste.',
    'codeSent': 'Ti abbiamo inviato un codice di 6 cifre.',
    'enterSix': 'Inserisci il codice di 6 cifre.',
    'emailNotVerified':
        'Email non ancora verificata. Ti abbiamo inviato un nuovo codice.',
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
    'landingSubtitle':
        'Verify certified content for free or become a verified Creator.',
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
    'productsMissing':
        'App Store products are not yet configured for this test account.',
    'storeUnavailable': 'App Store is unavailable on this device.',
    'annual': 'ANNUAL',
    'monthly': 'MONTHLY',
    'weekly': '7 DAYS',
    'restore': 'RESTORE PURCHASES',
    'logout': 'LOG OUT',
    'identityLastStep': 'Final step: verify your identity',
    'identityBody': 'To link certificates to a real Creator, SIGILLUM uses Stripe Identity. The process requires a valid identity document and a selfie check. Documents are handled through Stripe; SIGILLUM stores the verification status and the minimum technical data required.',
    'verifyIdentity': 'VERIFY IDENTITY',
    'checkIdentity': 'COMPLETED — CHECK STATUS',
    'privacyIdentity': 'PRIVACY AND IDENTITY VERIFICATION INFORMATION',
    'validationAccount': 'Enter your name, a valid email address and a password of at least 12 characters.',
    'validationConfirmations':
        'Complete all three confirmations to create a Creator account.',
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
    'weekly': '7 DÍAS',
    'restore': 'RESTAURAR COMPRAS',
    'logout': 'CERRAR SESIÓN',
    'identityLastStep': 'Último paso: verifica tu identidad',
    'identityBody': 'Para vincular los certificados a un Creator real, SIGILLUM utiliza Stripe Identity. El proceso requiere un documento de identidad válido y una comprobación mediante selfie. Los documentos se gestionan a través de Stripe; SIGILLUM conserva el estado de verificación y los datos técnicos mínimos necesarios.',
    'verifyIdentity': 'VERIFICAR IDENTIDAD',
    'checkIdentity': 'HE TERMINADO — COMPROBAR ESTADO',
    'privacyIdentity': 'PRIVACIDAD E INFORMACIÓN SOBRE LA VERIFICACIÓN',
    'validationAccount': 'Introduce tu nombre, un email válido y una contraseña de al menos 12 caracteres.',
    'validationConfirmations':
        'Completa las tres confirmaciones para crear una cuenta Creator.',
    'codeSent': 'Te hemos enviado un código de 6 dígitos.',
    'enterSix': 'Introduce el código de 6 dígitos.',
    'emailNotVerified':
        'El email aún no está verificado. Te hemos enviado un nuevo código.',
    'recoverySent': 'Código de recuperación enviado. Introdúcelo abajo.',
    'newPasswordShort':
        'La nueva contraseña debe contener al menos 12 caracteres.',
    'passwordUpdated': 'Contraseña actualizada. Ya puedes acceder.',
    'kycLinkMissing':
        'El enlace de verificación de identidad no está disponible.',
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
    'productsMissing':
        'Продукты App Store ещё не настроены для этого тестового аккаунта.',
    'storeUnavailable': 'App Store недоступен на этом устройстве.',
    'annual': 'ГОДОВАЯ',
    'monthly': 'МЕСЯЧНАЯ',
    'weekly': '7 ДНЕЙ',
    'restore': 'ВОССТАНОВИТЬ ПОКУПКИ',
    'logout': 'ВЫЙТИ ИЗ АККАУНТА',
    'identityLastStep': 'Последний шаг: подтвердите личность',
    'identityBody': 'Чтобы связать сертификаты с реальным Creator, SIGILLUM использует Stripe Identity. Процедура требует действительного документа и проверки селфи. Документы обрабатываются через Stripe; SIGILLUM хранит статус проверки и минимально необходимые технические данные.',
    'verifyIdentity': 'ПОДТВЕРДИТЬ ЛИЧНОСТЬ',
    'checkIdentity': 'ЗАВЕРШЕНО — ПРОВЕРИТЬ СТАТУС',
    'privacyIdentity': 'КОНФИДЕНЦИАЛЬНОСТЬ И ИНФОРМАЦИЯ О ПРОВЕРКЕ',
    'validationAccount':
        'Введите имя, корректный email и пароль длиной не менее 12 символов.',
    'validationConfirmations':
        'Для создания аккаунта Creator выполните все три подтверждения.',
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
    'kycServerConfirm':
        'Перед сертификацией сервер должен подтвердить проверку личности.',
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
    'heroSubtitle':
        'Verify the authenticity of digital content and share with confidence.',
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
    'trustSubtitle':
        'SIGILLUM hace que la web sea más transparente y verificable.',
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

enum _GateStage {
  loading,
  landing,
  auth,
  verifyEmail,
  billing,
  identity,
  creator,
}

class _CommercialGateState extends State<CommercialGate> {
  final CommercialAccountService _account = const CommercialAccountService();
  final RecentAccountService _recentAccountService =
      const RecentAccountService();
  List<String> _recentEmails = const [];
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();

  _GateStage _stage = _GateStage.loading;
  Map<String, dynamic> _accountData = const {};
  bool _busy = false;
  bool _loginMode = false;
  bool _forgotMode = false;
  bool _acceptTerms = false;
  bool _ackPrivacy = false;
  bool _adult = false;
  bool _obscure = true;
  bool _storeAvailable = false;
  List<ProductDetails> _products = const [];
  Map<String, String> _productDisplayPrices = const {};
  String _message = '';
  String _languageCode = SigillumCopy.initialLanguageCode();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  @override
  void initState() {
    super.initState();
    CommercialBillingService.instance.startListening();
    _purchaseSub = CommercialBillingService.instance.purchases.listen(
      _onPurchases,
    );
    Future.microtask(_loadRecentAccounts);
    _bootstrap();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _loadRecentAccounts() async {
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
        builder: (_) => SigillumQuickGuidePage(languageCode: _languageCode),
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

  String _t(String key) =>
      (_commercialGateCopy[_languageCode] ?? _commercialGateCopy['en']!)[key] ??
      _commercialGateCopy['en']![key] ??
      key;

  String _lv(String key) =>
      (_landingVisualCopy[_languageCode] ?? _landingVisualCopy['en']!)[key] ??
      _landingVisualCopy['en']![key] ??
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

  Future<void> _bootstrap() async {
    await _loadLanguage();
    try {
      final envelope = await _account.restoreAccount();
      if (!mounted) return;
      if (envelope == null) {
        setState(() => _stage = _GateStage.landing);
        return;
      }
      _applyEnvelope(envelope);
      await _routeAuthenticated(returnToLandingIfUnpaid: true);
    } catch (_) {
      if (mounted) setState(() => _stage = _GateStage.landing);
    }
  }

  void _applyEnvelope(Map<String, dynamic> envelope) {
    final raw = envelope['account'];
    if (raw is Map) {
      _accountData = Map<String, dynamic>.from(raw);
      _email.text = _accountData['email']?.toString() ?? _email.text;
      _name.text = _accountData['creatorName']?.toString() ?? _name.text;
    }
  }

  Future<void> _persistKycResult(Map<String, dynamic> result) async {
    final status = result['status']?.toString() ?? 'unknown';
    final sessionId = result['sessionId']?.toString() ?? '';
    final provider = result['provider']?.toString() ?? 'stripe_identity';
    final verificationLivemode = result['verificationLivemode'] == true;
    if (sessionId.isNotEmpty) {
      await HCVIdentity().saveKycSession(
        sessionId: sessionId,
        provider: provider,
        status: status,
      );
    }
    final rawOutputs = verificationLivemode ? result['verifiedOutputs'] : null;
    await HCVIdentity().saveKycStatus(
      status,
      verifiedOutputs: rawOutputs is Map
          ? Map<String, dynamic>.from(rawOutputs)
          : null,
    );
    if (mounted) {
      setState(() {
        _accountData = <String, dynamic>{..._accountData, 'kycStatus': status};
      });
    }
  }

  Future<bool> _recoverUnfinishedAppleTransactions() async {
    final unfinished = await CommercialBillingService.instance
        .unfinishedAppleTransactions();
    var entitlementActive = false;

    for (final transaction in unfinished) {
      final verified = await _account.verifyApplePurchase(
        productId: transaction.productId,
        transactionId: transaction.transactionId,
        receiptData: transaction.receiptData,
      );
      if (verified['verified'] != true) {
        throw CommercialAccountException(_t('subscriptionFailed'));
      }

      await CommercialBillingService.instance.finishUnfinishedAppleTransaction(
        transaction.transactionId,
      );

      final status = verified['status']?.toString() ?? 'inactive';
      if (status == 'active' || status == 'grace') {
        entitlementActive = true;
      }
    }

    return entitlementActive;
  }

  Future<void> _routeAuthenticated({
    bool returnToLandingIfUnpaid = false,
  }) async {
    final accountCreatorName =
        _accountData['creatorName']?.toString().trim() ?? '';
    if (accountCreatorName.isNotEmpty) {
      await HCVIdentity().saveCreatorName(accountCreatorName);
    }
    final verifiedEmail = _accountData['emailVerified'] == true;
    if (!verifiedEmail) {
      setState(() => _stage = _GateStage.verifyEmail);
      return;
    }

    Map<String, dynamic> billing = const {};
    try {
      billing = await _account.billingStatus();
    } catch (_) {}
    var serverStatus = billing['status']?.toString() ?? '';
    var serverActive = serverStatus == 'active' || serverStatus == 'grace';

    if (!serverActive) {
      try {
        final recoveredActive = await _recoverUnfinishedAppleTransactions();
        if (recoveredActive) {
          billing = await _account.billingStatus();
          serverStatus = billing['status']?.toString() ?? '';
          serverActive = serverStatus == 'active' || serverStatus == 'grace';
        }
      } catch (error) {
        _message = "${_t('subscriptionFailed')}: $error";
      }
    }

    if (!serverActive) {
      if (returnToLandingIfUnpaid) {
        if (mounted) setState(() => _stage = _GateStage.landing);
        return;
      }
      await _prepareBilling();
      if (mounted) setState(() => _stage = _GateStage.billing);
      return;
    }

    final kyc = _accountData['kycStatus']?.toString() ?? 'not_started';
    if (kyc != 'verified') {
      if (mounted) setState(() => _stage = _GateStage.identity);
      return;
    }

    try {
      final remoteKyc = await _account.refreshIdentityVerification();
      if (remoteKyc['status'] != 'verified') {
        if (mounted) {
          setState(() {
            _stage = _GateStage.identity;
            _message = _t('kycServerConfirm');
          });
        }
        return;
      }
      await _persistKycResult(remoteKyc);
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = _GateStage.identity;
          _message = "${_t('kycSyncFailed')}: $error";
        });
      }
      return;
    }

    if (mounted) setState(() => _stage = _GateStage.creator);
  }

  Future<void> _prepareBilling() async {
    try {
      _storeAvailable = await CommercialBillingService.instance.isAvailable();
      _products = _storeAvailable
          ? await CommercialBillingService.instance.loadProducts()
          : const [];
      _productDisplayPrices = _products.isEmpty
          ? const {}
          : await CommercialBillingService.instance
              .localizedDisplayPrices(_products);
      _productDisplayPrices = _products.isEmpty
          ? const {}
          : await CommercialBillingService.instance.localizedDisplayPrices(
              _products,
            );
    } catch (error) {
      _message = "${_t('storeError')}: $error";
      _products = const [];
      _productDisplayPrices = const {};
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!CommercialBillingService.productIds.contains(purchase.productID)) {
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (mounted) {
          setState(() {
            _busy = true;
            _message = _t('checkingSubscription');
          });
        }
        try {
          final verified = await _account.verifyApplePurchase(
            productId: purchase.productID,
            transactionId: purchase.purchaseID,
            receiptData: purchase.verificationData.serverVerificationData,
          );
          if (verified['verified'] != true) {
            throw CommercialAccountException(_t('subscriptionFailed'));
          }

          final status = verified['status']?.toString() ?? 'inactive';

          // StoreKit delivery lifecycle and entitlement are separate. Once
          // Apple authenticity is confirmed server-side, finish the StoreKit
          // transaction even when the subscription is expired or revoked.
          await CommercialBillingService.instance.completeVerifiedPurchase(
            purchase,
          );

          final entitlementActive = status == 'active' || status == 'grace';
          if (!entitlementActive) {
            if (mounted) {
              setState(() {
                _message = _t('subscriptionInactive');
              });
            }
            continue;
          }

          if (!mounted) return;
          setState(() {
            _message = _t('subscriptionVerified');
          });
          await _routeAuthenticated();
          return;
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _message = "${_t('subscriptionFailed')}: $error";
          });
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      }

      if (purchase.status == PurchaseStatus.error && mounted) {
        setState(() {
          _message = purchase.error?.message ?? _t('purchaseFailed');
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = _localizedError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    if (_name.text.trim().isEmpty ||
        !_email.text.contains('@') ||
        _password.text.length < 12) {
      setState(() => _message = _t('validationAccount'));
      return;
    }
    if (!_acceptTerms || !_ackPrivacy || !_adult) {
      setState(() => _message = _t('validationConfirmations'));
      return;
    }
    await _run(() async {
      try {
        await _account.register(
          email: _email.text,
          password: _password.text,
          creatorName: _name.text,
          acceptTerms: _acceptTerms,
          acknowledgePrivacy: _ackPrivacy,
          adultConfirmed: _adult,
          languageCode: _languageCode,
        );
      } on CommercialAccountException catch (error) {
        if (error.code != 'ACCOUNT_ESISTENTE') rethrow;
        if (!mounted) return;
        TextInput.finishAutofillContext(shouldSave: false);
        setState(() {
          _loginMode = true;
          _forgotMode = false;
          _password.clear();
          _message = 'Questa email è già associata a un account. Accedi oppure usa Password dimenticata.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _stage = _GateStage.verifyEmail;
        _message = _t('codeSent');
      });
    });
  }

  Future<void> _verifyEmail() async {
    if (_code.text.trim().length != 6) {
      setState(() => _message = _t('enterSix'));
      return;
    }
    await _run(() async {
      await _account.verifyEmail(email: _email.text, code: _code.text);
      final envelope = await _account.login(
        email: _email.text,
        password: _password.text,
      );
      _applyEnvelope(envelope);
      await _rememberCurrentEmail();
      TextInput.finishAutofillContext(shouldSave: true);
      await _routeAuthenticated();
    });
  }

  Future<void> _login() async {
    await _run(() async {
      try {
        final envelope = await _account.login(
          email: _email.text,
          password: _password.text,
        );
        _applyEnvelope(envelope);
        await _rememberCurrentEmail();
        TextInput.finishAutofillContext(shouldSave: true);
        await _routeAuthenticated();
      } on CommercialAccountException catch (error) {
        if (error.code == 'EMAIL_NON_VERIFICATA') {
          await _account.resendEmailCode(
            _email.text,
            languageCode: _languageCode,
          );
          if (!mounted) return;
          setState(() {
            _stage = _GateStage.verifyEmail;
            _message = _t('emailNotVerified');
          });
          return;
        }
        if (error.code == 'ACCOUNT_NON_TROVATO') {
          if (!mounted) return;
          TextInput.finishAutofillContext(shouldSave: false);
          setState(() {
            _loginMode = false;
            _forgotMode = false;
            _password.clear();
            _message = 'Non esiste un account con questa email. Puoi crearne uno nuovo.';
          });
          return;
        }
        rethrow;
      }
    });
  }

  Future<void> _forgot() async {
    await _run(() async {
      if (_code.text.trim().isEmpty) {
        await _account.forgotPassword(_email.text, languageCode: _languageCode);
        if (!mounted) return;
        setState(() => _message = _t('recoverySent'));
      } else {
        if (_newPassword.text.length < 12) {
          throw CommercialAccountException(_t('newPasswordShort'));
        }
        await _account.resetPassword(
          email: _email.text,
          code: _code.text,
          newPassword: _newPassword.text,
        );
        if (!mounted) return;
        final updatedPassword = _newPassword.text;
        TextInput.finishAutofillContext(shouldSave: true);
        setState(() {
          _forgotMode = false;
          _password.text = updatedPassword;
          _code.clear();
          _newPassword.clear();
          _message = _t('passwordUpdated');
        });
      }
    });
  }

  Future<void> _startKyc() async {
    await _run(() async {
      final result = await _account.startIdentityVerification();
      await _persistKycResult(result);
      final status = result['status']?.toString() ?? 'unknown';
      final url = result['url']?.toString() ?? '';
      if (status == 'verified') {
        await _refreshAfterKyc();
        return;
      }
      if (status == 'processing') {
        if (mounted) {
          setState(
            () => _message =
                'Verifica inviata a Stripe. Il controllo è in elaborazione.',
          );
        }
        return;
      }
      if (url.isEmpty) {
        throw StateError(
          'Link di verifica identità non disponibile per lo stato $status.',
        );
      }
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError(_t('kycOpenFailed'));
      if (mounted) {
        setState(
          () => _message = status == 'requires_input'
              ? 'Stripe richiede un ulteriore passaggio. Completa la verifica e poi torna in SIGILLUM.'
              : 'Completa la verifica e poi torna in SIGILLUM.',
        );
      }
    });
  }

  Future<void> _refreshAfterKyc() async {
    await _run(() async {
      final result = await _account.refreshIdentityVerification();
      await _persistKycResult(result);
      final status = result['status']?.toString() ?? 'unknown';
      if (status != 'verified') {
        if (mounted) {
          final text = switch (status) {
            'processing' =>
              'Verifica inviata a Stripe. Il controllo è in elaborazione.',
            'requires_input' => 'Stripe richiede un ulteriore passaggio per completare la verifica.',
            'canceled' =>
              'La verifica è stata annullata. Puoi avviare una nuova verifica.',
            _ => 'Stato verifica identità: $status',
          };
          setState(() => _message = text);
        }
        return;
      }
      final envelope = await _account.restoreAccount();
      if (envelope != null) {
        _applyEnvelope(envelope);
        final accountCreatorName =
            _accountData['creatorName']?.toString().trim() ?? '';
        if (result['verificationLivemode'] != true &&
            accountCreatorName.isNotEmpty) {
          await HCVIdentity().saveCreatorName(accountCreatorName);
        }
      }
      if (mounted) setState(() => _stage = _GateStage.creator);
    });
  }

  void _resetLoggedOutState() {
    if (!mounted) return;
    TextInput.finishAutofillContext(shouldSave: false);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    setState(() {
      _accountData = const {};
      _name.clear();
      _email.clear();
      _password.clear();
      _code.clear();
      _newPassword.clear();
      _loginMode = false;
      _forgotMode = false;
      _acceptTerms = false;
      _ackPrivacy = false;
      _adult = false;
      _obscure = true;
      _storeAvailable = false;
      _products = const [];
      _productDisplayPrices = const {};
      _message = '';
      _stage = _GateStage.landing;
    });
  }

  void _onSessionInvalidated() {
    _resetLoggedOutState();
  }

  Future<void> _logout() async {
    await _account.logout();
    _resetLoggedOutState();
  }

  void _openVerify() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportPage(languageCode: _languageCode),
      ),
    );
  }

  void _openLegal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalInfoPage(languageCode: _languageCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _GateStage.creator) {
      return UserHomePage(onSessionInvalidated: _onSessionInvalidated);
    }
    if (_stage == _GateStage.landing) {
      return Scaffold(body: _landing());
    }
    return AutofillGroup(
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9FA),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAFBFF), Color(0xFFFAF9FA), Color(0xFFF2ECFF)],
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

  Widget _content() {
    switch (_stage) {
      case _GateStage.loading:
        return const Center(child: CircularProgressIndicator());
      case _GateStage.landing:
        return _landing();
      case _GateStage.auth:
        return _auth();
      case _GateStage.verifyEmail:
        return _verifyEmailView();
      case _GateStage.billing:
        return _billing();
      case _GateStage.identity:
        return _identity();
      case _GateStage.creator:
        return const SizedBox.shrink();
    }
  }

  Widget _sigillumMark({double size = 58}) {
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
        _languageSelector(),
        const SizedBox(height: 14),
        Container(width: 0, height: 0),
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

  Widget _landing() {
    return Container(
      key: const ValueKey('landing-visual-v2'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: double.infinity),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAFBFF), Color(0xFFFAF9FA), Color(0xFFF2ECFF)],
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
                  _languageSelector(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _sigillumMark(size: 52),
                      const SizedBox(width: 11),
                      Expanded(
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
                              _lv('tagline'),
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
                        onPressed: _openQuickGuide,
                        tooltip: SigillumCopy.t(
                          _languageCode,
                          'quickGuideTooltip',
                        ),
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
                        TextSpan(text: _lv('welcomePrefix')),
                        TextSpan(
                          text: 'SIGILLUM!',
                          style: TextStyle(color: SigillumTheme.accentAlt),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _lv('heroSubtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                        Text(
                          _lv('verifySeconds'),
                          style: const TextStyle(
                            color: SigillumTheme.ink,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _lv('scanDescription'),
                          style: const TextStyle(
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
                                      colors: [
                                        Color(0xFFE8E0FF),
                                        Color(0xFFC6F5F8),
                                      ],
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
                          label: Text(_lv('verifyFree')),
                        ),
                        const SizedBox(height: 10),
                        Row(
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
                                _lv('secureFast'),
                                style: const TextStyle(
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
                    title: _lv('loginTitle'),
                    subtitle: _lv('loginSubtitle'),
                    accent: const Color(0xFF7645D9),
                    onTap: () => setState(() {
                      _loginMode = true;
                      _forgotMode = false;
                      _stage = _GateStage.auth;
                    }),
                  ),
                  const SizedBox(height: 11),
                  _landingAction(
                    icon: Icons.auto_awesome_rounded,
                    title: _lv('creatorTitle'),
                    subtitle: _lv('creatorSubtitle'),
                    accent: const Color(0xFFFFB237),
                    onTap: () => setState(() {
                      _loginMode = false;
                      _forgotMode = false;
                      _stage = _GateStage.auth;
                    }),
                  ),
                  const SizedBox(height: 11),
                  _landingAction(
                    icon: Icons.help_center_rounded,
                    title: SigillumCopy.t(_languageCode, 'quickGuideTitle'),
                    subtitle: SigillumCopy.t(
                      _languageCode,
                      'quickGuideSubtitle',
                    ),
                    accent: const Color(0xFF31D0AA),
                    onTap: _openQuickGuide,
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
                    child: Row(
                      children: [
                        const CircleAvatar(
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
                                _lv('trustTitle'),
                                style: const TextStyle(
                                  color: SigillumTheme.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                _lv('trustSubtitle'),
                                style: const TextStyle(
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
                        label: Text(_lv('privacy')),
                      ),
                      TextButton.icon(
                        onPressed: _openLegal,
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: Text(_lv('terms')),
                      ),
                      TextButton.icon(
                        onPressed: _openLegal,
                        icon: const Icon(Icons.support_agent_rounded, size: 18),
                        label: Text(_lv('support')),
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

  Widget _auth() {
    return Column(
      key: const ValueKey('auth'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(
          subtitle: _forgotMode
              ? _t('recoverAccount')
              : (_loginMode ? _t('loginCreator') : _t('createCreator')),
        ),
        const SizedBox(height: 24),
        if (!_loginMode && !_forgotMode) ...[
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: _t('name'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_loginMode && !_forgotMode && _recentEmails.isNotEmpty) ...[
          _recentAccountPicker(),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (!_forgotMode)
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: _loginMode
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: _t('password'),
              helperText: _t('passwordHint'),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        if (_forgotMode) ...[
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _t('receivedCode'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPassword,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: _t('newPassword'),
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (!_loginMode && !_forgotMode) ...[
          const SizedBox(height: 14),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptTerms,
            onChanged: _busy
                ? null
                : (v) => setState(() => _acceptTerms = v == true),
            title: Text(_t('acceptTerms')),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _ackPrivacy,
            onChanged: _busy
                ? null
                : (v) => setState(() => _ackPrivacy = v == true),
            title: Text(_t('ackPrivacy')),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _adult,
            onChanged: _busy ? null : (v) => setState(() => _adult = v == true),
            title: Text(_t('adult')),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          TextButton(
            onPressed: _openLegal,
            child: Text(_t('readPrivacyTerms')),
          ),
        ],
        const SizedBox(height: 10),
        if (_busy) const LinearProgressIndicator(),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SigillumTheme.accent),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy
              ? null
              : (_forgotMode ? _forgot : (_loginMode ? _login : _register)),
          child: Text(
            _forgotMode
                ? (_code.text.trim().isEmpty
                      ? _t('sendCode')
                      : _t('resetPassword'))
                : (_loginMode ? _t('login') : _t('createAccount')),
          ),
        ),
        if (!_forgotMode) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _loginMode = !_loginMode),
            child: Text(_loginMode ? _t('noAccount') : _t('haveAccount')),
          ),
          if (_loginMode)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _forgotMode = true),
              child: Text(_t('forgotPassword')),
            ),
        ] else
          TextButton(
            onPressed: _busy ? null : () => setState(() => _forgotMode = false),
            child: Text(_t('backToLogin')),
          ),
        TextButton(
          onPressed: () => setState(() => _stage = _GateStage.landing),
          child: Text(_t('back')),
        ),
      ],
    );
  }

  Widget _verifyEmailView() {
    return Column(
      key: const ValueKey('verify-email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(subtitle: _t('verifyEmailTitle')),
        const SizedBox(height: 22),
        Text(
          "${_t('sentCodeTo')} ${_email.text}.",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 8),
          decoration: InputDecoration(
            labelText: _t('sixDigitCode'),
            border: OutlineInputBorder(),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message.isNotEmpty)
          Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SigillumTheme.accent),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _verifyEmail,
          child: Text(_t('confirmEmail')),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => _account.resendEmailCode(
                    _email.text,
                    languageCode: _languageCode,
                  ),
                ),
          child: Text(_t('newCode')),
        ),
      ],
    );
  }

  String _creatorPlanLabel(ProductDetails product) {
    if (product.id == CommercialBillingService.weeklyProductId) {
      return _t('weekly');
    }
    if (product.id == CommercialBillingService.annualProductId) {
      return _t('annual');
    }
    return _t('monthly');
  }

  Widget _billing() {
    return Column(
      key: const ValueKey('billing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(subtitle: _t('activateCreator')),
        const SizedBox(height: 20),
        _Feature(text: _t('featureCert')),
        _Feature(text: _t('featureIdentity')),
        _Feature(text: _t('featureRegistry')),
        _Feature(text: _t('featurePack')),
        const SizedBox(height: 18),
        if (_email.text.trim().isNotEmpty)
          Text(
            'Account SIGILLUM: ${_email.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SigillumTheme.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 12),
        if (_products.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: SigillumTheme.muted),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _storeAvailable ? _t('productsMissing') : _t('storeUnavailable'),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final product in _products) ...[
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await CommercialBillingService.instance.purchase(product);
                    }),
              child: Text(
                '${_creatorPlanLabel(product)} — ${_productDisplayPrices[product.id] ?? product.price}',
              ),
            ),
            const SizedBox(height: 10),
          ],
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => CommercialBillingService.instance.restore(),
          child: Text(_t('restore')),
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SigillumTheme.accent),
            ),
          ),
        const SizedBox(height: 12),
        TextButton(onPressed: _logout, child: Text(_t('logout'))),
      ],
    );
  }

  Widget _identity() {
    final status = _accountData['kycStatus']?.toString() ?? 'not_started';
    final processing = status == 'processing';
    final requiresInput = status == 'requires_input';
    final canceled = status == 'canceled';
    final verified = status == 'verified';
    final actionLabel = verified
        ? 'IDENTITÀ VERIFICATA'
        : processing
        ? 'VERIFICA IN ELABORAZIONE'
        : requiresInput
        ? 'CONTINUA VERIFICA IDENTITÀ'
        : canceled
        ? 'RIPROVA VERIFICA IDENTITÀ'
        : 'VERIFICA IDENTITÀ';

    return Column(
      key: const ValueKey('identity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(subtitle: _t('identityLastStep')),
        const SizedBox(height: 22),
        Text(
          _t('identityBody'),
          textAlign: TextAlign.center,
          style: TextStyle(color: SigillumTheme.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy || processing || verified ? null : _startKyc,
          icon: const Icon(Icons.badge_outlined),
          label: Text(actionLabel),
        ),
        if (processing) ...[
          const SizedBox(height: 10),
          const Text(
            'La verifica è stata inviata a Stripe. Attendi l’esito prima di avviare altre procedure.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SigillumTheme.muted),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _busy ? null : _refreshAfterKyc,
          child: const Text('AGGIORNA STATO VERIFICA'),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SigillumTheme.accent),
            ),
          ),
        const SizedBox(height: 12),
        TextButton(onPressed: _openLegal, child: Text(_t('privacyIdentity'))),
        TextButton(onPressed: _logout, child: Text(_t('logout'))),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: SigillumTheme.verified),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
