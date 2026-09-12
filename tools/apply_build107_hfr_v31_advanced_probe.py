from pathlib import Path

swift_path = Path('ios/Runner/AppDelegate.swift')
probe_path = Path('lib/hcv_temporal_frequency_probe.dart')
fusion_path = Path('lib/hcv_display_risk_fusion.dart')
test_path = Path('test/hfr_v3_fullframe_mixed_scene_test.dart')
contract_path = Path('test/hfr_v31_advanced_probe_contract_test.dart')

swift = swift_path.read_text()
probe = probe_path.read_text()
fusion = fusion_path.read_text()
tests = test_path.read_text()

# ---------------------------------------------------------------------------
# Native iOS: preserve the production 1/1000 HFR capture, add two shorter
# diagnostic exposure stages in the SAME isolated AVCaptureSession, and retain
# one 2-D luma microtexture snapshot per stage before any Dart downsampling.
# ---------------------------------------------------------------------------
swift = swift.replace(
'''  private let targetFrameCount: Int
  private let rowBins: Int
  private let completion: ([String: Any]) -> Void
  private let lock = NSLock()
  private var frames: [[[Double]]] = []
  private var timestamps: [Double] = []
  private var frameLuma: [Double] = []
  private var finished = false
''',
'''  private let targetFrameCount: Int
  private let rowBins: Int
  private let spatialGridBins: Int
  private let completion: ([String: Any]) -> Void
  private let lock = NSLock()
  private var frames: [[[Double]]] = []
  private var timestamps: [Double] = []
  private var frameLuma: [Double] = []
  private var spatialSnapshot: [[[Double]]]?
  private var finished = false
''', 1)

swift = swift.replace(
'''  init(
    targetFrameCount: Int,
    rowBins: Int,
    completion: @escaping ([String: Any]) -> Void
  ) {
    self.targetFrameCount = targetFrameCount
    self.rowBins = rowBins
    self.completion = completion
  }
''',
'''  init(
    targetFrameCount: Int,
    rowBins: Int,
    spatialGridBins: Int = 0,
    completion: @escaping ([String: Any]) -> Void
  ) {
    self.targetFrameCount = targetFrameCount
    self.rowBins = rowBins
    self.spatialGridBins = spatialGridBins
    self.completion = completion
  }
''', 1)

swift = swift.replace(
'''    lock.lock()
    let shouldProcess = !finished && frames.count < targetFrameCount
    lock.unlock()
    guard shouldProcess,
          CMSampleBufferDataIsReady(sampleBuffer),
          let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let extracted = rowProfiles(from: pixelBuffer) else {
      return
    }
''',
'''    lock.lock()
    let shouldProcess = !finished && frames.count < targetFrameCount
    let needsSpatialSnapshot = spatialSnapshot == nil && spatialGridBins >= 8
    lock.unlock()
    guard shouldProcess,
          CMSampleBufferDataIsReady(sampleBuffer),
          let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let extracted = rowProfiles(
            from: pixelBuffer,
            includeSpatialSnapshot: needsSpatialSnapshot
          ) else {
      return
    }
''', 1)

swift = swift.replace(
'''      frames.append(extracted.profiles)
      timestamps.append(pts)
      frameLuma.append(extracted.meanLuma)
''',
'''      frames.append(extracted.profiles)
      timestamps.append(pts)
      frameLuma.append(extracted.meanLuma)
      if spatialSnapshot == nil, let snapshot = extracted.spatialGrids {
        spatialSnapshot = snapshot
      }
''', 1)

swift = swift.replace(
'''  private func snapshotLocked() -> [String: Any] {
    return [
      "frames": frames,
      "frameTimestampsSeconds": timestamps,
      "frameLuma": frameLuma,
      "frameCount": frames.count,
    ]
  }

  private func rowProfiles(
    from pixelBuffer: CVPixelBuffer
  ) -> (profiles: [[Double]], meanLuma: Double)? {
''',
'''  private func snapshotLocked() -> [String: Any] {
    var payload: [String: Any] = [
      "frames": frames,
      "frameTimestampsSeconds": timestamps,
      "frameLuma": frameLuma,
      "frameCount": frames.count,
    ]
    if let spatialSnapshot {
      payload["spatialLumaGridByCell"] = spatialSnapshot
      payload["spatialGridBins"] = spatialGridBins
    }
    return payload
  }

  private func rowProfiles(
    from pixelBuffer: CVPixelBuffer,
    includeSpatialSnapshot: Bool
  ) -> (profiles: [[Double]], meanLuma: Double, spatialGrids: [[[Double]]]?)? {
''', 1)

