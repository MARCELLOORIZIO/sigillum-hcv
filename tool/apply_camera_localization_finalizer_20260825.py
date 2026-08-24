from pathlib import Path

path = Path('lib/camera_page.dart')
source = path.read_text(encoding='utf-8')

# Presentation-only finalizer. It deliberately does not alter capture,
# screen-replay, geometry, ML scoring, signing or certificate claim logic.
if "import 'camera_ui_copy.dart';" not in source:
    anchor = "import 'sigillum_localization.dart';\n"
    if anchor not in source:
        raise RuntimeError('camera localization import anchor missing')
    source = source.replace(anchor, anchor + "import 'camera_ui_copy.dart';\n", 1)

if "String _c(String key)" not in source:
    anchor = "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n"
    if anchor not in source:
        raise RuntimeError('camera localization helper anchor missing')
    source = source.replace(
        anchor,
        anchor + "  String _c(String key) => CameraUiCopy.t(widget.languageCode, key);\n",
        1,
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

# The phrase below is intentionally internal metadata and must not be localized:
# displayRiskMeaning, HCV enums, signature claims and ML model labels stay stable.
for forbidden in [
    "widget.languageCode.toLowerCase().startsWith('it')",
    "'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'",
    "'MOVE THE PHONE SLIGHTLY SIDEWAYS...'",
    "status = 'STARTING...'",
    "status = 'RECORDING...'",
    "status = 'PROCESSING VIDEO...'",
    "status = 'SCATTO FOTO...'",
    "status = 'ANALYZING SCREEN REPLAY RISK...'",
    "status = 'ADDING SIGILLUM LOGO...'",
    "status = 'CREATING HCV CERTIFICATE...'",
    "status = 'DONE'",
]:
    if forbidden in source:
        raise RuntimeError(f'camera hard-coded public copy survived finalizer: {forbidden}')

required = [
    "import 'camera_ui_copy.dart';",
    "CameraUiCopy.t(widget.languageCode, key)",
    "_c('physicalProbe')",
    "_c('analyzingScreen')",
    "_c('registryPublishing')",
    "_c('humanVerified')",
]
for token in required:
    if token not in source:
        raise RuntimeError(f'camera localized public copy missing: {token}')

path.write_text(source, encoding='utf-8')
print('Camera runtime/public UI localized for IT/EN/ES/RU without detector changes')
