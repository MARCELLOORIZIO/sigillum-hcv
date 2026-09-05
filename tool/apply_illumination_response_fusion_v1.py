from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)

# ---------- Native iOS illumination probe ----------
swift_path = Path('ios/Runner/AppDelegate.swift')
swift = swift_path.read_text()

collector = r'''
private final class HCVIlluminationResponseNativeCollector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let maxFramesPerPhase: Int
  private let lock = NSLock()
  private var phase = -1
  private var phaseFrames: [[[Double]]] = [[], [], []]

  init(maxFramesPerPhase: Int = 12) {
    self.maxFramesPerPhase = maxFramesPerPhase
  }

  func setPhase(_ value: Int) {
    lock.lock()
    phase = value
    lock.unlock()
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard CMSampleBufferDataIsReady(sampleBuffer),
          let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let cells = cellMeans(from: pixelBuffer) else { return }
    lock.lock()
    let current = phase
    if current >= 0 && current < 3 && phaseFrames[current].count < maxFramesPerPhase {
      phaseFrames[current].append(cells)
    }
    lock.unlock()
  }

  func snapshot() -> [[[Double]]] {
    lock.lock()
    let copy = phaseFrames
    lock.unlock()
    return copy
  }

  private func cellMeans(from pixelBuffer: CVPixelBuffer) -> [Double]? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
          let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    guard width >= 6, height >= 6, bytesPerRow >= width else { return nil }
    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    var result: [Double] = []
    result.reserveCapacity(9)
    for gridRow in 0..<3 {
      for gridColumn in 0..<3 {
        let x0 = width * gridColumn / 3
        let x1 = width * (gridColumn + 1) / 3
        let y0 = height * gridRow / 3
        let y1 = height * (gridRow + 1) / 3
        let xStep = max(1, (x1 - x0) / 24)
        let yStep = max(1, (y1 - y0) / 24)
        var sum = 0.0
        var count = 0
        var y = y0
        while y < y1 {
          var x = x0
          while x < x1 {
            sum += Double(bytes[y * bytesPerRow + x]) / 255.0
            count += 1
            x += xStep
          }
          y += yStep
        }
        result.append(count > 0 ? sum / Double(count) : 0.0)
      }
    }
    return result
  }
}

'''
swift = replace_once(swift, '@main\n@objc class AppDelegate', collector + '@main\n@objc class AppDelegate', 'insert illumination collector')

swift = replace_once(
    swift,
    '  private var temporalFrequencyNativeCollector: HCVTemporalFrequencyNativeCollector?\n',
    '  private var temporalFrequencyNativeCollector: HCVTemporalFrequencyNativeCollector?\n  private var illuminationResponseNativeBusy = false\n  private var illuminationResponseNativeSession: AVCaptureSession?\n  private var illuminationResponseNativeCollector: HCVIlluminationResponseNativeCollector?\n',
    'illumination state vars',
)

