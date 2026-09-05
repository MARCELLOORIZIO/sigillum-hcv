from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()

camera = replace_once(
    camera,
    "import 'hcv_temporal_frequency_probe.dart';\nimport 'hcv_ml_screen_replay_classifier.dart';\n",
    "import 'hcv_temporal_frequency_probe.dart';\nimport 'hcv_hfr_display_rescue.dart';\nimport 'hcv_ml_screen_replay_classifier.dart';\n",
    'hfr rescue import',
)

camera = replace_once(
    camera,
    '''  bool ready = false;\n  bool recording = false;\n  bool _videoFinalizeInProgress = false;\n\n  bool photoMode = false;\n''',
    '''  bool ready = false;\n  bool recording = false;\n  bool _videoFinalizeInProgress = false;\n  bool _capturePipelineBusy = false;\n\n  bool get _cameraControlsLocked =>\n      _capturePipelineBusy || _videoFinalizeInProgress || recording;\n\n  bool photoMode = false;\n''',
    'capture state',
)

camera = replace_once(
    camera,
    '''  Future<void> _toggleCoordinateStamp() async {\n    if (_locationBusy) return;\n''',
    '''  Future<void> _toggleCoordinateStamp() async {\n    if (_cameraControlsLocked || _locationBusy) return;\n''',
    'coordinate guard',
)

camera = replace_once(
    camera,
    '''  Future<void> switchCamera() async {\n    if (cameras == null || cameras!.length < 2) return;\n''',
    '''  Future<void> switchCamera() async {\n    if (_cameraControlsLocked) return;\n    if (cameras == null || cameras!.length < 2) return;\n''',
    'switch camera guard',
)

camera = replace_once(
    camera,
    '''  Future<void> toggleFlash() async {\n    if (controller == null) return;\n''',
    '''  Future<void> toggleFlash() async {\n    if (_cameraControlsLocked) return;\n    if (controller == null) return;\n''',
    'flash guard',
)

camera = replace_once(
    camera,
    '''  Future<void> setZoom(double zoom) async {\n    if (controller == null || !controller!.value.isInitialized) return;\n''',
    '''  Future<void> setZoom(double zoom) async {\n    if (_cameraControlsLocked) return;\n    if (controller == null || !controller!.value.isInitialized) return;\n''',
    'zoom guard',
)