swift = swift.replace(
'''    var result: [[Double]] = []
    result.reserveCapacity(9)
    var total = 0.0
    var totalCount = 0
''',
'''    var result: [[Double]] = []
    result.reserveCapacity(9)
    var spatialGrids: [[[Double]]]? = includeSpatialSnapshot ? [] : nil
    spatialGrids?.reserveCapacity(9)
    var total = 0.0
    var totalCount = 0
''', 1)

swift = swift.replace(
'''        result.append(profile)
      }
    }

    return (result, totalCount > 0 ? total / Double(totalCount) : 0.0)
  }
}
''',
'''        result.append(profile)

        if includeSpatialSnapshot {
          let gridSize = max(8, min(32, spatialGridBins))
          var grid: [[Double]] = []
          grid.reserveCapacity(gridSize)
          for gy in 0..<gridSize {
            let sy0 = y0 + (y1 - y0) * gy / gridSize
            let sy1 = min(y1, max(sy0 + 1, y0 + (y1 - y0) * (gy + 1) / gridSize))
            var row: [Double] = []
            row.reserveCapacity(gridSize)
            for gx in 0..<gridSize {
              let sx0 = x0 + (x1 - x0) * gx / gridSize
              let sx1 = min(x1, max(sx0 + 1, x0 + (x1 - x0) * (gx + 1) / gridSize))
              var localSum = 0.0
              var localCount = 0
              let yStep = max(1, (sy1 - sy0) / 2)
              let xLocalStep = max(1, (sx1 - sx0) / 2)
              var y = sy0
              while y < sy1 {
                var x = sx0
                while x < sx1 {
                  localSum += Double(bytes[y * bytesPerRow + x]) / 255.0
                  localCount += 1
                  x += xLocalStep
                }
                y += yStep
              }
              row.append(localCount > 0 ? localSum / Double(localCount) : 0.0)
            }
            grid.append(row)
          }
          spatialGrids?.append(grid)
        }
      }
    }

    return (
      result,
      totalCount > 0 ? total / Double(totalCount) : 0.0,
      spatialGrids
    )
  }
}
''', 1)

# Add reusable same-session diagnostic stage capture before production capture.
marker = '''  private func captureTemporalFrequencyNative(
    device: AVCaptureDevice,
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
'''
advanced_native = r'''  private func captureTemporalFrequencyDiagnosticStage(
    output: AVCaptureVideoDataOutput,
    device: AVCaptureDevice,
    targetExposureSeconds: Double,
    baselineExposureSeconds: Double,
    baselineISO: Float,
    stageName: String,
    frameCount: Int = 18
  ) -> [String: Any] {
    let minimum = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
    let maximum = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
    let target = min(maximum, max(minimum, targetExposureSeconds))
    let compensation = baselineExposureSeconds / max(target, 0.000001)
    let compensatedISO = min(
      device.activeFormat.maxISO,
      max(device.activeFormat.minISO, baselineISO * Float(compensation))
    )
    let duration = CMTimeMakeWithSeconds(target, preferredTimescale: 1_000_000_000)
    let exposureSemaphore = DispatchSemaphore(value: 0)

    do {
      try device.lockForConfiguration()
      guard device.isExposureModeSupported(.custom) else {
        device.unlockForConfiguration()
        return [
          "stageName": stageName,
          "analysisStatus": "NOT_ANALYZED",
          "reason": "CUSTOM_EXPOSURE_UNSUPPORTED",
        ]
      }
      device.setExposureModeCustom(duration: duration, iso: compensatedISO) { _ in
        exposureSemaphore.signal()
      }
      device.unlockForConfiguration()
    } catch {
      return [
        "stageName": stageName,
        "analysisStatus": "NOT_ANALYZED",
        "reason": "EXPOSURE_CONFIGURATION_FAILED",
        "error": error.localizedDescription,
      ]
    }

    _ = exposureSemaphore.wait(timeout: .now() + 0.40)
    Thread.sleep(forTimeInterval: 0.018)
    let actualExposure = CMTimeGetSeconds(device.exposureDuration)
    let actualISO = Double(device.iso)
    let tolerance = max(0.00008, target * 0.25)
    let verified = actualExposure.isFinite && abs(actualExposure - target) <= tolerance

    let stageSemaphore = DispatchSemaphore(value: 0)
    let collector = HCVTemporalFrequencyNativeCollector(
      targetFrameCount: frameCount,
      rowBins: 128,
      spatialGridBins: 24
    ) { _ in
      stageSemaphore.signal()
    }
    output.setSampleBufferDelegate(collector, queue: temporalFrequencySampleQueue)
    let waitResult = stageSemaphore.wait(timeout: .now() + 0.55)
    let snapshot = collector.snapshotAndFinish()
    output.setSampleBufferDelegate(nil, queue: nil)

    var payload = snapshot
    payload["stageName"] = stageName
    payload["analysisStatus"] = waitResult == .success ? "CAPTURED" : "PARTIAL"
    payload["requestedExposureSeconds"] = targetExposureSeconds
    payload["targetExposureSecondsAfterClamp"] = target
    payload["actualExposureSeconds"] = actualExposure
    payload["exposureVerified"] = verified
    payload["iso"] = actualISO
    payload["isoClamped"] = compensatedISO >= device.activeFormat.maxISO - 0.5
    payload["rowProfileBins"] = 128
    payload["spatialGridBins"] = 24
    return payload
  }

'''
if marker not in swift:
    raise SystemExit('native capture marker not found')
