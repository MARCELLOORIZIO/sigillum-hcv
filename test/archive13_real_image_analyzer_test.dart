import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_screen_replay_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Archive 13 monitor and physical scene diverge in complete fusion', () async {
    final temp = await Directory.systemTemp.createTemp('sigillum_archive13_');
    try {
      final monitor = await _decodeFixture(
        'test/fixtures/archive13_monitor_compact.b64',
        '${temp.path}/monitor.jpg',
      );
      final reality = await _decodeFixture(
        'test/fixtures/archive13_reality_compact.b64',
        '${temp.path}/reality.jpg',
      );

      final analyzer = HCVScreenReplayAnalyzer();
      final monitorStatic = await analyzer.analyzeImage(monitor.path);
      final realityStatic = await analyzer.analyzeImage(reality.path);

      expect(
        monitorStatic['screenReplayRiskScore'],
        isNotNull,
        reason: 'Monitor non analizzato: $monitorStatic',
      );
      expect(
        realityStatic['screenReplayRiskScore'],
        isNotNull,
        reason: 'Scena fisica non analizzata: $realityStatic',
      );

      final monitorResult = HCVDisplayRiskFusion.combine(
        [
          _archive13MonitorLiveProbe,
          monitorStatic,
          _monitorMl,
        ],
        liveCaptureOnly: true,
      );
      final realityResult = HCVDisplayRiskFusion.combine(
        [
          _archive13RealityLiveProbe,
          realityStatic,
          _realityMl,
        ],
        liveCaptureOnly: true,
      );

      expect(
        monitorResult.decision,
        'STRONG_DISPLAY_RISK',
        reason:
            'La foto reale del monitor non viene riconosciuta dalla fusione: ${monitorResult.toJson()} static=$monitorStatic',
      );
      expect(
        monitorResult.evidenceSources,
        containsAll(<String>['LIVE_PREVIEW', 'ML_SCREEN_CLASS']),
      );
      expect(
        realityResult.decision,
        'NO_DISPLAY_EVIDENCE',
        reason:
            'La scena fisica produce un falso positivo: ${realityResult.toJson()} static=$realityStatic',
      );
      expect(realityResult.score, lessThanOrEqualTo(30));
      expect(
        realityResult.evidenceSources,
        isNot(contains('STATIC_OPTICAL')),
        reason:
            'Bande luminose generiche sono state accettate come evidenza ottica indipendente: $realityStatic',
      );
    } finally {
      await temp.delete(recursive: true);
    }
  });
}

const Map<String, dynamic> _archive13MonitorLiveProbe = {
  'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V2',
  'analysisStatus': 'ANALYZED',
  'analysisQuality': 0.82,
  'framesAnalyzed': 45,
  'screenReplayRisk': 'HIGH',
  'screenReplayRiskScore': 83,
  'displayRiskDecision': 'STRONG_DISPLAY_RISK',
  'localTemporalFlickerScore': 0.6672,
  'refreshBandScore': 0.1600,
  'fineStripeScore': 0.4396,
  'fineGridScore': 0.8782,
  'moireFrequencyScore': 0.5103,
  'persistentPatternScore': 0.6956,
  'signals': {
    'temporalEvidence': true,
    'stripeEvidence': true,
    'spatialEvidence': true,
    'crossPhasePersistence': true,
    'corroboratedModerateTrace': true,
    'confirmedDisplayTrace': true,
  },
};

const Map<String, dynamic> _archive13RealityLiveProbe = {
  'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V2',
  'analysisStatus': 'ANALYZED',
  'analysisQuality': 0.82,
  'framesAnalyzed': 45,
  'screenReplayRisk': 'LOW',
  'screenReplayRiskScore': 20,
  'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
  'localTemporalFlickerScore': 0.4364,
  'refreshBandScore': 0.0640,
  'signals': {
    'temporalEvidence': false,
    'stripeEvidence': false,
    'spatialEvidence': false,
    'crossPhasePersistence': false,
    'corroboratedModerateTrace': false,
    'confirmedDisplayTrace': false,
    'uncorroboratedDisplayPattern': false,
  },
};

const Map<String, dynamic> _monitorMl = {
  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'screenReplayRiskScore': 98,
  'predictedClass': 'SCREEN_MONITOR',
  'predictedClassConfidence': 0.98,
};

const Map<String, dynamic> _realityMl = {
  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'screenReplayRiskScore': 2,
  'predictedClass': 'REALITY_REFLECTED',
  'predictedClassConfidence': 0.99,
};

Future<File> _decodeFixture(String sourcePath, String targetPath) async {
  final normalized = (await File(sourcePath).readAsString())
      .replaceAll(RegExp(r'\s+'), '');
  final target = File(targetPath);
  await target.writeAsBytes(base64Decode(normalized), flush: true);
  return target;
}
