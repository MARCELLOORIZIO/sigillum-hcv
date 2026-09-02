from pathlib import Path

path = Path('lib/hcv_display_risk_fusion.dart')
s = path.read_text()

anchor = '''  static HCVDisplayRiskResult combine(
    List<Map<String, dynamic>?> analyses, {
    bool liveCaptureOnly = false,
  }) {'''
helper = '''  static bool _isCredibleRealityMl(
    Map<String, dynamic>? ml, {
    required double maxScreenProbability,
    required double minConfidence,
  }) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    return predictedClass.startsWith('REALITY_') &&
        score <= 2 &&
        screenProbability <= maxScreenProbability &&
        confidence >= minConfidence;
  }

  static Map<String, dynamic>? _embeddedPhotoTemporalMl(
    Map<String, dynamic>? live,
  ) {
    final probe = live?['photoTemporalVideoProbe'];
    if (probe is! Map) return null;
    final ml = probe['mlScreenReplayAnalysis'];
    if (ml is! Map) return null;
    return Map<String, dynamic>.from(ml);
  }

''' + anchor
if anchor not in s:
    raise SystemExit('combine anchor not found')
s = s.replace(anchor, helper, 1)

old = '''    final live = _firstOfType(available, 'SIGILLUM_LIVE_SCREEN_PROBE_V1');
    if (liveCaptureOnly) {
      final videoEquivalent = _embeddedVideoEquivalentResult(live);
      if (videoEquivalent != null && spatialPostCaptureMl == null) {
        return videoEquivalent;
      }
    }
'''
new = '''    final live = _firstOfType(available, 'SIGILLUM_LIVE_SCREEN_PROBE_V1');
    final photoTemporalMl =
        liveCaptureOnly ? _embeddedPhotoTemporalMl(live) : null;
    final photoDualRealityAgreement = liveCaptureOnly &&
        _isCredibleRealityMl(
          postCaptureMl,
          maxScreenProbability: 0.02,
          minConfidence: 0.40,
        ) &&
        _isCredibleRealityMl(
          photoTemporalMl,
          maxScreenProbability: 0.02,
          minConfidence: 0.60,
        );
    if (liveCaptureOnly) {
      final videoEquivalent = _embeddedVideoEquivalentResult(live);
      if (videoEquivalent != null &&
          spatialPostCaptureMl == null &&
          !photoDualRealityAgreement) {
        return videoEquivalent;
      }
    }
'''
if old not in s:
    raise SystemExit('photo early-return anchor not found')
s = s.replace(old, new, 1)

old = '''    final mlStrongScreenFrameCount =
        (ml?['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mlSignals = _signals(ml);
'''
new = '''    final mlStrongScreenFrameCount =
        (ml?['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mlMediumScreenFrameCount =
        (ml?['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mlSignals = _signals(ml);
'''
if old not in s:
    raise SystemExit('ML frame-count anchor not found')
s = s.replace(old, new, 1)

old = '''    final mlPlanarGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'PLANAR' &&
        (mlPersistentVideoEvidence || mlMultiFrameScreenConsistency);

    final strongDisplayFamilies = <String>{};
'''
new = '''    final mlPlanarGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'PLANAR' &&
        (mlPersistentVideoEvidence || mlMultiFrameScreenConsistency);
    final weakScreenAcrossVideoFrames = !liveCaptureOnly &&
        mlFramesAnalyzed >= 3 &&
        mlStrongScreenFrameCount == 0 &&
        mlMediumScreenFrameCount == 0 &&
        (mlAverageFrameScore ?? 100.0) <= 20.0 &&
        (mlScreenProbability ?? 1.0) <= 0.60 &&
        !mlStrong;
    final geometryRealityWithIndependentNonDisplay =
        geometrySceneClass == 'REALITY' &&
        weakScreenAcrossVideoFrames &&
        !passiveStructuralEvidence &&
        !passiveStrong &&
        !passiveModerate;

    final strongDisplayFamilies = <String>{};
'''
if old not in s:
    raise SystemExit('geometry override anchor not found')
s = s.replace(old, new, 1)

old = '''    } else if (mlStrong && geometryReality) {
      decision = 'NON_CONCLUSIVE';
      score = max(45, min(rawScore, 69));
      reasons.add('ML_GEOMETRY_CONFLICT');
    } else if (activeDisplayEvidence && geometryReality) {
'''
new = '''    } else if (geometryRealityWithIndependentNonDisplay) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      reasons.add(
        'GEOMETRIC_REALITY_AND_WEAK_MULTI_FRAME_SCREEN_EVIDENCE_AGREE',
      );
    } else if (photoDualRealityAgreement &&
        !passiveStructuralEvidence &&
        !hasIndependentCorroboration &&
        !mlStrong) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      reasons.add('PHOTO_DUAL_REALITY_ML_AGREEMENT_OVERRIDES_ACTIVE_ONLY_SIGNAL');
    } else if (mlStrong && geometryReality) {
      decision = 'NON_CONCLUSIVE';
      score = max(45, min(rawScore, 69));
      reasons.add('ML_GEOMETRY_CONFLICT');
    } else if (activeDisplayEvidence && geometryReality) {
'''
if old not in s:
    raise SystemExit('decision anchor not found')