swift = swift.replace(marker, advanced_native + marker, 1)

# Baseline collector retains current production data while preserving one spatial snapshot.
swift = swift.replace(
'''        let collector = HCVTemporalFrequencyNativeCollector(
          targetFrameCount: targetFrameCount,
          rowBins: rowBins
        ) { [weak self] snapshot in
''',
'''        let collector = HCVTemporalFrequencyNativeCollector(
          targetFrameCount: targetFrameCount,
          rowBins: rowBins,
          spatialGridBins: 24
        ) { [weak self] snapshot in
''', 1)

old_completion = '''          self.finishTemporalFrequencyNativeCapture(
            session: session,
            output: output,
            device: captureDevice,
            payload: payload,
            result: result
          )
'''
new_completion = '''          // BUILD107 V3.1 keeps the validated production burst untouched,
          // then reuses the same native session for two shorter diagnostic
          // shutters. These stages are certificate diagnostics only until the
          // physical corpus validates their display signatures.
          self.temporalFrequencyNativeQueue.async {
            var stages: [[String: Any]] = []
            let requestedStages = [
              ("SHORT_X2", targetExposure * 0.50),
              ("SHORT_X4", targetExposure * 0.25),
            ]
            var previousTarget = targetExposure
            for (name, requestedStageExposure) in requestedStages {
              let clamped = max(minExposure, requestedStageExposure)
              if abs(clamped - previousTarget) <= max(0.000005, previousTarget * 0.04) {
                stages.append([
                  "stageName": name,
                  "analysisStatus": "NOT_ANALYZED",
                  "reason": "NO_DISTINCT_SHORTER_EXPOSURE_AVAILABLE",
                  "targetExposureSecondsAfterClamp": clamped,
                ])
                continue
              }
              stages.append(
                self.captureTemporalFrequencyDiagnosticStage(
                  output: output,
                  device: captureDevice,
                  targetExposureSeconds: requestedStageExposure,
                  baselineExposureSeconds: baselineDuration,
                  baselineISO: baselineISO,
                  stageName: name
                )
              )
              previousTarget = clamped
            }
            payload["advancedDiagnosticStages"] = stages
            payload["advancedDiagnosticsDecisionRole"] =
              "DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION"
            payload["baselineSpatialGridBins"] = 24
            self.finishTemporalFrequencyNativeCapture(
              session: session,
              output: output,
              device: captureDevice,
              payload: payload,
              result: result
            )
          }
'''
if swift.count(old_completion) < 1:
    raise SystemExit('baseline completion block not found')
swift = swift.replace(old_completion, new_completion, 1)

# Give the two diagnostic stages enough time before the fallback timeout.
swift = swift.replace(
'''          deadline: .now() + requestedDuration + 0.75
''',
'''          deadline: .now() + requestedDuration + 2.20
''', 1)

# ---------------------------------------------------------------------------
# Dart V3.1: advanced diagnostics + correct epistemic separation.
# No-temporal-display-signature is explicitly NOT positive reality evidence.
# ---------------------------------------------------------------------------
probe = probe.replace(
'''/// Native HFR V3 physical probe for display-vs-reality evidence.
///
/// V3 keeps the isolated AVFoundation/CMSampleBuffer capture introduced by V2
/// and adds explicit 3x3 full-frame consistency plus row-by-time analysis.
/// A display verdict requires all nine cells to belong to one coherent physical
/// display family; partial display-like coverage is a mixed real scene.
''',
'''/// Native HFR V3.1 physical display probe.
///
/// BUILD107 preserves the validated V3 full-frame display decision and adds a
/// same-session short-exposure sweep, higher-resolution row-by-time diagnostics,
/// and 2-D spatial lattice/moire diagnostics. New V3.1 physics is diagnostic
/// until physically validated. Absence of temporal display evidence is never
/// treated as positive proof of physical reality.
''', 1)

