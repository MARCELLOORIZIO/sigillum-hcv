from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'missing expected text in {path}: {old[:120]!r}')
    if text.count(old) != 1:
        raise SystemExit(f'expected exactly one match in {path}, got {text.count(old)}')
    p.write_text(text.replace(old, new, 1))


# 1) Fast photo temporal capture: 1.5 s, three ML samples at 0.6 s cadence.
replace_once(
    'lib/hcv_temporal_capture_probe.dart',
    'static const Duration defaultDuration = Duration(milliseconds: 2400);',
    'static const Duration defaultDuration = Duration(milliseconds: 1500);',
)
replace_once(
    'lib/hcv_temporal_capture_probe.dart',
    'static const int photoMlFrameLimit = 4;',
    'static const int photoMlFrameLimit = 3;',
)
replace_once(
    'lib/hcv_temporal_capture_probe.dart',
    '/// Four ML samples are requested at 0.6 s spacing inside the 2.4 s clip,',
    '/// Three ML samples are requested at 0.6 s spacing inside the 1.5 s clip,',
)
replace_once(
    'lib/camera_page.dart',
    'Photo Temporal V2 uses a disposable 2.4 s clip immediately before automatic still capture. Manual parallax is not used.',
    'Photo Temporal V2 uses a disposable 1.5 s clip immediately before automatic still capture. Manual parallax is not used.',
)
replace_once(
    'lib/camera_page.dart',
    '// photo mode then gets the existing 2.4 s temporal clip as extra settle.',
    '// photo mode then gets the 1.5 s temporal clip as extra settle.',
)

# 2) Active dual-evidence resolver. Existing HFR V2 remains unchanged.
fusion = Path('lib/hcv_display_risk_fusion.dart')
text = fusion.read_text()
entry_old = """  }) {\n    if (base.decision != 'NON_CONCLUSIVE' ||\n"""
entry_new = """  }) {\n    final dualEvidence = _resolveDualEvidenceV1(\n      base: base,\n      passiveOptical: passiveOptical,\n      ml: ml,\n      temporalFrequencyProbe: temporalFrequencyProbe,\n      photoTemporalMl: photoTemporalMl,\n    );\n    if (dualEvidence != null) return dualEvidence;\n\n    if (base.decision != 'NON_CONCLUSIVE' ||\n"""
if entry_old not in text or text.count(entry_old) != 1:
    raise SystemExit('unable to locate fusion resolver entry')
text = text.replace(entry_old, entry_new, 1)
text = text.replace('            minFrames: 4,', '            minFrames: 3,', 1)

helper_marker = "  static bool _isCompleteStrictNegativeHfr(Map<String, dynamic>? probe) {"
if helper_marker not in text or text.count(helper_marker) != 1:
    raise SystemExit('unable to locate HFR helper insertion point')

