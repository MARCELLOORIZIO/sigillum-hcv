from pathlib import Path

def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)

fusion_path=Path("lib/hcv_display_risk_fusion.dart")
swift_path=Path("ios/Runner/AppDelegate.swift")
test_path=Path("test/hfr_v32_harmonic_reality_physics_test.dart")
fusion = fusion_path.read_text()
fusion = replace_once(fusion,
    '''      return v3?['fullFrameDisplay'] == true &&
          v3?['mixedSceneDetected'] != true &&
          v3?['allNineCellsSameDisplayFamily'] == true &&
          (v3?['spatialFamilyCellCount'] as num?)?.toInt() == 9 &&
          (v3?['rowTimeFamilyCellCount'] as num?)?.toInt() == 9;''',
    '''      final strictSpatialFamily =
          (v3?['spatialFamilyCellCount'] as num?)?.toInt() == 9;
      final harmonicSpatialFamily =
          v3?['harmonicDisplayRecovery'] == true &&
          (v3?['harmonicAwareSpatialFamilyCellCount'] as num?)?.toInt() == 9;
      return v3?['fullFrameDisplay'] == true &&
          v3?['mixedSceneDetected'] != true &&
          v3?['allNineCellsSameDisplayFamily'] == true &&
          (strictSpatialFamily || harmonicSpatialFamily) &&
          (v3?['rowTimeFamilyCellCount'] as num?)?.toInt() == 9;''',
    'fusion harmonic positive')
fusion = replace_once(fusion,
    '''      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3' ||
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1';''',
    '''      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3' ||
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1' ||
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2';''',
    'fusion type')
fusion_path.write_text(fusion)

swift = swift_path.read_text()
swift = replace_once(swift,
    '          let gridSize = max(8, min(32, spatialGridBins))',
    '          let gridSize = max(8, min(64, spatialGridBins))',
    'swift grid max')
swift = replace_once(swift,
    '''      spatialGridBins: 24
    ) { _ in''',
    '''      spatialGridBins: 64
    ) { _ in''',
    'swift diagnostic grid')
swift = replace_once(swift,
    '    payload["spatialGridBins"] = 24',
    '    payload["spatialGridBins"] = 64',
    'swift diagnostic grid metadata')
illum = '''  private func captureActiveIlluminationRealityChallenge(
    output: AVCaptureVideoDataOutput,
    device: AVCaptureDevice,
    frameCount: Int = 10
  ) -> [String: Any] {
    guard device.hasTorch, device.isTorchAvailable else {
      return [
        "analysisStatus": "NOT_ANALYZED",
        "reason": "TORCH_UNAVAILABLE",
      ]
    }

    func captureStage(_ stageName: String) -> [String: Any] {
      let semaphore = DispatchSemaphore(value: 0)
      let collector = HCVTemporalFrequencyNativeCollector(
        targetFrameCount: frameCount,
        rowBins: 48,
        spatialGridBins: 0
      ) { _ in
        semaphore.signal()
      }
      output.setSampleBufferDelegate(collector, queue: temporalFrequencySampleQueue)
      let waitResult = semaphore.wait(timeout: .now() + 0.45)
      let snapshot = collector.snapshotAndFinish()
      output.setSampleBufferDelegate(nil, queue: nil)
      var payload = snapshot
      payload["stageName"] = stageName
      payload["analysisStatus"] = waitResult == .success ? "CAPTURED" : "PARTIAL"
      return payload
    }

    do {
      try device.lockForConfiguration()
      if device.isTorchModeSupported(.off) {
        device.torchMode = .off
      }
      device.unlockForConfiguration()
      Thread.sleep(forTimeInterval: 0.025)
    } catch {
      return [
        "analysisStatus": "NOT_ANALYZED",
        "reason": "TORCH_OFF_CONFIGURATION_FAILED",
        "error": error.localizedDescription,
      ]
    }

    let torchOff = captureStage("TORCH_OFF")
    let torchLevel: Float = min(0.10, AVCaptureDevice.maxAvailableTorchLevel)
    do {
      try device.lockForConfiguration()
      try device.setTorchModeOn(level: torchLevel)
      device.unlockForConfiguration()
    } catch {
      return [
        "analysisStatus": "NOT_ANALYZED",
        "reason": "TORCH_ON_CONFIGURATION_FAILED",
        "error": error.localizedDescription,
        "torchOff": torchOff,
      ]
    }

    Thread.sleep(forTimeInterval: 0.040)
    let torchOn = captureStage("TORCH_ON")

    do {
      try device.lockForConfiguration()
      if device.isTorchModeSupported(.off) {
        device.torchMode = .off
      }
      device.unlockForConfiguration()
    } catch {
      // Handoff reset below will still restore normal exposure/focus state.
    }

    return [
      "analysisStatus": "CAPTURED",
      "torchLevel": Double(torchLevel),
      "torchOff": torchOff,
      "torchOn": torchOn,
      "decisionRole": "DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION",
    ]
  }

'''
swift = replace_once(swift,
    '''  private func captureTemporalFrequencyNative(
    device: AVCaptureDevice,''',
    illum + '''  private func captureTemporalFrequencyNative(
    device: AVCaptureDevice,''',
    'insert active illumination')