# Replace old reality decision construction.
old_reality = '''    final fullFrameRealityV3 = qualifiesFullFrameRealityV3(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      fullFrameDisplay: fullFrameDisplayV3,
      mixedSceneDetected: mixedSceneDetected,
      displayLikeCellCount: displayLikeCellCount,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      periodicCellCount: periodicCellCount,
      stableCellCount: stableCellCount,
    );
    final coherentDisplayPeriodicity = fullFrameDisplayV3;
'''
new_reality = '''    final noTemporalDisplaySignatureV31 =
        qualifiesNoTemporalDisplaySignatureV31(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      fullFrameDisplay: fullFrameDisplayV3,
      mixedSceneDetected: mixedSceneDetected,
      displayLikeCellCount: displayLikeCellCount,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      periodicCellCount: periodicCellCount,
      stableCellCount: stableCellCount,
    );
    // BUILD107 epistemic correction: a quiet HFR signature is NOT positive
    // reality evidence. Full-frame physical reality remains false until a
    // genuinely positive reality sensor is available and validated.
    const fullFrameRealityV3 = false;
    final advancedPhysicsV31 = _analyzeAdvancedDisplayPhysicsV31(raw);
    final coherentDisplayPeriodicity = fullFrameDisplayV3;
'''
if old_reality not in probe:
    raise SystemExit('old reality construction not found')
probe = probe.replace(old_reality, new_reality, 1)

probe = probe.replace(
'''      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DECISIONAL_DISPLAY_REALITY_V3_FULL_FRAME_OR_MIXED_SCENE',
      'productionDecisionChanged':
          fullFrameDisplayV3 || mixedSceneDetected || fullFrameRealityV3,
''',
'''      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V31_ADVANCED_PHYSICS_DIAGNOSTIC_ONLY',
      'productionDecisionChanged': fullFrameDisplayV3 || mixedSceneDetected,
''', 1)

probe = probe.replace(
'''        'fullFrameReality': fullFrameRealityV3,
        'mixedSceneDetected': mixedSceneDetected,
''',
'''        'fullFrameReality': fullFrameRealityV3,
        'positivePhysicalRealityEvidence': false,
        'noTemporalDisplaySignature': noTemporalDisplaySignatureV31,
        'noTemporalDisplaySignatureIsRealityEvidence': false,
        'mixedSceneDetected': mixedSceneDetected,
''', 1)

probe = probe.replace(
'''        'classificationPolicy':
            'BUILD106_GLOBAL_HFR_PLUS_ALL_9_CELLS_ONE_FREQUENCY_FAMILY;LOCAL_STABLE_CELL_COUNT_DIAGNOSTIC_ONLY;STRONG_LOW_PERIODICITY_SIGNATURE_IS_PHYSICAL_REALITY;PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE',
      },
''',
'''        'classificationPolicy':
            'BUILD107_VALIDATED_V3_DISPLAY_UNCHANGED;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE;V31_ADVANCED_DISPLAY_PHYSICS_DIAGNOSTIC_ONLY',
      },
      'advancedDisplayPhysicsV31': advancedPhysicsV31,
''', 1)

probe = probe.replace(
'''      'note': 'V3 BUILD106 combines native 240/120 fps timing, strict global HFR evidence, 3x3 row-profile rolling-shutter band evolution and row-by-time coherence. Full-frame display uses strict global medians plus all-nine family coherence without a redundant local stable-cell-count veto. Reality V3 is an independent strong low-periodicity physical signature. Partial display coverage remains a mixed real scene.',
''',
'''      'note': 'V3.1 BUILD107 preserves validated V3 full-frame display/mixed-scene decisions and adds same-session exposure sweep, 128-bin row-time diagnostics, and 2-D microtexture lattice diagnostics. New advanced physics is diagnostic-only pending iPhone validation. A quiet temporal signature is explicitly not positive reality evidence.',
''', 1)