illum_method = r'''
  private func captureIlluminationResponseNative(
    device: AVCaptureDevice,
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    if illuminationResponseNativeBusy {
      result(FlutterError(code: "ILLUMINATION_RESPONSE_BUSY", message: "Illumination response capture already running", details: nil))
      return
    }
    let captureDevice = temporalFrequencyPhysicalDevice(for: device)
    guard captureDevice.hasTorch, captureDevice.isTorchModeSupported(.on) else {
      result([
        "analysisStatus": "NOT_ANALYZED",
        "reason": "TORCH_UNAVAILABLE_ON_ACTIVE_PHYSICAL_CAMERA",
        "physicalCaptureDeviceUniqueId": captureDevice.uniqueID,
      ])
      return
    }
    let args = call.arguments as? [String: Any]
    let torchLevel = Float(max(0.1, min(0.6, args?["torchLevel"] as? Double ?? 0.30)))
    illuminationResponseNativeBusy = true

    temporalFrequencyNativeQueue.async { [weak self] in
      guard let self else { return }
      var session: AVCaptureSession?
      var output: AVCaptureVideoDataOutput?
      do {
        guard let selection = self.temporalFrequencyFormat(for: captureDevice, requestedMaxFps: 60.0) else {
          throw NSError(domain: "SIGILLUMIlluminationResponse", code: 1, userInfo: [NSLocalizedDescriptionKey: "No native 60 fps format available"])
        }
        let nativeSession = AVCaptureSession()
        nativeSession.beginConfiguration()
        let input = try AVCaptureDeviceInput(device: captureDevice)
        guard nativeSession.canAddInput(input) else { throw NSError(domain: "SIGILLUMIlluminationResponse", code: 2, userInfo: [NSLocalizedDescriptionKey: "Camera input unavailable"]) }
        nativeSession.addInput(input)
        let nativeOutput = AVCaptureVideoDataOutput()
        nativeOutput.alwaysDiscardsLateVideoFrames = true
        nativeOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        guard nativeSession.canAddOutput(nativeOutput) else { throw NSError(domain: "SIGILLUMIlluminationResponse", code: 3, userInfo: [NSLocalizedDescriptionKey: "Video data output unavailable"]) }
        nativeSession.addOutput(nativeOutput)

        try captureDevice.lockForConfiguration()
        captureDevice.activeFormat = selection.format
        captureDevice.activeVideoMinFrameDuration = selection.range.minFrameDuration
        captureDevice.activeVideoMaxFrameDuration = selection.range.minFrameDuration
        if captureDevice.isExposureModeSupported(.continuousAutoExposure) { captureDevice.exposureMode = .continuousAutoExposure }
        if captureDevice.isFocusModeSupported(.continuousAutoFocus) { captureDevice.focusMode = .continuousAutoFocus }
        if captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance }
        captureDevice.torchMode = .off
        captureDevice.unlockForConfiguration()
        nativeSession.commitConfiguration()
        session = nativeSession
        output = nativeOutput
        self.illuminationResponseNativeSession = nativeSession
        nativeSession.startRunning()
        guard nativeSession.isRunning else { throw NSError(domain: "SIGILLUMIlluminationResponse", code: 4, userInfo: [NSLocalizedDescriptionKey: "Illumination session failed to start"]) }
        Thread.sleep(forTimeInterval: 0.18)

        let baselineDuration = max(CMTimeGetSeconds(captureDevice.exposureDuration), CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration))
        let baselineISO = max(captureDevice.iso, captureDevice.activeFormat.minISO)
        let maxLockedDuration = min(CMTimeGetSeconds(captureDevice.activeFormat.maxExposureDuration), 0.90 / selection.fps)
        let lockedDuration = min(maxLockedDuration, baselineDuration)
        let exposureCompensation = baselineDuration / max(lockedDuration, 0.000001)
        let lockedISO = min(captureDevice.activeFormat.maxISO, max(captureDevice.activeFormat.minISO, baselineISO * Float(exposureCompensation)))
        let duration = CMTimeMakeWithSeconds(lockedDuration, preferredTimescale: 1_000_000_000)
        let exposureSemaphore = DispatchSemaphore(value: 0)
        try captureDevice.lockForConfiguration()
        if captureDevice.isFocusModeSupported(.locked) {
          captureDevice.setFocusModeLocked(lensPosition: captureDevice.lensPosition, completionHandler: nil)
        }
        if captureDevice.isWhiteBalanceModeSupported(.locked) {
          let gains = self.clampedWhiteBalanceGains(captureDevice.deviceWhiteBalanceGains, for: captureDevice)
          captureDevice.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        }
        guard captureDevice.isExposureModeSupported(.custom) else {
          captureDevice.unlockForConfiguration()
          throw NSError(domain: "SIGILLUMIlluminationResponse", code: 5, userInfo: [NSLocalizedDescriptionKey: "Custom exposure unavailable"])
        }
        captureDevice.setExposureModeCustom(duration: duration, iso: lockedISO) { _ in exposureSemaphore.signal() }
        captureDevice.unlockForConfiguration()
        _ = exposureSemaphore.wait(timeout: .now() + 0.8)
        Thread.sleep(forTimeInterval: 0.04)

        let collector = HCVIlluminationResponseNativeCollector(maxFramesPerPhase: 12)
        self.illuminationResponseNativeCollector = collector
        nativeOutput.setSampleBufferDelegate(collector, queue: self.temporalFrequencySampleQueue)

        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = .off
        captureDevice.unlockForConfiguration()
        collector.setPhase(0)
        Thread.sleep(forTimeInterval: 0.16)

        try captureDevice.lockForConfiguration()
        try captureDevice.setTorchModeOn(level: torchLevel)
        captureDevice.unlockForConfiguration()
        Thread.sleep(forTimeInterval: 0.04)
        collector.setPhase(1)
        Thread.sleep(forTimeInterval: 0.18)

        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = .off
        captureDevice.unlockForConfiguration()
        Thread.sleep(forTimeInterval: 0.04)
        collector.setPhase(2)
        Thread.sleep(forTimeInterval: 0.16)

        collector.setPhase(-1)
        nativeOutput.setSampleBufferDelegate(nil, queue: nil)
        let phases = collector.snapshot()
        if nativeSession.isRunning { nativeSession.stopRunning() }
        let handoff = self.resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)
        self.illuminationResponseNativeCollector = nil
        self.illuminationResponseNativeSession = nil
        self.illuminationResponseNativeBusy = false
        let dimensions = CMVideoFormatDescriptionGetDimensions(selection.format.formatDescription)
        let payload: [String: Any] = [
          "analysisStatus": phases.allSatisfy { $0.count >= 3 } ? "CAPTURED" : "NOT_ANALYZED",
          "reason": phases.allSatisfy { $0.count >= 3 } ? "CAPTURE_COMPLETE" : "NOT_ENOUGH_PHASE_FRAMES",
          "captureMode": "ISOLATED_NATIVE_TORCH_OFF_ON_OFF_LOCKED_EXPOSURE",
          "physicalCaptureDeviceUniqueId": captureDevice.uniqueID,
          "configuredFrameRate": selection.fps,
          "frameWidth": Int(dimensions.width),
          "frameHeight": Int(dimensions.height),
          "torchLevel": Double(torchLevel),
          "lockedExposureSeconds": CMTimeGetSeconds(captureDevice.exposureDuration),
          "lockedISO": Double(captureDevice.iso),
          "phaseFrames": phases,
          "phaseFrameCounts": phases.map { $0.count },
          "cameraHandoffAfterIlluminationProbe": handoff,
        ]
        DispatchQueue.main.async { result(payload) }
      } catch {
        do {
          try captureDevice.lockForConfiguration()
          captureDevice.torchMode = .off
          captureDevice.unlockForConfiguration()
        } catch {}
        output?.setSampleBufferDelegate(nil, queue: nil)
        if let session, session.isRunning { session.stopRunning() }
        _ = self.resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)
        self.illuminationResponseNativeCollector = nil
        self.illuminationResponseNativeSession = nil
        self.illuminationResponseNativeBusy = false
        DispatchQueue.main.async {
          result(FlutterError(code: "ILLUMINATION_RESPONSE_CAPTURE_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

'''
swift = replace_once(swift, '  private func handleCameraProbeCall(\n', illum_method + '  private func handleCameraProbeCall(\n', 'insert illumination method')

