from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()

for forbidden in (
    '_captureProbeReady',
    'geometryOverride',
    'waitForSufficientMovement',
    'combineVideoDisplayRiskWithPreCaptureEvidence',
):
    if forbidden in camera:
        raise RuntimeError(
            f'Unsafe previous camera patch still present: {forbidden}. '
            'Build must start from the restored camera source.'
        )

camera = replace_once(
    camera,
    "import 'hcv_video_watermark.dart';",
    "import 'hcv_location_video_watermark.dart';",
    'video location watermark import',
)
camera = replace_once(
    camera,
    "import 'hcv_image_watermark.dart';",
    "import 'hcv_location_image_watermark.dart';\nimport 'hcv_capture_location.dart';",
    'photo location watermark import',
)

camera = replace_once(
    camera,
    """HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  return HCVDisplayRiskFusion.combine(analyses, liveCaptureOnly: true);
}

class CameraPage extends StatefulWidget {""",
    """HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  return HCVDisplayRiskFusion.combine(analyses, liveCaptureOnly: true);
}

HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final normalResult = HCVDisplayRiskFusion.combine(analyses);
  Map<String, dynamic>? liveProbe;
  for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
    if (analysis['type'] == 'SIGILLUM_LIVE_SCREEN_PROBE_V1') {
      liveProbe = analysis;
      break;
    }
  }
  if (liveProbe == null || liveProbe['videoEquivalentAvailable'] != true) {
    return normalResult;
  }

  final preCaptureResult = combinePhotoDisplayRiskFromPreCaptureEvidence([
    liveProbe,
  ]);
  int rank(String decision) {
    switch (decision) {
      case 'STRONG_DISPLAY_RISK':
        return 2;
      case 'NON_CONCLUSIVE':
        return 1;
      default:
        return 0;
    }
  }

  return rank(preCaptureResult.decision) > rank(normalResult.decision)
      ? preCaptureResult
      : normalResult;
}

class CameraPage extends StatefulWidget {""",
    'video pre-capture result alignment',
)

camera = replace_once(
    camera,
    """  final liveSignals = HCVLiveSignals();
  Map<String, dynamic>? lastLiveSignals;
  Map<String, dynamic>? pendingLiveScreenProbe;
  DateTime? pendingVideoCapturedAt;

  bool ready = false;""",
    """  final liveSignals = HCVLiveSignals();
  final HCVCaptureLocationService _locationService =
      const HCVCaptureLocationService();
  Map<String, dynamic>? lastLiveSignals;
  Map<String, dynamic>? pendingLiveScreenProbe;
  HCVCaptureLocation? pendingVideoLocation;
  HCVCaptureLocation? _lastCaptureLocation;
  DateTime? pendingVideoCapturedAt;
  bool _printCoordinates = false;
  bool _locationBusy = false;

  bool ready = false;""",
    'capture location state',
)

camera = replace_once(
    camera,
    """  String get _physicalProbeStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'
          : 'MOVE THE PHONE SLIGHTLY SIDEWAYS...';

  @override""",
    """  String get _physicalProbeStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'
          : 'MOVE THE PHONE SLIGHTLY SIDEWAYS...';

  Future<void> _showCaptureReadyMessage() async {
    if (!mounted) return;
    final italian = widget.languageCode.toLowerCase().startsWith('it');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          italian ? 'VERIFICA COMPLETATA' : 'VERIFICATION COMPLETE',
        ),
        content: Text(
          italian
              ? 'Riporta il telefono sull’inquadratura desiderata. Ora puoi procedere con la foto o il video.'
              : 'Return the phone to the desired composition. You can now proceed with the photo or video.',
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              italian ? 'ORA PUOI PROCEDERE' : 'PROCEED NOW',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCoordinateStamp() async {
    if (_locationBusy) return;
    if (_printCoordinates) {
      setState(() {
        _printCoordinates = false;
        _lastCaptureLocation = null;
      });
      _showLocationMessage(
        widget.languageCode.toLowerCase().startsWith('it')
            ? 'Coordinate non stampate.'
            : 'Coordinates will not be printed.',
      );
      return;
    }

    setState(() => _locationBusy = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _printCoordinates = true;
        _lastCaptureLocation = location;
      });
      _showLocationMessage(location.watermarkText);
    } catch (error) {
      if (mounted) _showLocationMessage(error.toString());
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<HCVCaptureLocation?> _locationForCapture() async {
    if (!_printCoordinates) return null;
    final cached = _lastCaptureLocation;
    if (cached != null &&
        DateTime.now().difference(cached.measuredAt).abs() <
            const Duration(minutes: 1)) {
      return cached;
    }

    setState(() {
      _locationBusy = true;
      status = widget.languageCode.toLowerCase().startsWith('it')
          ? 'ACQUISIZIONE COORDINATE...'
          : 'ACQUIRING COORDINATES...';
    });
    try {
      final location = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _lastCaptureLocation = location);
      return location;
    } catch (error) {
      if (mounted) {
        setState(() => status = 'READY');
        _showLocationMessage(error.toString());
      }
      return null;
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override""",
    'safe ready dialog and coordinate controls',
)