swift = replace_once(swift,
    '''        self.temporalFrequencyNativeSession = session
        session.startRunning()''',
    '''        self.temporalFrequencyNativeSession = session
        session.startRunning()
        let totalProbeStartUptime = ProcessInfo.processInfo.systemUptime''',
    'total probe start')
swift = replace_once(swift,
    '''            payload["advancedDiagnosticStages"] = stages
            payload["advancedDiagnosticsDecisionRole"] =
              "DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION"
            payload["baselineSpatialGridBins"] = 24''',
    '''            payload["advancedDiagnosticStages"] = stages
            payload["advancedDiagnosticsDecisionRole"] =
              "V32_HARMONIC_RECOVERY_CORROBORATION_PLUS_DIAGNOSTIC_PHYSICS"
            payload["baselineSpatialGridBins"] = 24
            payload["advancedSpatialGridBins"] = 64
            payload["activeIlluminationChallenge"] =
              self.captureActiveIlluminationRealityChallenge(
                output: output,
                device: captureDevice
              )
            payload["totalNativeProbeDurationMs"] =
              Int(((ProcessInfo.processInfo.systemUptime - totalProbeStartUptime) * 1000.0).rounded())''',
    'active illumination call')
swift_path.write_text(swift)

test_path.write_text('''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_hcv/hcv_display_risk_fusion.dart';
import 'package:sigillum_hcv/hcv_temporal_frequency_probe.dart';

void main() {
  test('BUILD108 treats a strict 2:1 row harmonic as one physical family', () {
    expect(
      HCVTemporalFrequencyProbe.harmonicAwareModalBinCount(
        const [2, 2, 2, 4, 2, 2, 2, 2, 2],
      ),
      9,
    );
  });

  test('BUILD108 harmonic global HFR keeps strong global gates', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesHarmonicRecoveredGlobalHfrV32(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.2607,
        globalModulationDepth: 1.313,
        globalSpectralConcentration: 0.921,
        medianCellPeriodicityStrength: 0.162,
        medianCellFrequencyStability: 0.819,
        medianCellPhaseStepConsistency: 0.661,
        periodicCellCount: 8,
      ),
      isTrue,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesHarmonicRecoveredGlobalHfrV32(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 5.7,
        globalModulationDepth: 0.03,
        globalSpectralConcentration: 0.20,
        medianCellPeriodicityStrength: 0.01,
        medianCellFrequencyStability: 0.30,
        medianCellPhaseStepConsistency: 0.20,
        periodicCellCount: 0,
      ),
      isFalse,
    );
  });

  test('fusion accepts V3.2 corroborated harmonic full-frame display', () {
    const base = HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: const <String, dynamic>{},
      ml: const <String, dynamic>{'analysisStatus': 'NOT_ANALYZED'},
      temporalFrequencyProbe: const <String, dynamic>{
        'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
        'analysisStatus': 'ANALYZED',
        'coherentDisplayPeriodicity': true,
        'shortExposureVerified': true,
        'exposureLockedForEntireNativeCapture': true,
        'framesAnalyzed': 84,
        'actualFrameRateFromTimestamps': 240.62,
        'displayRealityEvidenceV3': <String, dynamic>{
          'fullFrameDisplay': true,
          'mixedSceneDetected': false,
          'allNineCellsSameDisplayFamily': true,
          'spatialFamilyCellCount': 8,
          'harmonicAwareSpatialFamilyCellCount': 9,
          'rowTimeFamilyCellCount': 9,
          'harmonicDisplayRecovery': true,
        },
      },
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, greaterThanOrEqualTo(95));
  });
}
''')

print('BUILD108 patch prepared')