# Video start: lock every conflicting control during the native probe and until
# the actual CameraController starts recording. The REC button is only enabled
# again once recording is real, at which point it acts only as STOP.
old_start = '''  Future<void> start() async {\n    if (controller == null || !controller!.value.isInitialized) return;\n    if (controller!.value.isRecordingVideo) return;\n\n    final captureLocation = await _locationForCapture();\n    if (_printCoordinates && captureLocation == null) return;\n\n    pendingLiveScreenProbe = null;\n    pendingTemporalFrequencyProbe = null;\n    pendingVideoLocation = captureLocation;\n    lastLiveSignals = null;\n\n    setState(() {\n      recording = true;\n      status = _c('starting');\n      result = null;\n      videoPath = null;\n      hcvPath = null;\n      packagePath = null;\n      hcvId = null;\n      verificationUrl = null;\n      registryStatus = null;\n    });\n\n    try {\n      // BUILD 80 remains the decision baseline. The V2 physical probe runs in\n      // its own native AVCaptureSession while Flutter camera is released.\n      pendingTemporalFrequencyProbe =\n          await _captureTemporalFrequencyNativeIsolated();\n\n      await _settleCameraAfterLiveProbe();\n      await controller!.startVideoRecording();\n      pendingVideoCapturedAt = DateTime.now();\n\n      try {\n        await liveSignals.start();\n      } catch (_) {\n        lastLiveSignals = null;\n      }\n\n      setState(() => status = _c('recording'));\n    } catch (e) {\n      pendingVideoCapturedAt = null;\n      pendingVideoLocation = null;\n      pendingLiveScreenProbe = null;\n      pendingTemporalFrequencyProbe = null;\n      setState(() {\n        recording = false;\n        status = '${_c('startError')}: $e';\n      });\n    }\n  }\n'''
new_start = '''  Future<void> start() async {\n    if (_capturePipelineBusy || recording || _videoFinalizeInProgress) return;\n    if (controller == null || !controller!.value.isInitialized) return;\n    if (controller!.value.isRecordingVideo) return;\n\n    if (mounted) {\n      setState(() {\n        _capturePipelineBusy = true;\n        status = _c('starting');\n        result = null;\n        videoPath = null;\n        hcvPath = null;\n        packagePath = null;\n        hcvId = null;\n        verificationUrl = null;\n        registryStatus = null;\n      });\n    }\n\n    final captureLocation = await _locationForCapture();\n    if (_printCoordinates && captureLocation == null) {\n      if (mounted) setState(() => _capturePipelineBusy = false);\n      return;\n    }\n\n    pendingLiveScreenProbe = null;\n    pendingTemporalFrequencyProbe = null;\n    pendingVideoLocation = captureLocation;\n    lastLiveSignals = null;\n\n    try {\n      // BUILD 80 remains the decision baseline. The V2 physical probe runs in\n      // its own native AVCaptureSession while Flutter camera is released.\n      pendingTemporalFrequencyProbe =\n          await _captureTemporalFrequencyNativeIsolated();\n\n      await _settleCameraAfterLiveProbe();\n      await controller!.startVideoRecording();\n      pendingVideoCapturedAt = DateTime.now();\n\n      try {\n        await liveSignals.start();\n      } catch (_) {\n        lastLiveSignals = null;\n      }\n\n      if (mounted) {\n        setState(() {\n          recording = true;\n          _capturePipelineBusy = false;\n          status = _c('recording');\n        });\n      }\n    } catch (e) {\n      pendingVideoCapturedAt = null;\n      pendingVideoLocation = null;\n      pendingLiveScreenProbe = null;\n      pendingTemporalFrequencyProbe = null;\n      if (mounted) {\n        setState(() {\n          recording = false;\n          _capturePipelineBusy = false;\n          status = '${_c('startError')}: $e';\n        });\n      }\n    }\n  }\n'''
camera = replace_once(camera, old_start, new_start, 'video start lifecycle lock')

camera = replace_once(
    camera,
    '''  Future<void> stop() async {\n    if (controller == null || _videoFinalizeInProgress) return;\n    _videoFinalizeInProgress = true;\n\n    try {\n''',
    '''  Future<void> stop() async {\n    if (controller == null ||\n        _videoFinalizeInProgress ||\n        _capturePipelineBusy ||\n        !recording) {\n      return;\n    }\n    if (mounted) {\n      setState(() {\n        _videoFinalizeInProgress = true;\n        _capturePipelineBusy = true;\n        status = _c('processingVideo');\n      });\n    } else {\n      _videoFinalizeInProgress = true;\n      _capturePipelineBusy = true;\n    }\n\n    try {\n''',
    'video stop lock',
)

camera = replace_once(
    camera,
    '''    } finally {\n      _videoFinalizeInProgress = false;\n    }\n  }\n\n  Map<String, dynamic> _photoTemporalV2Unavailable(\n''',
    '''    } finally {\n      if (mounted) {\n        setState(() {\n          _videoFinalizeInProgress = false;\n          _capturePipelineBusy = false;\n        });\n      } else {\n        _videoFinalizeInProgress = false;\n        _capturePipelineBusy = false;\n      }\n    }\n  }\n\n  Map<String, dynamic> _photoTemporalV2Unavailable(\n''',
    'video stop unlock',
)

camera = replace_once(
    camera,
    '''  Future<void> takePhoto() async {\n    if (controller == null || !controller!.value.isInitialized) return;\n    if (controller!.value.isRecordingVideo) return;\n\n    final captureLocation = await _locationForCapture();\n    if (_printCoordinates && captureLocation == null) return;\n''',
    '''  Future<void> takePhoto() async {\n    if (_capturePipelineBusy || recording || _videoFinalizeInProgress) return;\n    if (controller == null || !controller!.value.isInitialized) return;\n    if (controller!.value.isRecordingVideo) return;\n\n    if (mounted) {\n      setState(() {\n        _capturePipelineBusy = true;\n        status = _c('takingPhoto');\n        result = null;\n      });\n    }\n\n    final captureLocation = await _locationForCapture();\n    if (_printCoordinates && captureLocation == null) {\n      if (mounted) setState(() => _capturePipelineBusy = false);\n      return;\n    }\n''',
    'photo lock begin',
)

