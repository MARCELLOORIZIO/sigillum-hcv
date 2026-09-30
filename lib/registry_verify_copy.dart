class RegistryVerifyCopy {
  const RegistryVerifyCopy._();

  static String t(String languageCode, String key) {
    final code = languageCode.toLowerCase().split('-').first;
    return (_copy[code] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _copy = {
    'it': {
      'unprovenDerivativeTitle': 'CONTENUTO NON ORIGINALE VERIFICATO',
      'unprovenDerivativeStatus': 'Originale non verificato',
      'unprovenDerivativeDetail':
          'SHA-256 diverso dall originale certificato. Il fingerprint indica solo somiglianza e NON esclude oggetti aggiunti, scritte o fotogrammi alterati. L HCV-ID valido non autentica questa copia.',
      'unprovenDerivativeProvenance': 'HCV-ID valido, file non autenticato',
      'unprovenDerivativeAxis': 'Somiglianza non probante',
      'socialLimitedTitle':
          'CERTIFICATO IDENTIFICATO — INTEGRITÀ NON CONCLUSIVA',
      'socialLimitedStatus':
          'HCV-ID e certificato Registry validi. Il vecchio fingerprint globale V1 mostra somiglianza, ma non può distinguere una ricompressione da modifiche a colori, luminosità o contenuto.',
      'socialLimitedDetail':
          'Hash diverso dall originale. Certificato valido, ma fingerprint V1 insufficiente a certificare integrità della copia: eventuali modifiche visive non sono escluse.',
      'quickCheck': 'Controllo rapido SIGILLUM in corso...',
      'fileUnavailable':
          'File ricevuto ma non accessibile. Riprova da Verifica contenuto.',
      'notCertified': 'Contenuto non certificato SIGILLUM.',
      'idDetectedAuto': 'HCV-ID rilevato. Verifica Registry automatica...',
      'autoIncomplete':
          'Verifica automatica non completata. Il formato non è leggibile automaticamente: inserisci HCV-ID e premi VERIFICA DAL REGISTRY.',
      'iosImportFailed': 'File selezionato ma non importabile su iOS.',
      'selectOriginalNotPack':
          'Seleziona il file ORIGINALE da verificare, non un file .hcv o .hcvpack.',
      'ocrDetectedMedia': 'HCV-ID rilevato nel media.',
      'idDetectedPressVerify':
          'HCV-ID rilevato. Ora premi VERIFICA DAL REGISTRY.',
      'fileSelectedPressVerify':
          'File selezionato. Se disponibile, inserisci o rileva HCV-ID e premi VERIFICA DAL REGISTRY.',
      'enterId': 'Inserisci HCV-ID.',
      'selectOriginal': 'Seleziona il file originale da verificare.',
      'downloadingCertificate': 'Recupero del certificato dal Registry HCV...',
      'signatureInvalid':
          'Il certificato è stato recuperato, ma la firma crittografica non è valida.',
      'bindingMissing':
          'Il certificato non contiene un collegamento valido al contenuto.',
      'mediaMissing': 'File media non trovato.',
      'forensicStatus':
          'ORIGINALE CERTIFICATO VERIFICATO\nIl file è identico all’originale certificato. Hash SHA-256 corrispondente.',
      'socialTextStatus':
          'CONTENUTO CERTIFICATO COMPATIBILE\nIl testo pubblicato contiene il footer SIGILLUM/HCV-ID e il contenuto certificato corrisponde, anche se il file non è identico byte per byte.',
      'genericDerived':
          'CONTENUTO CERTIFICATO COMPATIBILE\nIl file è diverso dall’originale certificato ma supera i controlli di compatibilità disponibili per questo tipo di media.',
      'officialReferenceConforming':
          'COPIA CONFORME\nIl contenuto corrisponde alla copia ufficiale SIGILLUM. Le differenze rilevate sono compatibili con ricompressione o trasformazioni tecniche social tollerate.',
      'officialReferenceConformingDetail':
          'Confronto locale V3 compatibile con la fingerprint firmata della copia ufficiale SIGILLUM.',
      'officialReferenceModified':
          'COPIA MODIFICATA\nIl contenuto presenta differenze locali significative rispetto alla copia ufficiale SIGILLUM.',
      'officialReferenceModifiedDetail':
          'Il confronto locale V3 ha rilevato variazioni non compatibili con la sola ricompressione social, incluse possibili aggiunte, rimozioni o alterazioni di elementi.',
      'officialReferenceInconclusive':
          'VERIFICA NON CONCLUSIVA\nLa copia ufficiale SIGILLUM è disponibile, ma il confronto non produce evidenza sufficiente per dichiarare il contenuto conforme o modificato.',
      'officialReferenceInconclusiveDetail':
          'Qualità, ritaglio, trasformazioni o allineamento non consentono un confronto locale V3 affidabile.',
      'officialReferenceConformingTitle': 'COPIA UFFICIALE CONFORME',
      'officialReferenceModifiedTitle': 'COPIA UFFICIALE MODIFICATA',
      'officialReferenceInconclusiveTitle': 'VERIFICA NON CONCLUSIVA',
      'officialReferenceUnavailableTitle':
          'RIFERIMENTO UFFICIALE NON DISPONIBILE',
      'officialReferenceUnavailable':
          'VERIFICA NON ESEGUIBILE\nLa reference ufficiale SIGILLUM non è verificabile su YouTube in questo momento. Nessun controllo più debole viene usato per dichiarare conforme il file social.',
      'officialReferenceUnavailableDetail':
          'La reference YouTube deve risultare realmente presente, elaborata e unlisted prima della verifica di una copia social. Lo stato dei commenti resta un dato diagnostico e non determina la validità della reference.',
      'manualCompareTitle': 'CONFRONTO MANUALE',
      'manualCompareAction': 'CONFRONTA MANUALMENTE',
      'manualCompareSubscriberOnly':
          'Funzione riservata agli abbonati SIGILLUM.',
      'manualCompareIntro':
          'Controlla personalmente immagini e audio del file ricevuto e confrontali con la copia ufficiale pubblicata da SIGILLUM su YouTube.',
      'manualCompareAutomaticVerdict': 'Esito automatico',
      'manualCompareLocalTitle': 'FILE DA CONTROLLARE',
      'manualCompareOfficialTitle': 'COPIA UFFICIALE SIGILLUM',
      'manualCompareVideoHelp':
          'Porta il file al punto che vuoi controllare, poi apri la copia ufficiale allo stesso timestamp. Puoi confrontare immagini, voce, suoni, tagli e sequenza.',
      'manualComparePhotoHelp':
          'Osserva la foto ricevuta, poi apri la copia ufficiale SIGILLUM su YouTube per il confronto visivo.',
      'manualCompareOpenOfficial': 'APRI COPIA UFFICIALE',
      'manualCompareOpenAtTime': 'APRI COPIA UFFICIALE A {time}',
      'manualCompareReturnHelp':
          'YouTube viene aperto esternamente. Torna a SIGILLUM per continuare il confronto.',
      'manualComparePlayPause': 'Riproduci / pausa',
      'manualCompareAudio': 'Audio',
      'manualCompareSubscriptionRequired':
          'Questa funzione richiede un abbonamento SIGILLUM attivo.',
      'manualCompareReferenceUnavailable':
          'La copia ufficiale YouTube non è verificabile in questo momento.',
      'manualCompareMediaUnavailable':
          'Il file da confrontare non è più disponibile sul dispositivo.',
      'manualCompareLoadError': 'Impossibile preparare il confronto manuale.',
      'manualCompareOpenError':
          'Impossibile aprire la copia ufficiale su YouTube.',
      'verificationTiming':
          'Tempo verifica: {total} s · YouTube {youtube} s · confronto locale {local} s',
      'techReferenceVerification': 'RIFERIMENTO UFFICIALE YOUTUBE',
      'techReferenceMode': 'Modalità confronto',
      'techReferenceLive': 'Reference YouTube live',
      'techReferenceCommentsDisabled': 'Commenti disabilitati',
      'techReferenceServerMs': 'Controllo YouTube ms',
      'techReferenceLocalMs': 'Confronto locale ms',
      'techVerificationTotalMs': 'Verifica totale ms',
      'audioMismatchDetected':
          'HCV-ID e fingerprint visivo sono compatibili, ma il fingerprint audio non corrisponde. Possibile audio sostituito, rimosso o alterato oltre la tolleranza di ricompressione.',
      'audioMismatchProvided':
          'HCV-ID inserito e fingerprint visivo compatibile, ma il fingerprint audio non corrisponde. La traccia audio certificata non è verificata.',
      'videoBothDetected':
          'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID rilevato; certificato Registry valido; fingerprint visivo spaziale e audio compatibili; la causa della differenza SHA non è determinabile automaticamente.',
      'videoBothProvided':
          'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID inserito; certificato Registry valido; fingerprint visivo spaziale e audio compatibili; la causa della differenza SHA non è determinabile automaticamente.',
      'videoLegacyAudioDetected':
          'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID rilevato e fingerprint visivo compatibile. Certificato legacy precedente al fingerprint audio.',
      'videoLegacyAudioProvided':
          'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID inserito e fingerprint visivo compatibile. Certificato legacy precedente al fingerprint audio.',
      'videoLegacyLimitedDetected':
          'CERTIFICATO LEGACY IDENTIFICATO\nHCV-ID rilevato e certificato Registry valido, ma il certificato non contiene il moderno fingerprint visivo. La compatibilità del media non può essere confermata con la stessa forza delle versioni attuali.',
      'videoLegacyLimitedProvided':
          'CERTIFICATO LEGACY IDENTIFICATO\nHCV-ID inserito e certificato Registry valido, ma il certificato non contiene il moderno fingerprint visivo. La compatibilità del media non può essere confermata con la stessa forza delle versioni attuali.',
      'videoMismatchDetected':
          'HCV-ID rilevato nel video, ma il fingerprint visivo non corrisponde al contenuto certificato. Possibile HCV-ID sovrapposto a un video diverso.',
      'videoMismatchProvided':
          'HCV-ID inserito, ma il fingerprint visivo non corrisponde. Il video selezionato non è compatibile con quel certificato.',
      'photoCompatibleDetected':
          'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID rilevato; certificato Registry valido; fingerprint immagine spaziale compatibile; la causa della differenza SHA non è determinabile automaticamente.',
      'photoCompatibleProvided':
          'CONTENUTO CERTIFICATO COMPATIBILE\nHCV-ID inserito; certificato Registry valido; fingerprint immagine spaziale compatibile; la causa della differenza SHA non è determinabile automaticamente.',
      'photoLegacyDetected':
          'CERTIFICATO LEGACY IDENTIFICATO\nHCV-ID rilevato e certificato Registry valido. Il certificato è precedente al moderno fingerprint immagine: la verifica della copia è meno forte.',
      'photoLegacyProvided':
          'CERTIFICATO LEGACY IDENTIFICATO\nHCV-ID inserito e certificato Registry valido. Il certificato è precedente al moderno fingerprint immagine: la verifica della copia è meno forte.',
      'photoMismatchDetected':
          'HCV-ID rilevato nella foto, ma il fingerprint immagine non corrisponde. Possibile HCV-ID sovrapposto a una foto diversa.',
      'photoMismatchProvided':
          'HCV-ID inserito, ma il fingerprint immagine non corrisponde. La foto selezionata non è compatibile con quel certificato.',
      'idNotDetected':
          'HCV-ID valido nel Registry, ma non rilevato automaticamente nel file selezionato. La corrispondenza del media non è verificata.',
      'sceneWarning':
          'ATTENZIONE: segnali tecnici coerenti con una possibile ripresa da schermo ({risk}). Il media resta collegato al certificato, ma la scena non va interpretata come ripresa diretta della realtà.',
      'registryNotFoundDetail':
          'Certificato non presente nel Registry. Questo non dimostra una modifica del file: la pubblicazione online potrebbe essere ancora in attesa.',
      'registryUnavailableDetail':
          'Registry temporaneamente non raggiungibile. Il file locale non viene considerato invalido; riprova quando la connessione è disponibile.',
      'registryInvalidResponse': 'Risposta Registry non utilizzabile: {error}',
      'invalidLocalCertificate': 'Certificato locale non valido: {error}',
      'unexpectedRegistryError':
          'Errore imprevisto durante la verifica Registry: {error}',
      'contentType': 'Tipo',
      'techHcvTrust': 'Fiducia HCV',
      'techLiveTrust': 'Fiducia cattura live',
      'techSceneAuthenticity': 'Autenticità scena',
      'techSyntheticRisk': 'Rischio sintetico',
      'techAiProof': 'Livello prova AI',
      'techDisplayFusion': 'FUSIONE RISCHIO DISPLAY',
      'techDecision': 'Decisione',
      'techRisk': 'Rischio',
      'techScore': 'Punteggio',
      'techPassive': 'ANALISI PASSIVA VIDEO/IMMAGINE',
      'techSegments': 'Segmenti analizzati',
      'techWorstSecond': 'Secondo peggiore',
      'techLocalFlicker': 'Flicker temporale locale',
      'techRefreshBand': 'Bande di refresh',
      'techPixelGrid': 'Uniformità griglia pixel',
      'techLiveProbe': 'PROBE LIVE SCHERMO',
      'techAnalysisStatus': 'Stato analisi',
      'techFrames': 'Frame analizzati',
      'techReason': 'Motivo',
      'techError': 'Errore',
      'techFineStripe': 'Strisce fini',
      'techFineGrid': 'Griglia fine',
      'techMoireFrequency': 'Frequenza moiré',
      'techDynamicChallenge': 'Challenge dinamica',
      'techPersistentPattern': 'Pattern persistente',
      'techOpticalTrace': 'Traccia ottica corroborata',
      'techMoireTrace': 'Traccia moiré',
      'techDynamicTrace': 'Traccia challenge schermo',
      'techUncorroborated': 'Pattern display non corroborato',
      'techMl': 'ML RIPRESA DA SCHERMO',
      'techModelSource': 'Origine modello',
      'techModelVersion': 'Versione modello',
      'techRuntime': 'Runtime TFLite',
      'techModelSha': 'SHA-256 modello',
      'techPredictedClass': 'Classe prevista',
      'techConfidence': 'Confidenza prevista',
      'techScreenProbability': 'Probabilità schermo',
      'techMlDecision': 'Decisione ML',
    },
    'en': {
      'unprovenDerivativeTitle': 'ORIGINAL CONTENT NOT VERIFIED',
      'unprovenDerivativeStatus': 'Original not verified',
      'unprovenDerivativeDetail':
          'SHA-256 differs from the certified original. The fingerprint indicates resemblance only and CANNOT exclude inserted objects, text overlays, or altered frames. A valid HCV-ID does not authenticate this copy.',
      'unprovenDerivativeProvenance': 'HCV-ID valid, file not authenticated',
      'unprovenDerivativeAxis': 'Resemblance is not proof',
      'socialLimitedTitle': 'CERTIFICATE IDENTIFIED — INTEGRITY INCONCLUSIVE',
      'socialLimitedStatus':
          'HCV-ID and Registry certificate valid. The legacy V1 global fingerprint shows resemblance but cannot distinguish transcoding from colour, brightness or content edits.',
      'socialLimitedDetail':
          'Hash differs from the original. The certificate is valid, but V1 similarity cannot establish derivative integrity or exclude visual edits.',
      'quickCheck': 'Quick SIGILLUM check in progress...',
      'fileUnavailable':
          'The received file is not accessible. Try again from Verify content.',
      'notCertified': 'Content not certified by SIGILLUM.',
      'idDetectedAuto': 'HCV-ID detected. Automatic Registry verification...',
      'autoIncomplete':
          'Automatic verification was not completed. The format cannot be read automatically: enter the HCV-ID and press VERIFY FROM REGISTRY.',
      'iosImportFailed': 'The selected file cannot be imported on iOS.',
      'selectOriginalNotPack':
          'Select the ORIGINAL file to verify, not a .hcv or .hcvpack file.',
      'ocrDetectedMedia': 'HCV-ID detected in the media.',
      'idDetectedPressVerify':
          'HCV-ID detected. Now press VERIFY FROM REGISTRY.',
      'fileSelectedPressVerify':
          'File selected. If available, enter or detect the HCV-ID and press VERIFY FROM REGISTRY.',
      'enterId': 'Enter the HCV-ID.',
      'selectOriginal': 'Select the original file to verify.',
      'downloadingCertificate':
          'Retrieving the certificate from the HCV Registry...',
      'signatureInvalid':
          'The certificate was retrieved, but its cryptographic signature is invalid.',
      'bindingMissing':
          'The certificate does not contain a valid content binding.',
      'mediaMissing': 'Media file not found.',
      'forensicStatus':
          'CERTIFIED ORIGINAL VERIFIED\nThe file is identical to the certified original. SHA-256 hash matches.',
      'socialTextStatus':
          'CERTIFIED COMPATIBLE CONTENT\nThe published text includes the SIGILLUM/HCV-ID footer and the certified content matches, although the file is not byte-for-byte identical.',
      'genericDerived':
          'CERTIFIED COMPATIBLE CONTENT\nThe file differs from the certified original but passes the compatibility checks available for this media type.',
      'officialReferenceConforming':
          'CONFORMING COPY\nThe content matches the official SIGILLUM copy. Detected differences are compatible with tolerated social recompression or technical transformations.',
      'officialReferenceConformingDetail':
          'Local V3 comparison is compatible with the signed fingerprint of the official SIGILLUM copy.',
      'officialReferenceModified':
          'MODIFIED COPY\nThe content contains significant local differences from the official SIGILLUM copy.',
      'officialReferenceModifiedDetail':
          'Local V3 comparison detected changes not compatible with social recompression alone, including possible inserted, removed, or altered elements.',
      'officialReferenceInconclusive':
          'VERIFICATION INCONCLUSIVE\nThe official SIGILLUM copy is available, but the comparison does not provide enough evidence to classify the content as conforming or modified.',
      'officialReferenceInconclusiveDetail':
          'Quality, cropping, transformations, or alignment prevent a reliable local V3 comparison.',
      'officialReferenceConformingTitle': 'OFFICIAL COPY CONFORMING',
      'officialReferenceModifiedTitle': 'OFFICIAL COPY MODIFIED',
      'officialReferenceInconclusiveTitle': 'VERIFICATION INCONCLUSIVE',
      'officialReferenceUnavailableTitle': 'OFFICIAL REFERENCE UNAVAILABLE',
      'officialReferenceUnavailable':
          'VERIFICATION CANNOT BE COMPLETED\nThe official SIGILLUM reference cannot currently be verified on YouTube. No weaker check is used to declare the social file conforming.',
      'officialReferenceUnavailableDetail':
          'The YouTube reference must be confirmed as present, processed and unlisted before a social copy can be verified. Comment state remains diagnostic and does not determine reference validity.',
      'manualCompareTitle': 'MANUAL COMPARISON',
      'manualCompareAction': 'COMPARE MANUALLY',
      'manualCompareSubscriberOnly':
          'This feature is available to SIGILLUM subscribers.',
      'manualCompareIntro':
          'Personally inspect the images and audio of the received file and compare them with the official copy published by SIGILLUM on YouTube.',
      'manualCompareAutomaticVerdict': 'Automatic result',
      'manualCompareLocalTitle': 'FILE TO CHECK',
      'manualCompareOfficialTitle': 'OFFICIAL SIGILLUM COPY',
      'manualCompareVideoHelp':
          'Move the file to the moment you want to inspect, then open the official copy at the same timestamp. Compare images, voice, sounds, cuts and sequence.',
      'manualComparePhotoHelp':
          'Inspect the received photo, then open the official SIGILLUM copy on YouTube for a visual comparison.',
      'manualCompareOpenOfficial': 'OPEN OFFICIAL COPY',
      'manualCompareOpenAtTime': 'OPEN OFFICIAL COPY AT {time}',
      'manualCompareReturnHelp':
          'YouTube opens externally. Return to SIGILLUM to continue the comparison.',
      'manualComparePlayPause': 'Play / pause',
      'manualCompareAudio': 'Audio',
      'manualCompareSubscriptionRequired':
          'This feature requires an active SIGILLUM subscription.',
      'manualCompareReferenceUnavailable':
          'The official YouTube copy cannot be verified at this time.',
      'manualCompareMediaUnavailable':
          'The file to compare is no longer available on this device.',
      'manualCompareLoadError': 'Unable to prepare the manual comparison.',
      'manualCompareOpenError': 'Unable to open the official copy on YouTube.',
      'verificationTiming':
          'Verification time: {total} s · YouTube {youtube} s · local comparison {local} s',
      'techReferenceVerification': 'OFFICIAL YOUTUBE REFERENCE',
      'techReferenceMode': 'Comparison mode',
      'techReferenceLive': 'Live YouTube reference',
      'techReferenceCommentsDisabled': 'Comments disabled',
      'techReferenceServerMs': 'YouTube check ms',
      'techReferenceLocalMs': 'Local comparison ms',
      'techVerificationTotalMs': 'Total verification ms',
      'audioMismatchDetected':
          'The HCV-ID and visual fingerprint are compatible, but the audio fingerprint does not match. Audio may have been replaced, removed, or altered beyond recompression tolerance.',
      'audioMismatchProvided':
          'The entered HCV-ID and visual fingerprint are compatible, but the audio fingerprint does not match. The certified audio track is not verified.',
      'videoBothDetected':
          'CERTIFIED COMPATIBLE CONTENT\nHCV-ID detected; Registry certificate valid; spatial visual and audio fingerprints compatible; the cause of the SHA difference cannot be determined automatically.',
      'videoBothProvided':
          'CERTIFIED COMPATIBLE CONTENT\nHCV-ID entered; Registry certificate valid; spatial visual and audio fingerprints compatible; the cause of the SHA difference cannot be determined automatically.',
      'videoLegacyAudioDetected':
          'CERTIFIED COMPATIBLE CONTENT\nHCV-ID detected and visual fingerprint compatible. Legacy certificate predates audio fingerprinting.',
      'videoLegacyAudioProvided':
          'CERTIFIED COMPATIBLE CONTENT\nHCV-ID entered and visual fingerprint compatible. Legacy certificate predates audio fingerprinting.',
      'videoLegacyLimitedDetected':
          'LEGACY CERTIFICATE IDENTIFIED\nHCV-ID detected and Registry certificate valid, but the certificate does not contain the modern visual fingerprint. Media compatibility cannot be confirmed as strongly as with current certificates.',
      'videoLegacyLimitedProvided':
          'LEGACY CERTIFICATE IDENTIFIED\nHCV-ID entered and Registry certificate valid, but the certificate does not contain the modern visual fingerprint. Media compatibility cannot be confirmed as strongly as with current certificates.',
      'videoMismatchDetected':
          'HCV-ID detected in the video, but the visual fingerprint does not match the certified content. The HCV-ID may have been overlaid on a different video.',
      'videoMismatchProvided':
          'HCV-ID entered, but the visual fingerprint does not match. The selected video is not compatible with that certificate.',
      'photoCompatibleDetected':
          'CERTIFIED COMPATIBLE CONTENT\nHCV-ID detected; Registry certificate valid; spatial image fingerprint compatible; the cause of the SHA difference cannot be determined automatically.',
      'photoCompatibleProvided':
          'CERTIFIED COMPATIBLE CONTENT\nHCV-ID entered; Registry certificate valid; spatial image fingerprint compatible; the cause of the SHA difference cannot be determined automatically.',
      'photoLegacyDetected':
          'LEGACY CERTIFICATE IDENTIFIED\nHCV-ID detected and Registry certificate valid. The certificate predates modern image fingerprinting, so verification of the copy is weaker.',
      'photoLegacyProvided':
          'LEGACY CERTIFICATE IDENTIFIED\nHCV-ID entered and Registry certificate valid. The certificate predates modern image fingerprinting, so verification of the copy is weaker.',
      'photoMismatchDetected':
          'HCV-ID detected in the photo, but the image fingerprint does not match. The HCV-ID may have been overlaid on a different photo.',
      'photoMismatchProvided':
          'HCV-ID entered, but the image fingerprint does not match. The selected photo is not compatible with that certificate.',
      'idNotDetected':
          'The HCV-ID is valid in the Registry but was not detected automatically in the selected file. Media correspondence is not verified.',
      'sceneWarning':
          'WARNING: technical signals are consistent with a possible screen replay ({risk}). The media remains linked to the certificate, but the scene should not be interpreted as a direct capture of reality.',
      'registryNotFoundDetail':
          'Certificate not found in the Registry. This does not prove the file was modified; online publication may still be pending.',
      'registryUnavailableDetail':
          'The Registry is temporarily unavailable. The local file is not treated as invalid; try again when the connection is available.',
      'registryInvalidResponse': 'Unusable Registry response: {error}',
      'invalidLocalCertificate': 'Invalid local certificate: {error}',
      'unexpectedRegistryError':
          'Unexpected Registry verification error: {error}',
      'contentType': 'Type',
      'techHcvTrust': 'HCV trust',
      'techLiveTrust': 'Live capture trust',
      'techSceneAuthenticity': 'Scene authenticity',
      'techSyntheticRisk': 'Synthetic risk',
      'techAiProof': 'AI proof level',
      'techDisplayFusion': 'DISPLAY FUSION',
      'techDecision': 'Decision',
      'techRisk': 'Risk',
      'techScore': 'Score',
      'techPassive': 'PASSIVE VIDEO/IMAGE ANALYSIS',
      'techSegments': 'Segments analyzed',
      'techWorstSecond': 'Worst segment second',
      'techLocalFlicker': 'Local temporal flicker',
      'techRefreshBand': 'Refresh band',
      'techPixelGrid': 'Pixel-grid uniformity',
      'techLiveProbe': 'LIVE SCREEN PROBE',
      'techAnalysisStatus': 'Analysis status',
      'techFrames': 'Frames analyzed',
      'techReason': 'Reason',
      'techError': 'Error',
      'techFineStripe': 'Fine stripe',
      'techFineGrid': 'Fine grid',
      'techMoireFrequency': 'Moiré frequency',
      'techDynamicChallenge': 'Dynamic challenge',
      'techPersistentPattern': 'Persistent pattern',
      'techOpticalTrace': 'Optical corroborated trace',
      'techMoireTrace': 'Moiré trace',
      'techDynamicTrace': 'Dynamic screen challenge trace',
      'techUncorroborated': 'Uncorroborated display pattern',
      'techMl': 'ML SCREEN REPLAY',
      'techModelSource': 'Model source',
      'techModelVersion': 'Model version',
      'techRuntime': 'TFLite runtime',
      'techModelSha': 'Model SHA-256',
      'techPredictedClass': 'Predicted class',
      'techConfidence': 'Predicted confidence',
      'techScreenProbability': 'Screen probability',
      'techMlDecision': 'ML decision',
    },
    'es': {
      'unprovenDerivativeTitle': 'CONTENIDO ORIGINAL NO VERIFICADO',
      'unprovenDerivativeStatus': 'Original no verificado',
      'unprovenDerivativeDetail':
          'El SHA-256 difiere del original certificado. La huella solo indica semejanza y NO excluye objetos añadidos, texto superpuesto ni fotogramas alterados. Un HCV-ID válido no autentica esta copia.',
      'unprovenDerivativeProvenance': 'HCV-ID válido; archivo no autenticado',
      'unprovenDerivativeAxis': 'Semejanza sin prueba',
      'socialLimitedTitle':
          'CERTIFICADO IDENTIFICADO — INTEGRIDAD NO CONCLUYENTE',
      'socialLimitedStatus':
          'HCV-ID y certificado Registry válidos. La huella global V1 muestra similitud, pero no distingue recompresión de cambios de color, brillo o contenido.',
      'socialLimitedDetail':
          'El hash difiere del original. V1 no demuestra la integridad de la copia ni excluye ediciones visuales.',
      'quickCheck': 'Comprobación rápida de SIGILLUM en curso...',
      'fileUnavailable':
          'El archivo recibido no es accesible. Inténtalo de nuevo desde Verificar contenido.',
      'notCertified': 'Contenido no certificado por SIGILLUM.',
      'idDetectedAuto':
          'HCV-ID detectado. Verificación automática en Registry...',
      'autoIncomplete':
          'No se completó la verificación automática. El formato no se puede leer automáticamente: introduce el HCV-ID y pulsa VERIFICAR EN REGISTRY.',
      'iosImportFailed': 'El archivo seleccionado no se puede importar en iOS.',
      'selectOriginalNotPack':
          'Selecciona el archivo ORIGINAL que quieres verificar, no un archivo .hcv o .hcvpack.',
      'ocrDetectedMedia': 'HCV-ID detectado en el media.',
      'idDetectedPressVerify':
          'HCV-ID detectado. Ahora pulsa VERIFICAR EN REGISTRY.',
      'fileSelectedPressVerify':
          'Archivo seleccionado. Si está disponible, introduce o detecta el HCV-ID y pulsa VERIFICAR EN REGISTRY.',
      'enterId': 'Introduce el HCV-ID.',
      'selectOriginal': 'Selecciona el archivo original que quieres verificar.',
      'downloadingCertificate':
          'Recuperando el certificado del Registry HCV...',
      'signatureInvalid':
          'Se recuperó el certificado, pero su firma criptográfica no es válida.',
      'bindingMissing':
          'El certificado no contiene un vínculo válido con el contenido.',
      'mediaMissing': 'Archivo media no encontrado.',
      'forensicStatus':
          'ORIGINAL CERTIFICADO VERIFICADO\nEl archivo es idéntico al original certificado. El hash SHA-256 coincide.',
      'socialTextStatus':
          'CONTENIDO CERTIFICADO COMPATIBLE\nEl texto publicado incluye el pie SIGILLUM/HCV-ID y coincide con el contenido certificado, aunque el archivo no sea idéntico byte por byte.',
      'genericDerived':
          'CONTENIDO CERTIFICADO COMPATIBLE\nEl archivo difiere del original certificado, pero supera los controles de compatibilidad disponibles para este tipo de media.',
      'officialReferenceConforming':
          'COPIA CONFORME\nEl contenido coincide con la copia oficial SIGILLUM. Las diferencias detectadas son compatibles con recompresión social o transformaciones técnicas toleradas.',
      'officialReferenceConformingDetail':
          'La comparación local V3 es compatible con la huella firmada de la copia oficial SIGILLUM.',
      'officialReferenceModified':
          'COPIA MODIFICADA\nEl contenido presenta diferencias locales significativas respecto de la copia oficial SIGILLUM.',
      'officialReferenceModifiedDetail':
          'La comparación local V3 detectó cambios no compatibles únicamente con recompresión social, incluidas posibles inserciones, eliminaciones o alteraciones de elementos.',
      'officialReferenceInconclusive':
          'VERIFICACIÓN NO CONCLUYENTE\nLa copia oficial SIGILLUM está disponible, pero la comparación no aporta evidencia suficiente para clasificar el contenido como conforme o modificado.',
      'officialReferenceInconclusiveDetail':
          'La calidad, el recorte, las transformaciones o la alineación impiden una comparación local V3 fiable.',
      'officialReferenceConformingTitle': 'COPIA OFICIAL CONFORME',
      'officialReferenceModifiedTitle': 'COPIA OFICIAL MODIFICADA',
      'officialReferenceInconclusiveTitle': 'VERIFICACIÓN NO CONCLUYENTE',
      'officialReferenceUnavailableTitle': 'REFERENCIA OFICIAL NO DISPONIBLE',
      'officialReferenceUnavailable':
          'VERIFICACIÓN NO EJECUTABLE\nLa referencia oficial de SIGILLUM no puede verificarse actualmente en YouTube. No se usa un control más débil para declarar conforme el archivo social.',
      'officialReferenceUnavailableDetail':
          'La referencia de YouTube debe estar realmente presente, procesada y no listada antes de verificar una copia social. El estado de los comentarios es solo diagnóstico y no determina la validez de la referencia.',
      'manualCompareTitle': 'COMPARACIÓN MANUAL',
      'manualCompareAction': 'COMPARAR MANUALMENTE',
      'manualCompareSubscriberOnly':
          'Esta función está reservada a suscriptores de SIGILLUM.',
      'manualCompareIntro':
          'Comprueba personalmente las imágenes y el audio del archivo recibido y compáralos con la copia oficial publicada por SIGILLUM en YouTube.',
      'manualCompareAutomaticVerdict': 'Resultado automático',
      'manualCompareLocalTitle': 'ARCHIVO A COMPROBAR',
      'manualCompareOfficialTitle': 'COPIA OFICIAL SIGILLUM',
      'manualCompareVideoHelp':
          'Lleva el archivo al punto que quieres revisar y abre después la copia oficial en el mismo instante. Compara imágenes, voz, sonidos, cortes y secuencia.',
      'manualComparePhotoHelp':
          'Observa la foto recibida y abre después la copia oficial SIGILLUM en YouTube para realizar la comparación visual.',
      'manualCompareOpenOfficial': 'ABRIR COPIA OFICIAL',
      'manualCompareOpenAtTime': 'ABRIR COPIA OFICIAL EN {time}',
      'manualCompareReturnHelp':
          'YouTube se abre externamente. Vuelve a SIGILLUM para continuar la comparación.',
      'manualComparePlayPause': 'Reproducir / pausa',
      'manualCompareAudio': 'Audio',
      'manualCompareSubscriptionRequired':
          'Esta función requiere una suscripción SIGILLUM activa.',
      'manualCompareReferenceUnavailable':
          'La copia oficial de YouTube no se puede verificar en este momento.',
      'manualCompareMediaUnavailable':
          'El archivo que se va a comparar ya no está disponible en el dispositivo.',
      'manualCompareLoadError': 'No se puede preparar la comparación manual.',
      'manualCompareOpenError':
          'No se puede abrir la copia oficial en YouTube.',
      'verificationTiming':
          'Tiempo de verificación: {total} s · YouTube {youtube} s · comparación local {local} s',
      'techReferenceVerification': 'REFERENCIA OFICIAL DE YOUTUBE',
      'techReferenceMode': 'Modo de comparación',
      'techReferenceLive': 'Referencia YouTube activa',
      'techReferenceCommentsDisabled': 'Comentarios desactivados',
      'techReferenceServerMs': 'Control YouTube ms',
      'techReferenceLocalMs': 'Comparación local ms',
      'techVerificationTotalMs': 'Verificación total ms',
      'audioMismatchDetected':
          'El HCV-ID y la huella visual son compatibles, pero la huella de audio no coincide. El audio puede haber sido sustituido, eliminado o modificado más allá de la tolerancia de recompresión.',
      'audioMismatchProvided':
          'El HCV-ID introducido y la huella visual son compatibles, pero la huella de audio no coincide. La pista de audio certificada no está verificada.',
      'videoBothDetected':
          'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID detectado; certificado Registry válido; huellas espaciales visuales y de audio compatibles; no se puede determinar la causa de la diferencia SHA.',
      'videoBothProvided':
          'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID introducido; certificado Registry válido; huellas espaciales visuales y de audio compatibles; no se puede determinar la causa de la diferencia SHA.',
      'videoLegacyAudioDetected':
          'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID detectado y huella visual compatible. Certificado legacy anterior a la huella de audio.',
      'videoLegacyAudioProvided':
          'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID introducido y huella visual compatible. Certificado legacy anterior a la huella de audio.',
      'videoLegacyLimitedDetected':
          'CERTIFICADO LEGACY IDENTIFICADO\nHCV-ID detectado y certificado Registry válido, pero el certificado no contiene la huella visual moderna. La compatibilidad del media no puede confirmarse con la misma fuerza que en los certificados actuales.',
      'videoLegacyLimitedProvided':
          'CERTIFICADO LEGACY IDENTIFICADO\nHCV-ID introducido y certificado Registry válido, pero el certificado no contiene la huella visual moderna. La compatibilidad del media no puede confirmarse con la misma fuerza que en los certificados actuales.',
      'videoMismatchDetected':
          'HCV-ID detectado en el vídeo, pero la huella visual no coincide con el contenido certificado. Es posible que el HCV-ID se haya superpuesto a otro vídeo.',
      'videoMismatchProvided':
          'HCV-ID introducido, pero la huella visual no coincide. El vídeo seleccionado no es compatible con ese certificado.',
      'photoCompatibleDetected':
          'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID detectado; certificado Registry válido; huella espacial compatible; no se puede determinar la causa de la diferencia SHA.',
      'photoCompatibleProvided':
          'CONTENIDO CERTIFICADO COMPATIBLE\nHCV-ID introducido; certificado Registry válido; huella espacial compatible; no se puede determinar la causa de la diferencia SHA.',
      'photoLegacyDetected':
          'CERTIFICADO LEGACY IDENTIFICADO\nHCV-ID detectado y certificado Registry válido. El certificado es anterior a la huella de imagen moderna, por lo que la verificación de la copia es menos fuerte.',
      'photoLegacyProvided':
          'CERTIFICADO LEGACY IDENTIFICADO\nHCV-ID introducido y certificado Registry válido. El certificado es anterior a la huella de imagen moderna, por lo que la verificación de la copia es menos fuerte.',
      'photoMismatchDetected':
          'HCV-ID detectado en la foto, pero la huella de imagen no coincide. Es posible que el HCV-ID se haya superpuesto a otra foto.',
      'photoMismatchProvided':
          'HCV-ID introducido, pero la huella de imagen no coincide. La foto seleccionada no es compatible con ese certificado.',
      'idNotDetected':
          'El HCV-ID es válido en Registry, pero no se detectó automáticamente en el archivo seleccionado. La correspondencia del media no está verificada.',
      'sceneWarning':
          'ATENCIÓN: las señales técnicas son compatibles con una posible captura de pantalla ({risk}). El media sigue vinculado al certificado, pero la escena no debe interpretarse como una captura directa de la realidad.',
      'registryNotFoundDetail':
          'Certificado no encontrado en Registry. Esto no demuestra que el archivo haya sido modificado; la publicación en línea puede seguir pendiente.',
      'registryUnavailableDetail':
          'Registry no está disponible temporalmente. El archivo local no se considera inválido; inténtalo de nuevo cuando haya conexión.',
      'registryInvalidResponse': 'Respuesta de Registry no utilizable: {error}',
      'invalidLocalCertificate': 'Certificado local no válido: {error}',
      'unexpectedRegistryError':
          'Error inesperado durante la verificación de Registry: {error}',
      'contentType': 'Tipo',
      'techHcvTrust': 'Confianza HCV',
      'techLiveTrust': 'Confianza de captura live',
      'techSceneAuthenticity': 'Autenticidad de escena',
      'techSyntheticRisk': 'Riesgo sintético',
      'techAiProof': 'Nivel de prueba AI',
      'techDisplayFusion': 'FUSIÓN DE RIESGO DE PANTALLA',
      'techDecision': 'Decisión',
      'techRisk': 'Riesgo',
      'techScore': 'Puntuación',
      'techPassive': 'ANÁLISIS PASIVO DE VÍDEO/IMAGEN',
      'techSegments': 'Segmentos analizados',
      'techWorstSecond': 'Peor segundo',
      'techLocalFlicker': 'Parpadeo temporal local',
      'techRefreshBand': 'Banda de refresco',
      'techPixelGrid': 'Uniformidad de rejilla de píxeles',
      'techLiveProbe': 'PROBE LIVE DE PANTALLA',
      'techAnalysisStatus': 'Estado del análisis',
      'techFrames': 'Frames analizados',
      'techReason': 'Motivo',
      'techError': 'Error',
      'techFineStripe': 'Franjas finas',
      'techFineGrid': 'Rejilla fina',
      'techMoireFrequency': 'Frecuencia moiré',
      'techDynamicChallenge': 'Challenge dinámico',
      'techPersistentPattern': 'Patrón persistente',
      'techOpticalTrace': 'Traza óptica corroborada',
      'techMoireTrace': 'Traza moiré',
      'techDynamicTrace': 'Traza de challenge de pantalla',
      'techUncorroborated': 'Patrón de pantalla no corroborado',
      'techMl': 'ML CAPTURA DE PANTALLA',
      'techModelSource': 'Origen del modelo',
      'techModelVersion': 'Versión del modelo',
      'techRuntime': 'Runtime TFLite',
      'techModelSha': 'SHA-256 del modelo',
      'techPredictedClass': 'Clase prevista',
      'techConfidence': 'Confianza prevista',
      'techScreenProbability': 'Probabilidad de pantalla',
      'techMlDecision': 'Decisión ML',
    },
    'ru': {
      'unprovenDerivativeTitle': 'ПОДЛИННОСТЬ ОРИГИНАЛА НЕ ПОДТВЕРЖДЕНА',
      'unprovenDerivativeStatus': 'Оригинал не подтверждён',
      'unprovenDerivativeDetail':
          'SHA-256 отличается от сертифицированного оригинала. Отпечаток указывает лишь на сходство и НЕ исключает добавленные объекты, надписи или изменённые кадры. Действительный HCV-ID не подтверждает подлинность этой копии.',
      'unprovenDerivativeProvenance':
          'HCV-ID действителен; файл не подтверждён',
      'unprovenDerivativeAxis': 'Сходство не является доказательством',
      'socialLimitedTitle': 'СЕРТИФИКАТ НАЙДЕН — ЦЕЛОСТНОСТЬ НЕ УСТАНОВЛЕНА',
      'socialLimitedStatus':
          'HCV-ID и сертификат Registry действительны. Глобальный отпечаток V1 показывает сходство, но не отличает перекодирование от изменения цвета, яркости или содержимого.',
      'socialLimitedDetail':
          'Хеш отличается от оригинала. Сходство V1 не подтверждает целостность копии и не исключает визуальные изменения.',
      'quickCheck': 'Выполняется быстрая проверка SIGILLUM...',
      'fileUnavailable':
          'Полученный файл недоступен. Повторите через Проверку контента.',
      'notCertified': 'Контент не сертифицирован SIGILLUM.',
      'idDetectedAuto': 'HCV-ID обнаружен. Автоматическая проверка Registry...',
      'autoIncomplete':
          'Автоматическая проверка не завершена. Формат нельзя прочитать автоматически: введите HCV-ID и нажмите ПРОВЕРИТЬ В REGISTRY.',
      'iosImportFailed': 'Выбранный файл нельзя импортировать в iOS.',
      'selectOriginalNotPack':
          'Выберите ОРИГИНАЛЬНЫЙ файл для проверки, а не .hcv или .hcvpack.',
      'ocrDetectedMedia': 'HCV-ID обнаружен в медиа.',
      'idDetectedPressVerify':
          'HCV-ID обнаружен. Теперь нажмите ПРОВЕРИТЬ В REGISTRY.',
      'fileSelectedPressVerify':
          'Файл выбран. Если возможно, введите или определите HCV-ID и нажмите ПРОВЕРИТЬ В REGISTRY.',
      'enterId': 'Введите HCV-ID.',
      'selectOriginal': 'Выберите оригинальный файл для проверки.',
      'downloadingCertificate': 'Получение сертификата из HCV Registry...',
      'signatureInvalid':
          'Сертификат получен, но его криптографическая подпись недействительна.',
      'bindingMissing':
          'Сертификат не содержит действительной привязки к контенту.',
      'mediaMissing': 'Медиафайл не найден.',
      'forensicStatus':
          'СЕРТИФИЦИРОВАННЫЙ ОРИГИНАЛ ПОДТВЕРЖДЁН\nФайл идентичен сертифицированному оригиналу. SHA-256 совпадает.',
      'socialTextStatus':
          'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nОпубликованный текст содержит подпись SIGILLUM/HCV-ID и соответствует сертифицированному содержанию, хотя файл не идентичен побайтно.',
      'genericDerived':
          'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nФайл отличается от сертифицированного оригинала, но проходит доступные для этого типа медиа проверки совместимости.',
      'officialReferenceConforming':
          'СООТВЕТСТВУЮЩАЯ КОПИЯ\nСодержимое соответствует официальной копии SIGILLUM. Обнаруженные различия совместимы с допустимым социальным перекодированием или техническими преобразованиями.',
      'officialReferenceConformingDetail':
          'Локальное сравнение V3 совместимо с подписанным отпечатком официальной копии SIGILLUM.',
      'officialReferenceModified':
          'ИЗМЕНЁННАЯ КОПИЯ\nВ содержимом обнаружены значимые локальные отличия от официальной копии SIGILLUM.',
      'officialReferenceModifiedDetail':
          'Локальное сравнение V3 выявило изменения, не объясняемые только социальным перекодированием, включая возможное добавление, удаление или изменение элементов.',
      'officialReferenceInconclusive':
          'ПРОВЕРКА НЕ ДАЛА ОДНОЗНАЧНОГО РЕЗУЛЬТАТА\nОфициальная копия SIGILLUM доступна, но данных недостаточно, чтобы классифицировать содержимое как соответствующее или изменённое.',
      'officialReferenceInconclusiveDetail':
          'Качество, кадрирование, преобразования или выравнивание не позволяют выполнить надёжное локальное сравнение V3.',
      'officialReferenceConformingTitle': 'ОФИЦИАЛЬНАЯ КОПИЯ СООТВЕТСТВУЕТ',
      'officialReferenceModifiedTitle': 'ОФИЦИАЛЬНАЯ КОПИЯ ИЗМЕНЕНА',
      'officialReferenceInconclusiveTitle':
          'ПРОВЕРКА НЕ ДАЛА ОДНОЗНАЧНОГО РЕЗУЛЬТАТА',
      'officialReferenceUnavailableTitle': 'ОФИЦИАЛЬНЫЙ ЭТАЛОН НЕДОСТУПЕН',
      'officialReferenceUnavailable':
          'ПРОВЕРКА НЕ МОЖЕТ БЫТЬ ВЫПОЛНЕНА\nОфициальный эталон SIGILLUM сейчас нельзя подтвердить на YouTube. Более слабая проверка не используется для признания файла из соцсети соответствующим.',
      'officialReferenceUnavailableDetail':
          'Перед проверкой копии из соцсети эталон YouTube должен быть подтвержден как существующий, обработанный и доступный по unlisted-ссылке. Состояние комментариев остаётся только диагностическим и не определяет действительность эталона.',
      'manualCompareTitle': 'РУЧНОЕ СРАВНЕНИЕ',
      'manualCompareAction': 'СРАВНИТЬ ВРУЧНУЮ',
      'manualCompareSubscriberOnly': 'Функция доступна подписчикам SIGILLUM.',
      'manualCompareIntro':
          'Самостоятельно проверьте изображение и звук полученного файла и сравните их с официальной копией SIGILLUM, опубликованной на YouTube.',
      'manualCompareAutomaticVerdict': 'Автоматический результат',
      'manualCompareLocalTitle': 'ПРОВЕРЯЕМЫЙ ФАЙЛ',
      'manualCompareOfficialTitle': 'ОФИЦИАЛЬНАЯ КОПИЯ SIGILLUM',
      'manualCompareVideoHelp':
          'Перейдите в файле к нужному моменту, затем откройте официальную копию на том же времени. Сравните изображение, голос, звуки, монтаж и последовательность.',
      'manualComparePhotoHelp':
          'Рассмотрите полученную фотографию, затем откройте официальную копию SIGILLUM на YouTube для визуального сравнения.',
      'manualCompareOpenOfficial': 'ОТКРЫТЬ ОФИЦИАЛЬНУЮ КОПИЮ',
      'manualCompareOpenAtTime': 'ОТКРЫТЬ ОФИЦИАЛЬНУЮ КОПИЮ НА {time}',
      'manualCompareReturnHelp':
          'YouTube откроется во внешнем приложении. Вернитесь в SIGILLUM, чтобы продолжить сравнение.',
      'manualComparePlayPause': 'Воспроизведение / пауза',
      'manualCompareAudio': 'Звук',
      'manualCompareSubscriptionRequired':
          'Для этой функции требуется активная подписка SIGILLUM.',
      'manualCompareReferenceUnavailable':
          'Официальную копию YouTube сейчас невозможно подтвердить.',
      'manualCompareMediaUnavailable':
          'Проверяемый файл больше недоступен на устройстве.',
      'manualCompareLoadError': 'Не удалось подготовить ручное сравнение.',
      'manualCompareOpenError':
          'Не удалось открыть официальную копию на YouTube.',
      'verificationTiming':
          'Время проверки: {total} с · YouTube {youtube} с · локальное сравнение {local} с',
      'techReferenceVerification': 'ОФИЦИАЛЬНЫЙ ЭТАЛОН YOUTUBE',
      'techReferenceMode': 'Режим сравнения',
      'techReferenceLive': 'Эталон YouTube доступен',
      'techReferenceCommentsDisabled': 'Комментарии отключены',
      'techReferenceServerMs': 'Проверка YouTube, мс',
      'techReferenceLocalMs': 'Локальное сравнение, мс',
      'techVerificationTotalMs': 'Общее время проверки, мс',
      'audioMismatchDetected':
          'HCV-ID и визуальный отпечаток совместимы, но аудиоотпечаток не совпадает. Аудио могло быть заменено, удалено или изменено сверх допустимого при перекодировании.',
      'audioMismatchProvided':
          'Введённый HCV-ID и визуальный отпечаток совместимы, но аудиоотпечаток не совпадает. Сертифицированная аудиодорожка не подтверждена.',
      'videoBothDetected':
          'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID обнаружен; сертификат Registry действителен; пространственный визуальный и аудиоотпечатки совместимы; причина изменения SHA автоматически не определяется.',
      'videoBothProvided':
          'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID введён; сертификат Registry действителен; пространственный визуальный и аудиоотпечатки совместимы; причина изменения SHA автоматически не определяется.',
      'videoLegacyAudioDetected':
          'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID обнаружен, визуальный отпечаток совместим. Legacy-сертификат создан до внедрения аудиоотпечатка.',
      'videoLegacyAudioProvided':
          'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID введён, визуальный отпечаток совместим. Legacy-сертификат создан до внедрения аудиоотпечатка.',
      'videoLegacyLimitedDetected':
          'ОПРЕДЕЛЁН LEGACY-СЕРТИФИКАТ\nHCV-ID обнаружен и сертификат Registry действителен, но современного визуального отпечатка в сертификате нет. Совместимость медиа нельзя подтвердить с той же силой, что для текущих сертификатов.',
      'videoLegacyLimitedProvided':
          'ОПРЕДЕЛЁН LEGACY-СЕРТИФИКАТ\nHCV-ID введён и сертификат Registry действителен, но современного визуального отпечатка в сертификате нет. Совместимость медиа нельзя подтвердить с той же силой, что для текущих сертификатов.',
      'videoMismatchDetected':
          'HCV-ID обнаружен в видео, но визуальный отпечаток не совпадает с сертифицированным контентом. HCV-ID мог быть наложен на другое видео.',
      'videoMismatchProvided':
          'HCV-ID введён, но визуальный отпечаток не совпадает. Выбранное видео несовместимо с этим сертификатом.',
      'photoCompatibleDetected':
          'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID обнаружен; сертификат Registry действителен; пространственный отпечаток изображения совместим; причина изменения SHA автоматически не определяется.',
      'photoCompatibleProvided':
          'СОВМЕСТИМЫЙ СЕРТИФИЦИРОВАННЫЙ КОНТЕНТ\nHCV-ID введён; сертификат Registry действителен; пространственный отпечаток изображения совместим; причина изменения SHA автоматически не определяется.',
      'photoLegacyDetected':
          'ОПРЕДЕЛЁН LEGACY-СЕРТИФИКАТ\nHCV-ID обнаружен и сертификат Registry действителен. Сертификат создан до внедрения современного отпечатка изображения, поэтому проверка копии слабее.',
      'photoLegacyProvided':
          'ОПРЕДЕЛЁН LEGACY-СЕРТИФИКАТ\nHCV-ID введён и сертификат Registry действителен. Сертификат создан до внедрения современного отпечатка изображения, поэтому проверка копии слабее.',
      'photoMismatchDetected':
          'HCV-ID обнаружен на фото, но отпечаток изображения не совпадает. HCV-ID мог быть наложен на другое фото.',
      'photoMismatchProvided':
          'HCV-ID введён, но отпечаток изображения не совпадает. Выбранное фото несовместимо с этим сертификатом.',
      'idNotDetected':
          'HCV-ID действителен в Registry, но автоматически не обнаружен в выбранном файле. Соответствие медиа не подтверждено.',
      'sceneWarning':
          'ВНИМАНИЕ: технические сигналы соответствуют возможной съёмке с экрана ({risk}). Медиа остаётся связано с сертификатом, но сцену не следует считать прямой съёмкой реальности.',
      'registryNotFoundDetail':
          'Сертификат не найден в Registry. Это не доказывает изменение файла: онлайн-публикация может ещё ожидать завершения.',
      'registryUnavailableDetail':
          'Registry временно недоступен. Локальный файл не считается недействительным; повторите при наличии соединения.',
      'registryInvalidResponse': 'Непригодный ответ Registry: {error}',
      'invalidLocalCertificate':
          'Недействительный локальный сертификат: {error}',
      'unexpectedRegistryError':
          'Неожиданная ошибка проверки Registry: {error}',
      'contentType': 'Тип',
      'techHcvTrust': 'Доверие HCV',
      'techLiveTrust': 'Доверие live-захвату',
      'techSceneAuthenticity': 'Подлинность сцены',
      'techSyntheticRisk': 'Синтетический риск',
      'techAiProof': 'Уровень AI-доказательства',
      'techDisplayFusion': 'ОБЪЕДИНЕНИЕ РИСКА ЭКРАНА',
      'techDecision': 'Решение',
      'techRisk': 'Риск',
      'techScore': 'Оценка',
      'techPassive': 'ПАССИВНЫЙ АНАЛИЗ ВИДЕО/ИЗОБРАЖЕНИЯ',
      'techSegments': 'Проанализированные сегменты',
      'techWorstSecond': 'Худшая секунда',
      'techLocalFlicker': 'Локальное временное мерцание',
      'techRefreshBand': 'Полосы обновления',
      'techPixelGrid': 'Однородность пиксельной сетки',
      'techLiveProbe': 'LIVE-ПРОВЕРКА ЭКРАНА',
      'techAnalysisStatus': 'Статус анализа',
      'techFrames': 'Проанализированные кадры',
      'techReason': 'Причина',
      'techError': 'Ошибка',
      'techFineStripe': 'Тонкие полосы',
      'techFineGrid': 'Тонкая сетка',
      'techMoireFrequency': 'Частота муара',
      'techDynamicChallenge': 'Динамическая проверка',
      'techPersistentPattern': 'Устойчивый паттерн',
      'techOpticalTrace': 'Подтверждённый оптический след',
      'techMoireTrace': 'След муара',
      'techDynamicTrace': 'След динамической проверки экрана',
      'techUncorroborated': 'Неподтверждённый экранный паттерн',
      'techMl': 'ML СЪЁМКА С ЭКРАНА',
      'techModelSource': 'Источник модели',
      'techModelVersion': 'Версия модели',
      'techRuntime': 'Среда TFLite',
      'techModelSha': 'SHA-256 модели',
      'techPredictedClass': 'Предсказанный класс',
      'techConfidence': 'Уверенность',
      'techScreenProbability': 'Вероятность экрана',
      'techMlDecision': 'Решение ML',
    },
  };
}