helpers = r'''  static HCVDisplayRiskResult? _resolveDualEvidenceV1({
    required HCVDisplayRiskResult base,
    required Map<String, dynamic>? passiveOptical,
    required Map<String, dynamic>? ml,
    required Map<String, dynamic>? temporalFrequencyProbe,
    Map<String, dynamic>? photoTemporalMl,
  }) {
    final temporalMl = photoTemporalMl ?? ml;
    final temporalFrames = _temporalFrameCount(temporalMl);
    final highScreenFrames = _temporalHighScreenFrameCount(temporalMl);

    final physicalDisplay =
        _isCompleteStrictPositiveHfr(temporalFrequencyProbe);
    final persistentVisualDisplay =
        temporalFrames >= 2 && highScreenFrames >= 2;

    if (physicalDisplay || persistentVisualDisplay) {
      final evidenceSources = <String>{...base.evidenceSources};
      final strongSources = <String>{...base.strongSources};
      final reasons = base.reasons
          .where(
            (reason) =>
                reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
                reason != 'LIVE_PROBE_MISSING',
          )
          .toList();

      if (physicalDisplay) {
        evidenceSources.add('DUAL_EVIDENCE_PHYSICAL_DISPLAY_HFR');
        strongSources.add('DUAL_EVIDENCE_PHYSICAL_DISPLAY_HFR');
        reasons.add('DUAL_EVIDENCE_STRICT_COHERENT_DISPLAY_PHYSICS');
      }
      if (persistentVisualDisplay) {
        evidenceSources.add('DUAL_EVIDENCE_TEMPORAL_SCREEN_PERSISTENCE');
        strongSources.add('DUAL_EVIDENCE_TEMPORAL_SCREEN_PERSISTENCE');
        reasons.add('DUAL_EVIDENCE_TWO_HIGH_SCREEN_TEMPORAL_SAMPLES');
      }
      reasons.add('DUAL_EVIDENCE_V1_ACTIVE');

      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: max(base.score, 95),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources.toList(),
        strongSources: strongSources.toList(),
        reasons: reasons,
      );
    }

    final physicalReality =
        _isStrictPhysicalRealityHfr(temporalFrequencyProbe);
    final cleanOptical = _hasNoPhysicalDisplayTrace(passiveOptical);
    final realityEvidence = physicalReality &&
        cleanOptical &&
        base.strongSources.isEmpty &&
        temporalFrames >= 2 &&
        highScreenFrames == 0;

    if (!realityEvidence) return null;

    final reasons = base.reasons
        .where(
          (reason) =>
              reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
              reason != 'LIVE_PROBE_MISSING',
        )
        .toList()
      ..add('DUAL_EVIDENCE_STRICT_PHYSICAL_REALITY_SIGNATURE')
      ..add('DUAL_EVIDENCE_NO_HIGH_SCREEN_TEMPORAL_SAMPLE')
      ..add('DUAL_EVIDENCE_NO_OPTICAL_DISPLAY_TRACE')
      ..add('DUAL_EVIDENCE_V1_ACTIVE');

    return HCVDisplayRiskResult(
      risk: 'LOW',
      score: min(base.score, 20),
      decision: 'NO_DISPLAY_EVIDENCE',
      analysisStatus: 'COMPLETE',
      evidenceSources: base.evidenceSources,
      strongSources: base.strongSources,
      reasons: reasons,
    );
  }

  static bool _isCompleteStrictPositiveHfr(Map<String, dynamic>? probe) {
    if (probe == null ||
        probe['type'] != 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2' ||
        probe['analysisStatus'] != 'ANALYZED' ||
        probe['coherentDisplayPeriodicity'] != true ||
        probe['shortExposureVerified'] != true ||
        probe['exposureLockedForEntireNativeCapture'] != true) {
      return false;
    }
    final frames = (probe['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final fps =
        (probe['actualFrameRateFromTimestamps'] as num?)?.toDouble() ?? 0.0;
    return frames >= 60 && fps >= 120.0;
  }

  static bool _isStrictPhysicalRealityHfr(Map<String, dynamic>? probe) {
    if (!_isCompleteStrictNegativeHfr(probe)) return false;
    final raw = probe?['coherentDisplayPeriodicityEvidence'];
    if (raw is! Map) return false;
    final evidence = Map<String, dynamic>.from(raw);
    final frequency =
        (evidence['dominantTemporalFrequencyHz'] as num?)?.toDouble();
    final periodicity =
        (evidence['medianCellPeriodicityStrength'] as num?)?.toDouble();
    final stability =
        (evidence['medianCellFrequencyStability'] as num?)?.toDouble();
    final periodicCells =
        (evidence['periodicCellCount'] as num?)?.toInt();
    final stableCells = (evidence['stableCellCount'] as num?)?.toInt();
    if (frequency == null ||
        periodicity == null ||
        stability == null ||
        periodicCells == null ||
        stableCells == null) {
      return false;
    }
    return frequency < 10.0 &&
        periodicity < 0.02 &&
        stability < 0.45 &&
        periodicCells == 0 &&
        stableCells == 0;
  }

  static int _temporalFrameCount(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List) return 0;
    return rawFrames.whereType<Map>().length;
  }

  static int _temporalHighScreenFrameCount(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List) return 0;
    var count = 0;
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map) continue;
      final probability =
          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      if (probability >= 0.90) count++;
    }
    return count;
  }

'''
text = text.replace(helper_marker, helpers + helper_marker, 1)
fusion.write_text(text)

# Existing weak-semantic fallback now accepts the 3-sample photo contract.
weak_test = Path('test/weak_semantic_no_physical_resolution_test.dart')
weak = weak_test.read_text()
start = weak.find("  test('photo temporal resolver requires all four BUILD100+ samples', () {")
end = weak.find("  test('photo temporal max frame above 80 blocks downgrade', () {", start)
if start < 0 or end < 0:
    raise SystemExit('unable to locate old four-sample test')
