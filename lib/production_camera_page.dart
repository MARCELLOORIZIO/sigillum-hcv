import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'hcv_capture_timestamp.dart';
import 'hcv_display_risk_fusion.dart';
import 'hcv_engine.dart';
import 'hcv_image_watermark.dart';
import 'hcv_live_screen_probe.dart';
import 'hcv_live_signals.dart';
import 'hcv_ml_screen_replay_classifier.dart';
import 'hcv_package.dart';
import 'hcv_registry_service.dart';
import 'hcv_screen_replay_analyzer.dart';
import 'hcv_social_fingerprint.dart';
import 'hcv_trust_analyzer.dart';
import 'hcv_video_watermark.dart';

class ProductionCameraPage extends StatefulWidget {
  const ProductionCameraPage({
    super.key,
    this.initialPhotoMode = false,
  });

  final bool initialPhotoMode;

  @override
  State<ProductionCameraPage> createState() => _ProductionCameraPageState();
}

class _ProductionCameraPageState extends State<ProductionCameraPage> {
  static const MethodChannel _mediaChannel = MethodChannel('hcv.media');

  final HCVRegistryService _registry = const HCVRegistryService();
  final HCVLiveSignals _liveSignals = HCVLiveSignals();

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _ready = false;
  bool _busy = false;
  bool _recording = false;
  late bool _photoMode;
  FlashMode _flashMode = FlashMode.off;
  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;

  Map<String, dynamic>? _pendingVideoProbe;
  DateTime? _pendingVideoCapturedAt;

  String _status = 'Inizializzazione fotocamera...';
  String? _result;
  String? _mediaPath;
  String? _certificatePath;
  String? _packagePath;
  String? _hcvId;
  String? _displayDecision;
  String? _registryStatus;

