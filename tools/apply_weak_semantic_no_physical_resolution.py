from pathlib import Path

fusion_path = Path('lib/hcv_display_risk_fusion.dart')
camera_path = Path('lib/camera_page.dart')
test_path = Path('test/weak_semantic_no_physical_resolution_test.dart')

fusion = fusion_path.read_text()
marker = "class HCVDisplayRiskFusion {\n  static HCVDisplayRiskResult? mlFirstPhotoDecision("
if marker not in fusion:
    raise SystemExit('fusion insertion marker not found')

helper = r'''class HCVDisplayRiskFusion {
  /// Resolves only the narrow failure mode where the current fusion is already
  /// NON_CONCLUSIVE, no display evidence source survived, a complete strict
  /// HFR V2 probe was negative, the passive optical analyzer found no physical
  /// display trace, and ML evidence is either weak screen-like semantics or an
  /// extremely strong single-frame REALITY result.
  ///
  /// This is intentionally not a general "negative HFR means reality" rule.
  /// Missing/partial HFR, any hard optical trace, any surviving evidence source,
  /// or medium/strong persistent ML screen evidence leaves the decision intact.
  static HCVDisplayRiskResult resolveWeakSemanticOnlyWithNegativeHfr({
    required HCVDisplayRiskResult base,
    required Map<String, dynamic>? passiveOptical,
    required Map<String, dynamic>? ml,
    required Map<String, dynamic>? temporalFrequencyProbe,
    Map<String, dynamic>? photoTemporalMl,
  }) {
    if (base.decision != 'NON_CONCLUSIVE' ||
        base.evidenceSources.isNotEmpty ||
        base.strongSources.isNotEmpty ||
        !base.reasons.contains('DISPLAY_CLASSIFICATION_NOT_RESOLVED')) {
      return base;
    }
    if (!_isCompleteStrictNegativeHfr(temporalFrequencyProbe) ||
        !_hasNoPhysicalDisplayTrace(passiveOptical)) {
      return base;
    }

    final isPhotoTemporalCase = photoTemporalMl != null;
    if (isPhotoTemporalCase) {
      if (!_isWeakPhotoStillSemantic(ml) ||
          !_isWeakMultiFrameScreenSemantic(photoTemporalMl)) {
        return base;
      }
    } else {
      final weakMultiFrame = _isWeakMultiFrameScreenSemantic(ml);
      final extremeSingleFrameReality = _isExtremeSingleFrameReality(ml);
      if (!weakMultiFrame && !extremeSingleFrameReality) {
        return base;
      }
    }

    final reasons = base.reasons
        .where(
          (reason) =>
              reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
              reason != 'LIVE_PROBE_MISSING',
        )
        .toList();
    reasons.add('STRICT_NEGATIVE_HFR_NO_PHYSICAL_DISPLAY_TRACE');
    reasons.add(
      isPhotoTemporalCase
          ? 'WEAK_PHOTO_AND_TEMPORAL_SCREEN_SEMANTICS_UNCORROBORATED'
          : _isExtremeSingleFrameReality(ml)
              ? 'EXTREME_SINGLE_FRAME_REALITY_WITH_PHYSICAL_NEGATIVE_CORROBORATION'
              : 'WEAK_MULTI_FRAME_SCREEN_SEMANTICS_UNCORROBORATED',
    );

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

  static bool _isCompleteStrictNegativeHfr(
    Map<String, dynamic>? probe,
  ) {
    if (probe == null ||
        probe['type'] != 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2' ||
        probe['analysisStatus'] != 'ANALYZED' ||
        probe['coherentDisplayPeriodicity'] != false ||
        probe['shortExposureVerified'] != true ||
        probe['exposureLockedForEntireNativeCapture'] != true) {
      return false;
    }
    final frames = (probe['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final fps =
        (probe['actualFrameRateFromTimestamps'] as num?)?.toDouble() ?? 0.0;
    return frames >= 60 && fps >= 120.0;
  }

  static bool _hasNoPhysicalDisplayTrace(Map<String, dynamic>? optical) {
    if (optical == null || optical['analysisStatus'] == 'NOT_ANALYZED') {
      return false;
    }
    final frames = (optical['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final score = (optical['screenReplayRiskScore'] as num?)?.toInt();
    if (frames < 12 || score == null || score > 20) return false;

    final signals = _signals(optical);
    const hardSignalKeys = <String>[
      'displayFlicker',
      'pixelGridOrMoireHint',
      'uniformPixelGrid',
      'localRefreshFlicker',
      'horizontalRefreshBands',
      'pairedLocalRefresh',
      'temporalScreenPulse',
      'structuralDisplayTrace',
      'strongDisplayTrace',
      'confirmedDisplayTrace',
      'periodicLightTrace',
      'opticalCorroboratedTrace',
    ];
    return hardSignalKeys.every((key) => signals[key] != true);
  }

  static bool _isWeakPhotoStillSemantic(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 1.0;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final signals = _signals(ml);
    final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 100;
    final contentArea =
        (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 100;

    if (predictedClass.startsWith('REALITY_')) {
      return screenProbability <= 0.20 && score <= 20;
    }
    return predictedClass.startsWith('SCREEN_') &&
        screenProbability <= 0.70 &&
        score <= 70 &&
        confidence <= 0.60 &&
        (fullFrame < 90 || contentArea < 85);
  }

  static bool _isWeakMultiFrameScreenSemantic(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    if (frames < 2) return false;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrame =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 1.0;

    return medium == 0 &&
        strong == 0 &&
        average <= 65.0 &&
        maxFrame <= 80 &&
        screenProbability <= 0.80 &&
        confidence <= 0.60;
  }

  static bool _isExtremeSingleFrameReality(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    return frames == 1 &&
        predictedClass.startsWith('REALITY_') &&
        screenProbability <= 0.02 &&
        score <= 2 &&
        confidence >= 0.30;
  }

  static HCVDisplayRiskResult? mlFirstPhotoDecision('''