swift = replace_once(
    swift,
    '    switch call.method {\n    case "captureTemporalFrequencyNative":\n',
    '    switch call.method {\n    case "captureIlluminationResponseNative":\n      let physicalDevice = temporalFrequencyPhysicalDevice(for: device)\n      captureIlluminationResponseNative(device: physicalDevice, call: call, result: result)\n\n    case "captureTemporalFrequencyNative":\n',
    'route illumination method',
)
swift_path.write_text(swift)

# ---------- Dart illumination analyzer ----------
Path('lib/hcv_illumination_response_probe.dart').write_text(r'''import 'dart:math';

import 'package:flutter/services.dart';

class HCVIlluminationResponseProbe {
  const HCVIlluminationResponseProbe();

  static const MethodChannel _channel = MethodChannel('hcv.cameraProbe');

  Future<Map<String, dynamic>> captureNative(String deviceUniqueId) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'captureIlluminationResponseNative',
        {'deviceUniqueId': deviceUniqueId, 'torchLevel': 0.30},
      );
      if (raw == null) return unavailable('ILLUMINATION_RESPONSE_NO_RESULT');
      return analyzeNativeCapture(Map<String, dynamic>.from(raw));
    } catch (error) {
      return unavailable('ILLUMINATION_RESPONSE_CAPTURE_FAILED', error: error);
    }
  }

  Map<String, dynamic> analyzeNativeCapture(Map<String, dynamic> raw) {
    if (raw['analysisStatus'] != 'CAPTURED') {
      return {...unavailable((raw['reason'] as String?) ?? 'ILLUMINATION_CAPTURE_NOT_AVAILABLE'), 'nativeCaptureMetadata': _withoutFrames(raw)};
    }
    final rawPhases = raw['phaseFrames'];
    if (rawPhases is! List || rawPhases.length != 3) return unavailable('ILLUMINATION_PHASES_INVALID');
    final phases = <List<List<double>>>[];
    for (final rawPhase in rawPhases) {
      if (rawPhase is! List || rawPhase.length < 3) return unavailable('ILLUMINATION_PHASE_TOO_SHORT');
      final frames = <List<double>>[];
      for (final rawFrame in rawPhase) {
        if (rawFrame is! List || rawFrame.length != 9) continue;
        final frame = rawFrame.whereType<num>().map((e) => e.toDouble()).toList(growable: false);
        if (frame.length == 9) frames.add(frame);
      }
      if (frames.length < 3) return unavailable('ILLUMINATION_VALID_FRAMES_TOO_SHORT');
      phases.add(frames);
    }

    final cellResults = <Map<String, dynamic>>[];
    final relative = <double>[];
    final reversibility = <double>[];
    for (var cell = 0; cell < 9; cell++) {
      final off1 = _median(phases[0].map((f) => f[cell]).toList()..sort()) ?? 0.0;
      final on = _median(phases[1].map((f) => f[cell]).toList()..sort()) ?? 0.0;
      final off2 = _median(phases[2].map((f) => f[cell]).toList()..sort()) ?? 0.0;
      final baseline = (off1 + off2) / 2.0;
      final delta = on - baseline;
      final rel = delta / max(baseline.abs(), 0.03);
      final rev = (1.0 - (off2 - off1).abs() / max(delta.abs(), 0.03)).clamp(0.0, 1.0).toDouble();
      relative.add(rel);
      reversibility.add(rev);
      cellResults.add({'row': cell ~/ 3, 'column': cell % 3, 'off1Luma': off1, 'torchOnLuma': on, 'off2Luma': off2, 'relativeTorchResponse': rel, 'reversibility': rev});
    }
    final sortedRelative = List<double>.from(relative)..sort();
    final sortedReversibility = List<double>.from(reversibility)..sort();
    final count20 = relative.where((v) => v >= 0.20).length;
    final count35 = relative.where((v) => v >= 0.35).length;
    final medianResponse = _median(sortedRelative) ?? 0.0;
    final medianRev = _median(sortedReversibility) ?? 0.0;
    final reflectiveCandidate = medianResponse >= 0.35 && count20 >= 6 && medianRev >= 0.55;

    return {
      'type': 'SIGILLUM_ILLUMINATION_RESPONSE_PROBE_V1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'PHYSICAL_REFLECTION_GUARD_ONLY',
      'productionDecisionChanged': false,
      'captureSource': 'ISOLATED_NATIVE_TORCH_OFF_ON_OFF_LOCKED_EXPOSURE',
      'configuredFrameRate': raw['configuredFrameRate'],
      'frameWidth': raw['frameWidth'],
      'frameHeight': raw['frameHeight'],
      'torchLevel': raw['torchLevel'],
      'lockedExposureSeconds': raw['lockedExposureSeconds'],
      'lockedISO': raw['lockedISO'],
      'phaseFrameCounts': raw['phaseFrameCounts'],
      'medianCellRelativeTorchResponse': medianResponse,
      'maximumCellRelativeTorchResponse': sortedRelative.isEmpty ? null : sortedRelative.last,
      'medianCellReversibility': medianRev,
      'reflectiveCellsAt20Percent': count20,
      'reflectiveCellsAt35Percent': count35,
      'strongReflectiveResponseCandidate': reflectiveCandidate,
      'cellResults': cellResults,
      'nativeCaptureMetadata': _withoutFrames(raw),
      'note': 'A strong reversible OFF→ON→OFF response is evidence of externally illuminated/reflected scene content. Weak response is inconclusive and never proves DISPLAY.',
    };
  }

  static Map<String, dynamic> unavailable(String reason, {Object? error}) => {
        'type': 'SIGILLUM_ILLUMINATION_RESPONSE_PROBE_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'decisionRole': 'PHYSICAL_REFLECTION_GUARD_ONLY',
        'productionDecisionChanged': false,
        'reason': reason,
        if (error != null) 'error': error.toString(),
      };

  Map<String, dynamic> _withoutFrames(Map<String, dynamic> raw) {
    final copy = Map<String, dynamic>.from(raw);
    copy.remove('phaseFrames');
    return copy;
  }

  double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2.0;
  }
}
''')

