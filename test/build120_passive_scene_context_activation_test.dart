import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_final_policy.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_context_evidence.dart';

void main() {
  group('BUILD120 passive scene context', () {
    test(
        'multi-depth geometry plus accelerometer motion confirms embedded reality',
        () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _realityGeometryProbe(),
        sensorSignals: _sensorSignals(
          accelerometerSamples: 12,
          accelerometerMotion: 0.12,
          gyroscopeSamples: 4,
          gyroscopeMotion: 0.0,
        ),
      );

      expect(
        context.contextClass,
        HCVSceneContextEvidence.displayEmbeddedInReality,
      );
      expect(context.positiveRealityEvidence, isTrue);
      expect(
        context.reasons,
        contains('ACCELEROMETER_CAMERA_MOTION_CORROBORATED'),
      );
      expect(
        context.reasons,
        contains('PASSIVE_GEOMETRY_SENSOR_CORROBORATION_V1'),
      );
    });

    test('multi-depth geometry plus gyroscope motion confirms embedded reality',
        () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _realityGeometryProbe(),
        sensorSignals: _sensorSignals(
          accelerometerSamples: 4,
          accelerometerMotion: 0.0,
          gyroscopeSamples: 10,
          gyroscopeMotion: 0.06,
        ),
      );

      expect(
        context.contextClass,
        HCVSceneContextEvidence.displayEmbeddedInReality,
      );
      expect(
        context.reasons,
        contains('GYROSCOPE_CAMERA_MOTION_CORROBORATED'),
      );
    });

    test('geometry alone remains unknown', () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _realityGeometryProbe(),
        sensorSignals: _sensorSignals(
          accelerometerSamples: 12,
          accelerometerMotion: 0.0,
          gyroscopeSamples: 12,
          gyroscopeMotion: 0.0,
        ),
      );

      expect(
        context.contextClass,
        HCVSceneContextEvidence.sceneContextUnknown,
      );
      expect(context.positiveRealityEvidence, isTrue);
      expect(
        context.reasons,
        contains('DEVICE_MOTION_SENSOR_CORROBORATION_INSUFFICIENT'),
      );
    });

    test('planar geometry remains unknown even with strong device motion', () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _planarGeometryProbe(),
        sensorSignals: _sensorSignals(
          accelerometerSamples: 20,
          accelerometerMotion: 0.8,
          gyroscopeSamples: 20,
          gyroscopeMotion: 0.4,
        ),
      );

      expect(
        context.contextClass,
        HCVSceneContextEvidence.sceneContextUnknown,
      );
      expect(context.positiveRealityEvidence, isFalse);
      expect(
        context.reasons,
        contains('PLANAR_GEOMETRY_IS_NOT_DISPLAY_DOMINANCE_PROOF'),
      );
    });

    test('confirmed embedded physical context resolves strong display physics',
        () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _realityGeometryProbe(),
        sensorSignals: _sensorSignals(
          accelerometerSamples: 12,
          accelerometerMotion: 0.12,
          gyroscopeSamples: 12,
          gyroscopeMotion: 0.04,
        ),
      );
      final physics = HCVDisplayRiskResult(
        risk: 'HIGH',
        score: 98,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['HFR_DISPLAY', 'ML_SCREEN'],
        strongSources: const <String>['HFR_DISPLAY', 'ML_SCREEN'],
        reasons: const <String>['DISPLAY_PHYSICS_STRONG'],
      );

      final result = HCVDisplayFinalPolicy.resolve(
        displayPhysics: physics,
        sceneContext: context,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('DISPLAY_EMBEDDED_IN_REALITY_FINAL_POLICY'),
      );
    });

    test('camera pipeline captures context before both photo and video', () {
      final source = File('lib/camera_page.dart').readAsStringSync();

      expect(
        RegExp(
          r'pendingSceneContextProbe\s*=\s*await _capturePassiveSceneContext\(\)',
        ).hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(
          r'sceneContextProbe\s*=\s*await _capturePassiveSceneContext\(\)',
        ).hasMatch(source),
        isTrue,
      );
      expect(source, contains('"passiveSceneContextProbe": sceneContextProbe'));
      expect(
        source,
        contains('HCVSceneContextEvidence.fromPassiveGeometryAndSensors'),
      );
    });

    test('accepted photo temporal cycle remains 1.5 seconds and 3 ML frames',
        () {
      final source =
          File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

      expect(
        source,
        contains(
          'static const Duration defaultDuration = Duration(milliseconds: 1500)',
        ),
      );
      expect(source, contains('static const int photoMlFrameLimit = 3'));
    });
  });
}

Map<String, dynamic> _realityGeometryProbe() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'REALITY',
        'realityEvidence': true,
        'planarEvidence': false,
        'motionMagnitude': 0.25,
        'flowReliability': 0.72,
        'directionCoherence': 0.58,
        'depthDispersion': 0.78,
        'planarCoherence': 0.18,
        'matchedRegions': 8,
      },
    };

Map<String, dynamic> _planarGeometryProbe() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'PLANAR',
        'realityEvidence': false,
        'planarEvidence': true,
        'motionMagnitude': 0.25,
        'flowReliability': 0.72,
        'directionCoherence': 0.82,
        'depthDispersion': 0.12,
        'planarCoherence': 0.78,
        'matchedRegions': 8,
      },
    };

Map<String, dynamic> _sensorSignals({
  required int accelerometerSamples,
  required double accelerometerMotion,
  required int gyroscopeSamples,
  required double gyroscopeMotion,
}) =>
    <String, dynamic>{
      'signalsRecorded': accelerometerSamples > 0 || gyroscopeSamples > 0,
      'accelerometerSamples': accelerometerSamples,
      'gyroscopeSamples': gyroscopeSamples,
      'accelerometerMotionScore': accelerometerMotion,
      'gyroscopeMotionScore': gyroscopeMotion,
    };
