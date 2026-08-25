from pathlib import Path
import re

CAMERA = Path('lib/camera_page.dart')
CAMERA_COPY = Path('lib/camera_ui_extended_copy.dart')
QUICK = Path('lib/quick_hcv_media_gate_page.dart')
VERIFY_COPY = Path('lib/verification_ui_copy.dart')
REGISTRY = Path('lib/registry_verify_page.dart')


def require_replace(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    if old not in source:
        raise RuntimeError(f'{label} anchor missing')
    return source.replace(old, new, 1)


# 1) Capture gate: photo/video cannot arm until the live probe has enough
# actual lateral-motion geometry to measure parallax. These are the same
# eligibility minima already used by HCVSceneGeometryClassifier; no detector or
# fusion threshold is changed here.
camera = CAMERA.read_text(encoding='utf-8')

camera = require_replace(
    camera,
    "  bool _locationBusy = false;\n",
    "  bool _locationBusy = false;\n"
    "  bool _parallaxRetryRequired = false;\n",
    'camera parallax state',
)

helper = """  bool _hasRequiredParallax(Map<String, dynamic> probe) {
    final geometry = probe['geometryChallenge'];
    if (geometry is! Map) return false;

    final matchedRegions = (geometry['matchedRegions'] as num?)?.toInt() ?? 0;
    final motionMagnitude =
        (geometry['motionMagnitude'] as num?)?.toDouble() ?? 0.0;
    final flowReliability =
        (geometry['flowReliability'] as num?)?.toDouble() ?? 0.0;

    return matchedRegions >= 5 &&
        motionMagnitude >= 0.16 &&
        flowReliability >= 0.46;
  }

"""
if helper not in camera:
    anchor = "  String get _physicalProbeStatus => _c('physicalProbe');\n\n"
    if anchor not in camera:
        raise RuntimeError('camera physical-probe helper anchor missing')
    camera = camera.replace(anchor, anchor + helper, 1)

video_old = """        pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
        pendingVideoLocation = captureLocation;
        _videoArmed = true;
"""
video_new = """        pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
        if (!_hasRequiredParallax(pendingLiveScreenProbe!)) {
          pendingLiveScreenProbe = null;
          pendingVideoLocation = null;
          _videoArmed = false;
          _videoArmExpiresAt = null;
          _videoArmCameraIndex = null;
          _videoArmZoom = null;
          if (mounted) {
            setState(() {
              _parallaxRetryRequired = true;
              status = _c('parallaxRequired');
              recording = false;
            });
          }
          return;
        }
        if (mounted) {
          setState(() {
            _parallaxRetryRequired = false;
          });
        }
        pendingVideoLocation = captureLocation;
        _videoArmed = true;
"""
camera = require_replace(camera, video_old, video_new, 'video parallax gate')

photo_old = """        liveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
        _armedPhotoScreenProbe = liveScreenProbe;
        _armedPhotoLocation = captureLocation;
"""
photo_new = """        liveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
        if (!_hasRequiredParallax(liveScreenProbe)) {
          _armedPhotoScreenProbe = null;
          _armedPhotoLocation = null;
          _armedPhotoExpiresAt = null;
          _armedPhotoCameraIndex = null;
          _armedPhotoZoom = null;
          if (mounted) {
            setState(() {
              _parallaxRetryRequired = true;
              status = _c('parallaxRequired');
            });
          }
          return;
        }
        if (mounted) {
          setState(() {
            _parallaxRetryRequired = false;
          });
        }
        _armedPhotoScreenProbe = liveScreenProbe;
        _armedPhotoLocation = captureLocation;
"""
camera = require_replace(camera, photo_old, photo_new, 'photo parallax gate')

badge_old = """        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
"""
badge_new = """        style: TextStyle(
          color: _parallaxRetryRequired ? Colors.redAccent : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
"""
camera = require_replace(camera, badge_old, badge_new, 'camera red parallax status')

for token in [
    'bool _parallaxRetryRequired = false;',
    'bool _hasRequiredParallax(Map<String, dynamic> probe)',
    'matchedRegions >= 5',
    'motionMagnitude >= 0.16',
    'flowReliability >= 0.46',
    "status = _c('parallaxRequired');",
    '_parallaxRetryRequired ? Colors.redAccent : Colors.white',
]:
    if token not in camera:
        raise RuntimeError(f'camera parallax contract missing: {token}')
if camera.count('if (!_hasRequiredParallax(') < 2:
    raise RuntimeError('camera parallax gate must protect both photo and video')
CAMERA.write_text(camera, encoding='utf-8')

camera_copy = CAMERA_COPY.read_text(encoding='utf-8')
translations = {
    "'armedPhotoReady': 'INQUADRA E PREMI IL PULSANTE DI SCATTO',":
        "'armedPhotoReady': 'INQUADRA E PREMI IL PULSANTE DI SCATTO',\n"
        "      'parallaxRequired':\n"
        "          'MOVIMENTO INSUFFICIENTE — MUOVI IL TELEFONO LATERALMENTE E RIPROVA',",
    "'armedPhotoReady': 'COMPOSE AND PRESS THE SHUTTER BUTTON',":
        "'armedPhotoReady': 'COMPOSE AND PRESS THE SHUTTER BUTTON',\n"
        "      'parallaxRequired':\n"
        "          'NOT ENOUGH MOVEMENT — MOVE THE PHONE SIDEWAYS AND TRY AGAIN',",
    "'armedPhotoReady': 'ENCUADRA Y PULSA EL BOTÓN DE DISPARO',":
        "'armedPhotoReady': 'ENCUADRA Y PULSA EL BOTÓN DE DISPARO',\n"
        "      'parallaxRequired':\n"
        "          'MOVIMIENTO INSUFICIENTE — MUEVE EL TELÉFONO LATERALMENTE Y VUELVE A INTENTARLO',",
    "'armedPhotoReady': 'ВЫСТРОЙТЕ КАДР И НАЖМИТЕ КНОПКУ СЪЁМКИ',":
        "'armedPhotoReady': 'ВЫСТРОЙТЕ КАДР И НАЖМИТЕ КНОПКУ СЪЁМКИ',\n"
        "      'parallaxRequired':\n"
        "          'НЕДОСТАТОЧНО ДВИЖЕНИЯ — СДВИНЬТЕ ТЕЛЕФОН В СТОРОНУ И ПОВТОРИТЕ',",
}
if camera_copy.count("'parallaxRequired':") < 4:
    for old, new in translations.items():
        if old in camera_copy and new not in camera_copy:
            camera_copy = camera_copy.replace(old, new, 1)
if camera_copy.count("'parallaxRequired':") != 4:
    raise RuntimeError(
        f'camera parallax copy must exist in four languages; got '
        f'{camera_copy.count(chr(39) + "parallaxRequired" + chr(39) + ":")}'
    )
CAMERA_COPY.write_text(camera_copy, encoding='utf-8')


# 2) Quick HCV gate: reuse the robust, tested multi-pass OCR already present in
# the app instead of the weaker one-crop duplicate. Language does not affect
# detection.
quick = QUICK.read_text(encoding='utf-8')
if "import 'hcv_media_id_ocr.dart';" not in quick:
    import_anchor = "import 'registry_verify_page.dart';\n"
    if import_anchor not in quick:
        raise RuntimeError('quick-gate Registry import anchor missing')
    quick = quick.replace(
        import_anchor,
        "import 'hcv_media_id_ocr.dart';\n" + import_anchor,
        1,
    )

ocr_pattern = re.compile(
    r"  Future<String\?> _prepareUpperWatermarkImage\(String sourcePath\) async \{.*?"
    r"\n  Future<String\?> _checkVideo\(\) async \{",
    re.S,
)
ocr_replacement = """  Future<String?> _ocrImage(String sourcePath) async {
    return HCVMediaIdOcr.extractFromImage(sourcePath);
  }

  Future<String?> _checkVideo() async {"""
if 'return HCVMediaIdOcr.extractFromImage(sourcePath);' not in quick:
    quick, count = ocr_pattern.subn(ocr_replacement, quick, count=1)
    if count != 1:
        raise RuntimeError('quick-gate legacy OCR block anchor missing')

for token in [
    "import 'hcv_media_id_ocr.dart';",
    'return HCVMediaIdOcr.extractFromImage(sourcePath);',
]:
    if token not in quick:
        raise RuntimeError(f'quick-gate robust OCR contract missing: {token}')
QUICK.write_text(quick, encoding='utf-8')


# 3) Verification wording: hash mismatch + compatible HCV-ID/fingerprint does
# not prove a derivative. iOS Photos export, metadata, recompression or another
# transformation can all change bytes. State only what evidence supports.
verify_copy = VERIFY_COPY.read_text(encoding='utf-8')
copy_replacements = {
    "'compatibleDerivative': 'Derivato compatibile',":
        "'compatibleDerivative': 'Contenuto certificato compatibile',",
    "'compatible': 'Compatibile',":
        "'compatible': 'Non determinabile',",
    "'derivedDetail': 'File ricompresso o modificato, ma compatibile con il certificato.',":
        "'derivedDetail': 'I byte selezionati differiscono dall originale certificato, ma HCV-ID e fingerprint restano compatibili. La causa non è determinabile automaticamente.',",
    "'derivedDerivationDetail': 'Il file è una copia o versione ricompressa compatibile.',":
        "'derivedDerivationDetail': 'La rappresentazione selezionata differisce byte-per-byte dal file originale certificato; la causa non è determinabile automaticamente.',",
    "'socialOk': 'Contenuto derivato verificato',":
        "'socialOk': 'Contenuto certificato compatibile verificato',",
    "'socialOkDetail': 'Il file è stato ricompresso o rinominato, ma resta collegato al certificato SIGILLUM.',":
        "'socialOkDetail': 'HCV-ID e fingerprint collegano il file al certificato SIGILLUM, ma SHA-256 non coincide con il file originale registrato.',",

    "'compatibleDerivative': 'Compatible derivative',":
        "'compatibleDerivative': 'Certified compatible content',",
    "'compatible': 'Compatible',":
        "'compatible': 'Not determinable',",
    "'derivedDetail': 'The file was recompressed or changed but remains compatible with the certificate.',":
        "'derivedDetail': 'The selected bytes differ from the certified original, while HCV-ID and fingerprint remain compatible. The cause cannot be determined automatically.',",
    "'derivedDerivationDetail': 'The file is a compatible copy or recompressed version.',":
        "'derivedDerivationDetail': 'The selected representation differs byte-for-byte from the certified original; the cause cannot be determined automatically.',",
    "'socialOk': 'Derived content verified',":
        "'socialOk': 'Certified compatible content verified',",
    "'socialOkDetail': 'The file was recompressed or renamed but remains linked to the SIGILLUM certificate.',":
        "'socialOkDetail': 'HCV-ID and fingerprint link the file to the SIGILLUM certificate, but SHA-256 does not match the registered original.',",

    "'compatibleDerivative': 'Derivado compatible',":
        "'compatibleDerivative': 'Contenido certificado compatible',",
    "'compatible': 'Compatible',":
        "'compatible': 'No determinable',",
    "'derivedDetail': 'El archivo fue recomprimido o modificado, pero sigue siendo compatible con el certificado.',":
        "'derivedDetail': 'Los bytes seleccionados difieren del original certificado, pero HCV-ID y fingerprint siguen siendo compatibles. La causa no puede determinarse automáticamente.',",
    "'derivedDerivationDetail': 'El archivo es una copia o versión recomprimida compatible.',":
        "'derivedDerivationDetail': 'La representación seleccionada difiere byte a byte del original certificado; la causa no puede determinarse automáticamente.',",
    "'socialOk': 'Contenido derivado verificado',":
        "'socialOk': 'Contenido certificado compatible verificado',",
    "'socialOkDetail': 'El archivo fue recomprimido o renombrado, pero sigue vinculado al certificado SIGILLUM.',":
        "'socialOkDetail': 'HCV-ID y fingerprint vinculan el archivo al certificado SIGILLUM, pero SHA-256 no coincide con el original registrado.',",

    "'compatibleDerivative': 'Совместимая производная',":
        "'compatibleDerivative': 'Совместимый сертифицированный контент',",
    "'compatible': 'Совместимо',":
        "'compatible': 'Причина не определена',",
    "'derivedDetail': 'Файл был перекодирован или изменён, но совместим с сертификатом.',":
        "'derivedDetail': 'Выбранные байты отличаются от сертифицированного оригинала, но HCV-ID и fingerprint совместимы. Причина автоматически не определяется.',",
    "'derivedDerivationDetail': 'Файл является совместимой копией или перекодированной версией.',":
        "'derivedDerivationDetail': 'Выбранное представление побайтно отличается от сертифицированного оригинала; причина автоматически не определяется.',",
    "'socialOk': 'Производный контент подтверждён',":
        "'socialOk': 'Совместимый сертифицированный контент подтверждён',",
    "'socialOkDetail': 'Файл был перекодирован или переименован, но остаётся связан с сертификатом SIGILLUM.',":
        "'socialOkDetail': 'HCV-ID и fingerprint связывают файл с сертификатом SIGILLUM, но SHA-256 не совпадает с зарегистрированным оригиналом.',",
}
for old, new in copy_replacements.items():
    if old in verify_copy:
        verify_copy = verify_copy.replace(old, new)

for forbidden in [
    "'compatibleDerivative': 'Derivato compatibile',",
    "'compatibleDerivative': 'Compatible derivative',",
    "'compatibleDerivative': 'Derivado compatible',",
    "'compatibleDerivative': 'Совместимая производная',",
    "'socialOk': 'Contenuto derivato verificato',",
    "'socialOk': 'Derived content verified',",
    "'socialOk': 'Contenido derivado verificado',",
    "'socialOk': 'Производный контент подтверждён',",
]:
    if forbidden in verify_copy:
        raise RuntimeError(f'known-derivative public copy survived: {forbidden}')
VERIFY_COPY.write_text(verify_copy, encoding='utf-8')

registry = REGISTRY.read_text(encoding='utf-8')
registry = registry.replace(
    'Hash diverso perche il file e stato ricompresso o rinominato.',
    'Hash diverso; HCV-ID e fingerprint restano compatibili. '
    'La causa della differenza non e determinabile automaticamente.',
)
registry = registry.replace(
    'File ricompresso, rinominato o modificato dai social. '
    'HCV-ID e certificato Registry validi, ma hash non identico.',
    'Hash non identico al file certificato. HCV-ID e certificato Registry '
    'sono validi; la causa della differenza non e determinabile automaticamente.',
)
REGISTRY.write_text(registry, encoding='utf-8')

print(
    'RC2 photo parallax gate, robust HCV-ID OCR and evidence-neutral '
    'compatible-content verification finalized'
)
