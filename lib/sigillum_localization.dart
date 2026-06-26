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
      'headline': 'Certifica contenuti con una prova tecnica verificabile.',
      'subtitle':
          'Foto, video e testi vengono collegati a identita tecnica, impronta del file, certificato firmato e registro online.',
      'certifyMediaTitle': 'Certifica foto o video',
      'certifyMediaSubtitle': 'Registra o scatta e crea il certificato.',
      'certifyTextTitle': 'Certifica testo',
      'certifyTextSubtitle': 'Crea un testo verificabile con HCV-ID.',
      'verifyTitle': 'Verifica contenuto',
      'verifySubtitle': 'Apri un file, un HCVPACK o verifica dal Registry.',
      'infoTitle': 'Informazioni e privacy',
      'infoSubtitle': 'Controlli, limiti, termini e supporto.',
      'trustChain': 'Catena di controllo',
      'controls': 'Controlli SIGILLUM',
      'capture': 'Cattura',
      'captureText': 'Creata in app',
      'fingerprint': 'Impronta',
      'fingerprintText': 'Hash del file',
      'identityStep': 'Identita',
      'identityText': 'Creatore collegato',
      'signature': 'Firma',
      'signatureText': 'Certificato protetto',
      'registry': 'Registro',
      'registryText': 'Verifica online',
      'checkIntegrity': 'Integrita file e coerenza col certificato',
      'checkSignature': 'Firma digitale del certificato',
      'checkWatermark': 'Watermark visibile nel contenuto pubblicato',
      'checkRegistry': 'Registro online per verifica futura',
      'checkScreen': 'Controllo anti-ripresa da schermo',
      'checkSocial': 'Fingerprint per file ricompressi dai social',
      'legalPageTitle': 'Informazioni',
      'legalIntro':
          'SIGILLUM crea una prova tecnica verificabile che collega contenuto, HCV-ID, identita del creatore, impronta del file e Registry online.',
      'legalControls': 'Controlli eseguiti',
      'legalData': 'Dati trattati',
      'legalLimits': 'Limiti del servizio',
      'data1': 'contenuto creato o selezionato dall’utente',
      'data2': 'HCV-ID e impronta crittografica del file',
      'data3': 'metadati tecnici necessari alla verifica',
      'data4': 'identita tecnica del creatore, se configurata',
      'limit1':
          'SIGILLUM verifica coerenza tecnica e integrita, non sostituisce una perizia legale.',
      'limit2':
          'Un avviso di rischio schermo indica cautela, non una prova automatica di falso.',
      'limit3':
          'La verifica online richiede che il Registry sia raggiungibile.',
      'privacyPolicy': 'Privacy policy',
      'terms': 'Termini del servizio',
      'support': 'Supporto e cancellazione dati',
      'copied': 'Copiato',
    },
    'en': {
      'identity': 'Identity',
      'headline': 'Certify content with a verifiable technical proof.',
      'subtitle':
          'Photos, videos and texts are linked to a technical identity, file fingerprint, signed certificate and online registry.',
      'certifyMediaTitle': 'Certify photo or video',
      'certifyMediaSubtitle': 'Record or capture and create the certificate.',
      'certifyTextTitle': 'Certify text',
      'certifyTextSubtitle': 'Create verifiable text with an HCV-ID.',
      'verifyTitle': 'Verify content',
      'verifySubtitle': 'Open a file, an HCVPACK or verify from Registry.',
      'infoTitle': 'Information and privacy',
      'infoSubtitle': 'Checks, limits, terms and support.',
      'trustChain': 'Control chain',
      'controls': 'SIGILLUM checks',
      'capture': 'Capture',
      'captureText': 'Created in app',
      'fingerprint': 'Fingerprint',
      'fingerprintText': 'File hash',
      'identityStep': 'Identity',
      'identityText': 'Creator linked',
      'signature': 'Signature',
      'signatureText': 'Protected certificate',
      'registry': 'Registry',
      'registryText': 'Online verification',
      'checkIntegrity': 'File integrity and certificate consistency',
      'checkSignature': 'Digital certificate signature',
      'checkWatermark': 'Visible watermark in published content',
      'checkRegistry': 'Online registry for future verification',
      'checkScreen': 'Screen replay risk check',
      'checkSocial': 'Fingerprint for social-media recompressed files',
      'legalPageTitle': 'Information',
      'legalIntro':
          'SIGILLUM creates a verifiable technical proof linking content, HCV-ID, creator identity, file fingerprint and online Registry.',
      'legalControls': 'Checks performed',
      'legalData': 'Data processed',
      'legalLimits': 'Service limits',
      'data1': 'content created or selected by the user',
      'data2': 'HCV-ID and cryptographic file fingerprint',
      'data3': 'technical metadata required for verification',
      'data4': 'technical creator identity, when configured',
      'limit1':
          'SIGILLUM verifies technical consistency and integrity; it does not replace a legal expert report.',
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
      'headline': 'Certifica contenidos con una prueba tecnica verificable.',
      'subtitle':
          'Fotos, videos y textos se vinculan a identidad tecnica, huella del archivo, certificado firmado y registro en linea.',
      'certifyMediaTitle': 'Certificar foto o video',
      'certifyMediaSubtitle': 'Graba o captura y crea el certificado.',
      'certifyTextTitle': 'Certificar texto',
      'certifyTextSubtitle': 'Crea un texto verificable con HCV-ID.',
      'verifyTitle': 'Verificar contenido',
      'verifySubtitle': 'Abre un archivo, un HCVPACK o verifica en Registry.',
      'infoTitle': 'Informacion y privacidad',
      'infoSubtitle': 'Controles, limites, terminos y soporte.',
      'trustChain': 'Cadena de control',
      'controls': 'Controles SIGILLUM',
      'capture': 'Captura',
      'captureText': 'Creada en la app',
      'fingerprint': 'Huella',
      'fingerprintText': 'Hash del archivo',
      'identityStep': 'Identidad',
      'identityText': 'Creador vinculado',
      'signature': 'Firma',
      'signatureText': 'Certificado protegido',
      'registry': 'Registro',
      'registryText': 'Verificacion en linea',
      'checkIntegrity': 'Integridad del archivo y coherencia del certificado',
      'checkSignature': 'Firma digital del certificado',
      'checkWatermark': 'Marca visible en el contenido publicado',
      'checkRegistry': 'Registro en linea para verificacion futura',
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
          'SIGILLUM verifica coherencia tecnica e integridad; no sustituye un informe pericial legal.',
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
          'Сертифицируйте контент с проверяемым техническим доказательством.',
      'subtitle':
          'Фото, видео и тексты связываются с технической идентичностью, отпечатком файла, подписанным сертификатом и онлайн-реестром.',
      'certifyMediaTitle': 'Сертифицировать фото или видео',
      'certifyMediaSubtitle': 'Снимите материал и создайте сертификат.',
      'certifyTextTitle': 'Сертифицировать текст',
      'certifyTextSubtitle': 'Создайте проверяемый текст с HCV-ID.',
      'verifyTitle': 'Проверить контент',
      'verifySubtitle': 'Откройте файл, HCVPACK или проверьте через Registry.',
      'infoTitle': 'Информация и приватность',
      'infoSubtitle': 'Проверки, ограничения, условия и поддержка.',
      'trustChain': 'Цепочка контроля',
      'controls': 'Проверки SIGILLUM',
      'capture': 'Съемка',
      'captureText': 'Создано в приложении',
      'fingerprint': 'Отпечаток',
      'fingerprintText': 'Хэш файла',
      'identityStep': 'Идентичность',
      'identityText': 'Автор связан',
      'signature': 'Подпись',
      'signatureText': 'Защищенный сертификат',
      'registry': 'Реестр',
      'registryText': 'Онлайн-проверка',
      'checkIntegrity': 'Целостность файла и соответствие сертификату',
      'checkSignature': 'Цифровая подпись сертификата',
      'checkWatermark': 'Видимый watermark в опубликованном контенте',
      'checkRegistry': 'Онлайн-реестр для будущей проверки',
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
          'SIGILLUM проверяет техническую согласованность и целостность; это не заменяет юридическую экспертизу.',
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