fusion = fusion.replace(marker, helper, 1)
fusion_path.write_text(fusion)

camera = camera_path.read_text()
photo_old = '''      final displayRisk = _promoteWithCoherentHfrDisplayPeriodicity(
        baseDisplayRisk,
        temporalFrequencyProbe,
      );'''
photo_new = '''      final hfrDisplayRisk = _promoteWithCoherentHfrDisplayPeriodicity(
        baseDisplayRisk,
        temporalFrequencyProbe,
      );
      final photoTemporalProbeRaw =
          liveScreenProbe['photoTemporalVideoProbe'];
      final photoTemporalProbe = photoTemporalProbeRaw is Map
          ? Map<String, dynamic>.from(photoTemporalProbeRaw)
          : null;
      final photoTemporalMlRaw =
          photoTemporalProbe?['mlScreenReplayAnalysis'];
      final photoTemporalOpticalRaw =
          photoTemporalProbe?['screenReplayAnalysis'];
      final photoTemporalMl = photoTemporalMlRaw is Map
          ? Map<String, dynamic>.from(photoTemporalMlRaw)
          : null;
      final photoTemporalOptical = photoTemporalOpticalRaw is Map
          ? Map<String, dynamic>.from(photoTemporalOpticalRaw)
          : null;
      final displayRisk =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: hfrDisplayRisk,
        passiveOptical: photoTemporalOptical,
        ml: mlScreenReplayAnalysis,
        temporalFrequencyProbe: temporalFrequencyProbe,
        photoTemporalMl: photoTemporalMl,
      );'''
if camera.count(photo_old) != 1:
    raise SystemExit(f'expected one photo HFR decision block, found {camera.count(photo_old)}')
camera = camera.replace(photo_old, photo_new, 1)

video_old = '''    final displayRisk = _promoteWithCoherentHfrDisplayPeriodicity(
      baseDisplayRisk,
      temporalFrequencyProbe,
    );'''
video_new = '''    final hfrDisplayRisk = _promoteWithCoherentHfrDisplayPeriodicity(
      baseDisplayRisk,
      temporalFrequencyProbe,
    );
    final displayRisk =
        HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: hfrDisplayRisk,
      passiveOptical: screenReplayAnalysis,
      ml: mlScreenReplayAnalysis,
      temporalFrequencyProbe: temporalFrequencyProbe,
    );'''