camera = replace_once(
    camera,
    '''      // One user tap starts the technical clip and automatically finishes with\n      // the actual still. No PROSEGUI step and no 15-second scene gap remain.\n      setState(() {\n        status = _c('takingPhoto');\n        result = null;\n      });\n\n      temporalFrequencyProbe = await _captureTemporalFrequencyNativeIsolated();\n''',
    '''      // One user tap starts the technical clip and automatically finishes with\n      // the actual still. No PROSEGUI step and no 15-second scene gap remain.\n      temporalFrequencyProbe = await _captureTemporalFrequencyNativeIsolated();\n''',
    'remove duplicate photo busy setState',
)

camera = replace_once(
    camera,
    '''    } catch (e) {\n      if (temporalClip != null) {\n        await temporalProbeEngine.discard(temporalClip.path);\n      }\n      setState(() {\n        status = '${_c('photoError')}: $e';\n      });\n    }\n  }\n\n  Future<Directory> _downloadsDirectory() async {\n''',
    '''    } catch (e) {\n      if (temporalClip != null) {\n        await temporalProbeEngine.discard(temporalClip.path);\n      }\n      if (mounted) {\n        setState(() {\n          status = '${_c('photoError')}: $e';\n        });\n      }\n    } finally {\n      if (mounted) {\n        setState(() => _capturePipelineBusy = false);\n      } else {\n        _capturePipelineBusy = false;\n      }\n    }\n  }\n\n  Future<Directory> _downloadsDirectory() async {\n''',
    'photo unlock finally',
)

# Positive-only native HFR rescue. Weak HFR can never demote a display warning
# and can never prove REALITY. Full-frame support is 9/9 with no escape cells.
camera = replace_once(
    camera,
    '''      final displayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(\n        screenReplayAnalyses,\n      );\n''',
    '''      final baselineDisplayRisk =\n          combinePhotoDisplayRiskFromPreCaptureEvidence(screenReplayAnalyses);\n      final displayRisk = HCVHfrDisplayRescue.apply(\n        baseline: baselineDisplayRisk,\n        temporalFrequencyProbe: temporalFrequencyProbe,\n      );\n''',
    'photo hfr rescue',
)

camera = replace_once(
    camera,
    '''        "temporalFrequencyProbe": temporalFrequencyProbe,\n        "physicalSceneClass": liveScreenProbe["sceneClass"] ?? "UNKNOWN",\n''',
    '''        "temporalFrequencyProbe": temporalFrequencyProbe,\n        "hfrDisplayRescueAssessment":\n            HCVHfrDisplayRescue.inspect(temporalFrequencyProbe),\n        "physicalSceneClass": liveScreenProbe["sceneClass"] ?? "UNKNOWN",\n''',
    'photo hfr assessment claim',
)

camera = replace_once(
    camera,
    '''    final displayRisk = combineVideoDisplayRiskFromCaptureEvidence(\n      screenReplayAnalyses,\n    );\n''',
    '''    final baselineDisplayRisk =\n        combineVideoDisplayRiskFromCaptureEvidence(screenReplayAnalyses);\n    final displayRisk = HCVHfrDisplayRescue.apply(\n      baseline: baselineDisplayRisk,\n      temporalFrequencyProbe: temporalFrequencyProbe,\n    );\n''',
    'video hfr rescue',
)

camera = replace_once(
    camera,
    '''      "temporalFrequencyProbe": temporalFrequencyProbe,\n      "physicalSceneClass": liveScreenProbe?["sceneClass"] ?? "UNKNOWN",\n''',
    '''      "temporalFrequencyProbe": temporalFrequencyProbe,\n      "hfrDisplayRescueAssessment":\n          HCVHfrDisplayRescue.inspect(temporalFrequencyProbe),\n      "physicalSceneClass": liveScreenProbe?["sceneClass"] ?? "UNKNOWN",\n''',
    'video hfr assessment claim',
)

# App navigation and camera controls are disabled for the whole capture lifecycle.
camera = replace_once(
    camera,
    '''    return Scaffold(\n      backgroundColor: Colors.black,\n''',
    '''    return PopScope(\n      canPop: !_cameraControlsLocked,\n      child: Scaffold(\n        backgroundColor: Colors.black,\n''',
    'PopScope begin',
)

