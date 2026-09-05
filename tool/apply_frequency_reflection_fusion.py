from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# New illumination-response probe (Flutter camera, fixed exposure, torch OFF/ON)
# ---------------------------------------------------------------------------
illumination_path = Path('lib/hcv_illumination_response_probe.dart')
illumination_path.write_text(r'''import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';

/// Measures how strongly the framed scene responds to a brief external light
/// pulse while exposure is locked. This is deliberately asymmetric evidence:
/// a strong response can support a reflective-surface conflict, while a weak
/// response never proves that the scene is a display.
class HCVIlluminationResponseProbe {
  const HCVIlluminationResponseProbe();

  static const int framesPerPhase = 4;
  static const Duration phaseTimeout = Duration(milliseconds: 900);
  static const Duration torchSettle = Duration(milliseconds: 110);
  static const Duration opticalRestoreSettle = Duration(milliseconds: 250);

  Future<Map<String, dynamic>> capture(
    CameraController controller, {
    required FlashMode restoreFlash,
  }) async {
    if (!controller.value.isInitialized || controller.value.isRecordingVideo) {
      return unavailable('CAMERA_NOT_READY_FOR_ILLUMINATION_RESPONSE');
    }

    final offFrames = <List<double>>[];
    final onFrames = <List<double>>[];
    final offReady = Completer<void>();
    final onReady = Completer<void>();
    var phase = 0; // 0=OFF, 1=transition, 2=ON, 3=finished
    var streamStarted = false;
    var exposureLockApplied = false;
    var torchApplied = false;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.setFlashMode(FlashMode.off);

      try {
        await controller.setExposureMode(ExposureMode.locked);
        exposureLockApplied = true;
      } catch (_) {
        exposureLockApplied = false;
      }

      await Future.delayed(const Duration(milliseconds: 70));

      await controller.startImageStream((image) {
        if (phase != 0 && phase != 2) return;
        final cells = _cellLuma(image);
        if (cells == null || cells.length != 9) return;
        if (phase == 0) {
          if (offFrames.length < framesPerPhase) offFrames.add(cells);
          if (offFrames.length >= framesPerPhase && !offReady.isCompleted) {
            phase = 1;
            offReady.complete();
          }
        } else if (phase == 2) {
          if (onFrames.length < framesPerPhase) onFrames.add(cells);
          if (onFrames.length >= framesPerPhase && !onReady.isCompleted) {
            phase = 3;
            onReady.complete();
          }
        }
      });
      streamStarted = true;

      await offReady.future.timeout(phaseTimeout);

      try {
        await controller.setFlashMode(FlashMode.torch);
        torchApplied = true;
      } catch (error) {
        return unavailable(
          'TORCH_UNAVAILABLE_FOR_ILLUMINATION_RESPONSE',
          error: error,
          extra: {
            'offFramesCaptured': offFrames.length,
            'exposureLockApplied': exposureLockApplied,
          },
        );
      }

      await Future.delayed(torchSettle);
      phase = 2;
      await onReady.future.timeout(phaseTimeout);

      return _analyze(
        offFrames: offFrames,
        onFrames: onFrames,
        exposureLockApplied: exposureLockApplied,
        torchApplied: torchApplied,
      );
    } on TimeoutException catch (error) {
      return unavailable(
        'ILLUMINATION_RESPONSE_FRAME_TIMEOUT',
        error: error,
        extra: {
          'offFramesCaptured': offFrames.length,
          'onFramesCaptured': onFrames.length,
          'exposureLockApplied': exposureLockApplied,
          'torchApplied': torchApplied,
        },
      );
    } catch (error) {
      return unavailable(
        'ILLUMINATION_RESPONSE_CAPTURE_FAILED',
        error: error,
        extra: {
          'offFramesCaptured': offFrames.length,
          'onFramesCaptured': onFrames.length,
          'exposureLockApplied': exposureLockApplied,
          'torchApplied': torchApplied,
        },
      );
    } finally {
      phase = 3;
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (streamStarted && controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }
      try {
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setExposurePoint(null);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFocusPoint(null);
      } catch (_) {}
      try {
        await controller.setFlashMode(restoreFlash);
      } catch (_) {}
      await Future.delayed(opticalRestoreSettle);
    }
  }

  Map<String, dynamic> _analyze({
    required List<List<double>> offFrames,
    required List<List<double>> onFrames,
    required bool exposureLockApplied,
    required bool torchApplied,
  }) {
    if (offFrames.length < framesPerPhase ||
        onFrames.length < framesPerPhase ||
        offFrames.any((f) => f.length != 9) ||
        onFrames.any((f) => f.length != 9)) {
      return unavailable('ILLUMINATION_RESPONSE_NOT_ENOUGH_VALID_FRAMES');
    }

    final offCells = List<double>.generate(9, (cell) {
      final values = offFrames.map((f) => f[cell]).toList()..sort();
      return _median(values);
    });
    final onCells = List<double>.generate(9, (cell) {
      final values = onFrames.map((f) => f[cell]).toList()..sort();
      return _median(values);
    });

    final absoluteIncrease = <double>[];
    final relativeIncrease = <double>[];
    var responsiveCellCount = 0;
    var saturatedCellCount = 0;
    for (var i = 0; i < 9; i++) {
      final delta = onCells[i] - offCells[i];
      final relative = delta / max(0.05, offCells[i]);
      absoluteIncrease.add(delta);
      relativeIncrease.add(relative);
      if (delta >= 0.08 && relative >= 0.20) responsiveCellCount++;
      if (onCells[i] >= 0.98) saturatedCellCount++;
    }

    final absSorted = List<double>.from(absoluteIncrease)..sort();
    final relSorted = List<double>.from(relativeIncrease)..sort();
    final medianAbsoluteIncrease = _median(absSorted);
    final medianRelativeIncrease = _median(relSorted);
    final lowerQuartileRelativeIncrease = relSorted[2];

    // Intentionally stringent. This is not a generic reality classifier; it
    // only marks a large, spatially broad response to external illumination.
    final qualitySufficient = exposureLockApplied &&
        torchApplied &&
        saturatedCellCount <= 6;
    final strongReflectiveResponse = qualitySufficient &&
        medianAbsoluteIncrease >= 0.12 &&
        medianRelativeIncrease >= 0.35 &&
        lowerQuartileRelativeIncrease >= 0.20 &&
        responsiveCellCount >= 7;

    return {
      'type': 'SIGILLUM_ILLUMINATION_RESPONSE_PROBE_V1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'CONSERVATIVE_REFLECTION_CONFLICT_SUPPORT_ONLY',
      'captureSource': 'FLUTTER_CAMERA_IMAGE_STREAM_FIXED_EXPOSURE_TORCH_OFF_ON',
      'exposureLockApplied': exposureLockApplied,
      'torchApplied': torchApplied,
      'framesPerPhaseTarget': framesPerPhase,
      'offFramesAnalyzed': offFrames.length,
      'onFramesAnalyzed': onFrames.length,
      'offCellLumaMedians': offCells,
      'onCellLumaMedians': onCells,
      'cellAbsoluteLumaIncrease': absoluteIncrease,
      'cellRelativeLumaIncrease': relativeIncrease,
      'medianAbsoluteLumaIncrease': medianAbsoluteIncrease,
      'medianRelativeLumaIncrease': medianRelativeIncrease,
      'lowerQuartileRelativeLumaIncrease': lowerQuartileRelativeIncrease,
      'responsiveCellCount': responsiveCellCount,
      'saturatedCellCount': saturatedCellCount,
      'measurementQualitySufficient': qualitySufficient,
      'strongReflectiveResponse': strongReflectiveResponse,
      'note':
          'A strong response supports a reflective-surface conflict only. A weak response never proves display emission.',
    };
  }

  static Map<String, dynamic> unavailable(
    String reason, {
    Object? error,
    Map<String, dynamic>? extra,
  }) {
    return {
      'type': 'SIGILLUM_ILLUMINATION_RESPONSE_PROBE_V1',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole': 'CONSERVATIVE_REFLECTION_CONFLICT_SUPPORT_ONLY',
      'reason': reason,
      if (error != null) 'error': error.toString(),
      if (extra != null) ...extra,
    };
  }

  List<double>? _cellLuma(CameraImage image) {
    if (image.width < 3 || image.height < 3 || image.planes.isEmpty) {
      return null;
    }
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;
    final bytesPerPixel = plane.bytesPerPixel ?? 1;
    if (bytesPerRow <= 0 || bytesPerPixel <= 0 || bytes.isEmpty) return null;

    final result = <double>[];
    for (var gridRow = 0; gridRow < 3; gridRow++) {
      for (var gridColumn = 0; gridColumn < 3; gridColumn++) {
        final x0 = image.width * gridColumn ~/ 3;
        final x1 = image.width * (gridColumn + 1) ~/ 3;
        final y0 = image.height * gridRow ~/ 3;
        final y1 = image.height * (gridRow + 1) ~/ 3;
        final xStep = max(1, (x1 - x0) ~/ 14);
        final yStep = max(1, (y1 - y0) ~/ 14);
        var sum = 0.0;
        var count = 0;

        for (var y = y0; y < y1; y += yStep) {
          for (var x = x0; x < x1; x += xStep) {
            final index = y * bytesPerRow + x * bytesPerPixel;
            if (index < 0 || index >= bytes.length) continue;
            double luma;
            if (image.planes.length == 1 &&
                bytesPerPixel >= 4 &&
                index + 2 < bytes.length) {
              final b = bytes[index].toDouble();
              final g = bytes[index + 1].toDouble();
              final r = bytes[index + 2].toDouble();
              luma = (0.114 * b + 0.587 * g + 0.299 * r) / 255.0;
            } else {
              luma = bytes[index] / 255.0;
            }
            sum += luma;
            count++;
          }
        }
        result.add(count == 0 ? 0.0 : sum / count);
      }
    }
    return result;
  }

  double _median(List<double> sorted) {
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[i]
        : (sorted[i - 1] + sorted[i]) / 2.0;
  }
}
''')


