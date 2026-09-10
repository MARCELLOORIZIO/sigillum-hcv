from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing patch anchor: {label}")
    return text.replace(old, new, 1)


probe_path = Path("lib/hcv_temporal_frequency_probe.dart")
probe = probe_path.read_text()

probe = replace_once(
    probe,
    """    final configuredFps = (raw['configuredFrameRate'] as num?)?.toDouble();
    final actualExposure =
        (raw['actualShortExposureSeconds'] as num?)?.toDouble();
    final framePeriod =
        configuredFps != null && configuredFps > 0 ? 1.0 / configuredFps : null;

    return {
""",
    """    final configuredFps = (raw['configuredFrameRate'] as num?)?.toDouble();
    final actualExposure =
        (raw['actualShortExposureSeconds'] as num?)?.toDouble();
    final framePeriod =
        configuredFps != null && configuredFps > 0 ? 1.0 / configuredFps : null;

    final globalTemporalSpectrum =
        HCVTemporalFrequencyMath.analyzeScalarSequence(frameLuma);
    final dominantTemporalBin =
        (globalTemporalSpectrum['dominantTemporalFrequencyBin'] as num?)
                ?.toInt() ??
            0;
    final dominantTemporalFrequencyHz = actualFps != null &&
            actualFps > 0 &&
            dominantTemporalBin > 0 &&
            acceptedFrames > 0
        ? dominantTemporalBin * actualFps / acceptedFrames
        : null;
    final globalModulationDepth =
        (globalTemporalSpectrum['robustFrameLumaModulationDepth'] as num?)
                ?.toDouble() ??
            0.0;
    final globalSpectralConcentration =
        (globalTemporalSpectrum['temporalSpectralConcentration'] as num?)
                ?.toDouble() ??
            0.0;
    final medianCellPeriodicity = _median(periodicityStrengths) ?? 0.0;
    final medianCellStability = _median(frequencyStabilities) ?? 0.0;
    final medianCellPhase = _median(phaseConsistencies) ?? 0.0;
    final periodicCellCount = cellResults.where((entry) {
      return ((entry['periodicityStrength'] as num?)?.toDouble() ?? 0.0) >=
          0.10;
    }).length;
    final stableCellCount = cellResults.where((entry) {
      return ((entry['dominantFrequencyStability'] as num?)?.toDouble() ??
              0.0) >=
          0.80;
    }).length;
    final coherentDisplayPeriodicity = qualifiesCoherentDisplayPeriodicity(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      globalModulationDepth: globalModulationDepth,
      globalSpectralConcentration: globalSpectralConcentration,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      medianCellPhaseStepConsistency: medianCellPhase,
      periodicCellCount: periodicCellCount,
      stableCellCount: stableCellCount,
    );

    return {
""",
    "probe metrics insertion",
)

probe = replace_once(
    probe,
    """      'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
      'productionDecisionChanged': false,
""",
    """      'decisionRole':
          'DECISIONAL_ONLY_FOR_STRICT_HFR_COHERENT_DISPLAY_PERIODICITY',
      'productionDecisionChanged': coherentDisplayPeriodicity,
      'coherentDisplayPeriodicity': coherentDisplayPeriodicity,
      'coherentDisplayPeriodicityEvidence': {
        'dominantTemporalFrequencyHz': dominantTemporalFrequencyHz,
        'globalModulationDepth': globalModulationDepth,
        'globalSpectralConcentration': globalSpectralConcentration,
        'medianCellPeriodicityStrength': medianCellPeriodicity,
        'medianCellFrequencyStability': medianCellStability,
        'medianCellPhaseStepConsistency': medianCellPhase,
        'periodicCellCount': periodicCellCount,
        'stableCellCount': stableCellCount,
        'requiredPeriodicCells': 6,
        'requiredStableCells': 6,
      },
""",
    "probe decision metadata",
)

probe = replace_once(
    probe,
    """      'globalFrameLumaTemporalSpectrum':
          HCVTemporalFrequencyMath.analyzeScalarSequence(frameLuma),
""",
    """      'globalFrameLumaTemporalSpectrum': globalTemporalSpectrum,
      'globalDominantTemporalFrequencyHz': dominantTemporalFrequencyHz,
""",
    "global temporal spectrum",
)