# ---------- Conservative physical fusion ----------
Path('lib/hcv_physical_display_fusion.dart').write_text(r'''import 'dart:math';

import 'hcv_display_risk_fusion.dart';

class HCVPhysicalDisplayFusion {
  const HCVPhysicalDisplayFusion._();

  static const double hfrMinPeriodicity = 0.10;
  static const double hfrMinFrequencyStability = 0.70;
  static const double hfrMinPhaseConsistency = 0.55;
  static const double hfrMinSpectralConcentration = 0.85;

  static bool hasStrongHfrDisplaySignature(Map<String, dynamic>? probe) {
    if (probe == null || probe['analysisStatus'] != 'ANALYZED') return false;
    final periodicity = (probe['medianCellPeriodicityStrength'] as num?)?.toDouble() ?? 0.0;
    final stability = (probe['medianCellFrequencyStability'] as num?)?.toDouble() ?? 0.0;
    final phase = (probe['medianCellPhaseStepConsistency'] as num?)?.toDouble() ?? 0.0;
    final spectrumRaw = probe['globalFrameLumaTemporalSpectrum'];
    final spectrum = spectrumRaw is Map ? spectrumRaw : const {};
    final concentration = (spectrum['temporalSpectralConcentration'] as num?)?.toDouble() ?? 0.0;
    return periodicity >= hfrMinPeriodicity &&
        stability >= hfrMinFrequencyStability &&
        phase >= hfrMinPhaseConsistency &&
        concentration >= hfrMinSpectralConcentration;
  }

  static bool hasStrongReflectiveResponse(Map<String, dynamic>? probe) {
    if (probe == null || probe['analysisStatus'] != 'ANALYZED') return false;
    return probe['strongReflectiveResponseCandidate'] == true &&
        ((probe['medianCellRelativeTorchResponse'] as num?)?.toDouble() ?? 0.0) >= 0.35 &&
        ((probe['reflectiveCellsAt20Percent'] as num?)?.toInt() ?? 0) >= 6 &&
        ((probe['medianCellReversibility'] as num?)?.toDouble() ?? 0.0) >= 0.55;
  }

  static HCVDisplayRiskResult apply({
    required HCVDisplayRiskResult baseline,
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? illuminationResponseProbe,
    required bool hardDisplayCorroboration,
  }) {
    final hfrDisplay = hasStrongHfrDisplaySignature(temporalFrequencyProbe);
    final reflective = hasStrongReflectiveResponse(illuminationResponseProbe);
    final cleanedReasons = baseline.reasons.where((r) => r != 'LIVE_PROBE_MISSING').toList();
    if (temporalFrequencyProbe?['analysisStatus'] == 'ANALYZED' &&
        !cleanedReasons.contains('NATIVE_HFR_PHYSICAL_PROBE_AVAILABLE')) {
      cleanedReasons.add('NATIVE_HFR_PHYSICAL_PROBE_AVAILABLE');
    }

    if (hfrDisplay && baseline.decision != 'STRONG_DISPLAY_RISK') {
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: max(90, baseline.score),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: baseline.analysisStatus,
        evidenceSources: {...baseline.evidenceSources, 'NATIVE_HFR_PERIODICITY'}.toList(),
        strongSources: {...baseline.strongSources, 'NATIVE_HFR_PERIODICITY'}.toList(),
        reasons: {...cleanedReasons, 'PHYSICAL_HFR_DISPLAY_RESCUE_V1'}.toList(),
      );
    }

    if (baseline.decision == 'STRONG_DISPLAY_RISK' &&
        reflective &&
        !hfrDisplay &&
        !hardDisplayCorroboration) {
      return HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: min(69, max(45, baseline.score)),
        decision: 'NON_CONCLUSIVE',
        analysisStatus: baseline.analysisStatus,
        evidenceSources: {...baseline.evidenceSources, 'ILLUMINATION_REFLECTION_RESPONSE'}.toList(),
        strongSources: const [],
        reasons: {...cleanedReasons, 'REFLECTIVE_ILLUMINATION_RESPONSE_BLOCKS_UNCORROBORATED_DISPLAY_WARNING'}.toList(),
      );
    }

    if (cleanedReasons.length != baseline.reasons.length || !baseline.reasons.every(cleanedReasons.contains)) {
      return HCVDisplayRiskResult(
        risk: baseline.risk,
        score: baseline.score,
        decision: baseline.decision,
        analysisStatus: baseline.analysisStatus,
        evidenceSources: baseline.evidenceSources,
        strongSources: baseline.strongSources,
        reasons: cleanedReasons,
      );
    }
    return baseline;
  }
}
''')