# ---------------------------------------------------------------------------
# Conservative physical fusion: strong HFR rescue + ML-only conflict guard.
# ---------------------------------------------------------------------------
physical_path = Path('lib/hcv_physical_display_evidence.dart')
physical_path.write_text(r'''import 'dart:math';

import 'hcv_display_risk_fusion.dart';

class HCVPhysicalDisplayEvidence {
  const HCVPhysicalDisplayEvidence._();

  static bool hasStrongHfrDisplaySignature(Map<String, dynamic>? probe) {
    if (!_hfrQualityReady(probe)) return false;
    final cells = probe?['cellResults'];
    if (cells is! List || cells.length != 9) return false;

    var periodicCells = 0;
    var stableCells = 0;
    var phaseCells = 0;
    for (final raw in cells) {
      if (raw is! Map) return false;
      final periodicity = (raw['periodicityStrength'] as num?)?.toDouble() ?? 0.0;
      final stability =
          (raw['dominantFrequencyStability'] as num?)?.toDouble() ?? 0.0;
      final phase = (raw['phaseStepConsistency'] as num?)?.toDouble() ?? 0.0;
      if (periodicity >= 0.10) periodicCells++;
      if (stability >= 0.70) stableCells++;
      if (phase >= 0.55) phaseCells++;
    }

    final global = probe?['globalFrameLumaTemporalSpectrum'];
    final globalMap = global is Map ? global : const <String, dynamic>{};
    final modulation =
        (globalMap['robustFrameLumaModulationDepth'] as num?)?.toDouble() ?? 0.0;
    final spectral =
        (globalMap['temporalSpectralConcentration'] as num?)?.toDouble() ?? 0.0;

    return periodicCells >= 7 &&
        stableCells >= 8 &&
        phaseCells >= 7 &&
        modulation >= 0.25 &&
        spectral >= 0.85;
  }

  static bool hasElectronicallyQuietHfr(Map<String, dynamic>? probe) {
    if (!_hfrQualityReady(probe)) return false;
    final periodicity =
        (probe?['medianCellPeriodicityStrength'] as num?)?.toDouble() ?? 1.0;
    final stability =
        (probe?['medianCellFrequencyStability'] as num?)?.toDouble() ?? 1.0;
    final phase =
        (probe?['medianCellPhaseStepConsistency'] as num?)?.toDouble() ?? 1.0;
    final global = probe?['globalFrameLumaTemporalSpectrum'];
    final globalMap = global is Map ? global : const <String, dynamic>{};
    final modulation =
        (globalMap['robustFrameLumaModulationDepth'] as num?)?.toDouble() ?? 1.0;
    final spectral =
        (globalMap['temporalSpectralConcentration'] as num?)?.toDouble() ?? 1.0;

    return periodicity <= 0.02 &&
        stability <= 0.35 &&
        phase <= 0.35 &&
        modulation <= 0.06 &&
        spectral <= 0.55;
  }

  static HCVDisplayRiskResult apply({
    required HCVDisplayRiskResult baseline,
    required Map<String, dynamic>? mlAnalysis,
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? illuminationResponseProbe,
    required bool hardDisplayCorroboration,
  }) {
    var current = _sanitizeLegacyLiveProbeReason(
      baseline,
      temporalFrequencyProbe,
    );

    final strongHfr = hasStrongHfrDisplaySignature(temporalFrequencyProbe);
    if (strongHfr) {
      final evidence = <String>{
        ...current.evidenceSources,
        'NATIVE_HFR_FREQUENCY_SIGNATURE',
      }.toList()..sort();
      final strong = <String>{
        ...current.strongSources,
        'NATIVE_HFR_FREQUENCY_SIGNATURE',
      }.toList()..sort();
      final reasons = <String>{
        ...current.reasons,
        'NATIVE_HFR_STRONG_PERIODIC_DISPLAY_SIGNATURE',
      }.toList();
      if (current.decision != 'STRONG_DISPLAY_RISK') {
        return HCVDisplayRiskResult(
          risk: 'HIGH',
          score: max(92, current.score),
          decision: 'STRONG_DISPLAY_RISK',
          analysisStatus: 'COMPLETE',
          evidenceSources: evidence,
          strongSources: strong,
          reasons: reasons,
        );
      }
      current = HCVDisplayRiskResult(
        risk: current.risk,
        score: current.score,
        decision: current.decision,
        analysisStatus: current.analysisStatus,
        evidenceSources: evidence,
        strongSources: strong,
        reasons: reasons,
      );
    }

    final mlOnlyStrong = current.decision == 'STRONG_DISPLAY_RISK' &&
        current.strongSources.length == 1 &&
        current.strongSources.single == 'ML_SCREEN_CLASS' &&
        !hardDisplayCorroboration;
    if (!mlOnlyStrong || strongHfr) return current;

    final screenProbability =
        (mlAnalysis?['screenProbability'] as num?)?.toDouble();
    final mediumMl = screenProbability != null && screenProbability < 0.90;
    if (!mediumMl) return current;

    final quietHfr = hasElectronicallyQuietHfr(temporalFrequencyProbe);
    final reflective = illuminationResponseProbe?['analysisStatus'] == 'ANALYZED' &&
        illuminationResponseProbe?['measurementQualitySufficient'] == true &&
        illuminationResponseProbe?['strongReflectiveResponse'] == true;
    if (!quietHfr && !reflective) return current;

    final evidence = <String>{...current.evidenceSources};
    final reasons = <String>{...current.reasons};
    if (quietHfr) {
      evidence.add('NATIVE_HFR_ELECTRONIC_QUIET');
      reasons.add('ML_ONLY_DISPLAY_CONFLICTS_WITH_ELECTRONICALLY_QUIET_HFR');
    }
    if (reflective) {
      evidence.add('ILLUMINATION_RESPONSE_REFLECTIVE_SURFACE');
      reasons.add('ML_ONLY_DISPLAY_CONFLICTS_WITH_STRONG_REFLECTIVE_RESPONSE');
    }

    return HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: min(69, max(55, current.score - 20)),
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'COMPLETE',
      evidenceSources: evidence.toList()..sort(),
      strongSources: const [],
      reasons: reasons.toList(),
    );
  }

  static bool _hfrQualityReady(Map<String, dynamic>? probe) {
    if (probe == null || probe['analysisStatus'] != 'ANALYZED') return false;
    final fps = (probe['actualFrameRateFromTimestamps'] as num?)?.toDouble() ?? 0.0;
    final exposureVerified = probe['shortExposureVerified'] == true;
    final frames = (probe['framesAnalyzed'] as num?)?.toInt() ?? 0;
    return fps >= 119.0 && exposureVerified && frames >= 24;
  }

  static HCVDisplayRiskResult _sanitizeLegacyLiveProbeReason(
    HCVDisplayRiskResult baseline,
    Map<String, dynamic>? temporalFrequencyProbe,
  ) {
    if (temporalFrequencyProbe?['analysisStatus'] != 'ANALYZED' ||
        !baseline.reasons.contains('LIVE_PROBE_MISSING')) {
      return baseline;
    }
    final reasons = baseline.reasons
        .where((reason) => reason != 'LIVE_PROBE_MISSING')
        .toSet()
      ..add('NATIVE_TEMPORAL_FREQUENCY_PROBE_REPLACES_LEGACY_LIVE_PROBE');
    return HCVDisplayRiskResult(
      risk: baseline.risk,
      score: baseline.score,
      decision: baseline.decision,
      analysisStatus: baseline.analysisStatus,
      evidenceSources: baseline.evidenceSources,
      strongSources: baseline.strongSources,
      reasons: reasons.toList(),
    );
  }
}
''')


