from pathlib import Path

path = Path('lib/camera_page.dart')
source = path.read_text(encoding='utf-8')

# Presentation-only finalizer. It deliberately does not alter capture,
# screen-replay, geometry, ML scoring, signing or certificate claim logic.
if "import 'camera_ui_extended_copy.dart';" not in source:
    anchor = "import 'sigillum_localization.dart';\n"
    if anchor not in source:
        raise RuntimeError('camera localization import anchor missing')
    source = source.replace(
        anchor,
        anchor + "import 'camera_ui_extended_copy.dart';\n",
        1,
    )

# Remove an earlier RC2 base import if this finalizer is re-applied after a
# partially materialized workspace. ExtendedCopy delegates to CameraUiCopy.
source = source.replace("import 'camera_ui_copy.dart';\n", '')

if "String _c(String key)" not in source:
    anchor = "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n"
    if anchor not in source:
        raise RuntimeError('camera localization helper anchor missing')
    source = source.replace(
        anchor,
        anchor
        + "  String _c(String key) => CameraUiExtendedCopy.t(widget.languageCode, key);\n",
        1,
    )
else:
    source = source.replace(
        "String _c(String key) => CameraUiCopy.t(widget.languageCode, key);",
        "String _c(String key) => CameraUiExtendedCopy.t(widget.languageCode, key);",
    )

source = source.replace("  String status = 'INIT';", "  String status = '';")
source = source.replace(
    """  String get _physicalProbeStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'
          : 'MOVE THE PHONE SLIGHTLY SIDEWAYS...';""",
    "  String get _physicalProbeStatus => _c('physicalProbe');",
)

if "status = _c('initializing');" not in source:
    anchor = "    photoMode = widget.initialPhotoMode;\n    initCamera();"
    if anchor not in source:
        raise RuntimeError('camera init status anchor missing')
    source = source.replace(
        anchor,
        "    photoMode = widget.initialPhotoMode;\n    status = _c('initializing');\n    initCamera();",
        1,
    )

# Base camera runtime statuses.
replacements = {
    "status = 'NO CAMERA'": "status = _c('noCamera')",
    "status = 'READY'": "status = _c('ready')",
    "status = 'ERROR: $e'": "status = '${_c('error')}: $e'",
    "status = 'ZOOM ERROR: $e'": "status = '${_c('zoomError')}: $e'",
    "status = 'STARTING...'": "status = _c('starting')",
    "status = 'RECORDING...'": "status = _c('recording')",
    "status = 'ERROR START: $e'": "status = '${_c('startError')}: $e'",
    "status = 'PROCESSING VIDEO...'": "status = _c('processingVideo')",
    "status = 'STOP ERROR: $e'": "status = '${_c('stopError')}: $e'",
    "status = 'SCATTO FOTO...'": "status = _c('takingPhoto')",
    "status = 'ANALYZING SCREEN REPLAY RISK...'": "status = _c('analyzingScreen')",
    "status = 'ADDING SIGILLUM WATERMARK...'": "status = _c('addingWatermark')",
    "status = 'SAVING MP4 TO DOWNLOAD...'": "status = _c('savingVideo')",
    "status = 'ADDING SIGILLUM LOGO...'": "status = _c('addingLogo')",
    "status = 'CREATING HCV CERTIFICATE...'": "status = _c('creatingCertificate')",
    "status = 'WATERMARK ERROR: $e'": "status = '${_c('watermarkError')}: $e'",
    "status = 'RENAME ERROR: $e'": "status = '${_c('renameError')}: $e'",
    "status = 'PHOTO ERROR: $e'": "status = '${_c('photoError')}: $e'",
    "status = 'DONE'": "status = _c('done')",
    "registryStatus = 'Pubblicazione certificato nel Registry...'": "registryStatus = _c('registryPublishing')",
    "? 'Registry OK: ${hcvId ?? 'certificato pubblicato'}'": "? '${_c('registryOk')}: ${hcvId ?? _c('certificatePublished')}'",
    ": 'Certificato salvato: pubblicazione Registry in attesa'": ": _c('registryPending')",
    "'Certificato salvato localmente. Registry non raggiungibile: $e'": "'${_c('registryUnavailableLocal')}: $e'",
    "? 'Registry sincronizzato'": "? _c('registrySynced')",
    ": 'Registry: ${report.uploaded} pubblicati, ${report.pending} in attesa'": ": 'Registry: ${report.uploaded} ${_c('registryPublished')}, ${report.pending} ${_c('registryWaiting')}'",
    "setState(() => status = 'ERROR TEST: $e')": "setState(() => status = '${_c('error')}: $e')",
    "setState(() => status = 'NESSUN FILE DA CONDIVIDERE')": "setState(() => status = _c('noFileToShare'))",
    "setState(() => status = 'SHARE ERROR: $e')": "setState(() => status = '${_c('shareError')}: $e')",
    "setState(() => status = 'NESSUN PACCHETTO DA CONDIVIDERE')": "setState(() => status = _c('noPackToShare'))",
    "setState(() => status = 'SHARE PACK ERROR: $e')": "setState(() => status = '${_c('sharePackError')}: $e')",
}
for old, new in replacements.items():
    source = source.replace(old, new)