# ---------- Camera integration ----------
dart_path = Path('lib/camera_page.dart')
dart = dart_path.read_text()
dart = replace_once(dart, "import 'hcv_temporal_frequency_probe.dart';\n", "import 'hcv_temporal_frequency_probe.dart';\nimport 'hcv_illumination_response_probe.dart';\nimport 'hcv_physical_display_fusion.dart';\n", 'imports')
dart = replace_once(dart, '  Map<String, dynamic>? pendingTemporalFrequencyProbe;\n', '  Map<String, dynamic>? pendingTemporalFrequencyProbe;\n  Map<String, dynamic>? pendingIlluminationResponseProbe;\n', 'pending illumination')

# Capture illumination while Flutter camera remains disposed, immediately after HFR.
dart = replace_once(
    dart,
    '''    try {\n      probe = await const HCVTemporalFrequencyProbe().captureNative(\n        description.name,\n      );\n    } catch (error) {\n      probe = HCVTemporalFrequencyProbe.unavailable(\n        'ISOLATED_NATIVE_TEMPORAL_FREQUENCY_FAILED',\n        error: error,\n      );\n    }\n\n    // The native method returns only after its AVCaptureSession has stopped.\n''',
    '''    try {\n      probe = await const HCVTemporalFrequencyProbe().captureNative(\n        description.name,\n      );\n    } catch (error) {\n      probe = HCVTemporalFrequencyProbe.unavailable(\n        'ISOLATED_NATIVE_TEMPORAL_FREQUENCY_FAILED',\n        error: error,\n      );\n    }\n\n    try {\n      pendingIlluminationResponseProbe =\n          await const HCVIlluminationResponseProbe().captureNative(description.name);\n    } catch (error) {\n      pendingIlluminationResponseProbe = HCVIlluminationResponseProbe.unavailable(\n        'ISOLATED_NATIVE_ILLUMINATION_RESPONSE_FAILED',\n        error: error,\n      );\n    }\n\n    // The native methods return only after their AVCaptureSessions have stopped.\n''',
    'illumination capture integration',
)