if camera.count(video_old) != 1:
    raise SystemExit(f'expected one video HFR decision block, found {camera.count(video_old)}')
camera = camera.replace(video_old, video_new, 1)
camera_path.write_text(camera)

test_path.write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

HCVDisplayRiskResult unresolved() => const HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'PARTIAL',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>[
        'DISPLAY_CLASSIFICATION_NOT_RESOLVED',
        'LIVE_PROBE_MISSING',
      ],
    );

Map<String, dynamic> negativeHfr() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
    };

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

Map<String, dynamic> ml({
  required int frames,
  required String predictedClass,
  required double p,
  required double confidence,
  required int score,
  int medium = 0,
  int strong = 0,
  double? average,
  int? maxFrame,
  int fullFrame = 0,
  int contentArea = 0,
}) => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frames,
      'predictedClass': predictedClass,
      'screenProbability': p,
      'predictedClassConfidence': confidence,
      'screenReplayRiskScore': score,
      'mediumScreenFrameCount': medium,
      'strongScreenFrameCount': strong,
      if (average != null) 'averageScreenReplayRiskScore': average,
      if (maxFrame != null) 'maxFrameScreenReplayRiskScore': maxFrame,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

void main() {
  test('build100 reflective artwork photo resolves without weakening gates', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.5516,
        confidence: 0.4407,
        score: 55,
        fullFrame: 55,
        contentArea: 59,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.5915,
        confidence: 0.3368,
        score: 59,
        average: 53.75,
        maxFrame: 59,
        fullFrame: 59,
        contentArea: 66,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
  });

  test('build100 textile photo resolves weak texture semantics', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.6155,
        confidence: 0.3864,
        score: 62,
        fullFrame: 62,
        contentArea: 26,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.7795,
        confidence: 0.5167,
        score: 78,
        average: 51.5,
        maxFrame: 78,
        fullFrame: 78,
        contentArea: 67,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('build100 reflective artwork video resolves weak screen semantics', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 2,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.7476,
        confidence: 0.4658,
        score: 75,
        average: 64.5,
        maxFrame: 75,
        fullFrame: 75,
        contentArea: 81,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('build100 short real video resolves extreme single-frame reality', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'REALITY_ROOM',
        p: 0.0008,
        confidence: 0.4795,
        score: 0,
        average: 0.0,
        maxFrame: 0,
        fullFrame: 0,
        contentArea: 1,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('missing HFR keeps historical incompatible samples unchanged', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 2,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.60,
        confidence: 0.40,
        score: 60,
        average: 55.0,
        maxFrame: 65,
      ),
      temporalFrequencyProbe: null,
    );
    expect(identical(result, base), isTrue);
  });

  test('any hard physical display signal blocks downgrade', () {
    final base = unresolved();
    final optical = cleanOptical();
    (optical['signals'] as Map<String, dynamic>)['horizontalRefreshBands'] = true;
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: optical,
      ml: ml(
        frames: 2,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.60,
        confidence: 0.40,
        score: 60,
        average: 55.0,
        maxFrame: 65,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(identical(result, base), isTrue);
  });

  test('persistent medium or strong ML screen evidence blocks downgrade', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.94,
        confidence: 0.92,
        score: 94,
        medium: 4,
        strong: 3,
        average: 92.75,
        maxFrame: 94,
        fullFrame: 94,
        contentArea: 90,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(identical(result, base), isTrue);
  });

  test('positive coherent HFR can never be downgraded', () {
    final base = unresolved();
    final hfr = negativeHfr()..['coherentDisplayPeriodicity'] = true;
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 2,
        predictedClass: 'REALITY_OUTDOOR',
        p: 0.01,
        confidence: 0.90,
        score: 1,
        average: 1.0,
        maxFrame: 1,
      ),
      temporalFrequencyProbe: hfr,
    );
    expect(identical(result, base), isTrue);
  });
}
''')

print('Applied bounded weak-semantic/no-physical-display resolution patch.')