# ---------------------------------------------------------------------------
# Update temporal frequency certificate role: it now has a positive rescue role.
# ---------------------------------------------------------------------------
tf_path = Path('lib/hcv_temporal_frequency_probe.dart')
tf = tf_path.read_text()
tf = tf.replace(
    "/// Shadow-only native physical probe for display refresh / PWM periodicity.",
    "/// Native physical probe for display refresh / PWM periodicity.",
)
tf = tf.replace(
    "'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',\n      'productionDecisionChanged': false,",
    "'decisionRole': 'POSITIVE_DISPLAY_RESCUE_AND_CONFLICT_DIAGNOSTIC',\n      'productionFusionEnabled': true,",
)
tf = tf.replace(
    "'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',\n      'productionDecisionChanged': false,",
    "'decisionRole': 'POSITIVE_DISPLAY_RESCUE_AND_CONFLICT_DIAGNOSTIC',\n      'productionFusionEnabled': true,",
)
tf = tf.replace(
    "V2 measures row-profile phase evolution directly from native consecutive CMSampleBuffers at the highest isolated hardware tier available (240, 120, then 60 fps). It never participates in BUILD 80 display fusion.",
    "V2 measures row-profile phase evolution directly from native consecutive CMSampleBuffers at the highest isolated hardware tier available (240, 120, then 60 fps). Only a stringent positive periodic signature can rescue DISPLAY; weak HFR never proves REALITY.",
)
tf_path.write_text(tf)


