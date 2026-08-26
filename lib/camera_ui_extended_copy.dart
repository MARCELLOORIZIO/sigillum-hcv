import 'camera_ui_copy.dart';

class CameraUiExtendedCopy {
  const CameraUiExtendedCopy._();

  static String t(String languageCode, String key) {
    final code = languageCode.toLowerCase().split('-').first;
    final value = (_copy[code] ?? _copy['en']!)[key];
    return value ?? CameraUiCopy.t(languageCode, key);
  }

  static const Map<String, Map<String, String>> _copy = {
    'it': {
      'verificationCompleteTitle': 'VERIFICA COMPLETATA',
      'returnPhoneInstruction':
          'Riporta il telefono sull’inquadratura desiderata. Ora puoi procedere con la foto o il video.',
      'proceedNow': 'ORA PUOI PROCEDERE',
      'coordinatesOff': 'Coordinate non stampate.',
      'acquiringCoordinates': 'ACQUISIZIONE COORDINATE...',
      'printGpsCoordinates': 'Stampa coordinate GPS',
      'armedVideoReady': 'PRONTO — PREMI REGISTRA PER INIZIARE',
      'armedPhotoReady': 'INQUADRA E PREMI IL PULSANTE DI SCATTO',
      'parallaxRequired':
          'MOVIMENTO INSUFFICIENTE — MUOVI IL TELEFONO LATERALMENTE E RIPROVA',
      'transcriptionAudio': 'TRASCRIZIONE AUDIO...',
      'transcriptionReady': 'TRASCRIZIONE PRONTA',
      'transcriptionFailed': 'TRASCRIZIONE NON RIUSCITA',
      'transcriptionTitle': 'Trascrizione audio',
      'subtitlesCreated': 'Sottotitoli creati.',
      'close': 'CHIUDI',
      'transcribing': 'TRASCRIZIONE IN CORSO...',
      'createCaptionedVideo': 'CREA VIDEO CON SOTTOTITOLI',
      'saveCaptionedPhotos': 'SALVA VIDEO SOTTOTITOLATO IN FOTO',
      'shareCaptionedVideo': 'CONDIVIDI VIDEO SOTTOTITOLATO',
      'shareSrt': 'CONDIVIDI SOTTOTITOLI .SRT',
      'subtitleShareText': 'Sottotitoli SIGILLUM',
      'captionedReady': 'VIDEO SOTTOTITOLATO PRONTO',
      'captionedReadyPhotos': 'VIDEO SOTTOTITOLATO PRONTO — SALVATO IN FOTO',
      'captionedReadyFiles': 'VIDEO SOTTOTITOLATO PRONTO — DISPONIBILE IN FILE',
      'captionedSavedPhotos': 'Video sottotitolato salvato in Foto',
      'captionedSavedPhotosSentence': 'Video sottotitolato salvato in Foto.',
      'captionedSaveFailed':
          'Non è stato possibile salvare il video sottotitolato in Foto.',
      'captionedAvailableFiles':
          'Video sottotitolato disponibile in File; salvataggio in Foto non riuscito',
      'certifiedPhotoSaved': 'Foto certificata salvata in Foto',
      'certifiedOriginalSaved':
          'Originale certificato salvato in Foto (senza sottotitoli)',
      'filesWhere': 'DOVE TROVI I FILE',
      'filesPath': 'File > Sul mio iPhone > Fotocamera Sigillum',
      'filesExplanation':
          'SIGILLUM salva automaticamente qui i file principali. Non devi scegliere manualmente la cartella.',
      'certifiedOriginal': 'Originale certificato',
      'hcvCertificate': 'Certificato HCV',
      'captionedVideo': 'Video sottotitolato',
      'srtSubtitles': 'Sottotitoli SRT',
      'quickGuide': 'GUIDA RAPIDA',
      'quickGuideTooltip': 'Guida rapida',
      'captionExplanation':
          'Le scritte sono sincronizzate con l’audio e impresse nella copia video. L’originale certificato resta invariato.',
      'shareCaptionedText':
          'Copia video SIGILLUM con sottotitoli sincronizzati. L’originale certificato resta invariato.',
    },
    'en': {
      'verificationCompleteTitle': 'VERIFICATION COMPLETE',
      'returnPhoneInstruction':
          'Return the phone to the desired composition. You can now proceed with the photo or video.',
      'proceedNow': 'PROCEED NOW',
      'coordinatesOff': 'Coordinates will not be printed.',
      'acquiringCoordinates': 'ACQUIRING COORDINATES...',
      'printGpsCoordinates': 'Print GPS coordinates',
      'armedVideoReady': 'READY — PRESS RECORD TO START',
      'armedPhotoReady': 'COMPOSE AND PRESS THE SHUTTER BUTTON',
      'parallaxRequired':
          'NOT ENOUGH MOVEMENT — MOVE THE PHONE SIDEWAYS AND TRY AGAIN',
      'transcriptionAudio': 'TRANSCRIBING AUDIO...',
      'transcriptionReady': 'TRANSCRIPTION READY',
      'transcriptionFailed': 'TRANSCRIPTION FAILED',
      'transcriptionTitle': 'Audio transcription',
      'subtitlesCreated': 'Subtitles created.',
      'close': 'CLOSE',
      'transcribing': 'TRANSCRIPTION IN PROGRESS...',
      'createCaptionedVideo': 'CREATE CAPTIONED VIDEO',
      'saveCaptionedPhotos': 'SAVE CAPTIONED VIDEO TO PHOTOS',
      'shareCaptionedVideo': 'SHARE CAPTIONED VIDEO',
      'shareSrt': 'SHARE .SRT SUBTITLES',
      'subtitleShareText': 'SIGILLUM subtitles',
      'captionedReady': 'CAPTIONED VIDEO READY',
      'captionedReadyPhotos': 'CAPTIONED VIDEO READY — SAVED TO PHOTOS',
      'captionedReadyFiles': 'CAPTIONED VIDEO READY — AVAILABLE IN FILES',
      'captionedSavedPhotos': 'Captioned video saved to Photos',
      'captionedSavedPhotosSentence': 'Captioned video saved to Photos.',
      'captionedSaveFailed':
          'The captioned video could not be saved to Photos.',
      'captionedAvailableFiles':
          'Captioned video is available in Files; saving to Photos failed',
      'certifiedPhotoSaved': 'Certified photo saved to Photos',
      'certifiedOriginalSaved':
          'Certified original saved to Photos (without subtitles)',
      'filesWhere': 'WHERE TO FIND YOUR FILES',
      'filesPath': 'Files > On My iPhone > Fotocamera Sigillum',
      'filesExplanation':
          'SIGILLUM automatically saves the main files here. You do not need to choose the folder manually.',
      'certifiedOriginal': 'Certified original',
      'hcvCertificate': 'HCV certificate',
      'captionedVideo': 'Captioned video',
      'srtSubtitles': 'SRT subtitles',
      'quickGuide': 'QUICK GUIDE',
      'quickGuideTooltip': 'Quick guide',
      'captionExplanation':
          'The captions are synchronized with the audio and burned into the derived video. The certified original remains unchanged.',
      'shareCaptionedText':
          'SIGILLUM video copy with synchronized captions. The certified original remains unchanged.',
    },
    'es': {
      'verificationCompleteTitle': 'VERIFICACIÓN COMPLETADA',
      'returnPhoneInstruction':
          'Vuelve a colocar el teléfono en el encuadre deseado. Ahora puedes hacer la foto o iniciar el vídeo.',
      'proceedNow': 'PUEDES CONTINUAR',
      'coordinatesOff': 'Las coordenadas no se imprimirán.',
      'acquiringCoordinates': 'OBTENIENDO COORDENADAS...',
      'printGpsCoordinates': 'Imprimir coordenadas GPS',
      'armedVideoReady': 'LISTO — PULSA GRABAR PARA EMPEZAR',
      'armedPhotoReady': 'ENCUADRA Y PULSA EL BOTÓN DE DISPARO',
      'parallaxRequired':
          'MOVIMIENTO INSUFICIENTE — MUEVE EL TELÉFONO LATERALMENTE Y VUELVE A INTENTARLO',
      'transcriptionAudio': 'TRANSCRIBIENDO AUDIO...',
      'transcriptionReady': 'TRANSCRIPCIÓN LISTA',
      'transcriptionFailed': 'TRANSCRIPCIÓN FALLIDA',
      'transcriptionTitle': 'Transcripción de audio',
      'subtitlesCreated': 'Subtítulos creados.',
      'close': 'CERRAR',
      'transcribing': 'TRANSCRIPCIÓN EN CURSO...',
      'createCaptionedVideo': 'CREAR VÍDEO CON SUBTÍTULOS',
      'saveCaptionedPhotos': 'GUARDAR VÍDEO SUBTITULADO EN FOTOS',
      'shareCaptionedVideo': 'COMPARTIR VÍDEO SUBTITULADO',
      'shareSrt': 'COMPARTIR SUBTÍTULOS .SRT',
      'subtitleShareText': 'Subtítulos SIGILLUM',
      'captionedReady': 'VÍDEO SUBTITULADO LISTO',
      'captionedReadyPhotos': 'VÍDEO SUBTITULADO LISTO — GUARDADO EN FOTOS',
      'captionedReadyFiles': 'VÍDEO SUBTITULADO LISTO — DISPONIBLE EN ARCHIVOS',
      'captionedSavedPhotos': 'Vídeo subtitulado guardado en Fotos',
      'captionedSavedPhotosSentence': 'Vídeo subtitulado guardado en Fotos.',
      'captionedSaveFailed':
          'No se pudo guardar el vídeo subtitulado en Fotos.',
      'captionedAvailableFiles':
          'El vídeo subtitulado está disponible en Archivos; no se pudo guardar en Fotos',
      'certifiedPhotoSaved': 'Foto certificada guardada en Fotos',
      'certifiedOriginalSaved':
          'Original certificado guardado en Fotos (sin subtítulos)',
      'filesWhere': 'DÓNDE ENCONTRAR LOS ARCHIVOS',
      'filesPath': 'Archivos > En mi iPhone > Fotocamera Sigillum',
      'filesExplanation':
          'SIGILLUM guarda aquí automáticamente los archivos principales. No necesitas elegir la carpeta manualmente.',
      'certifiedOriginal': 'Original certificado',
      'hcvCertificate': 'Certificado HCV',
      'captionedVideo': 'Vídeo subtitulado',
      'srtSubtitles': 'Subtítulos SRT',
      'quickGuide': 'GUÍA RÁPIDA',
      'quickGuideTooltip': 'Guía rápida',
      'captionExplanation':
          'Los subtítulos están sincronizados con el audio y se imprimen en la copia de vídeo. El original certificado permanece sin cambios.',
      'shareCaptionedText':
          'Copia de vídeo SIGILLUM con subtítulos sincronizados. El original certificado permanece sin cambios.',
    },
    'ru': {
      'verificationCompleteTitle': 'ПРОВЕРКА ЗАВЕРШЕНА',
      'returnPhoneInstruction':
          'Верните телефон к нужной композиции кадра. Теперь можно сделать фото или начать запись видео.',
      'proceedNow': 'МОЖНО ПРОДОЛЖАТЬ',
      'coordinatesOff': 'Координаты не будут наноситься.',
      'acquiringCoordinates': 'ПОЛУЧЕНИЕ КООРДИНАТ...',
      'printGpsCoordinates': 'Нанести GPS-координаты',
      'armedVideoReady': 'ГОТОВО — НАЖМИТЕ ЗАПИСЬ ДЛЯ НАЧАЛА',
      'armedPhotoReady': 'ВЫСТРОЙТЕ КАДР И НАЖМИТЕ КНОПКУ СЪЁМКИ',
      'parallaxRequired':
          'НЕДОСТАТОЧНО ДВИЖЕНИЯ — СДВИНЬТЕ ТЕЛЕФОН В СТОРОНУ И ПОВТОРИТЕ',
      'transcriptionAudio': 'РАСШИФРОВКА АУДИО...',
      'transcriptionReady': 'РАСШИФРОВКА ГОТОВА',
      'transcriptionFailed': 'НЕ УДАЛОСЬ РАСШИФРОВАТЬ',
      'transcriptionTitle': 'Расшифровка аудио',
      'subtitlesCreated': 'Субтитры созданы.',
      'close': 'ЗАКРЫТЬ',
      'transcribing': 'ИДЁТ РАСШИФРОВКА...',
      'createCaptionedVideo': 'СОЗДАТЬ ВИДЕО С СУБТИТРАМИ',
      'saveCaptionedPhotos': 'СОХРАНИТЬ ВИДЕО С СУБТИТРАМИ В ФОТО',
      'shareCaptionedVideo': 'ПОДЕЛИТЬСЯ ВИДЕО С СУБТИТРАМИ',
      'shareSrt': 'ПОДЕЛИТЬСЯ СУБТИТРАМИ .SRT',
      'subtitleShareText': 'Субтитры SIGILLUM',
      'captionedReady': 'ВИДЕО С СУБТИТРАМИ ГОТОВО',
      'captionedReadyPhotos': 'ВИДЕО С СУБТИТРАМИ ГОТОВО — СОХРАНЕНО В ФОТО',
      'captionedReadyFiles': 'ВИДЕО С СУБТИТРАМИ ГОТОВО — ДОСТУПНО В ФАЙЛАХ',
      'captionedSavedPhotos': 'Видео с субтитрами сохранено в Фото',
      'captionedSavedPhotosSentence': 'Видео с субтитрами сохранено в Фото.',
      'captionedSaveFailed': 'Не удалось сохранить видео с субтитрами в Фото.',
      'captionedAvailableFiles':
          'Видео с субтитрами доступно в Файлах; сохранить в Фото не удалось',
      'certifiedPhotoSaved': 'Сертифицированное фото сохранено в Фото',
      'certifiedOriginalSaved':
          'Сертифицированный оригинал сохранён в Фото (без субтитров)',
      'filesWhere': 'ГДЕ НАЙТИ ФАЙЛЫ',
      'filesPath': 'Файлы > На моём iPhone > Fotocamera Sigillum',
      'filesExplanation':
          'SIGILLUM автоматически сохраняет основные файлы здесь. Выбирать папку вручную не нужно.',
      'certifiedOriginal': 'Сертифицированный оригинал',
      'hcvCertificate': 'Сертификат HCV',
      'captionedVideo': 'Видео с субтитрами',
      'srtSubtitles': 'Субтитры SRT',
      'quickGuide': 'КРАТКОЕ РУКОВОДСТВО',
      'quickGuideTooltip': 'Краткое руководство',
      'captionExplanation':
          'Субтитры синхронизированы с аудио и нанесены на производную копию видео. Сертифицированный оригинал остаётся неизменным.',
      'shareCaptionedText':
          'Копия видео SIGILLUM с синхронизированными субтитрами. Сертифицированный оригинал остаётся неизменным.',
    },
  };
}