camera = replace_once(
    camera,
    '''        leading: IconButton(\n          icon: const Icon(Icons.arrow_back, color: Colors.white),\n          onPressed: () {\n            Navigator.of(context).pop();\n          },\n        ),\n''',
    '''        leading: IconButton(\n          icon: const Icon(Icons.arrow_back, color: Colors.white),\n          onPressed: _cameraControlsLocked\n              ? null\n              : () {\n                  Navigator.of(context).pop();\n                },\n        ),\n''',
    'appbar back lock',
)

camera = replace_once(
    camera,
    '''            onPressed: _locationBusy ? null : _toggleCoordinateStamp,\n''',
    '''            onPressed: _cameraControlsLocked || _locationBusy\n                ? null\n                : _toggleCoordinateStamp,\n''',
    'coordinate ui lock',
)

camera = replace_once(
    camera,
    '''            onPressed: toggleFlash,\n''',
    '''            onPressed: _cameraControlsLocked ? null : toggleFlash,\n''',
    'flash ui lock',
)

camera = replace_once(
    camera,
    '''            onPressed: switchCamera,\n''',
    '''            onPressed: _cameraControlsLocked ? null : switchCamera,\n''',
    'switch ui lock',
)

camera = replace_once(
    camera,
    '''                          onChanged: (value) async {\n                            await setZoom(value);\n                          },\n''',
    '''                          onChanged: _cameraControlsLocked\n                              ? null\n                              : (value) async {\n                                  await setZoom(value);\n                                },\n''',
    'slider lock',
)

# Both mode chips are blocked while starting, recording, stopping or finalizing.
first_chip = '''                            onSelected: (_) {\n                              setState(() {\n                                photoMode = false;\n                              });\n                            },\n'''
camera = replace_once(
    camera,
    first_chip,
    '''                            onSelected: _cameraControlsLocked\n                                ? null\n                                : (_) {\n                                    setState(() {\n                                      photoMode = false;\n                                    });\n                                  },\n''',
    'video chip lock',
)
second_chip = '''                            onSelected: (_) {\n                              pendingLiveScreenProbe = null;\n                              pendingVideoLocation = null;\n                              setState(() {\n                                photoMode = true;\n                              });\n                            },\n'''
camera = replace_once(
    camera,
    second_chip,
    '''                            onSelected: _cameraControlsLocked\n                                ? null\n                                : (_) {\n                                    pendingLiveScreenProbe = null;\n                                    pendingVideoLocation = null;\n                                    setState(() {\n                                      photoMode = true;\n                                    });\n                                  },\n''',
    'photo chip lock',
)

camera = replace_once(
    camera,
    '''                        onTap: !ready || _videoFinalizeInProgress\n                            ? null\n''',
    '''                        onTap: !ready ||\n                                _videoFinalizeInProgress ||\n                                _capturePipelineBusy\n                            ? null\n''',
    'capture button lock',
)

# Add a transparent modal barrier above the body while capture/finalization is
# in progress. This also blocks result/share buttons if result becomes available
# before gallery/registry persistence has fully finished.
camera = replace_once(
    camera,
    '''          if (result != null)\n            Positioned.fill(\n              child: SafeArea(\n''',
    '''          if (_capturePipelineBusy)\n            const Positioned.fill(\n              child: ModalBarrier(\n                dismissible: false,\n                color: Colors.transparent,\n              ),\n            ),\n          if (result != null)\n            Positioned.fill(\n              child: SafeArea(\n''',
    'modal body lock',
)

# Close PopScope after Scaffold.
camera = replace_once(
    camera,
    '''      ),\n    );\n  }\n}\n''',
    '''      ),\n      ),\n    );\n  }\n}\n''',
    'PopScope end',
)

camera_path.write_text(camera)