# ---------------------------------------------------------------------------
# Camera integration and production fusion wrapper.
# ---------------------------------------------------------------------------
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()

camera = replace_once(
    camera,
    "import 'hcv_temporal_frequency_probe.dart';\n",
    "import 'hcv_temporal_frequency_probe.dart';\nimport 'hcv_illumination_response_probe.dart';\nimport 'hcv_physical_display_evidence.dart';\n",
    'imports',
)

camera = replace_once(
    camera,
    'HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(\n',
    'HCVDisplayRiskResult _combinePhotoDisplayRiskBase(\n',
    'rename photo base fusion',
)
camera = replace_once(
    camera,
    'HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(\n',
    'HCVDisplayRiskResult _combineVideoDisplayRiskBase(\n',
    'rename video base fusion',
)
camera = replace_once(
    camera,
    'final preCaptureResult = combinePhotoDisplayRiskFromPreCaptureEvidence([\n',
    'final preCaptureResult = _combinePhotoDisplayRiskBase([\n',
    'legacy pre-capture base call',
)

wrapper_marker = 'class CameraPage extends StatefulWidget {\n'
wrappers = r'''HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses, {
  Map<String, dynamic>? temporalFrequencyProbe,
  Map<String, dynamic>? illuminationResponseProbe,
}) {
  final baseline = _combinePhotoDisplayRiskBase(analyses);
  return HCVPhysicalDisplayEvidence.apply(
    baseline: baseline,
    mlAnalysis: _mlAnalysisFromAnalyses(analyses),
    temporalFrequencyProbe: temporalFrequencyProbe,
    illuminationResponseProbe: illuminationResponseProbe,
    hardDisplayCorroboration: _hasHardDisplayCorroboration(analyses),
  );
}

HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(
  List<Map<String, dynamic>?> analyses, {
  Map<String, dynamic>? temporalFrequencyProbe,
  Map<String, dynamic>? illuminationResponseProbe,
}) {
  final baseline = _combineVideoDisplayRiskBase(analyses);
  return HCVPhysicalDisplayEvidence.apply(
    baseline: baseline,
    mlAnalysis: _mlAnalysisFromAnalyses(analyses),
    temporalFrequencyProbe: temporalFrequencyProbe,
    illuminationResponseProbe: illuminationResponseProbe,
    hardDisplayCorroboration: _hasHardDisplayCorroboration(analyses),
  );
}

'''
camera = replace_once(camera, wrapper_marker, wrappers + wrapper_marker, 'fusion wrappers')