# Reset pending probe in video start.
dart = replace_once(dart, '    pendingTemporalFrequencyProbe = null;\n    pendingVideoLocation = captureLocation;\n', '    pendingTemporalFrequencyProbe = null;\n    pendingIlluminationResponseProbe = null;\n    pendingVideoLocation = captureLocation;\n', 'video reset')

# Preserve/retrieve in processVideo.
dart = replace_once(dart, '    final temporalFrequencyProbe = pendingTemporalFrequencyProbe;\n    pendingTemporalFrequencyProbe = null;\n', '    final temporalFrequencyProbe = pendingTemporalFrequencyProbe;\n    pendingTemporalFrequencyProbe = null;\n    final illuminationResponseProbe = pendingIlluminationResponseProbe;\n    pendingIlluminationResponseProbe = null;\n', 'video probe retrieval')

# Photo local probe retrieval after native capture.
dart = replace_once(dart, '    Map<String, dynamic>? temporalFrequencyProbe;\n\n    try {\n', '    Map<String, dynamic>? temporalFrequencyProbe;\n    Map<String, dynamic>? illuminationResponseProbe;\n\n    try {\n', 'photo illumination local')
dart = replace_once(dart, '      temporalFrequencyProbe = await _captureTemporalFrequencyNativeIsolated();\n\n      try {\n', '      pendingIlluminationResponseProbe = null;\n      temporalFrequencyProbe = await _captureTemporalFrequencyNativeIsolated();\n      illuminationResponseProbe = pendingIlluminationResponseProbe;\n      pendingIlluminationResponseProbe = null;\n\n      try {\n', 'photo capture probes')