Path('lib/hcv_hfr_display_rescue.dart').write_text(r'''import 'dart:math';

import 'hcv_display_risk_fusion.dart';

class HCVHfrDisplayRescue {
  const HCVHfrDisplayRescue._();

  // Empirical positive-only guard derived from the native 240 fps corpus.
  // The difficult full-frame TV recaptures had minimum per-cell periodicity
  // >= 0.0925 and minimum frequency stability >= 0.7349, while the uploaded
  // real/mixed scenes and the BUILD 91 corpus stayed far below this full-frame
  // support. The guard deliberately requires all 9 cells: realityEscape=0.
  static const double minCellPeriodicity = 0.08;
  static const double minCellFrequencyStability = 0.70;
  static const double minMedianPhaseConsistency = 0.55;
  static const double minGlobalSpectralConcentration = 0.85;
  static const double minGlobalModulationDepth = 0.45;
  static const int requiredCells = 9;

  static Map<String, dynamic> inspect(Map<String, dynamic>? probe) {
    if (probe == null || probe['analysisStatus'] != 'ANALYZED') {
      return const {
        'type': 'SIGILLUM_HFR_FULL_FRAME_RESCUE_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'decisionRole': 'POSITIVE_DISPLAY_RESCUE_ONLY',
        'fullFrameDisplaySignature': false,
      };
    }

    final rawCells = probe['cellResults'];
    final cells = rawCells is List ? rawCells.whereType<Map>().toList() : const <Map>[];
    var supportedCells = 0;
    final cellAssessments = <Map<String, dynamic>>[];
    for (final cell in cells) {
      final periodicity = (cell['periodicityStrength'] as num?)?.toDouble() ?? 0.0;
      final stability =
          (cell['dominantFrequencyStability'] as num?)?.toDouble() ?? 0.0;
      final supported = periodicity >= minCellPeriodicity &&
          stability >= minCellFrequencyStability;
      if (supported) supportedCells++;
      cellAssessments.add({
        'row': cell['row'],
        'column': cell['column'],
        'periodicityStrength': periodicity,
        'frequencyStability': stability,
        'supported': supported,
      });
    }

    final medianPhase =
        (probe['medianCellPhaseStepConsistency'] as num?)?.toDouble() ?? 0.0;
    final globalRaw = probe['globalFrameLumaTemporalSpectrum'];
    final global = globalRaw is Map ? globalRaw : const {};
    final globalConcentration =
        (global['temporalSpectralConcentration'] as num?)?.toDouble() ?? 0.0;
    final globalModulation =
        (global['robustFrameLumaModulationDepth'] as num?)?.toDouble() ?? 0.0;

    final realityEscapeCellCount = max(0, requiredCells - supportedCells);
    final fullFrame = cells.length == requiredCells &&
        supportedCells == requiredCells &&
        medianPhase >= minMedianPhaseConsistency &&
        globalConcentration >= minGlobalSpectralConcentration &&
        globalModulation >= minGlobalModulationDepth;

    return {
      'type': 'SIGILLUM_HFR_FULL_FRAME_RESCUE_V1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'POSITIVE_DISPLAY_RESCUE_ONLY',
      'gridRows': 3,
      'gridColumns': 3,
      'requiredDisplaySupportCells': requiredCells,
      'supportedDisplayCells': supportedCells,
      'realityEscapeCellCount': realityEscapeCellCount,
      'fullFrameDisplaySignature': fullFrame,
      'minimumCellPeriodicityThreshold': minCellPeriodicity,
      'minimumCellFrequencyStabilityThreshold': minCellFrequencyStability,
      'medianPhaseConsistency': medianPhase,
      'minimumMedianPhaseConsistency': minMedianPhaseConsistency,
      'globalSpectralConcentration': globalConcentration,
      'minimumGlobalSpectralConcentration': minGlobalSpectralConcentration,
      'globalModulationDepth': globalModulation,
      'minimumGlobalModulationDepth': minGlobalModulationDepth,
      'cellAssessments': cellAssessments,
      'negativeMeaning':
          'A weak or absent HFR signature never proves REALITY and never downgrades an existing display warning.',
    };
  }

  static HCVDisplayRiskResult apply({
    required HCVDisplayRiskResult baseline,
    required Map<String, dynamic>? temporalFrequencyProbe,
  }) {
    final assessment = inspect(temporalFrequencyProbe);
    final analyzed = assessment['analysisStatus'] == 'ANALYZED';
    final fullFrame = assessment['fullFrameDisplaySignature'] == true;

    final reasons = baseline.reasons
        .where((reason) => !(analyzed && reason == 'LIVE_PROBE_MISSING'))
        .toSet();
    if (analyzed) reasons.add('NATIVE_HFR_PHYSICAL_PROBE_AVAILABLE');

    if (fullFrame && baseline.decision != 'STRONG_DISPLAY_RISK') {
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: max(90, baseline.score),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: baseline.analysisStatus,
        evidenceSources: {
          ...baseline.evidenceSources,
          'NATIVE_HFR_FULL_FRAME_9_OF_9',
        }.toList(),
        strongSources: {
          ...baseline.strongSources,
          'NATIVE_HFR_FULL_FRAME_9_OF_9',
        }.toList(),
        reasons: {
          ...reasons,
          'PHYSICAL_HFR_FULL_FRAME_DISPLAY_RESCUE_V1',
        }.toList(),
      );
    }

    if (reasons.length != baseline.reasons.length ||
        !baseline.reasons.every(reasons.contains)) {
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
    return baseline;
  }
}
''')

