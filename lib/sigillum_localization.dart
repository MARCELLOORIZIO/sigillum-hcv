import 'dart:ui';

class SigillumLanguage {
  const SigillumLanguage({
    required this.code,
    required this.name,
    required this.shortName,
  });

  final String code;
  final String name;
  final String shortName;
}

class SigillumCopy {
  static const languages = [
    SigillumLanguage(code: 'it', name: 'Italiano', shortName: 'IT'),
    SigillumLanguage(code: 'en', name: 'English', shortName: 'EN'),
    SigillumLanguage(code: 'es', name: 'Espanol', shortName: 'ES'),
    SigillumLanguage(code: 'ru', name: 'Русский', shortName: 'RU'),
  ];

  static String initialLanguageCode() {
    final localeCode = PlatformDispatcher.instance.locale.languageCode;
    return languages.any((language) => language.code == localeCode)
        ? localeCode
        : 'en';
  }

  static SigillumLanguage language(String code) {
    return languages.firstWhere(
      (language) => language.code == code,
      orElse: () => languages[1],
    );
  }

  static String t(String code, String key) {
    return (_copy[code] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;
  }

  static const _copy = {
    'it': {
      'identity': 'Identita',
      'headline': 'Prova tecnica per contenuti creati da persone reali.',
      'subtitle':
          'SIGILLUM collega foto, video e testi a HCV-ID, identita tecnica, impronta del file, certificato firmato e Registry online. Le modifiche restano rilevabili.',
      'certifyMediaTitle': 'Certifica foto o video',
      'certifyMediaSubtitle': 'Scatta o registra e crea il certificato HCV.',
      'certifyTextTitle': 'Certifica testo',
      'certifyTextSubtitle': 'Crea un testo verificabile con HCV-ID.',
      'verifyTitle': 'Verifica contenuto',
      'verifySubtitle': 'Apri file, HCVPACK o verifica dal Registry.',
      'infoTitle': 'Informazioni e privacy',
      'infoSubtitle': 'Controlli, limiti, termini e supporto.',
      'trustChain': 'Catena di controllo',
      'controls': 'Controlli SIGILLUM',
      'capture': 'Cattura',
      'captureText': 'creata nell app',
      'fingerprint': 'Impronta',
      'fingerprintText': 'hash del file',
      'identityStep': 'Identita',
      'identityText': 'creatore collegato',
      'signature': 'Firma',
      'signatureText': 'certificato protetto',
      'registry': 'Registry',
      'registryText': 'verifica online',
      'checkIntegrity': 'Integrita del file e coerenza con il certificato',
      'checkSignature': 'Firma digitale del certificato',
      'checkWatermark': 'Watermark visibile nel contenuto pubblicato',
      'checkRegistry': 'Registry online per verifica futura',
      'checkScreen': 'Controllo rischio ripresa da schermo',
      'checkSocial': 'Fingerprint per file ricompressi dai social',
      'legalPageTitle': 'Informazioni',
      'legalIntro':
          'SIGILLUM crea una prova tecnica verificabile che collega contenuto, HCV-ID, identita del creatore, impronta del file e Registry online.',
      'legalControls': 'Controlli eseguiti',
      'legalData': 'Dati trattati',
      'legalLimits': 'Limiti del servizio',
      'data1': 'contenuto creato o selezionato dall utente',
      'data2': 'HCV-ID e impronta crittografica del file',
      'data3': 'metadati tecnici necessari alla verifica',
      'data4': 'identita tecnica del creatore, se configurata',
      'limit1':
          'SIGILLUM verifica provenienza tecnica e integrita, non sostituisce una perizia legale.',
      'limit2':
          'Un avviso di rischio schermo indica cautela, non prova automatica di falso.',
      'limit3':
          'La verifica online richiede che il Registry sia raggiungibile.',
      'privacyPolicy': 'Privacy policy',
      'terms': 'Termini del servizio',
      'support': 'Supporto e cancellazione dati',
      'copied': 'Copiato',
    },
    'en': {
      'identity': 'Identity',
      'headline': 'Technical proof for content created by real people.',
      'subtitle':
          'SIGILLUM links photos, videos and text to an HCV-ID, technical identity, file fingerprint, signed certificate and online Registry. Changes remain detectable.',
      'certifyMediaTitle': 'Certify photo or video',
      'certifyMediaSubtitle':
          'Capture or record and create the HCV certificate.',
      'certifyTextTitle': 'Certify text',
      'certifyTextSubtitle': 'Create verifiable text with an HCV-ID.',
      'verifyTitle': 'Verify content',
      'verifySubtitle': 'Open a file, HCVPACK or verify from Registry.',
      'infoTitle': 'Information and privacy',
      'infoSubtitle': 'Checks, limits, terms and support.',
      'trustChain': 'Control chain',
      'controls': 'SIGILLUM checks',
      'capture': 'Capture',
      'captureText': 'created in app',
      'fingerprint': 'Fingerprint',
      'fingerprintText': 'file hash',
      'identityStep': 'Identity',
      'identityText': 'creator linked',
      'signature': 'Signature',
      'signatureText': 'protected certificate',
      'registry': 'Registry',
      'registryText': 'online verification',
      'checkIntegrity': 'File integrity and certificate consistency',
      'checkSignature': 'Digital certificate signature',
      'checkWatermark': 'Visible watermark in published content',
      'checkRegistry': 'Online Registry for future verification',
      'checkScreen': 'Screen replay risk check',
      'checkSocial': 'Fingerprint for social-media recompressed files',
      'legalPageTitle': 'Information',
      'legalIntro':
          'SIGILLUM creates verifiable technical proof linking content, HCV-ID, creator identity, file fingerprint and online Registry.',
      'legalControls': 'Checks performed',
      'legalData': 'Data processed',
      'legalLimits': 'Service limits',
      'data1': 'content created or selected by the user',
      'data2': 'HCV-ID and cryptographic file fingerprint',
      'data3': 'technical metadata required for verification',
      'data4': 'technical creator identity, when configured',
      'limit1':
          'SIGILLUM verifies technical provenance and integrity; it does not replace a legal expert report.',
      'limit2':
          'A screen-risk warning means caution, not automatic proof of falsification.',
      'limit3': 'Online verification requires the Registry to be reachable.',
      'privacyPolicy': 'Privacy policy',
      'terms': 'Terms of service',
      'support': 'Support and data deletion',
      'copied': 'Copied',
    },
    'es': {
      'identity': 'Identidad',
      'headline': 'Prueba tecnica para contenidos creados por personas reales.',
      'subtitle':
          'SIGILLUM vincula fotos, videos y textos a un HCV-ID, identidad tecnica, huella del archivo, certificado firmado y Registry online. Las modificaciones siguen siendo detectables.',
      'certifyMediaTitle': 'Certificar foto o video',
      'certifyMediaSubtitle': 'Captura o graba y crea el certificado HCV.',
      'certifyTextTitle': 'Certificar texto',
      'certifyTextSubtitle': 'Crea un texto verificable con HCV-ID.',
      'verifyTitle': 'Verificar contenido',
      'verifySubtitle': 'Abre un archivo, HCVPACK o verifica en Registry.',
      'infoTitle': 'Informacion y privacidad',
      'infoSubtitle': 'Controles, limites, terminos y soporte.',
      'trustChain': 'Cadena de control',
      'controls': 'Controles SIGILLUM',
      'capture': 'Captura',
      'captureText': 'creada en la app',
      'fingerprint': 'Huella',
      'fingerprintText': 'hash del archivo',
      'identityStep': 'Identidad',
      'identityText': 'creador vinculado',
      'signature': 'Firma',
      'signatureText': 'certificado protegido',
      'registry': 'Registry',
      'registryText': 'verificacion online',
      'checkIntegrity': 'Integridad del archivo y coherencia del certificado',
      'checkSignature': 'Firma digital del certificado',
      'checkWatermark': 'Marca visible en el contenido publicado',
      'checkRegistry': 'Registry online para verificacion futura',
      'checkScreen': 'Control de riesgo de regrabacion de pantalla',
      'checkSocial': 'Fingerprint para archivos recomprimidos por redes',
      'legalPageTitle': 'Informacion',
      'legalIntro':
          'SIGILLUM crea una prueba tecnica verificable que vincula contenido, HCV-ID, identidad del creador, huella del archivo y Registry online.',
      'legalControls': 'Controles realizados',
      'legalData': 'Datos tratados',
      'legalLimits': 'Limites del servicio',
      'data1': 'contenido creado o seleccionado por el usuario',
      'data2': 'HCV-ID y huella criptografica del archivo',
      'data3': 'metadatos tecnicos necesarios para la verificacion',
      'data4': 'identidad tecnica del creador, si esta configurada',
      'limit1':
          'SIGILLUM verifica procedencia tecnica e integridad; no sustituye un informe pericial legal.',
      'limit2':
          'Una advertencia de riesgo de pantalla indica cautela, no prueba automatica de falsedad.',
      'limit3':
          'La verificacion online requiere que el Registry este accesible.',
      'privacyPolicy': 'Politica de privacidad',
      'terms': 'Terminos del servicio',
      'support': 'Soporte y eliminacion de datos',
      'copied': 'Copiado',
    },
    'ru': {
      'identity': 'Идентификация',
      'headline':
          'Техническое доказательство для контента, созданного человеком.',
      'subtitle':
          'SIGILLUM связывает фото, видео и текст с HCV-ID, технической идентичностью, отпечатком файла, подписанным сертификатом и онлайн-реестром. Изменения остаются обнаруживаемыми.',
      'certifyMediaTitle': 'Сертифицировать фото или видео',
      'certifyMediaSubtitle': 'Снимите материал и создайте HCV-сертификат.',
      'certifyTextTitle': 'Сертифицировать текст',
      'certifyTextSubtitle': 'Создайте проверяемый текст с HCV-ID.',
      'verifyTitle': 'Проверить контент',
      'verifySubtitle': 'Откройте файл, HCVPACK или проверьте через Registry.',
      'infoTitle': 'Информация и конфиденциальность',
      'infoSubtitle': 'Проверки, ограничения, условия и поддержка.',
      'trustChain': 'Цепочка контроля',
      'controls': 'Проверки SIGILLUM',
      'capture': 'Съемка',
      'captureText': 'создано в приложении',
      'fingerprint': 'Отпечаток',
      'fingerprintText': 'хэш файла',
      'identityStep': 'Идентичность',
      'identityText': 'автор связан',
      'signature': 'Подпись',
      'signatureText': 'защищенный сертификат',
      'registry': 'Registry',
      'registryText': 'онлайн-проверка',
      'checkIntegrity': 'Целостность файла и соответствие сертификату',
      'checkSignature': 'Цифровая подпись сертификата',
      'checkWatermark': 'Видимый watermark в опубликованном контенте',
      'checkRegistry': 'Онлайн Registry для будущей проверки',
      'checkScreen': 'Проверка риска пересъемки с экрана',
      'checkSocial': 'Fingerprint для файлов, сжатых соцсетями',
      'legalPageTitle': 'Информация',
      'legalIntro':
          'SIGILLUM создает проверяемое техническое доказательство, связывающее контент, HCV-ID, идентичность автора, отпечаток файла и онлайн Registry.',
      'legalControls': 'Выполняемые проверки',
      'legalData': 'Обрабатываемые данные',
      'legalLimits': 'Ограничения сервиса',
      'data1': 'контент, созданный или выбранный пользователем',
      'data2': 'HCV-ID и криптографический отпечаток файла',
      'data3': 'технические метаданные, необходимые для проверки',
      'data4': 'техническая идентичность автора, если настроена',
      'limit1':
          'SIGILLUM проверяет техническое происхождение и целостность; это не заменяет юридическую экспертизу.',
      'limit2':
          'Предупреждение о риске экрана означает осторожность, а не автоматическое доказательство подделки.',
      'limit3': 'Онлайн-проверка требует доступности Registry.',
      'privacyPolicy': 'Политика конфиденциальности',
      'terms': 'Условия сервиса',
      'support': 'Поддержка и удаление данных',
      'copied': 'Скопировано',
    },
  };
}