# Replace the old misnamed reality predicate with no-signature predicate and a
# compatibility reality method that cannot claim positive reality.
old_method = '''  static bool qualifiesFullFrameRealityV3({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required bool fullFrameDisplay,
    required bool mixedSceneDetected,
    required int displayLikeCellCount,
    required double? dominantTemporalFrequencyHz,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required int periodicCellCount,
    required int stableCellCount,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    if (fullFrameDisplay || mixedSceneDetected || displayLikeCellCount != 0) {
      return false;
    }
    if (dominantTemporalFrequencyHz == null ||
        dominantTemporalFrequencyHz >= 10.0) {
      return false;
    }
    return medianCellPeriodicityStrength < 0.05 &&
        medianCellFrequencyStability < 0.60 &&
        periodicCellCount <= 1 &&
        stableCellCount <= 1;
  }
'''
new_method = '''  static bool qualifiesNoTemporalDisplaySignatureV31({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required bool fullFrameDisplay,
    required bool mixedSceneDetected,
    required int displayLikeCellCount,
    required double? dominantTemporalFrequencyHz,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required int periodicCellCount,
    required int stableCellCount,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    if (fullFrameDisplay || mixedSceneDetected || displayLikeCellCount != 0) {
      return false;
    }
    if (dominantTemporalFrequencyHz == null || dominantTemporalFrequencyHz >= 10.0) {
      return false;
    }
    return medianCellPeriodicityStrength < 0.05 &&
        medianCellFrequencyStability < 0.60 &&
        periodicCellCount <= 1 &&
        stableCellCount <= 1;
  }

  @Deprecated('Absence of temporal display evidence is not positive reality evidence.')
  static bool qualifiesFullFrameRealityV3({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required bool fullFrameDisplay,
    required bool mixedSceneDetected,
    required int displayLikeCellCount,
    required double? dominantTemporalFrequencyHz,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required int periodicCellCount,
    required int stableCellCount,
  }) => false;
'''
if old_method not in probe:
    raise SystemExit('old fullFrameReality method not found')
probe = probe.replace(old_method, new_method, 1)

# Inject V3.1 advanced diagnostic analysis before unavailable().
advanced_dart = r'''
  static Map<String, dynamic> _analyzeAdvancedDisplayPhysicsV31(
    Map<String, dynamic> raw,
  ) {
    final stages = <Map<String, dynamic>>[];

    Map<String, dynamic> analyzeStage(Map<String, dynamic> stage) {
      final rawFrames = stage['frames'];
      if (rawFrames is! List || rawFrames.length < 6) {
        return {
          'stageName': stage['stageName'],
          'analysisStatus': 'NOT_ANALYZED',
          'reason': stage['reason'] ?? 'NOT_ENOUGH_DIAGNOSTIC_FRAMES',
          'actualExposureSeconds': stage['actualExposureSeconds'],
        };
      }
      final sequences = List.generate(9, (_) => <List<double>>[]);
      for (final frame in rawFrames) {
        if (frame is! List || frame.length != 9) continue;
        for (var cell = 0; cell < 9; cell++) {
          final rawCell = frame[cell];
          if (rawCell is! List) continue;
          final parsed = rawCell.whereType<num>().map((n) => n.toDouble()).toList();
          if (parsed.length == rawCell.length && parsed.length >= 16) {
            sequences[cell].add(parsed);
          }
        }
      }
      final rolling = <Map<String, dynamic>>[];
      final rowTime = <Map<String, dynamic>>[];
      for (var cell = 0; cell < 9; cell++) {
        rolling.add(HCVTemporalFrequencyMath.analyzeRowProfileSequence(sequences[cell]));
        rowTime.add(HCVTemporalFrequencyMath.analyzeRowTimeMatrix(sequences[cell]));
      }
      final spatialBins = rolling
          .map((m) => (m['dominantRowFrequencyBin'] as num?)?.toInt() ?? 0)
          .toList();
      final rowTimeBins = rowTime
          .map((m) => (m['rowTimeDominantTemporalFrequencyBin'] as num?)?.toInt() ?? 0)
          .toList();
      final band = rolling
          .map((m) => (m['rollingShutterBandCoherence'] as num?)?.toDouble())
          .whereType<double>()
          .toList()..sort();
      final phase = rolling
          .map((m) => (m['rollingShutterPhaseDriftConsistency'] as num?)?.toDouble())
          .whereType<double>()
          .toList()..sort();
      final rt = rowTime
          .map((m) => (m['rowTimeCoherenceScore'] as num?)?.toDouble())
          .whereType<double>()
          .toList()..sort();

      final spatialRaw = stage['spatialLumaGridByCell'];
      final lattice = <Map<String, dynamic>>[];
      if (spatialRaw is List) {
        for (final cell in spatialRaw) {
          if (cell is! List) continue;
          final grid = <List<double>>[];
          for (final row in cell) {
            if (row is! List) continue;
            grid.add(row.whereType<num>().map((n) => n.toDouble()).toList());
          }
          lattice.add(HCVTemporalFrequencyMath.analyzeSpatialLattice(grid));
        }
      }
      final latticeStrengths = lattice
          .map((m) => (m['latticeStrength'] as num?)?.toDouble())
          .whereType<double>()
          .toList()..sort();
      final spatialFamily = _compatibleModalBinCount(spatialBins);
      final rowTimeFamily = _compatibleModalBinCount(rowTimeBins);
      final medianBand = _medianStatic(band) ?? 0.0;
      final medianPhase = _medianStatic(phase) ?? 0.0;
      final medianRt = _medianStatic(rt) ?? 0.0;
      final medianLattice = _medianStatic(latticeStrengths) ?? 0.0;
      return {
        'stageName': stage['stageName'] ?? 'BASELINE',
        'analysisStatus': 'ANALYZED',
        'requestedExposureSeconds': stage['requestedExposureSeconds'],
        'actualExposureSeconds': stage['actualExposureSeconds'],
        'exposureVerified': stage['exposureVerified'],
        'iso': stage['iso'],
        'frameCount': rawFrames.length,
        'rowProfileBins': stage['rowProfileBins'],
        'spatialGridBins': stage['spatialGridBins'],
        'spatialFamilyCellCount': spatialFamily,
        'rowTimeFamilyCellCount': rowTimeFamily,
        'medianRollingShutterBandCoherence': medianBand,
        'medianRollingShutterPhaseDriftConsistency': medianPhase,
        'medianRowTimeCoherence': medianRt,
        'medianSpatialLatticeStrength': medianLattice,
        'rollingShutterHighFrequencyCandidate':
            spatialFamily >= 8 && medianBand >= 0.45 && medianPhase >= 0.20,
        'spatialLatticeCandidate': latticeStrengths.length >= 6 && medianLattice >= 0.30,
      };
    }

    final rawStages = raw['advancedDiagnosticStages'];
    if (rawStages is List) {
      for (final rawStage in rawStages) {
        if (rawStage is Map) {
          stages.add(analyzeStage(Map<String, dynamic>.from(rawStage)));
        }
      }
    }
    final rollingCandidates = stages.where((s) => s['rollingShutterHighFrequencyCandidate'] == true).length;
    final latticeCandidates = stages.where((s) => s['spatialLatticeCandidate'] == true).length;
    return {
      'analysisStatus': stages.isEmpty ? 'NOT_ANALYZED' : 'ANALYZED',
      'decisionRole': 'DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION',
      'productionDecisionChanged': false,
      'exposureSweepStageCount': stages.length,
      'rollingShutterCandidateStageCount': rollingCandidates,
      'spatialLatticeCandidateStageCount': latticeCandidates,
      'persistentHighFrequencyRollingShutterCandidate': rollingCandidates >= 2,
      'persistentSpatialLatticeCandidate': latticeCandidates >= 2,
      'advancedPhysicalDisplayCandidate': rollingCandidates >= 2 || latticeCandidates >= 2,
      'stages': stages,
      'note': 'Advanced V3.1 signatures are diagnostic only; physical iPhone validation is required before they can change production verdicts.',
    };
  }

  static double? _medianStatic(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2.0;
  }

'''
insert_marker = '''  static Map<String, dynamic> unavailable(String reason, {Object? error}) {
'''
if insert_marker not in probe:
    raise SystemExit('unavailable marker not found')