Path('test/hfr_full_frame_rescue_v1_test.dart').write_text(r'''import '../lib/hcv_display_risk_fusion.dart';
import '../lib/hcv_hfr_display_rescue.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> probe({
  required List<double> periodicity,
  required List<double> stability,
  required double medianPhase,
  required double globalConcentration,
  required double globalModulation,
}) {
  return {
    'analysisStatus': 'ANALYZED',
    'medianCellPhaseStepConsistency': medianPhase,
    'globalFrameLumaTemporalSpectrum': {
      'temporalSpectralConcentration': globalConcentration,
      'robustFrameLumaModulationDepth': globalModulation,
    },
    'cellResults': [
      for (var i = 0; i < 9; i++)
        {
          'row': i ~/ 3,
          'column': i % 3,
          'periodicityStrength': periodicity[i],
          'dominantFrequencyStability': stability[i],
        },
    ],
  };
}

const baselineNoDisplay = HCVDisplayRiskResult(
  risk: 'LOW',
  score: 20,
  decision: 'NO_DISPLAY_EVIDENCE',
  analysisStatus: 'ANALYZED',
  evidenceSources: [],
  strongSources: [],
  reasons: ['LIVE_PROBE_MISSING'],
);

void main() {
  test('rescues uploaded full-frame TV photo signature', () {
    final p = probe(
      periodicity: const [0.2411, 0.3749, 0.2461, 0.0925, 0.2758, 0.3098, 0.2141, 0.1695, 0.2027],
      stability: const [0.9639, 0.9759, 1.0, 0.7831, 0.9639, 1.0, 0.7349, 0.9036, 0.9157],
      medianPhase: 0.6420,
      globalConcentration: 0.8942,
      globalModulation: 0.8141,
    );
    final a = HCVHfrDisplayRescue.inspect(p);
    expect(a['supportedDisplayCells'], 9);
    expect(a['realityEscapeCellCount'], 0);
    expect(a['fullFrameDisplaySignature'], true);
    final result = HCVHfrDisplayRescue.apply(
      baseline: baselineNoDisplay,
      temporalFrequencyProbe: p,
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('PHYSICAL_HFR_FULL_FRAME_DISPLAY_RESCUE_V1'));
  });

  test('rescues uploaded full-frame TV video signature', () {
    final p = probe(
      periodicity: const [0.1942, 0.2660, 0.1402, 0.4237, 0.3052, 0.2267, 0.1361, 0.3350, 0.1100],
      stability: const [0.9036, 0.9759, 0.7349, 1.0, 0.9277, 0.9157, 0.8313, 1.0, 0.9759],
      medianPhase: 0.7170,
      globalConcentration: 0.9074,
      globalModulation: 0.6264,
    );
    expect(HCVHfrDisplayRescue.inspect(p)['fullFrameDisplaySignature'], true);
  });

  test('mixed real room plus monitors is never promoted', () {
    final p = probe(
      periodicity: const [0.0126, 0.0635, 0.0276, 0.0498, 0.0289, 0.0040, 0.0296, 0.0014, 0.0238],
      stability: const [0.4699, 0.6145, 0.6024, 0.5904, 0.6988, 0.1807, 0.3976, 0.3253, 0.5060],
      medianPhase: 0.2725,
      globalConcentration: 0.6297,
      globalModulation: 0.0379,
    );
    final a = HCVHfrDisplayRescue.inspect(p);
    expect(a['fullFrameDisplaySignature'], false);
    expect((a['realityEscapeCellCount'] as int), greaterThan(0));
    final result = HCVHfrDisplayRescue.apply(
      baseline: baselineNoDisplay,
      temporalFrequencyProbe: p,
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('one weak cell blocks rescue: no majority rule', () {
    final p = probe(
      periodicity: const [0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.079],
      stability: const [0.90, 0.90, 0.90, 0.90, 0.90, 0.90, 0.90, 0.90, 0.90],
      medianPhase: 0.80,
      globalConcentration: 0.95,
      globalModulation: 0.80,
    );
    final a = HCVHfrDisplayRescue.inspect(p);
    expect(a['supportedDisplayCells'], 8);
    expect(a['realityEscapeCellCount'], 1);
    expect(a['fullFrameDisplaySignature'], false);
  });

  test('weak HFR never downgrades an existing display decision', () {
    const strong = HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 85,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'ANALYZED',
      evidenceSources: ['ML'],
      strongSources: ['ML'],
      reasons: ['ML_SCREEN_CLASS'],
    );
    final weak = probe(
      periodicity: List<double>.filled(9, 0.01),
      stability: List<double>.filled(9, 0.25),
      medianPhase: 0.2,
      globalConcentration: 0.5,
      globalModulation: 0.03,
    );
    final result = HCVHfrDisplayRescue.apply(
      baseline: strong,
      temporalFrequencyProbe: weak,
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, 85);
  });
}
''')