camera = replace_once(
    camera,
    '  Map<String, dynamic>? pendingTemporalFrequencyProbe;\n',
    '  Map<String, dynamic>? pendingTemporalFrequencyProbe;\n  Map<String, dynamic>? pendingIlluminationResponseProbe;\n',
    'pending illumination state',
)

camera = replace_once(
    camera,
    '    pendingTemporalFrequencyProbe = null;\n    pendingVideoLocation = captureLocation;\n',
    '    pendingTemporalFrequencyProbe = null;\n    pendingIlluminationResponseProbe = null;\n    pendingVideoLocation = captureLocation;\n',
    'video start reset',
)

camera = replace_once(
    camera,
    '''      pendingTemporalFrequencyProbe =
          await _captureTemporalFrequencyNativeIsolated();

      await _settleCameraAfterLiveProbe();
''',
    '''      pendingTemporalFrequencyProbe =
          await _captureTemporalFrequencyNativeIsolated();
      pendingIlluminationResponseProbe =
          await const HCVIlluminationResponseProbe().capture(
        controller!,
        restoreFlash: currentFlashMode,
      );

      await _settleCameraAfterLiveProbe();
''',
    'video illumination capture',
)

camera = replace_once(
    camera,
    '      pendingTemporalFrequencyProbe = null;\n      setState(() {\n        recording = false;\n',
    '      pendingTemporalFrequencyProbe = null;\n      pendingIlluminationResponseProbe = null;\n      setState(() {\n        recording = false;\n',
    'video start catch reset',
)