# Photo fusion now sees physical probes and applies conservative post-baseline fusion.
dart = replace_once(
    dart,
    '''      final screenReplayAnalyses = [\n        liveScreenProbe,\n        screenReplayAnalysis,\n        mlScreenReplayAnalysis,\n      ];\n      final displayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(\n        screenReplayAnalyses,\n      );\n''',
    '''      final screenReplayAnalyses = [\n        liveScreenProbe,\n        screenReplayAnalysis,\n        mlScreenReplayAnalysis,\n      ];\n      final baselineDisplayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(\n        screenReplayAnalyses,\n      );\n      final displayRisk = HCVPhysicalDisplayFusion.apply(\n        baseline: baselineDisplayRisk,\n        temporalFrequencyProbe: temporalFrequencyProbe,\n        illuminationResponseProbe: illuminationResponseProbe,\n        hardDisplayCorroboration: _hasHardDisplayCorroboration(screenReplayAnalyses),\n      );\n''',
    'photo physical fusion',
)

# Photo certificate.
dart = replace_once(dart, '        "temporalFrequencyProbe": temporalFrequencyProbe,\n', '        "temporalFrequencyProbe": temporalFrequencyProbe,\n        "illuminationResponseProbe": illuminationResponseProbe,\n', 'photo certificate illumination')

# Video fusion.
dart = replace_once(
    dart,
    '''    final screenReplayAnalyses = [\n      liveScreenProbe,\n      screenReplayAnalysis,\n      mlScreenReplayAnalysis,\n    ];\n    final displayRisk = combineVideoDisplayRiskFromCaptureEvidence(\n      screenReplayAnalyses,\n    );\n''',
    '''    final screenReplayAnalyses = [\n      liveScreenProbe,\n      screenReplayAnalysis,\n      mlScreenReplayAnalysis,\n    ];\n    final baselineDisplayRisk = combineVideoDisplayRiskFromCaptureEvidence(\n      screenReplayAnalyses,\n    );\n    final displayRisk = HCVPhysicalDisplayFusion.apply(\n      baseline: baselineDisplayRisk,\n      temporalFrequencyProbe: temporalFrequencyProbe,\n      illuminationResponseProbe: illuminationResponseProbe,\n      hardDisplayCorroboration: _hasHardDisplayCorroboration(screenReplayAnalyses),\n    );\n''',
    'video physical fusion',
)
# Video certificate: replace second temporalFrequencyProbe occurrence only by using unique context.
dart = replace_once(dart, '      "temporalFrequencyProbe": temporalFrequencyProbe,\n      "physicalSceneClass": liveScreenProbe?["sceneClass"] ?? "UNKNOWN",\n', '      "temporalFrequencyProbe": temporalFrequencyProbe,\n      "illuminationResponseProbe": illuminationResponseProbe,\n      "physicalSceneClass": liveScreenProbe?["sceneClass"] ?? "UNKNOWN",\n', 'video certificate illumination')

# Clear pending illumination on video errors where temporal is cleared.
dart = dart.replace('      pendingTemporalFrequencyProbe = null;\n      setState(() {', '      pendingTemporalFrequencyProbe = null;\n      pendingIlluminationResponseProbe = null;\n      setState(() {')

dart_path.write_text(dart)