  @override
  void initState() {
    super.initState();
    _photoMode = widget.initialPhotoMode;
    Future.microtask(_initializeCamera);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _setStatus('Nessuna fotocamera disponibile');
        return;
      }
      await _openCamera(_cameraIndex);
    } catch (error) {
      _setStatus('Errore fotocamera: $error');
    }
  }

  Future<void> _openCamera(int index) async {
    final previous = _controller;
    _ready = false;
    if (mounted) setState(() {});
    await previous?.dispose();

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    _minZoom = await controller.getMinZoomLevel();
    _maxZoom = await controller.getMaxZoomLevel();
    _zoom = _minZoom.clamp(_minZoom, _maxZoom).toDouble();
    await controller.setZoomLevel(_zoom);
    await controller.setFlashMode(FlashMode.off);

    _controller = controller;
    _flashMode = FlashMode.off;
    _ready = true;
    _setStatus('Pronta');
  }

  Future<void> _switchCamera() async {
    if (_busy || _recording || _cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(_cameraIndex);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (error) {
      _setStatus('Flash non disponibile: $error');
    }
  }

  Future<void> _setZoom(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    final safe = value.clamp(_minZoom, _maxZoom).toDouble();
    await controller.setZoomLevel(safe);
    if (mounted) setState(() => _zoom = safe);
  }

  void _setStatus(String value) {
    if (!mounted) return;
    setState(() => _status = value);
  }

  void _resetOutput() {
    _result = null;
    _mediaPath = null;
    _certificatePath = null;
    _packagePath = null;
    _hcvId = null;
    _displayDecision = null;
    _registryStatus = null;
  }

  Future<Map<String, dynamic>> _runPreCaptureProbe() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const {
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V2',
        'analysisStatus': 'NOT_ANALYZED',
        'displayRiskDecision': 'NOT_ANALYZED',
        'reason': 'CAMERA_NOT_READY',
      };
    }

    final flashToRestore = _flashMode;
    final zoomToRestore = _zoom;
    try {
      await controller.setFlashMode(FlashMode.off);
      await Future.delayed(const Duration(milliseconds: 250));
      final analysis = await HCVLiveScreenProbe().analyzePreview(
        controller,
        restoreZoomLevel: zoomToRestore,
      );
      analysis['flashSuppressedDuringProbe'] = flashToRestore != FlashMode.off;
      analysis['probeFlashMode'] = 'OFF';
      return analysis;
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.setZoomLevel(zoomToRestore);
        await Future.delayed(const Duration(milliseconds: 700));
      } catch (_) {}
      try {
        await controller.setFlashMode(flashToRestore);
        await Future.delayed(const Duration(milliseconds: 250));
      } catch (_) {}
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;

    setState(() {
      _busy = true;
      _resetOutput();
      _status = 'Analisi live prima dello scatto...';
    });

    try {
      final liveProbe = await _runPreCaptureProbe();
      _setStatus('Scatto foto...');
      await controller.setZoomLevel(_zoom);
      await Future.delayed(const Duration(milliseconds: 350));
      final capturedAt = DateTime.now();
      final raw = await controller.takePicture();

      _setStatus('Analisi ottica e ML...');
      final staticAnalysis = await _safeStaticImageAnalysis(raw.path);
      final mlAnalysis = await _safeMlImageAnalysis(raw.path);
      final displayRisk = HCVDisplayRiskFusion.combine(
        [liveProbe, staticAnalysis, mlAnalysis],
        liveCaptureOnly: true,
      );

      final engine = HCVEngine()..start();
      final preparedId = engine.hcvId;
      _setStatus('Applicazione watermark...');
      final publishedPath = await HCVImageWatermark().createPublishedPhoto(
        inputPath: raw.path,
        hcvId: preparedId,
        capturedAt: capturedAt,
      );
      final publishedFile = File(publishedPath);
      final publishedBytes = await publishedFile.readAsBytes();
      final contentHash = sha256.convert(publishedBytes).toString();
      final socialFingerprint = await _safeImageFingerprint(publishedPath);

      engine.setContent(
        type: 'photo',
        hash: contentHash,
        size: publishedBytes.length,
        name: p.basename(publishedPath),
      );
      engine.setClaims({
        'fileIntegrity': 'VERIFIED',
        'captureSource': 'HCV_CAMERA',
        'captureType': 'PHOTO',
        'liveCapture': true,
        'liveCaptureMode': 'STILL_CAPTURE',
        'displayRiskDecision': displayRisk.decision,
        'displayRiskEvidence': displayRisk.toJson(),
        'displayRiskMeaning': _displayRiskMeaning(displayRisk.decision),
        'screenReplayRisk': displayRisk.risk,
        'screenReplayRiskScore': displayRisk.score,
        'sceneAuthenticity': _sceneAuthenticity(displayRisk.decision, 'PHOTO'),
        'syntheticRisk': displayRisk.decision == 'STRONG_DISPLAY_RISK'
            ? 'POSSIBLE_SCREEN_REPLAY'
            : displayRisk.decision == 'NOT_ANALYZED'
                ? 'UNKNOWN'
                : 'REDUCED',
        'analysisStatus': displayRisk.analysisStatus,
        'aiProofLevel': 'MULTI_SOURCE_CAPTURE_V2',
        'captureCreatedAt': capturedAt.toUtc().toIso8601String(),
        'captureCreatedAtLocal': HCVCaptureTimestamp.format(capturedAt),
        'liveScreenProbe': liveProbe,
        'screenReplayAnalysis': staticAnalysis,
        'mlScreenReplayAnalysis': mlAnalysis,
        'mlScreenReplayAnalysisStatus': _analysisStatus(mlAnalysis),
        'watermark': 'SIGILLUM_VISIBLE',
        'socialVerification': true,
        'socialFingerprintAlgorithm': socialFingerprint?['algorithm'],
        'socialFingerprint': socialFingerprint,
      });
      engine.stop();

      _setStatus('Firma e verifica RSA locale...');
      final certificate = await engine.exportToFile();
      final package = await HCVPackage().createContentPackage(
        contentPath: publishedPath,
        hcvPath: certificate,
      );
      final registryStatus = await _queueAndPublish(certificate);
      await _saveToPhotos(publishedPath);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'VALID';
        _status = 'Foto certificata e verificata localmente';
        _mediaPath = publishedPath;
        _certificatePath = certificate;
        _packagePath = package;
        _hcvId = preparedId;
        _displayDecision = displayRisk.decision;
        _registryStatus = registryStatus;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'ERROR';
        _status = 'Errore foto: $error';
      });
    }
  }

  Future<void> _startVideo() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    setState(() {
      _busy = true;
      _resetOutput();
      _status = 'Analisi live prima della registrazione...';
    });

    try {
      _pendingVideoProbe = await _runPreCaptureProbe();
      await controller.setZoomLevel(_zoom);
      await Future.delayed(const Duration(milliseconds: 350));
      await controller.startVideoRecording();
      _pendingVideoCapturedAt = DateTime.now();
      try {
        await _liveSignals.start();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recording = true;
        _status = 'Registrazione in corso...';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recording = false;
        _status = 'Avvio video non riuscito: $error';
      });
    }
  }

  Future<void> _stopVideo() async {
    final controller = _controller;
    if (controller == null || !_recording || _busy) return;
    setState(() {
      _busy = true;
      _status = 'Chiusura registrazione...';
    });

    try {
      final raw = await controller.stopVideoRecording();
      Map<String, dynamic>? liveSignals;
      try {
        liveSignals = await _liveSignals.stopAndBuildSummary();
      } catch (_) {}
      final capturedAt = _pendingVideoCapturedAt ?? DateTime.now();
      final probe = _pendingVideoProbe ?? const <String, dynamic>{
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V2',
        'analysisStatus': 'NOT_ANALYZED',
        'displayRiskDecision': 'NOT_ANALYZED',
        'reason': 'LIVE_PROBE_MISSING',
      };
      _pendingVideoCapturedAt = null;
      _pendingVideoProbe = null;
      if (mounted) setState(() => _recording = false);
      await _processVideo(
        raw.path,
        capturedAt: capturedAt,
        liveProbe: probe,
        liveSignals: liveSignals,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recording = false;
        _status = 'Errore chiusura video: $error';
      });
    }
  }

  Future<void> _processVideo(
    String rawPath, {
    required DateTime capturedAt,
    required Map<String, dynamic> liveProbe,
    required Map<String, dynamic>? liveSignals,
  }) async {
    try {
      _setStatus('Analisi temporale e ML del video...');
      final passiveAnalysis = await _safeVideoAnalysis(rawPath);
      final mlAnalysis = await _safeMlVideoAnalysis(rawPath);
      final displayRisk = HCVDisplayRiskFusion.combine(
        [liveProbe, passiveAnalysis, mlAnalysis],
      );
      final trust = HCVTrustAnalyzer.analyze(
        liveSignals: liveSignals,
        audioCaptured: true,
        captureMode: 'field',
      );

      final engine = HCVEngine()..start();
      final preparedId = engine.hcvId;
      _setStatus('Applicazione watermark video...');
      final watermarked = await HCVVideoWatermark().createPublishedVideo(
        inputPath: rawPath,
        hcvId: preparedId,
        capturedAt: capturedAt,
      );
      final publishedPath = await _renamePublishedVideo(watermarked, preparedId);
      final publishedFile = File(publishedPath);
      final bytes = await publishedFile.readAsBytes();
      final contentHash = sha256.convert(bytes).toString();
      final socialFingerprint = await _safeVideoFingerprint(publishedPath);

      engine.setContent(
        type: 'video',
        hash: contentHash,
        size: bytes.length,
        name: p.basename(publishedPath),
      );
      engine.setClaims({
        'fileIntegrity': 'VERIFIED',
        'captureSource': 'HCV_CAMERA',
        'captureType': 'VIDEO',
        'captureMode': 'field',
        'liveCapture': true,
        'liveCaptureMode': 'PASSIVE_SENSOR_CAPTURE',
        'audioCaptured': true,
        'audioIncludedInVideoContainer': true,
        'sensorIntegrity': liveSignals == null ? 'NOT_RECORDED' : 'RECORDED',
        'displayRiskDecision': displayRisk.decision,
        'displayRiskEvidence': displayRisk.toJson(),
        'displayRiskMeaning': _displayRiskMeaning(displayRisk.decision),
        'screenReplayRisk': displayRisk.risk,
        'screenReplayRiskScore': displayRisk.score,
        'sceneAuthenticity': _sceneAuthenticity(displayRisk.decision, 'VIDEO'),
        'syntheticRisk': displayRisk.decision == 'STRONG_DISPLAY_RISK'
            ? 'POSSIBLE_SCREEN_REPLAY'
            : displayRisk.decision == 'NOT_ANALYZED'
                ? 'UNKNOWN'
                : 'REDUCED',
        'analysisStatus': displayRisk.analysisStatus,
        'aiProofLevel': 'MULTI_SOURCE_CAPTURE_V2',
        'trustLevel': trust['trustLevel'],
        'liveCaptureTrust': trust['liveCaptureTrust'],
        'passiveLiveProofScore': trust['score'],
        'audioTrust': trust['audioTrust'],
        'captureCreatedAt': capturedAt.toUtc().toIso8601String(),
        'captureCreatedAtLocal': HCVCaptureTimestamp.format(capturedAt),
        'liveScreenProbe': liveProbe,
        'screenReplayAnalysis': passiveAnalysis,
        'mlScreenReplayAnalysis': mlAnalysis,
        'mlScreenReplayAnalysisStatus': _analysisStatus(mlAnalysis),
        'watermark': 'SIGILLUM_VISIBLE_MP4',
        'publishedVideo': true,
        'socialVerification': true,
        'socialFingerprintAlgorithm': socialFingerprint?['algorithm'],
        'socialFingerprint': socialFingerprint,
      });
      if (liveSignals != null) engine.setLiveSignals(liveSignals);
      engine.stop();

      _setStatus('Firma e verifica RSA locale...');
      final certificate = await engine.exportToFile();
      final package = await HCVPackage().createContentPackage(
        contentPath: publishedPath,
        hcvPath: certificate,
      );
      final registryStatus = await _queueAndPublish(certificate);
      await _saveToPhotos(publishedPath);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'VALID';
        _status = 'Video certificato e verificato localmente';
        _mediaPath = publishedPath;
        _certificatePath = certificate;
        _packagePath = package;
        _hcvId = preparedId;
        _displayDecision = displayRisk.decision;
        _registryStatus = registryStatus;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'ERROR';
        _status = 'Errore elaborazione video: $error';
      });
    }
  }

  Future<Map<String, dynamic>> _safeStaticImageAnalysis(String path) async {
    try {
      return await HCVScreenReplayAnalyzer().analyzeImage(path);
    } catch (error) {
      return _analysisFailure('SIGILLUM_SCREEN_REPLAY_IMAGE_ANALYSIS_V1', error);
    }
  }

  Future<Map<String, dynamic>> _safeVideoAnalysis(String path) async {
    try {
      return await HCVScreenReplayAnalyzer().analyzeVideo(path);
    } catch (error) {
      return _analysisFailure('SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1', error);
    }
  }

  Future<Map<String, dynamic>> _safeMlImageAnalysis(String path) async {
    try {
      return await HCVMLScreenReplayClassifier.instance.analyzeImage(path);
    } catch (error) {
      return _analysisFailure('SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1', error);
    }
  }

  Future<Map<String, dynamic>> _safeMlVideoAnalysis(String path) async {
    try {
      return await HCVMLScreenReplayClassifier.instance.analyzeVideo(path);
    } catch (error) {
      return _analysisFailure('SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1', error);
    }
  }

  Map<String, dynamic> _analysisFailure(String type, Object error) {
    return {
      'type': type,
      'analysisStatus': 'NOT_ANALYZED',
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'reason': 'ANALYSIS_EXCEPTION',
      'error': error.toString(),
    };
  }

  Future<Map<String, dynamic>?> _safeImageFingerprint(String path) async {
    try {
      return await HCVSocialFingerprint().buildFromImage(path);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _safeVideoFingerprint(String path) async {
    try {
      return await HCVSocialFingerprint().buildFromVideo(path);
    } catch (_) {
      return null;
    }
  }

  Future<String> _queueAndPublish(String certificatePath) async {
    await _registry.enqueueCertificateFile(certificatePath);
    try {
      final report = await _registry.retryPendingUploads();
      if (report.pending == 0) return 'REGISTRY_CONFIRMED';
      return 'REGISTRY_PENDING (${report.pending})';
    } catch (_) {
      return 'REGISTRY_PENDING';
    }
  }

  Future<void> _saveToPhotos(String path) async {
    if (!Platform.isIOS) return;
    try {
      await _mediaChannel.invokeMethod<bool>('saveToPhotos', {'path': path});
    } catch (_) {}
  }

  Future<String> _renamePublishedVideo(String sourcePath, String hcvId) async {
    final source = File(sourcePath);
    final dir = await getApplicationDocumentsDirectory();
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final target = File(p.join(dir.path, 'hcv_video_$safeId.mp4'));
    if (await target.exists()) await target.delete();
    final copied = await source.copy(target.path);
    if (source.absolute.path != copied.absolute.path) {
      try {
        await source.delete();
      } catch (_) {}
    }
    return copied.path;
  }

  String _analysisStatus(Map<String, dynamic>? analysis) {
    if (analysis == null) return 'NOT_ANALYZED';
    return analysis['analysisStatus']?.toString() ??
        (analysis['screenReplayRiskScore'] == null ? 'NOT_ANALYZED' : 'ANALYZED');
  }

  String _displayRiskMeaning(String decision) {
    switch (decision) {
      case 'STRONG_DISPLAY_RISK':
        return 'Piu fonti indipendenti indicano una possibile ripresa da display.';
      case 'NON_CONCLUSIVE':
        return 'Sono presenti indizi compatibili con un display, ma non sufficienti per un verdetto forte.';
      case 'NOT_ANALYZED':
        return 'La qualita dell acquisizione non consente di escludere o confermare una ripresa da display.';
      default:
        return 'Le fonti analizzate non mostrano indizi tecnici sufficienti di ripresa da display.';
    }
  }

  String _sceneAuthenticity(String decision, String type) {
    switch (decision) {
      case 'STRONG_DISPLAY_RISK':
        return '${type}_CAPTURE_WITH_SCREEN_REPLAY_RISK';
      case 'NON_CONCLUSIVE':
        return '${type}_CAPTURE_SCENE_NON_CONCLUSIVE';
      case 'NOT_ANALYZED':
        return '${type}_CAPTURE_SCENE_NOT_ANALYZED';
      default:
        return '${type}_CAPTURE_NO_DISPLAY_EVIDENCE';
    }
  }

  Future<void> _shareOutputs() async {
    final paths = <XFile>[];
    for (final path in [_mediaPath, _certificatePath, _packagePath]) {
      if (path != null && await File(path).exists()) paths.add(XFile(path));
    }
    if (paths.isEmpty) return;
    await Share.shareXFiles(paths, text: _hcvId ?? 'SIGILLUM HCV');
  }

  Widget _info(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SelectableText('$label: $value', textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(_photoMode ? 'Foto verificabile' : 'Video verificabile'),
        actions: [
          IconButton(
            onPressed: _busy || _recording ? null : _switchCamera,
            icon: const Icon(Icons.cameraswitch),
          ),
          IconButton(
            onPressed: _busy || _recording ? null : _toggleFlash,
            icon: Icon(
              _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: _ready && controller != null
                  ? CameraPreview(controller)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          if (_ready)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Slider(
                value: _zoom.clamp(_minZoom, _maxZoom).toDouble(),
                min: _minZoom,
                max: _maxZoom <= _minZoom ? _minZoom + 0.01 : _maxZoom,
                onChanged: _busy || _recording ? null : _setZoom,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('FOTO'), icon: Icon(Icons.photo_camera)),
                    ButtonSegment(value: false, label: Text('VIDEO'), icon: Icon(Icons.videocam)),
                  ],
                  selected: {_photoMode},
                  onSelectionChanged: _busy || _recording
                      ? null
                      : (selection) => setState(() => _photoMode = selection.first),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: !_ready || _busy
                      ? null
                      : _photoMode
                          ? _capturePhoto
                          : _recording
                              ? _stopVideo
                              : _startVideo,
                  icon: Icon(
                    _photoMode
                        ? Icons.camera_alt
                        : _recording
                            ? Icons.stop
                            : Icons.fiber_manual_record,
                  ),
                  label: Text(
                    _photoMode
                        ? 'SCATTA E CERTIFICA'
                        : _recording
                            ? 'TERMINA E CERTIFICA'
                            : 'AVVIA REGISTRAZIONE',
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(_status, textAlign: TextAlign.center),
                if (_busy) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                _info('Esito', _result),
                _info('HCV-ID', _hcvId),
                _info('Scena', _displayDecision),
                _info('Registry', _registryStatus),
                if (_result == 'VALID') ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _shareOutputs,
                    icon: const Icon(Icons.share),
                    label: const Text('CONDIVIDI MEDIA + HCV + HCVPACK'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