camera = replace_once(
    camera,
    '''      pendingTemporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'VIDEO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );

      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
''',
    '''      pendingTemporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'VIDEO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );
      pendingIlluminationResponseProbe ??=
          HCVIlluminationResponseProbe.unavailable(
        'VIDEO_ILLUMINATION_RESPONSE_NOT_AVAILABLE',
      );

      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
''',
    'video stop fallbacks',
)

camera = replace_once(
    camera,
    '      pendingTemporalFrequencyProbe = null;\n      try {\n        lastLiveSignals = await liveSignals.stopAndBuildSummary();\n',
    '      pendingTemporalFrequencyProbe = null;\n      pendingIlluminationResponseProbe = null;\n      try {\n        lastLiveSignals = await liveSignals.stopAndBuildSummary();\n',
    'video stop catch reset',
)

camera = replace_once(
    camera,
    '''  Map<String, dynamic> _buildPhotoTemporalV2LiveProbe(
    Map<String, dynamic> temporalProbe,
  ) {
''',
    '''  Map<String, dynamic> _buildPhotoTemporalV2LiveProbe(
    Map<String, dynamic> temporalProbe, {
    Map<String, dynamic>? temporalFrequencyProbe,
    Map<String, dynamic>? illuminationResponseProbe,
  }) {
''',
    'photo live probe signature',
)

camera = replace_once(
    camera,
    '''    final temporalRisk = analyzed
        ? combineVideoDisplayRiskFromCaptureEvidence([optical, ml])
        : null;
''',
    '''    final temporalRisk = analyzed
        ? combineVideoDisplayRiskFromCaptureEvidence(
            [optical, ml],
            temporalFrequencyProbe: temporalFrequencyProbe,
            illuminationResponseProbe: illuminationResponseProbe,
          )
        : null;
''',
    'photo temporal fusion physical args',
)

camera = replace_once(
    camera,
    '    Map<String, dynamic>? temporalFrequencyProbe;\n',
    '    Map<String, dynamic>? temporalFrequencyProbe;\n    Map<String, dynamic>? illuminationResponseProbe;\n',
    'photo illumination local',
)

camera = replace_once(
    camera,
    '''      temporalFrequencyProbe = await _captureTemporalFrequencyNativeIsolated();

      try {
        temporalClip = await temporalProbeEngine.capture(
''',
    '''      temporalFrequencyProbe = await _captureTemporalFrequencyNativeIsolated();
      illuminationResponseProbe =
          await const HCVIlluminationResponseProbe().capture(
        controller!,
        restoreFlash: currentFlashMode,
      );

      try {
        temporalClip = await temporalProbeEngine.capture(
''',
    'photo illumination capture',
)

camera = replace_once(
    camera,
    '''      temporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'PHOTO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );

      if (temporalClip != null) {
''',
    '''      temporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'PHOTO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );
      illuminationResponseProbe ??=
          HCVIlluminationResponseProbe.unavailable(
        'PHOTO_ILLUMINATION_RESPONSE_NOT_AVAILABLE',
      );

      if (temporalClip != null) {
''',
    'photo illumination fallback',
)

camera = replace_once(
    camera,
    '      final liveScreenProbe = _buildPhotoTemporalV2LiveProbe(temporalProbe);\n',
    '''      final liveScreenProbe = _buildPhotoTemporalV2LiveProbe(
        temporalProbe,
        temporalFrequencyProbe: temporalFrequencyProbe,
        illuminationResponseProbe: illuminationResponseProbe,
      );
''',
    'photo live probe physical args call',
)