probe = replace_once(
    probe,
    """      'spatialPolicy': const {
        'gridRows': 3,
        'gridColumns': 3,
        'decisionEnabled': false,
      },
""",
    """      'spatialPolicy': const {
        'gridRows': 3,
        'gridColumns': 3,
        'decisionEnabled': true,
        'decisionGate': 'STRICT_HFR_COHERENT_DISPLAY_PERIODICITY',
      },
""",
    "spatial policy",
)

probe = replace_once(
    probe,
    """      'note':
          'V2 measures row-profile phase evolution directly from native consecutive CMSampleBuffers at the highest isolated hardware tier available (240, 120, then 60 fps). It never participates in BUILD 80 display fusion.',
""",
    """      'note':
          'V2 measures row-profile phase evolution directly from native consecutive CMSampleBuffers. It participates in display fusion only when the strict coherent HFR periodicity gate is satisfied across the frame.',
""",
    "probe note",
)

method_anchor = """  static Map<String, dynamic> unavailable(
"""
method = """  static bool qualifiesCoherentDisplayPeriodicity({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required double? dominantTemporalFrequencyHz,
    required double globalModulationDepth,
    required double globalSpectralConcentration,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int periodicCellCount,
    required int stableCellCount,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    if (dominantTemporalFrequencyHz == null ||
        dominantTemporalFrequencyHz < 40.0 ||
        dominantTemporalFrequencyHz > 120.0 ||
        dominantTemporalFrequencyHz > actualFps / 2.0 + 1.0) {
      return false;
    }
    return globalModulationDepth >= 0.75 &&
        globalSpectralConcentration >= 0.85 &&
        medianCellPeriodicityStrength >= 0.12 &&
        medianCellFrequencyStability >= 0.85 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6 &&
        stableCellCount >= 6;
  }

"""
probe = replace_once(probe, method_anchor, method + method_anchor, "public gate method")

probe = replace_once(
    probe,
    """      'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
      'productionDecisionChanged': false,
      'reason': reason,
""",
    """      'decisionRole':
          'DECISIONAL_ONLY_FOR_STRICT_HFR_COHERENT_DISPLAY_PERIODICITY',
      'productionDecisionChanged': false,
      'coherentDisplayPeriodicity': false,
      'reason': reason,
""",
    "unavailable metadata",
)

probe_path.write_text(probe)

camera_path = Path("lib/camera_page.dart")
camera = camera_path.read_text()

helper_anchor = """bool _hasLiveTemporalScreenCorroboration(Map<String, dynamic>? live) {
"""
helper = """HCVDisplayRiskResult _promoteWithCoherentHfrDisplayPeriodicity(
  HCVDisplayRiskResult base,
  Map<String, dynamic>? temporalFrequencyProbe,
) {
  if (temporalFrequencyProbe == null ||
      temporalFrequencyProbe['analysisStatus'] != 'ANALYZED' ||
      temporalFrequencyProbe['coherentDisplayPeriodicity'] != true) {
    return base;
  }

  final evidenceSources = <String>{
    ...base.evidenceSources,
    'HFR_COHERENT_DISPLAY_PERIODICITY',
  }.toList()
    ..sort();
  final strongSources = <String>{
    ...base.strongSources,
    'HFR_COHERENT_DISPLAY_PERIODICITY',
  }.toList()
    ..sort();
  final reasons = <String>{
    ...base.reasons,
    'HFR_FULL_FRAME_COHERENT_DISPLAY_PERIODICITY',
  }.toList();

  return HCVDisplayRiskResult(
    risk: 'HIGH',
    score: base.score < 95 ? 95 : base.score,
    decision: 'STRONG_DISPLAY_RISK',
    analysisStatus: 'COMPLETE',
    evidenceSources: evidenceSources,
    strongSources: strongSources,
    reasons: reasons,
  );
}

"""
camera = replace_once(
    camera,
    helper_anchor,
    helper + helper_anchor,
    "camera HFR promotion helper",
)