source = source.replace(
    "status = ok ? 'PHOTO VERIFIED' : 'PHOTO INVALID';",
    "status = ok ? _c('photoVerified') : _c('photoInvalid');",
)
source = source.replace(
    "const SnackBar(content: Text('HCV-ID copiato'))",
    "SnackBar(content: Text(_c('hcvCopied')))",
)
source = source.replace(
    "? 'Contenuto verificato SIGILLUM'\n            : 'Contenuto verificato SIGILLUM\\nID: $hcvId\\nVerify with SIGILLUM'",
    "? _c('verifiedContent')\n            : '${_c('verifiedContent')}\\nID: $hcvId\\nVerify with SIGILLUM'",
)

# Location/probe UI inserted by the safe-capture patcher.
source = source.replace(
    "    final italian = widget.languageCode.toLowerCase().startsWith('it');\n",
    '',
)
source = source.replace(
    "italian ? 'VERIFICA COMPLETATA' : 'VERIFICATION COMPLETE'",
    "_c('verificationCompleteTitle')",
)
source = source.replace(
    """italian
              ? 'Riporta il telefono sull’inquadratura desiderata. Ora puoi procedere con la foto o il video.'
              : 'Return the phone to the desired composition. You can now proceed with the photo or video.'""",
    "_c('returnPhoneInstruction')",
)
source = source.replace(
    "italian ? 'ORA PUOI PROCEDERE' : 'PROCEED NOW'",
    "_c('proceedNow')",
)
source = source.replace(
    """widget.languageCode.toLowerCase().startsWith('it')
            ? 'Coordinate non stampate.'
            : 'Coordinates will not be printed.'""",
    "_c('coordinatesOff')",
)
source = source.replace(
    """widget.languageCode.toLowerCase().startsWith('it')
          ? 'ACQUISIZIONE COORDINATE...'
          : 'ACQUIRING COORDINATES...'""",
    "_c('acquiringCoordinates')",
)
source = source.replace(
    """widget.languageCode.toLowerCase().startsWith('it')
                ? 'Stampa coordinate GPS'
                : 'Print GPS coordinates'""",
    "_c('printGpsCoordinates')",
)
source = source.replace(
    """widget.languageCode.toLowerCase().startsWith('it')
              ? 'PRONTO — PREMI REGISTRA PER INIZIARE'
              : 'READY — PRESS RECORD TO START'""",
    "_c('armedVideoReady')",
)
source = source.replace(
    """widget.languageCode.toLowerCase().startsWith('it')
              ? 'INQUADRA E PREMI IL PULSANTE DI SCATTO'
              : 'COMPOSE AND PRESS THE SHUTTER BUTTON'""",
    "_c('armedPhotoReady')",
)

# Post-certification transcription/subtitle UI introduced by older prelaunch
# patchers. Keep the derived-video feature, but make every visible label follow
# the selected app language.
subtitle_replacements = {
    "status = 'TRASCRIZIONE AUDIO...'": "status = _c('transcriptionAudio')",
    "status = 'TRASCRIZIONE PRONTA'": "status = _c('transcriptionReady')",
    "status = 'VIDEO SOTTOTITOLATO PRONTO'": "status = _c('captionedReady')",
    "? 'VIDEO SOTTOTITOLATO PRONTO — SALVATO IN FOTO'": "? _c('captionedReadyPhotos')",
    ": 'VIDEO SOTTOTITOLATO PRONTO — DISPONIBILE IN FILE'": ": _c('captionedReadyFiles')",
    "status = 'TRASCRIZIONE NON RIUSCITA: $error'": "status = '${_c('transcriptionFailed')}: $error'",
    "'Video SOTTOTITOLATO salvato in Foto'": "_c('captionedSavedPhotos')",
    "'Foto certificata salvata in Foto'": "_c('certifiedPhotoSaved')",
    "'Originale certificato salvato in Foto (senza sottotitoli)'": "_c('certifiedOriginalSaved')",
    "'Video sottotitolato disponibile in File; salvataggio in Foto non riuscito'": "_c('captionedAvailableFiles')",
    "'Non salvato in Foto: permesso non disponibile'": "_c('photosPermissionUnavailable')",
    "'Video sottotitolato salvato in Foto.'": "_c('captionedSavedPhotosSentence')",
    "'Non è stato possibile salvare il video sottotitolato in Foto.'": "_c('captionedSaveFailed')",
    "'Sottotitoli SIGILLUM'": "_c('subtitleShareText')",
    "'Copia video SIGILLUM con sottotitoli sincronizzati. L’originale certificato resta invariato.'": "_c('shareCaptionedText')",
}
for old, new in subtitle_replacements.items():
    source = source.replace(old, new)