camera = replace_once(
    camera,
    '''      final displayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(
        screenReplayAnalyses,
      );
''',
    '''      final displayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(
        screenReplayAnalyses,
        temporalFrequencyProbe: temporalFrequencyProbe,
        illuminationResponseProbe: illuminationResponseProbe,
      );
''',
    'photo final physical fusion',
)

camera = replace_once(
    camera,
    '        "temporalFrequencyProbe": temporalFrequencyProbe,\n',
    '        "temporalFrequencyProbe": temporalFrequencyProbe,\n        "illuminationResponseProbe": illuminationResponseProbe,\n',
    'photo claims illumination',
)

camera = replace_once(
    camera,
    '''    final temporalFrequencyProbe = pendingTemporalFrequencyProbe;
    pendingTemporalFrequencyProbe = null;
    final effectiveCapturedAt = capturedAt ?? DateTime.now();
''',
    '''    final temporalFrequencyProbe = pendingTemporalFrequencyProbe;
    pendingTemporalFrequencyProbe = null;
    final illuminationResponseProbe = pendingIlluminationResponseProbe;
    pendingIlluminationResponseProbe = null;
    final effectiveCapturedAt = capturedAt ?? DateTime.now();
''',
    'video process extract illumination',
)

camera = replace_once(
    camera,
    '''    final displayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
    );
''',
    '''    final displayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
      temporalFrequencyProbe: temporalFrequencyProbe,
      illuminationResponseProbe: illuminationResponseProbe,
    );
''',
    'video final physical fusion',
)

camera = replace_once(
    camera,
    '      "temporalFrequencyProbe": temporalFrequencyProbe,\n',
    '      "temporalFrequencyProbe": temporalFrequencyProbe,\n      "illuminationResponseProbe": illuminationResponseProbe,\n',
    'video claims illumination',
)

camera_path.write_text(camera)