Path('test/camera_capture_finalization_lock_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture finalization lock protects every conflicting camera command', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('bool _capturePipelineBusy = false;'));
    expect(source, contains('bool get _cameraControlsLocked =>'));
    expect(source, contains('canPop: !_cameraControlsLocked'));
    expect(source, contains('onPressed: _cameraControlsLocked ? null : toggleFlash'));
    expect(source, contains('onPressed: _cameraControlsLocked ? null : switchCamera'));
    expect(source, contains('_cameraControlsLocked || _locationBusy'));
    expect(source, contains('onChanged: _cameraControlsLocked'));
    expect(source, contains('onSelected: _cameraControlsLocked'));
    expect(source, contains('_capturePipelineBusy ||\n                                _videoFinalizeInProgress'));
    expect(source, contains('ModalBarrier('));
  });

  test('video stop locks before stopVideoRecording and unlocks only in finally', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final start = source.indexOf('  Future<void> stop() async {');
    final end = source.indexOf('  Map<String, dynamic> _photoTemporalV2Unavailable(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);
    final lock = block.indexOf('_capturePipelineBusy = true;');
    final stop = block.indexOf('stopVideoRecording()');
    final process = block.indexOf('await processVideo(');
    final unlock = block.lastIndexOf('_capturePipelineBusy = false;');
    expect(lock, greaterThanOrEqualTo(0));
    expect(stop, greaterThan(lock));
    expect(process, greaterThan(stop));
    expect(unlock, greaterThan(process));
  });

  test('photo remains locked through the entire save/certificate pipeline', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final start = source.indexOf('  Future<void> takePhoto() async {');
    final end = source.indexOf('  Future<Directory> _downloadsDirectory()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);
    expect(block.indexOf('_capturePipelineBusy = true;'), greaterThanOrEqualTo(0));
    expect(block.indexOf('takePicture()'), greaterThanOrEqualTo(0));
    expect(block.indexOf('createPhotoPackage('), greaterThanOrEqualTo(0));
    expect(block.indexOf('saveContentToGallery('), greaterThanOrEqualTo(0));
    expect(block, contains('finally {'));
    expect(block.lastIndexOf('_capturePipelineBusy = false;'), greaterThan(block.indexOf('saveContentToGallery(')));
  });

  test('no illumination or torch probe is introduced', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, isNot(contains('HCVIlluminationResponseProbe')));
    expect(source, isNot(contains('captureIlluminationResponseNative')));
  });
}
''')

print('BUILD92 capture lock + HFR full-frame rescue patch applied')