source = source.replace(
    "title: const Text('Trascrizione audio')",
    "title: Text(_c('transcriptionTitle'))",
)
source = source.replace(
    "transcript.text.isEmpty ? 'Sottotitoli creati.' : transcript.text",
    "transcript.text.isEmpty ? _c('subtitlesCreated') : transcript.text",
)
source = source.replace(
    "child: const Text('CHIUDI')",
    "child: Text(_c('close'))",
)
source = source.replace(
    "? 'TRASCRIZIONE IN CORSO...'\n                    : 'CREA VIDEO CON SOTTOTITOLI'",
    "? _c('transcribing')\n                    : _c('createCaptionedVideo')",
)
source = source.replace(
    "? 'TRASCRIZIONE IN CORSO...'\n                    : 'TRASCRIVI AUDIO / CREA SOTTOTITOLI'",
    "? _c('transcribing')\n                    : _c('createCaptionedVideo')",
)
source = source.replace(
    "label: const Text('SALVA VIDEO SOTTOTITOLATO IN FOTO')",
    "label: Text(_c('saveCaptionedPhotos'))",
)
source = source.replace(
    "label: const Text('CONDIVIDI VIDEO SOTTOTITOLATO')",
    "label: Text(_c('shareCaptionedVideo'))",
)
source = source.replace(
    "label: const Text('CONDIVIDI SOTTOTITOLI .SRT')",
    "label: Text(_c('shareSrt'))",
)
source = source.replace(
    """const Text(
                  'Le scritte sono sincronizzate con l’audio e impresse nella copia video. L’originale certificato resta invariato.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                )""",
    """Text(
                  _c('captionExplanation'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )""",
)

# Friendly Apple Files card and guide labels.
source = source.replace(
    "const Text(\n            'DOVE TROVI I FILE'",
    "Text(\n            _c('filesWhere')",
)
source = source.replace(
    "const Text(\n            'File > Sul mio iPhone > Fotocamera Sigillum'",
    "Text(\n            _c('filesPath')",
)
source = source.replace(
    "const Text(\n            'SIGILLUM salva automaticamente qui i file principali. Non devi scegliere manualmente la cartella.'",
    "Text(\n            _c('filesExplanation')",
)
# When const was removed from Text above, its style must remain const-safe.
source = source.replace(
    "Text(\n            _c('filesWhere'),\n            textAlign: TextAlign.center,\n            style: TextStyle(",
    "Text(\n            _c('filesWhere'),\n            textAlign: TextAlign.center,\n            style: const TextStyle(",
)
source = source.replace(
    "Text(\n            _c('filesPath'),\n            textAlign: TextAlign.center,\n            style: TextStyle(",
    "Text(\n            _c('filesPath'),\n            textAlign: TextAlign.center,\n            style: const TextStyle(",
)
source = source.replace(
    "Text(\n            _c('filesExplanation'),\n            textAlign: TextAlign.center,\n            style: TextStyle(",
    "Text(\n            _c('filesExplanation'),\n            textAlign: TextAlign.center,\n            style: const TextStyle(",
)
source = source.replace(
    "Text('Originale certificato: ${fileName(videoPath)}'",
    "Text('${_c('certifiedOriginal')}: ${fileName(videoPath)}'",
)
source = source.replace(
    "Text('Certificato HCV: ${fileName(hcvPath)}'",
    "Text('${_c('hcvCertificate')}: ${fileName(hcvPath)}'",
)
source = source.replace(
    "'Video sottotitolato: ${fileName(_captionedVideoPath)}'",
    "'${_c('captionedVideo')}: ${fileName(_captionedVideoPath)}'",
)
source = source.replace(
    "Text('Sottotitoli SRT: ${fileName(_subtitlePath)}'",
    "Text('${_c('srtSubtitles')}: ${fileName(_subtitlePath)}'",
)
source = source.replace(
    "label: const Text('GUIDA RAPIDA')",
    "label: Text(_c('quickGuide'))",
)
source = source.replace(
    "tooltip: 'Guida rapida'",
    "tooltip: _c('quickGuideTooltip')",
)

