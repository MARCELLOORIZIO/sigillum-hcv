import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  test('archive 20 monitor profile is strong when planar parallax agrees', () {
    final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
      <String, dynamic>{
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'framesAnalyzed': 45,
        'screenReplayRiskScore': 45,
        'displayRiskDecision': 'NON_CONCLUSIVE',
        'localTemporalFlickerScore': 0.5525,
        'refreshBandScore': 0.1647,
        'persistentPatternScore': 0.6759,
        'signals': <String, dynamic>{
          'rawActiveDisplayEvidence': true,
          'activeIlluminationDisplayEvidence': true,
          'planarSceneEvidence': true,
          'reflectedRealityEvidence': false,
          'geometricRealityEvidence': false,
        },
      },
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.strongSources, contains('ACTIVE_PLANAR_TEMPORAL'));
    expect(result.evidenceSources, contains('PLANAR_PARALLAX'));
  });

  test('depth without planar agreement does not become a strong display', () {
    final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
      <String, dynamic>{
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'framesAnalyzed': 45,
        'screenReplayRiskScore': 20,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'localTemporalFlickerScore': 0.55,
        'refreshBandScore': 0.17,
        'persistentPatternScore': 0.70,
        'signals': <String, dynamic>{
          'rawActiveDisplayEvidence': true,
          'activeIlluminationDisplayEvidence': false,
          'planarSceneEvidence': false,
          'reflectedRealityEvidence': false,
          'geometricRealityEvidence': true,
        },
      },
    ]);

    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('geometry source never compares different lighting phases', () {
    final geometry = File('lib/hcv_live_screen_probe_geometry.dart')
        .readAsStringSync();
    expect(geometry, isNot(contains('baseline.first, recovery.last')));
    expect(geometry, isNot(contains('baseline.last, recovery.first')));
    expect(geometry, isNot(contains('min(0.30, metrics.depthDispersion)')));
    expect(geometry, contains('HCVProjectiveMotionModel.fit'));
  });

  test('capture confirmation is compact and above the zoom strip', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final start = camera.indexOf('_showCaptureReadyMessage');
    final end = camera.indexOf('_toggleCoordinateStamp', start);
    final confirmation = camera.substring(start, end);

    expect(confirmation, contains('Alignment.topCenter'));
    expect(confirmation, contains("'PROSEGUI'"));
    expect(confirmation, contains('BoxConstraints(maxWidth: 320)'));
    expect(confirmation, contains('minimumSize: const Size(0, 56)'));
    expect(confirmation, isNot(contains('AlertDialog')));
  });

  test('raw display flash and geometric depth stay distinct', () {
    final core = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    expect(core, contains("'rawActiveDisplayEvidence'"));
    expect(core, contains("'geometryModelVersion'"));
    expect(
      core,
      contains("final reflectedRealityEvidence = active.reasons.contains("),
    );
    expect(
      core,
      isNot(
        contains(
          'final reflectedRealityEvidence = sceneDecision.realityEvidence',
        ),
      ),
    );
  });
}