camera = replace_once(
    camera,
    """  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    setState(() {""",
    """  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) return;

    setState(() {""",
    'video resolves optional location before probe',
)
camera = replace_once(
    camera,
    """    try {
      pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();

      setState(() {""",
    """    try {
      pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
      pendingVideoLocation = captureLocation;
      await _showCaptureReadyMessage();

      setState(() {""",
    'video confirmation after original probe',
)
camera = replace_once(
    camera,
    """    } catch (e) {
      pendingVideoCapturedAt = null;
      setState(() {""",
    """    } catch (e) {
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;
      setState(() {""",
    'clear video location on start error',
)

camera = replace_once(
    camera,
    """      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
      pendingVideoCapturedAt = null;

      setState(() {""",
    """      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
      final captureLocation = pendingVideoLocation;
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;

      setState(() {""",
    'consume video location at stop',
)
camera = replace_once(
    camera,
    """      await processVideo(file.path, capturedAt: capturedAt);""",
    """      await processVideo(
        file.path,
        capturedAt: capturedAt,
        captureLocation: captureLocation,
      );""",
    'pass location to video processing',
)

camera = replace_once(
    camera,
    """  Future<void> takePhoto() async {
    if (controller == null) return;

    try {""",
    """  Future<void> takePhoto() async {
    if (controller == null) return;

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) return;

    try {""",
    'photo resolves optional location before probe',
)
camera = replace_once(
    camera,
    """      final liveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
      await _settleCameraAfterLiveProbe();""",
    """      final liveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
      await _showCaptureReadyMessage();
      await _settleCameraAfterLiveProbe();""",
    'photo confirmation after original probe',
)
camera = replace_once(
    camera,
    """      final publishedPhoto = await HCVImageWatermark().createPublishedPhoto(
        inputPath: savedPhotoPath,
        hcvId: preparedHcvId,
        capturedAt: capturedAt,
      );""",
    """      final publishedPhoto =
          await HCVLocationImageWatermark().createPublishedPhoto(
        inputPath: savedPhotoPath,
        hcvId: preparedHcvId,
        capturedAt: capturedAt,
        captureLocation: captureLocation,
      );""",
    'photo location watermark',
)
camera = replace_once(
    camera,
    """        \"captureCreatedAtLocal\": HCVCaptureTimestamp.format(capturedAt),
        \"liveScreenProbe\": liveScreenProbe,""",
    """        \"captureCreatedAtLocal\": HCVCaptureTimestamp.format(capturedAt),
        \"captureLocation\": captureLocation?.toJson(),
        \"locationPrinted\": captureLocation != null,
        \"liveScreenProbe\": liveScreenProbe,""",
    'photo signed location claim',
)

camera = replace_once(
    camera,
    """  Future<void> processVideo(String path, {DateTime? capturedAt}) async {""",
    """  Future<void> processVideo(
    String path, {
    DateTime? capturedAt,
    HCVCaptureLocation? captureLocation,
  }) async {""",
    'video processing location argument',
)
camera = replace_once(
    camera,
    """    final displayRisk = HCVDisplayRiskFusion.combine(screenReplayAnalyses);""",
    """    final displayRisk =
        combineVideoDisplayRiskFromCaptureEvidence(screenReplayAnalyses);""",
    'video uses same stronger pre-capture result as photo',
)
camera = replace_once(
    camera,
    """      savedVideoPath = await HCVVideoWatermark().createPublishedVideo(
        inputPath: savedVideoPath,
        hcvId: preparedHcvId,
        capturedAt: effectiveCapturedAt,
      );""",
    """      savedVideoPath =
          await HCVLocationVideoWatermark().createPublishedVideo(
        inputPath: savedVideoPath,
        hcvId: preparedHcvId,
        capturedAt: effectiveCapturedAt,
        captureLocation: captureLocation,
      );""",
    'video location watermark',
)
camera = replace_once(
    camera,
    """      \"captureCreatedAtLocal\": HCVCaptureTimestamp.format(effectiveCapturedAt),
      \"liveScreenProbe\": liveScreenProbe,""",
    """      \"captureCreatedAtLocal\": HCVCaptureTimestamp.format(effectiveCapturedAt),
      \"captureLocation\": captureLocation?.toJson(),
      \"locationPrinted\": captureLocation != null,
      \"liveScreenProbe\": liveScreenProbe,""",
    'video signed location claim',
)