s = s.replace(old, new, 1)
path.write_text(s)

test = r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _photoLive() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'sceneClass': 'UNKNOWN',
      'localTemporalFlickerScore': 0.5854,
      'refreshBandScore': 0.1755,
      'fineStripeScore': 0.0198,
      'fineGridScore': 0.9799,
      'moireFrequencyScore': 0.4976,
      'signals': <String, dynamic>{
        'rawActiveDisplayEvidence': true,
        'activeIlluminationDisplayEvidence': true,
        'reflectedRealityEvidence': false,
        'activeChallengeIndeterminate': false,
        'planarSceneEvidence': false,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
      },
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'UNKNOWN',
        'realityEvidence': false,
        'planarEvidence': false,
      },
      'videoEquivalentAvailable': true,
      'videoEquivalentDisplayRisk': <String, dynamic>{
        'risk': 'MEDIUM',
        'score': 45,
        'decision': 'NON_CONCLUSIVE',
        'analysisStatus': 'COMPLETE',
        'evidenceSources': <String>['ACTIVE_ILLUMINATION'],
        'strongSources': <String>[],
        'reasons': <String>['ACTIVE_EMISSIVE_DISPLAY_EVIDENCE'],
      },
      'photoTemporalVideoProbe': <String, dynamic>{
        'mlScreenReplayAnalysis': <String, dynamic>{
          'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
          'analysisStatus': 'ANALYZED',
          'framesAnalyzed': 3,
          'screenReplayRiskScore': 0,
          'screenProbability': 0.0033,
          'predictedClass': 'REALITY_OUTDOOR',
          'predictedClassConfidence': 0.7358,
        },
      },
    };

Map<String, dynamic> _photoPostMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRiskScore': 0,
      'screenProbability': 0.0028,
      'predictedClass': 'REALITY_ROOM',
      'predictedClassConfidence': 0.4815,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 0,
        'contentAreaRiskScore': 0,
      },
    };

Map<String, dynamic> _videoLive() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'sceneClass': 'UNKNOWN',
      'signals': <String, dynamic>{
        'rawActiveDisplayEvidence': true,
        'activeIlluminationDisplayEvidence': true,
        'reflectedRealityEvidence': false,
        'activeChallengeIndeterminate': false,
        'planarSceneEvidence': false,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
      },
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'REALITY',
        'realityEvidence': true,
        'planarEvidence': false,
      },
    };

Map<String, dynamic> _videoPassiveReality() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'screenReplayRiskScore': 0,
      'signals': <String, dynamic>{
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'strongDisplayTrace': false,
        'horizontalRefreshBands': false,
      },
    };

Map<String, dynamic> _videoWeakScreenMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 4,
      'screenReplayRiskScore': 45,
      'screenProbability': 0.4504,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.4441,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 11.5,
      'maxFrameScreenReplayRiskScore': 45,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 45,
        'contentAreaRiskScore': 45,
      },
    };

Map<String, dynamic> _strongMonitorMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 5,
      'screenReplayRiskScore': 99,
      'screenProbability': 0.9941,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.9935,
      'strongScreenFrameCount': 3,
      'mediumScreenFrameCount': 4,
      'averageScreenReplayRiskScore': 94.4,
      'maxFrameScreenReplayRiskScore': 99,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 99,
        'contentAreaRiskScore': 99,
      },
    };

void main() {
  test('HCV-729930 photo dual REALITY agreement defeats active-only false cue', () {
    final result = HCVDisplayRiskFusion.combine(
      <Map<String, dynamic>?>[_photoLive(), _photoPostMl()],
      liveCaptureOnly: true,
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
    expect(result.reasons,
        contains('PHOTO_DUAL_REALITY_ML_AGREEMENT_OVERRIDES_ACTIVE_ONLY_SIGNAL'));
  });

  test('HCV-90C4 video geometry REALITY plus weak screen frames wins', () {
    final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
      _videoLive(),
      _videoPassiveReality(),
      _videoWeakScreenMl(),
    ]);
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
    expect(result.reasons,
        contains('GEOMETRIC_REALITY_AND_WEAK_MULTI_FRAME_SCREEN_EVIDENCE_AGREE'));
  });

  test('strong REALITY-geometry monitor remains STRONG DISPLAY', () {
    final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
      _videoLive(),
      _videoPassiveReality(),
      _strongMonitorMl(),
    ]);
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, greaterThanOrEqualTo(85));
    expect(result.reasons,
        contains('ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'));
  });
}
'''
Path('test/build67_reality_regression_test.dart').write_text(test)