block = weak[start:end]
block = block.replace(
    "test('photo temporal resolver requires all four BUILD100+ samples'",
    "test('photo temporal resolver accepts three fast samples'",
)
block = block.replace("    expect(identical(result, base), isTrue);", "    expect(result.decision, 'NO_DISPLAY_EVIDENCE');")
weak = weak[:start] + block + weak[end:]
weak_test.write_text(weak)

# Active dual-evidence decision tests.
Path('test/dual_display_reality_evidence_v1_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

HCVDisplayRiskResult unresolved() => const HCVDisplayRiskResult(
  risk: 'MEDIUM',
  score: 45,
  decision: 'NON_CONCLUSIVE',
  analysisStatus: 'PARTIAL',
  evidenceSources: <String>[],
  strongSources: <String>[],
  reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
);

Map<String, dynamic> cleanOptical() => <String, dynamic>{
  'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'framesAnalyzed': 15,
  'screenReplayRiskScore': 20,
  'signals': <String, dynamic>{
    'displayFlicker': false,
    'pixelGridOrMoireHint': false,
    'uniformPixelGrid': false,
    'localRefreshFlicker': false,
    'horizontalRefreshBands': false,
    'pairedLocalRefresh': false,
    'temporalScreenPulse': false,
    'structuralDisplayTrace': false,
    'strongDisplayTrace': false,
  },
};

Map<String, dynamic> hfr({required bool coherent, bool reality = false}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': coherent,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'dominantTemporalFrequencyHz': reality ? 2.86 : 100.26,
        'medianCellPeriodicityStrength': reality ? 0.007 : 0.27,
        'medianCellFrequencyStability': reality ? 0.22 : 0.99,
        'medianCellPhaseStepConsistency': reality ? 0.28 : 0.64,
        'periodicCellCount': reality ? 0 : 9,
        'stableCellCount': reality ? 0 : 8,
      },
    };

Map<String, dynamic> temporal(List<double> probabilities) => <String, dynamic>{
  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'framesAnalyzed': probabilities.length,
  'videoFrameAnalyses': <Map<String, dynamic>>[
    for (var i = 0; i < probabilities.length; i++)
      <String, dynamic>{
        'videoFrameIndex': i,
        'screenProbability': probabilities[i],
      },
  ],
};

void main() {
  test('strict coherent HFR is active DISPLAY evidence', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.01, 0.02]),
      temporalFrequencyProbe: hfr(coherent: true),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('DUAL_EVIDENCE_STRICT_COHERENT_DISPLAY_PHYSICS'));
  });

  test('two high temporal screen samples are active DISPLAY evidence', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.98, 0.97]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('DUAL_EVIDENCE_TWO_HIGH_SCREEN_TEMPORAL_SAMPLES'));
  });

  test('BUILD102-like reality signature resolves NON_CONCLUSIVE to reality', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.7414, 0.0204, 0.7886, 0.0055]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
    expect(result.reasons, contains('DUAL_EVIDENCE_STRICT_PHYSICAL_REALITY_SIGNATURE'));
  });

  test('three-sample fast photo monitor remains DISPLAY', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: <String, dynamic>{'analysisStatus': 'ANALYZED'},
      photoTemporalMl: temporal(<double>[0.9599, 0.9784, 0.9625]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });

  test('one isolated high screen sample does not become DISPLAY', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.95, 0.20, 0.30]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('hard optical display trace prevents reality override', () {
    final optical = cleanOptical();
    (optical['signals'] as Map<String, dynamic>)['horizontalRefreshBands'] = true;
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: optical,
      ml: temporal(<double>[0.20, 0.30, 0.40]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(identical(result, base), isTrue);
  });

  test('incomplete HFR cannot create reality evidence', () {
    final incomplete = hfr(coherent: false, reality: true)..['framesAnalyzed'] = 20;
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.20, 0.30, 0.40]),
      temporalFrequencyProbe: incomplete,
    );
    expect(identical(result, base), isTrue);
  });
}
''')

Path('test/photo_temporal_fast_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo temporal capture is 1.5 seconds with three 0.6 second ML samples', () {
    final source = File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();
    expect(source, contains('Duration(milliseconds: 1500)'));
    expect(source, contains('photoMlFrameIntervalSeconds = 0.6'));
    expect(source, contains('photoMlFrameLimit = 3'));
  });

  test('camera certificate note reports the active 1.5 second clip', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('disposable 1.5 s clip'));
    expect(source, isNot(contains('disposable 2.4 s clip')));
  });
}
''')

print('BUILD103 patch applied')