camera = replace_once(
    camera,
    """        title: Text(_t('cameraTitle')),
        actions: [
          IconButton(
            icon: Icon(
              currentFlashMode == FlashMode.off""",
    """        title: Text(_t('cameraTitle')),
        actions: [
          IconButton(
            tooltip: widget.languageCode.toLowerCase().startsWith('it')
                ? 'Stampa coordinate GPS'
                : 'Print GPS coordinates',
            onPressed: _locationBusy ? null : _toggleCoordinateStamp,
            icon: Icon(
              _printCoordinates ? Icons.location_on : Icons.location_off,
              color: _printCoordinates ? Colors.greenAccent : Colors.white,
            ),
          ),
          IconButton(
            icon: Icon(
              currentFlashMode == FlashMode.off""",
    'camera location toggle',
)

camera_path.write_text(camera)


info_path = Path('ios/Runner/Info.plist')
info = info_path.read_text()
if 'NSLocationWhenInUseUsageDescription' not in info:
    info = replace_once(
        info,
        """\t<key>NSPhotoLibraryAddUsageDescription</key>
\t<string>SIGILLUM salva video verificati nella libreria.</string>
""",
        """\t<key>NSPhotoLibraryAddUsageDescription</key>
\t<string>SIGILLUM salva video verificati nella libreria.</string>

\t<key>NSLocationWhenInUseUsageDescription</key>
\t<string>Fotocamera Sigillum usa la posizione solo su richiesta per stampare e certificare le coordinate del luogo di acquisizione.</string>
""",
        'iOS location purpose',
    )
    info_path.write_text(info)


manifest_path = Path('android/app/src/main/AndroidManifest.xml')
manifest = manifest_path.read_text()
if 'android.permission.ACCESS_FINE_LOCATION' not in manifest:
    manifest = replace_once(
        manifest,
        """    <!-- CAMERA -->
    <uses-permission android:name=\"android.permission.CAMERA\" />
""",
        """    <!-- CAMERA -->
    <uses-permission android:name=\"android.permission.CAMERA\" />

    <!-- OPTIONAL LOCATION WATERMARK -->
    <uses-permission android:name=\"android.permission.ACCESS_FINE_LOCATION\" />
    <uses-permission android:name=\"android.permission.ACCESS_COARSE_LOCATION\" />
""",
        'Android location permissions',
    )
    manifest_path.write_text(manifest)


test_path = Path('test/capture_location_contract_test.dart')
test_path.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera preserves the original monitor probe and adds safe confirmation', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    expect(camera, contains('await _analyzeLiveScreenProbeWithoutFlash()'));
    expect(camera, contains('await _showCaptureReadyMessage()'));
    expect(camera, contains('combineVideoDisplayRiskFromCaptureEvidence'));
    expect(camera, isNot(contains('_captureProbeReady')));
    expect(camera, isNot(contains('geometryOverride')));
    expect(camera, isNot(contains('waitForSufficientMovement')));
  });

  test('coordinates are optional visible and signed capture metadata', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final location = File('lib/hcv_capture_location.dart').readAsStringSync();
    final photo = File('lib/hcv_location_image_watermark.dart').readAsStringSync();
    final video = File('lib/hcv_location_video_watermark.dart').readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(camera, contains('_printCoordinates = false'));
    expect(camera, contains('Icons.location_on'));
    expect(camera, contains('captureLocation?.toJson()'));
    expect(camera, contains('locationPrinted'));
    expect(location, contains('Geolocator.requestPermission()'));
    expect(photo, contains('captureLocation.watermarkText'));
    expect(video, contains('captureLocation.watermarkText'));
    expect(info, contains('NSLocationWhenInUseUsageDescription'));
  });
}
""")