probe = probe.replace(insert_marker, advanced_dart + insert_marker, 1)

# Add 2-D normalized autocorrelation microtexture analysis.
math_marker = '''  static Map<String, dynamic> analyzeScalarSequence(List<double> values) {
'''
math_method = r'''  static Map<String, dynamic> analyzeSpatialLattice(List<List<double>> grid) {
    if (grid.length < 8 || grid.any((row) => row.length < 8)) {
      return const {
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'SPATIAL_GRID_TOO_SMALL',
      };
    }
    final height = grid.length;
    final width = grid.map((row) => row.length).reduce(min);
    final values = <double>[];
    for (var y = 0; y < height; y++) {
      values.addAll(grid[y].take(width));
    }
    final mean = _mean(values);
    var variance = 0.0;
    for (final v in values) {
      final d = v - mean;
      variance += d * d;
    }
    if (variance <= 1e-12) {
      return const {
        'analysisStatus': 'ANALYZED',
        'latticeStrength': 0.0,
        'horizontalPeakLag': 0,
        'verticalPeakLag': 0,
      };
    }

    double correlation(int dx, int dy) {
      var numerator = 0.0;
      var leftPower = 0.0;
      var rightPower = 0.0;
      for (var y = 0; y < height - dy; y++) {
        for (var x = 0; x < width - dx; x++) {
          final a = grid[y][x] - mean;
          final b = grid[y + dy][x + dx] - mean;
          numerator += a * b;
          leftPower += a * a;
          rightPower += b * b;
        }
      }
      final denom = sqrt(leftPower * rightPower);
      return denom <= 1e-12 ? 0.0 : numerator / denom;
    }

    final maxLag = min(12, min(width, height) ~/ 3);
    var bestH = 0.0;
    var bestHLag = 0;
    var bestV = 0.0;
    var bestVLag = 0;
    for (var lag = 2; lag <= maxLag; lag++) {
      final h = correlation(lag, 0).abs();
      final v = correlation(0, lag).abs();
      if (h > bestH) { bestH = h; bestHLag = lag; }
      if (v > bestV) { bestV = v; bestVLag = lag; }
    }
    final latticeStrength = sqrt(bestH * bestV);
    return {
      'analysisStatus': 'ANALYZED',
      'latticeStrength': latticeStrength,
      'horizontalAutocorrelationPeak': bestH,
      'verticalAutocorrelationPeak': bestV,
      'horizontalPeakLag': bestHLag,
      'verticalPeakLag': bestVLag,
      'gridWidth': width,
      'gridHeight': height,
    };
  }

'''
if math_marker not in probe:
    raise SystemExit('scalar math marker not found')