camera = replace_once(
    camera,
    """      final displayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(
        screenReplayAnalyses,
      );
""",
    """      final baseDisplayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(
        screenReplayAnalyses,
      );
      final displayRisk = _promoteWithCoherentHfrDisplayPeriodicity(
        baseDisplayRisk,
        temporalFrequencyProbe,
      );
""",
    "photo HFR promotion",
)

camera = replace_once(
    camera,
    """    final displayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
    );
""",
    """    final baseDisplayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
    );
    final displayRisk = _promoteWithCoherentHfrDisplayPeriodicity(
      baseDisplayRisk,
      temporalFrequencyProbe,
    );
""",
    "video HFR promotion",
)

camera_path.write_text(camera)

Path("test/hfr_coherent_display_periodicity_gate_test.dart").write_text(
    """import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_hcv/hcv_temporal_frequency_probe.dart';

void main() {
  bool gate({
    required double frequencyHz,
    required double modulation,
    required double concentration,
    required double periodicity,
    required double stability,
    double phase = 0.55,
    int periodicCells = 8,
    int stableCells = 8,
  }) {
    return HCVTemporalFrequencyProbe.qualifiesCoherentDisplayPeriodicity(
      actualFps: 240.62,
      framesAnalyzed: 84,
      shortExposureVerified: true,
      exposureLocked: true,
      dominantTemporalFrequencyHz: frequencyHz,
      globalModulationDepth: modulation,
      globalSpectralConcentration: concentration,
      medianCellPeriodicityStrength: periodicity,
      medianCellFrequencyStability: stability,
      medianCellPhaseStepConsistency: phase,
      periodicCellCount: periodicCells,
      stableCellCount: stableCells,
    );
  }

  test('B6D full-frame TV signature remains strong', () {
    expect(gate(frequencyHz: 100.26, modulation: 1.19, concentration: 0.909, periodicity: 0.184, stability: 0.916), isTrue);
  });

  test('3A3 full-frame TV signature remains strong', () {
    expect(gate(frequencyHz: 100.26, modulation: 1.44, concentration: 0.902, periodicity: 0.167, stability: 0.928), isTrue);
  });

  test('D7A semantic reality false negative is recovered physically', () {
    expect(gate(frequencyHz: 100.26, modulation: 0.98, concentration: 0.895, periodicity: 0.208, stability: 0.916), isTrue);
  });

  test('4300 semantic reality false negative is recovered physically', () {
    expect(gate(frequencyHz: 100.26, modulation: 1.15, concentration: 0.899, periodicity: 0.223, stability: 0.928), isTrue);
  });

  test('reflective framed artwork does not satisfy HFR display gate', () {
    expect(gate(frequencyHz: 2.86, modulation: 0.026, concentration: 0.95, periodicity: 0.008, stability: 0.92, periodicCells: 0), isFalse);
  });

  test('TV visible only as part of a real room does not satisfy full-frame gate', () {
    expect(gate(frequencyHz: 100.26, modulation: 0.108, concentration: 0.90, periodicity: 0.022, stability: 0.90, periodicCells: 2), isFalse);
  });

  test('gate requires verified short locked exposure', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesCoherentDisplayPeriodicity(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: false,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.26,
        globalModulationDepth: 1.0,
        globalSpectralConcentration: 0.90,
        medianCellPeriodicityStrength: 0.20,
        medianCellFrequencyStability: 0.92,
        medianCellPhaseStepConsistency: 0.55,
        periodicCellCount: 8,
        stableCellCount: 8,
      ),
      isFalse,
    );
  });
}
"""
)

Path("test/hfr_coherent_display_periodicity_integration_contract_test.dart").write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo and video final decisions both consume strict HFR evidence', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('HFR_COHERENT_DISPLAY_PERIODICITY'));
    expect(source, contains('HFR_FULL_FRAME_COHERENT_DISPLAY_PERIODICITY'));
    expect(RegExp(r'_promoteWithCoherentHfrDisplayPeriodicity\\(').allMatches(source).length, greaterThanOrEqualTo(3));
    expect(RegExp(r'baseDisplayRisk,\\s*temporalFrequencyProbe,').allMatches(source).length, equals(2));
  });
}
"""
)