# ---------------------------------------------------------------------------
# Regression tests based on BUILD 92 physical measurements.
# ---------------------------------------------------------------------------
Path('test/physical_frequency_reflection_fusion_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';

import 'package:sigillum_hcv/hcv_display_risk_fusion.dart';
import 'package:sigillum_hcv/hcv_physical_display_evidence.dart';

Map<String, dynamic> _hfr({
  required double periodicity,
  required double stability,
  required double phase,
  required double modulation,
  required double spectral,
  int periodicCells = 0,
  int stableCells = 0,
  int phaseCells = 0,
}) {
  final cells = List.generate(9, (i) {
    return {
      'periodicityStrength': i < periodicCells ? 0.20 : periodicity,
      'dominantFrequencyStability': i < stableCells ? 0.90 : stability,
      'phaseStepConsistency': i < phaseCells ? 0.70 : phase,
    };
  });
  return {
    'analysisStatus': 'ANALYZED',
    'actualFrameRateFromTimestamps': 240.62,
    'shortExposureVerified': true,
    'framesAnalyzed': 84,
    'medianCellPeriodicityStrength': periodicity,
    'medianCellFrequencyStability': stability,
    'medianCellPhaseStepConsistency': phase,
    'globalFrameLumaTemporalSpectrum': {
      'robustFrameLumaModulationDepth': modulation,
      'temporalSpectralConcentration': spectral,
    },
    'cellResults': cells,
  };
}

HCVDisplayRiskResult _result({
  required String decision,
  required int score,
  List<String> strongSources = const [],
  List<String> reasons = const [],
}) {
  return HCVDisplayRiskResult(
    risk: decision == 'STRONG_DISPLAY_RISK'
        ? 'HIGH'
        : decision == 'NON_CONCLUSIVE'
            ? 'MEDIUM'
            : 'LOW',
    score: score,
    decision: decision,
    analysisStatus: 'COMPLETE',
    evidenceSources: strongSources,
    strongSources: strongSources,
    reasons: reasons,
  );
}

void main() {
  test('BUILD92 missed TV is rescued by strong 240 fps periodic signature', () {
    final probe = _hfr(
      periodicity: 0.23,
      stability: 0.93,
      phase: 0.64,
      modulation: 0.63,
      spectral: 0.91,
      periodicCells: 9,
      stableCells: 9,
      phaseCells: 8,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(decision: 'NO_DISPLAY_EVIDENCE', score: 20),
      mlAnalysis: {'screenProbability': 0.56},
      temporalFrequencyProbe: probe,
      illuminationResponseProbe: null,
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'STRONG_DISPLAY_RISK');
    expect(out.strongSources, contains('NATIVE_HFR_FREQUENCY_SIGNATURE'));
  });

  test('BUILD92 reflective false positive becomes non-conclusive when HFR is quiet', () {
    final quiet = _hfr(
      periodicity: 0.007,
      stability: 0.23,
      phase: 0.18,
      modulation: 0.03,
      spectral: 0.50,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(
        decision: 'STRONG_DISPLAY_RISK',
        score: 85,
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: const [
          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
          'LIVE_PROBE_MISSING',
        ],
      ),
      mlAnalysis: {'screenProbability': 0.855},
      temporalFrequencyProbe: quiet,
      illuminationResponseProbe: null,
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'NON_CONCLUSIVE');
    expect(out.reasons, isNot(contains('LIVE_PROBE_MISSING')));
    expect(
      out.reasons,
      contains('ML_ONLY_DISPLAY_CONFLICTS_WITH_ELECTRONICALLY_QUIET_HFR'),
    );
  });

  test('BUILD92 true monitor with temporal modulation is not vetoed by quiet rule', () {
    final monitor = _hfr(
      periodicity: 0.009,
      stability: 0.23,
      phase: 0.285,
      modulation: 0.166,
      spectral: 0.727,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(
        decision: 'STRONG_DISPLAY_RISK',
        score: 85,
        strongSources: const ['ML_SCREEN_CLASS'],
      ),
      mlAnalysis: {'screenProbability': 0.848},
      temporalFrequencyProbe: monitor,
      illuminationResponseProbe: null,
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'STRONG_DISPLAY_RISK');
  });

  test('strong reflective response can conflict with medium ML-only display', () {
    final nonStrongHfr = _hfr(
      periodicity: 0.04,
      stability: 0.55,
      phase: 0.40,
      modulation: 0.12,
      spectral: 0.70,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(
        decision: 'STRONG_DISPLAY_RISK',
        score: 84,
        strongSources: const ['ML_SCREEN_CLASS'],
      ),
      mlAnalysis: {'screenProbability': 0.84},
      temporalFrequencyProbe: nonStrongHfr,
      illuminationResponseProbe: {
        'analysisStatus': 'ANALYZED',
        'measurementQualitySufficient': true,
        'strongReflectiveResponse': true,
      },
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'NON_CONCLUSIVE');
    expect(
      out.reasons,
      contains('ML_ONLY_DISPLAY_CONFLICTS_WITH_STRONG_REFLECTIVE_RESPONSE'),
    );
  });

  test('very high ML confidence is not vetoed by reflection conflict support', () {
    final quiet = _hfr(
      periodicity: 0.007,
      stability: 0.23,
      phase: 0.18,
      modulation: 0.03,
      spectral: 0.50,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(
        decision: 'STRONG_DISPLAY_RISK',
        score: 99,
        strongSources: const ['ML_SCREEN_CLASS'],
      ),
      mlAnalysis: {'screenProbability': 0.996},
      temporalFrequencyProbe: quiet,
      illuminationResponseProbe: {
        'analysisStatus': 'ANALYZED',
        'measurementQualitySufficient': true,
        'strongReflectiveResponse': true,
      },
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'STRONG_DISPLAY_RISK');
  });
}
''')

Path('test/illumination_response_integration_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('illumination response is captured before photo and video final capture', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('HCVIlluminationResponseProbe().capture'));
    expect(source, contains('pendingIlluminationResponseProbe'));
    expect(
      RegExp(r'"illuminationResponseProbe": illuminationResponseProbe')
          .allMatches(source)
          .length,
      2,
    );
    expect(
      source,
      contains('temporalFrequencyProbe: temporalFrequencyProbe'),
    );
  });

  test('illumination probe locks exposure and restores camera state', () {
    final source =
        File('lib/hcv_illumination_response_probe.dart').readAsStringSync();
    expect(source, contains('setExposureMode(ExposureMode.locked)'));
    expect(source, contains('setFlashMode(FlashMode.off)'));
    expect(source, contains('setFlashMode(FlashMode.torch)'));
    expect(source, contains('setExposureMode(ExposureMode.auto)'));
    expect(source, contains('setFocusMode(FocusMode.auto)'));
    expect(source, contains("'strongReflectiveResponse': strongReflectiveResponse"));
  });
}
''')

print('frequency + reflection fusion patch applied')