# Base result/share UI.
source = source.replace(
    "? 'Salvato anche in Foto'\n              : '$registryStatus\\nSalvato anche in Foto'",
    "? _c('savedToPhotos')\n              : '$registryStatus\\n${_c('savedToPhotos')}'",
)
source = source.replace(
    "? 'Non salvato in Foto: permesso non disponibile'\n              : '$registryStatus\\nNon salvato in Foto: permesso non disponibile'",
    "? _c('photosPermissionUnavailable')\n              : '$registryStatus\\n${_c('photosPermissionUnavailable')}'",
)
source = source.replace(
    "    if (createdContentKind == 'photo') return 'foto';\n    if (createdContentKind == 'video') return 'video';\n    return 'contenuto';",
    "    if (createdContentKind == 'photo') return _c('photoLower');\n    if (createdContentKind == 'video') return _c('videoLower');\n    return _c('contentLower');",
)
source = source.replace(
    "    if (createdContentKind == 'photo') return 'Foto';\n    if (createdContentKind == 'video') return 'Video';\n    return 'Contenuto';",
    "    if (createdContentKind == 'photo') return _c('photoTitle');\n    if (createdContentKind == 'video') return _c('videoTitle');\n    return _c('contentTitle');",
)
source = source.replace(
    "verified ? 'HUMAN VERIFIED' : 'NOT VERIFIED'",
    "verified ? _c('humanVerified') : _c('notVerified')",
)
source = source.replace(
    "'${_createdFileLabel} verificabile creato'",
    "'${_createdFileLabel}: ${_c('verifiableCreated')}'",
)
source = source.replace(
    """'${_createdFileLabel}, certificato HCV e HCVPACK sono collegati dallo stesso HCV-ID. '
              'La verifica online usa HCV-ID e Registry.'""",
    "'${_createdFileLabel}, ${_t('certificate')} HCV, HCVPACK: ${_c('linkedFiles')}'",
)
source = source.replace(
    "label: const Text('COPIA HCV-ID')",
    "label: Text(_c('copyHcvId'))",
)

# Technical claim values and detector reasons remain stable English identifiers.
# Any binary IT/EN selector left in CameraPage now represents an incomplete
# public-localization path and must fail the build.
for forbidden in [
    "widget.languageCode.toLowerCase().startsWith('it')",
    "'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'",
    "'MOVE THE PHONE SLIGHTLY SIDEWAYS...'",
    "'VERIFICA COMPLETATA'",
    "'PRONTO — PREMI REGISTRA PER INIZIARE'",
    "'INQUADRA E PREMI IL PULSANTE DI SCATTO'",
    "status = 'STARTING...'",
    "status = 'RECORDING...'",
    "status = 'PROCESSING VIDEO...'",
    "status = 'SCATTO FOTO...'",
    "status = 'ANALYZING SCREEN REPLAY RISK...'",
    "status = 'ADDING SIGILLUM LOGO...'",
    "status = 'CREATING HCV CERTIFICATE...'",
    "status = 'DONE'",
    "'TRASCRIZIONE AUDIO...'",
    "'TRASCRIZIONE IN CORSO...'",
    "'CREA VIDEO CON SOTTOTITOLI'",
    "'CONDIVIDI VIDEO SOTTOTITOLATO'",
    "'DOVE TROVI I FILE'",
]:
    if forbidden in source:
        raise RuntimeError(f'camera hard-coded public copy survived finalizer: {forbidden}')

required = [
    "import 'camera_ui_extended_copy.dart';",
    "CameraUiExtendedCopy.t(widget.languageCode, key)",
    "_c('physicalProbe')",
    "_c('verificationCompleteTitle')",
    "_c('armedVideoReady')",
    "_c('armedPhotoReady')",
    "_c('analyzingScreen')",
    "_c('registryPublishing')",
    "_c('createCaptionedVideo')",
    "_c('filesWhere')",
    "_c('humanVerified')",
]
for token in required:
    if token not in source:
        raise RuntimeError(f'camera localized public copy missing: {token}')

path.write_text(source, encoding='utf-8')
print('Complete Camera/probe/location/subtitle UI localized for IT/EN/ES/RU without detector changes')