probe = probe.replace(math_marker, math_method + math_marker, 1)

# Strip heavy diagnostic raw matrices from certificate metadata after analysis.
old_strip = '''  Map<String, dynamic> _withoutRawFrames(Map<String, dynamic> raw) {
    final copy = Map<String, dynamic>.from(raw);
    copy.remove('frames');
    return copy;
  }
'''
new_strip = '''  Map<String, dynamic> _withoutRawFrames(Map<String, dynamic> raw) {
    final copy = Map<String, dynamic>.from(raw);
    copy.remove('frames');
    copy.remove('spatialLumaGridByCell');
    final stages = copy['advancedDiagnosticStages'];
    if (stages is List) {
      copy['advancedDiagnosticStages'] = stages.map((stage) {
        if (stage is! Map) return stage;
        final cleaned = Map<String, dynamic>.from(stage);
        cleaned.remove('frames');
        cleaned.remove('spatialLumaGridByCell');
        return cleaned;
      }).toList();
    }
    return copy;
  }
'''
if old_strip not in probe:
    raise SystemExit('raw frame strip helper not found')
probe = probe.replace(old_strip, new_strip, 1)

probe = probe.replace(
'''      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole':
          'DECISIONAL_DISPLAY_REALITY_V3_FULL_FRAME_OR_MIXED_SCENE',
''',
'''      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole':
          'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V31_ADVANCED_PHYSICS_DIAGNOSTIC_ONLY',
''', 1)

# ---------------------------------------------------------------------------
# Fusion: accept V3.1, preserve display/mixed decisions, and forbid quiet HFR
# from becoming positive physical reality.
# ---------------------------------------------------------------------------
fusion = fusion.replace(
'''    final v3Analyzed =
        temporalFrequencyProbe?['type'] ==
                'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3' &&
            temporalFrequencyProbe?['analysisStatus'] == 'ANALYZED';
''',
'''    final v3Analyzed =
        _isV3OrLater(temporalFrequencyProbe?['type']) &&
            temporalFrequencyProbe?['analysisStatus'] == 'ANALYZED';
''', 1)

fusion = fusion.replace(
'''    if (probe['type'] == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3') {
''',
'''    if (_isV3OrLater(probe['type'])) {
''', 1)

fusion = fusion.replace(
'''  static bool _isSupportedHfrType(Object? type) =>
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2' ||
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3';
''',
'''  static bool _isV3OrLater(Object? type) =>
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3' ||
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1';

  static bool _isSupportedHfrType(Object? type) =>
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2' || _isV3OrLater(type);
''', 1)

fusion = fusion.replace(
'''    if (probe?['type'] != 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3' ||
        probe?['analysisStatus'] != 'ANALYZED') {
''',
'''    if (!_isV3OrLater(probe?['type']) ||
        probe?['analysisStatus'] != 'ANALYZED') {
''', 1)

old_phys_reality = '''    if (probe?['type'] == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3') {
      final v3 = _v3Evidence(probe);
      if (v3 == null || v3['mixedSceneDetected'] == true) return false;
      return v3['fullFrameReality'] == true &&
          ((v3['displayLikeCellCount'] as num?)?.toInt() ?? 9) == 0;
    }
'''
new_phys_reality = '''    if (_isV3OrLater(probe?['type'])) {
      final v3 = _v3Evidence(probe);
      if (v3 == null || v3['mixedSceneDetected'] == true) return false;
      // BUILD107: only a future validated POSITIVE reality sensor may enter
      // this branch. Quiet HFR/no periodicity is explicitly insufficient.
      return v3['positivePhysicalRealityEvidence'] == true &&
          v3['fullFrameReality'] == true;
    }
'''
if old_phys_reality not in fusion:
    raise SystemExit('V3 physical reality fusion block not found')
fusion = fusion.replace(old_phys_reality, new_phys_reality, 1)