# ---------- Tests ----------
Path('test/illumination_response_probe_math_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_hcv/hcv_illumination_response_probe.dart';

List<List<double>> phase(double value) => List.generate(8, (_) => List.filled(9, value));

void main() {
  test('strong reversible torch response is marked reflective', () {
    final result = const HCVIlluminationResponseProbe().analyzeNativeCapture({
      'analysisStatus': 'CAPTURED',
      'phaseFrames': [phase(0.20), phase(0.34), phase(0.205)],
      'configuredFrameRate': 60.0,
    });
    expect(result['analysisStatus'], 'ANALYZED');
    expect(result['strongReflectiveResponseCandidate'], true);
    expect(result['reflectiveCellsAt20Percent'], 9);
  });

  test('weak torch response stays inconclusive', () {
    final result = const HCVIlluminationResponseProbe().analyzeNativeCapture({
      'analysisStatus': 'CAPTURED',
      'phaseFrames': [phase(0.40), phase(0.43), phase(0.402)],
    });
    expect(result['strongReflectiveResponseCandidate'], false);
  });
}
''')

Path('test/physical_display_fusion_v1_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_hcv/hcv_display_risk_fusion.dart';
import 'package:sigillum_hcv/hcv_physical_display_fusion.dart';

const noDisplay = HCVDisplayRiskResult(risk: 'LOW', score: 4, decision: 'NO_DISPLAY_EVIDENCE', analysisStatus: 'COMPLETE', evidenceSources: ['ML_REALITY_CLASS'], strongSources: [], reasons: ['LIVE_PROBE_MISSING']);
const mlStrong = HCVDisplayRiskResult(risk: 'HIGH', score: 85, decision: 'STRONG_DISPLAY_RISK', analysisStatus: 'COMPLETE', evidenceSources: ['ML_SCREEN_CLASS'], strongSources: ['ML_SCREEN_CLASS'], reasons: ['ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY']);

Map<String, dynamic> hfr({double p = .24, double s = .94, double phase = .68, double c = .90}) => {
  'analysisStatus': 'ANALYZED',
  'medianCellPeriodicityStrength': p,
  'medianCellFrequencyStability': s,
  'medianCellPhaseStepConsistency': phase,
  'globalFrameLumaTemporalSpectrum': {'temporalSpectralConcentration': c},
};
Map<String, dynamic> reflect(bool strong) => {
  'analysisStatus': 'ANALYZED',
  'strongReflectiveResponseCandidate': strong,
  'medianCellRelativeTorchResponse': strong ? .55 : .08,
  'reflectiveCellsAt20Percent': strong ? 8 : 1,
  'medianCellReversibility': strong ? .85 : .20,
};

void main() {
  test('strong HFR rescues ML false negative', () {
    final r = HCVPhysicalDisplayFusion.apply(baseline: noDisplay, temporalFrequencyProbe: hfr(), illuminationResponseProbe: reflect(false), hardDisplayCorroboration: false);
    expect(r.decision, 'STRONG_DISPLAY_RISK');
    expect(r.reasons, contains('PHYSICAL_HFR_DISPLAY_RESCUE_V1'));
    expect(r.reasons, isNot(contains('LIVE_PROBE_MISSING')));
  });

  test('strong reflection demotes uncorroborated ML display', () {
    final r = HCVPhysicalDisplayFusion.apply(baseline: mlStrong, temporalFrequencyProbe: hfr(p: .01, s: .2, phase: .2, c: .4), illuminationResponseProbe: reflect(true), hardDisplayCorroboration: false);
    expect(r.decision, 'NON_CONCLUSIVE');
    expect(r.reasons, contains('REFLECTIVE_ILLUMINATION_RESPONSE_BLOCKS_UNCORROBORATED_DISPLAY_WARNING'));
  });

  test('reflection cannot veto hard display corroboration', () {
    final r = HCVPhysicalDisplayFusion.apply(baseline: mlStrong, temporalFrequencyProbe: hfr(p: .01, s: .2, phase: .2, c: .4), illuminationResponseProbe: reflect(true), hardDisplayCorroboration: true);
    expect(r.decision, 'STRONG_DISPLAY_RISK');
  });
}
''')

Path('test/native_illumination_response_contract_test.dart').write_text(r'''import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native illumination probe locks exposure and uses OFF ON OFF torch phases', () {
    final s = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(s, contains('captureIlluminationResponseNative'));
    expect(s, contains('ISOLATED_NATIVE_TORCH_OFF_ON_OFF_LOCKED_EXPOSURE'));
    expect(s, contains('captureDevice.setExposureModeCustom'));
    expect(s, contains('captureDevice.setTorchModeOn(level: torchLevel)'));
    expect(RegExp(r'collector\.setPhase\([012]\)').allMatches(s).length, 3);
    expect(s, contains('resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)'));
  });
}
''')

print('illumination response + physical fusion V1 patch applied')