# ---------------------------------------------------------------------------
# Update existing tests that encoded the now-invalid "quiet HFR = reality" idea.
# ---------------------------------------------------------------------------
tests = tests.replace(
"test('BUILD105 framed artwork video qualifies as strong physical Reality V3', () {",
"test('BUILD105 framed artwork video is quiet temporal signature, not positive Reality', () {",
1)
tests = tests.replace(
'''      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
''',
'''      HCVTemporalFrequencyProbe.qualifiesNoTemporalDisplaySignatureV31(
''', 1)
tests = tests.replace(
"test('BUILD105 desk video qualifies as physical Reality V3 despite one weak periodic cell', () {",
"test('BUILD105 desk video is quiet temporal signature despite one weak periodic cell', () {",
1)
# second occurrence
idx = tests.find("HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(")
if idx >= 0:
    tests = tests[:idx] + tests[idx:].replace(
        "HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(",
        "HCVTemporalFrequencyProbe.qualifiesNoTemporalDisplaySignatureV31(",
        1,
    )
# Any remaining old Reality qualification expectations must now be false because
# that API is intentionally non-decisional. Replace method calls in the specific
# rejection test; expected false remains correct.
tests = tests.replace(
    "HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(",
    "HCVTemporalFrequencyProbe.qualifiesNoTemporalDisplaySignatureV31(",
)
# The high-frequency rejection test remains false with the no-signature method.

# Tests that expected Reality V3 to resolve weak semantics should now stay
# non-conclusive because no positive reality sensor exists yet.
tests = tests.replace(
"test('Reality V3 resolves weak artwork semantics without changing ML thresholds', () {",
"test('quiet HFR alone does not resolve weak artwork semantics as reality', () {",
1)
tests = tests.replace(
"test('Reality V3 can override temporal-only passive optical false cue', () {",
"test('quiet HFR alone cannot override temporal-only passive optical cue', () {",
1)
# Narrow expected decisions inside the two renamed test blocks by replacing the
# next occurrences only.
for name in [
    "quiet HFR alone does not resolve weak artwork semantics as reality",
    "quiet HFR alone cannot override temporal-only passive optical cue",
]:
    pos = tests.find("test('" + name)
    if pos < 0:
        continue
    end = tests.find("\n  });", pos)
    block = tests[pos:end]
    block = block.replace("expect(result.decision, 'NO_DISPLAY_EVIDENCE');", "expect(result.decision, 'NON_CONCLUSIVE');")
    block = block.replace("expect(result.score, 20);", "expect(result.score, 45);")
    tests = tests[:pos] + block + tests[end:]

contract = r'''import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  test('BUILD107 native source contains same-session exposure sweep and spatial snapshot', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(source, contains('captureTemporalFrequencyDiagnosticStage'));
    expect(source, contains('SHORT_X2'));
    expect(source, contains('SHORT_X4'));
    expect(source, contains('spatialLumaGridByCell'));
    expect(source, contains('spatialGridBins: 24'));
    expect(source, contains('rowBins: 128'));
    expect(source, contains('DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION'));
  });

  test('spatial lattice diagnostic reacts to coherent 2-D periodic structure', () {
    final grid = List<List<double>>.generate(24, (y) {
      return List<double>.generate(24, (x) {
        return 0.5 + 0.2 * sin(2 * pi * x / 4) + 0.2 * sin(2 * pi * y / 6);
      });
    });
    final result = HCVTemporalFrequencyMath.analyzeSpatialLattice(grid);
    expect(result['analysisStatus'], 'ANALYZED');
    expect((result['latticeStrength'] as num).toDouble(), greaterThan(0.30));
    expect((result['horizontalPeakLag'] as num).toInt(), greaterThan(0));
    expect((result['verticalPeakLag'] as num).toInt(), greaterThan(0));
  });

  test('flat field is not a spatial lattice', () {
    final grid = List<List<double>>.generate(
      24,
      (_) => List<double>.filled(24, 0.5),
    );
    final result = HCVTemporalFrequencyMath.analyzeSpatialLattice(grid);
    expect((result['latticeStrength'] as num).toDouble(), 0.0);
  });

  test('quiet temporal signature is explicitly not positive physical reality', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesNoTemporalDisplaySignatureV31(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 2.8645,
        medianCellPeriodicityStrength: 0.007,
        medianCellFrequencyStability: 0.17,
        periodicCellCount: 0,
        stableCellCount: 0,
      ),
      isTrue,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 2.8645,
        medianCellPeriodicityStrength: 0.007,
        medianCellFrequencyStability: 0.17,
        periodicCellCount: 0,
        stableCellCount: 0,
      ),
      isFalse,
    );
  });
}
'''

swift_path.write_text(swift)
probe_path.write_text(probe)
fusion_path.write_text(fusion)
test_path.write_text(tests)
contract_path.write_text(contract)
