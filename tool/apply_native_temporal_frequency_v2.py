from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# 1. Replace the Dart probe transport with native CMSampleBuffer capture.
#    Keep the already-tested math implementation below HCVTemporalFrequencyMath.
# ---------------------------------------------------------------------------
probe_path = Path('lib/hcv_temporal_frequency_probe.dart')
probe = probe_path.read_text()
math_marker = 'class HCVTemporalFrequencyMath {'
if math_marker not in probe:
    raise SystemExit('temporal frequency math marker missing')
math_suffix = math_marker + probe.split(math_marker, 1)[1]

probe_prefix = r'''import 'dart:math';

import 'package:flutter/services.dart';

/// Shadow-only native physical probe for display refresh / PWM periodicity.
///
/// V2 deliberately does NOT use Flutter camera recording or FFmpeg. The
/// Flutter CameraController is released before this call, then iOS owns the
/// camera in a short isolated AVCaptureSession and returns row profiles from
/// consecutive CMSampleBuffers together with their real presentation times.
class HCVTemporalFrequencyProbe {
  const HCVTemporalFrequencyProbe();

  static const MethodChannel _channel = MethodChannel('hcv.cameraProbe');
  static const double targetMaxFps = 240.0;
  static const double requestedShortExposureSeconds = 1.0 / 1000.0;
  static const double targetCaptureDurationSeconds = 0.35;
  static const int rowProfileBins = 96;

  Future<Map<String, dynamic>> captureNative(String deviceUniqueId) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'captureTemporalFrequencyNative',
        {
          'deviceUniqueId': deviceUniqueId,
          'targetMaxFps': targetMaxFps,
          'targetDurationSeconds': targetCaptureDurationSeconds,
          'targetExposureSeconds': requestedShortExposureSeconds,
          'rowProfileBins': rowProfileBins,
        },
      );
      if (raw == null) {
        return unavailable('NATIVE_TEMPORAL_FREQUENCY_NO_RESULT');
      }
      return analyzeNativeCapture(Map<String, dynamic>.from(raw));
    } catch (error) {
      return unavailable(
        'NATIVE_TEMPORAL_FREQUENCY_CAPTURE_FAILED',
        error: error,
      );
    }
  }

  Map<String, dynamic> analyzeNativeCapture(Map<String, dynamic> raw) {
    if (raw['analysisStatus'] != 'CAPTURED') {
      return {
        ...unavailable(
          (raw['reason'] as String?) ?? 'NATIVE_CAPTURE_NOT_AVAILABLE',
        ),
        'nativeCapture': _withoutRawFrames(raw),
      };
    }

    final rawFrames = raw['frames'];
    if (rawFrames is! List || rawFrames.length < 6) {
      return {
        ...unavailable('NOT_ENOUGH_NATIVE_CONSECUTIVE_FRAMES'),
        'nativeCapture': _withoutRawFrames(raw),
      };
    }

    final cellSequences = List.generate(
      9,
      (_) => <List<double>>[],
      growable: false,
    );
    final frameLuma = <double>[];
    var acceptedFrames = 0;

    for (final rawFrame in rawFrames) {
      if (rawFrame is! List || rawFrame.length != 9) continue;
      final parsedCells = <List<double>>[];
      var valid = true;
      for (final rawCell in rawFrame) {
        if (rawCell is! List || rawCell.length < 16) {
          valid = false;
          break;
        }
        final profile = rawCell
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList(growable: false);
        if (profile.length != rawCell.length) {
          valid = false;
          break;
        }
        parsedCells.add(profile);
      }
      if (!valid || parsedCells.length != 9) continue;
      for (var cell = 0; cell < 9; cell++) {
        cellSequences[cell].add(parsedCells[cell]);
      }
      final values = parsedCells.expand((profile) => profile).toList();
      frameLuma.add(_mean(values));
      acceptedFrames++;
    }

    if (acceptedFrames < 6) {
      return {
        ...unavailable('NOT_ENOUGH_VALID_NATIVE_FRAMES'),
        'nativeCapture': _withoutRawFrames(raw),
      };
    }

    final cellResults = <Map<String, dynamic>>[];
    for (var cell = 0; cell < 9; cell++) {
      final result = HCVTemporalFrequencyMath.analyzeRowProfileSequence(
        cellSequences[cell],
      );
      cellResults.add({
        'row': cell ~/ 3,
        'column': cell % 3,
        ...result,
      });
    }

    final timestamps = (raw['frameTimestampsSeconds'] as List?)
            ?.whereType<num>()
            .map((value) => value.toDouble())
            .toList(growable: false) ??
        const <double>[];
    final normalizedTimestamps = timestamps.isEmpty
        ? const <double>[]
        : timestamps.map((value) => value - timestamps.first).toList();
    final intervals = <double>[];
    for (var i = 1; i < timestamps.length; i++) {
      final delta = timestamps[i] - timestamps[i - 1];
      if (delta > 0 && delta.isFinite) intervals.add(delta);
    }
    final sortedIntervals = List<double>.from(intervals)..sort();
    final medianInterval = _median(sortedIntervals);
    final actualFps = medianInterval != null && medianInterval > 0
        ? 1.0 / medianInterval
        : (raw['actualFrameRate'] as num?)?.toDouble();
    final intervalMad = medianInterval == null
        ? null
        : _median(
            intervals
                .map((value) => (value - medianInterval).abs())
                .toList()
              ..sort(),
          );

    final periodicityStrengths = cellResults
        .map((e) => (e['periodicityStrength'] as num?)?.toDouble())
        .whereType<double>()
        .toList()
      ..sort();
    final frequencyStabilities = cellResults
        .map((e) => (e['dominantFrequencyStability'] as num?)?.toDouble())
        .whereType<double>()
        .toList()
      ..sort();
    final phaseConsistencies = cellResults
        .map((e) => (e['phaseStepConsistency'] as num?)?.toDouble())
        .whereType<double>()
        .toList()
      ..sort();

    final configuredFps = (raw['configuredFrameRate'] as num?)?.toDouble();
    final actualExposure =
        (raw['actualShortExposureSeconds'] as num?)?.toDouble();
    final framePeriod = configuredFps != null && configuredFps > 0
        ? 1.0 / configuredFps
        : null;

    return {
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
      'productionDecisionChanged': false,
      'captureSource': 'ISOLATED_NATIVE_AVCAPTURESESSION_CMSAMPLEBUFFER',
      'flutterCameraDisposedDuringProbe': true,
      'requestedTargetFps': raw['requestedTargetFps'],
      'configuredFrameRate': configuredFps,
      'actualFrameRateFromTimestamps': actualFps,
      'frameRateTier': raw['frameRateTier'],
      'configuredHighSpeedFormatWidth': raw['frameWidth'],
      'configuredHighSpeedFormatHeight': raw['frameHeight'],
      'configuredFormatMaxSupportedFrameRate':
          raw['configuredFormatMaxSupportedFrameRate'],
      'requestedShortExposureSeconds': raw['requestedShortExposureSeconds'],
      'targetShortExposureSecondsAfterClamp':
          raw['targetShortExposureSecondsAfterClamp'],
      'actualShortExposureSeconds': actualExposure,
      'shortExposureVerified': raw['shortExposureVerified'] == true,
      'shortExposureISO': raw['shortExposureISO'],
      'shortExposureISOClamped': raw['shortExposureISOClamped'] == true,
      'exposureLockedForEntireNativeCapture':
          raw['exposureLockedForEntireNativeCapture'] == true,
      if (framePeriod != null && actualExposure != null)
        'exposureToFramePeriodRatio': actualExposure / framePeriod,
      'framesCaptured': raw['frameCount'],
      'framesAnalyzed': acceptedFrames,
      'targetFrameCount': raw['targetFrameCount'],
      'rowProfileBins': raw['rowProfileBins'],
      'frameTimestampsSecondsFromFirst': normalizedTimestamps,
      'medianFrameIntervalSeconds': medianInterval,
      'frameIntervalMadSeconds': intervalMad,
      if (actualFps != null) 'temporalNyquistHz': actualFps / 2.0,
      'consecutiveNativeSampleBuffers': true,
      'encodedVideoUsed': false,
      'ffmpegUsed': false,
      'rawNativeFramesOmittedFromCertificate': true,
      'globalFrameLumaTemporalSpectrum':
          HCVTemporalFrequencyMath.analyzeScalarSequence(frameLuma),
      'cellResults': cellResults,
      'minimumCellPeriodicityStrength':
          periodicityStrengths.isEmpty ? null : periodicityStrengths.first,
      'medianCellPeriodicityStrength': _median(periodicityStrengths),
      'minimumCellFrequencyStability':
          frequencyStabilities.isEmpty ? null : frequencyStabilities.first,
      'medianCellFrequencyStability': _median(frequencyStabilities),
      'minimumCellPhaseStepConsistency':
          phaseConsistencies.isEmpty ? null : phaseConsistencies.first,
      'medianCellPhaseStepConsistency': _median(phaseConsistencies),
      'spatialPolicy': const {
        'gridRows': 3,
        'gridColumns': 3,
        'decisionEnabled': false,
      },
      'nativeCaptureMetadata': _withoutRawFrames(raw),
      'note':
          'V2 measures row-profile phase evolution directly from native consecutive CMSampleBuffers at the highest isolated hardware tier available (240, 120, then 60 fps). It never participates in BUILD 80 display fusion.',
    };
  }

  static Map<String, dynamic> unavailable(
    String reason, {
    Object? error,
  }) {
    return {
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
      'productionDecisionChanged': false,
      'reason': reason,
      if (error != null) 'error': error.toString(),
    };
  }

  Map<String, dynamic> _withoutRawFrames(Map<String, dynamic> raw) {
    final copy = Map<String, dynamic>.from(raw);
    copy.remove('frames');
    return copy;
  }

  double _mean(List<double> values) =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

  double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[i]
        : (sorted[i - 1] + sorted[i]) / 2.0;
  }
}

'''
probe_path.write_text(probe_prefix + math_suffix)


# ---------------------------------------------------------------------------
# 2. Camera page: dispose Flutter's session before the native probe, then
#    rebuild it before BUILD 80 temporal/photo/video capture continues.
# ---------------------------------------------------------------------------
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()

camera = camera.replace(
    '  HCVTemporalFrequencyClip? pendingTemporalFrequencyClip;\n',
    '',
)
camera = camera.replace(
    '    pendingTemporalFrequencyClip = null;\n',
    '',
)

settle_marker = '''  Future<void> _settleCameraAfterLiveProbe() async {
'''
helper = r'''  Future<Map<String, dynamic>> _captureTemporalFrequencyNativeIsolated() async {
    final active = controller;
    final available = cameras;
    if (active == null ||
        !active.value.isInitialized ||
        available == null ||
        selectedCameraIndex < 0 ||
        selectedCameraIndex >= available.length) {
      return HCVTemporalFrequencyProbe.unavailable(
        'FLUTTER_CAMERA_NOT_READY_FOR_NATIVE_PROBE',
      );
    }

    final description = available[selectedCameraIndex];
    final savedZoom = currentZoom;
    final savedFlash = currentFlashMode;
    Map<String, dynamic> probe;

    // The native high-speed session must own the camera exclusively. BUILD 87
    // proved that changing activeFormat underneath an initialized Flutter
    // CameraController is unsafe. Release the Flutter AVCaptureSession first.
    try {
      await active.dispose();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      probe = await const HCVTemporalFrequencyProbe().captureNative(
        description.name,
      );
    } catch (error) {
      probe = HCVTemporalFrequencyProbe.unavailable(
        'ISOLATED_NATIVE_TEMPORAL_FREQUENCY_FAILED',
        error: error,
      );
    }

    // The native method returns only after its AVCaptureSession has stopped.
    // Give AVFoundation a short release interval, then reconstruct the Flutter
    // camera before BUILD 80's original capture path resumes.
    await Future.delayed(const Duration(milliseconds: 220));
    final replacement = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: true,
    );
    try {
      await replacement.initialize();
      final newMinZoom = await replacement.getMinZoomLevel();
      final deviceMaxZoom = await replacement.getMaxZoomLevel();
      final newMaxZoom = deviceMaxZoom.clamp(newMinZoom, 10.0).toDouble();
      final restoredZoom = savedZoom.clamp(newMinZoom, newMaxZoom).toDouble();
      await replacement.setZoomLevel(restoredZoom);
      try {
        await replacement.setFlashMode(savedFlash);
      } catch (_) {}

      controller = replacement;
      minZoom = newMinZoom;
      maxZoom = newMaxZoom;
      currentZoom = restoredZoom;
      if (mounted) {
        setState(() {
          ready = true;
        });
      }
    } catch (error) {
      try {
        await replacement.dispose();
      } catch (_) {}
      controller = null;
      if (mounted) {
        setState(() {
          ready = false;
          status = '${_c('error')}: CAMERA_REINITIALIZATION_AFTER_NATIVE_PROBE_FAILED';
        });
      }
      throw StateError(
        'CAMERA_REINITIALIZATION_AFTER_NATIVE_PROBE_FAILED: $error',
      );
    }

    return probe;
  }

'''
camera = replace_once(camera, settle_marker, helper + settle_marker, 'camera native probe helper')

old_video_probe = '''      // BUILD 80 remains the decision baseline. A separate high-speed,
      // short-shutter clip is captured only for shadow physical research and
      // is never supplied to displayRisk fusion.
      const frequencyProbeEngine = HCVTemporalFrequencyProbe();
      try {
        pendingTemporalFrequencyClip =
            await frequencyProbeEngine.capture(controller!);
      } catch (e) {
        pendingTemporalFrequencyProbe = HCVTemporalFrequencyProbe.unavailable(
          'VIDEO_TEMPORAL_FREQUENCY_CAPTURE_FAILED',
          error: e,
        );
      }

'''
new_video_probe = '''      // BUILD 80 remains the decision baseline. The V2 physical probe runs in
      // its own native AVCaptureSession while Flutter camera is released.
      pendingTemporalFrequencyProbe =
          await _captureTemporalFrequencyNativeIsolated();

'''
camera = replace_once(camera, old_video_probe, new_video_probe, 'video native probe integration')

old_video_stop_analysis = '''      if (pendingTemporalFrequencyClip != null) {
        pendingTemporalFrequencyProbe = await const HCVTemporalFrequencyProbe()
            .analyzeCapturedClip(pendingTemporalFrequencyClip!);
        pendingTemporalFrequencyClip = null;
      }
      pendingTemporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'VIDEO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );

'''
camera = replace_once(
    camera,
    old_video_stop_analysis,
    '''      pendingTemporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'VIDEO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );

''',
    'video stop native probe analysis removal',
)

old_cleanup = '''      if (pendingTemporalFrequencyClip != null) {
        await const HCVTemporalFrequencyProbe()
            .discard(pendingTemporalFrequencyClip!.path);
      }
      pendingTemporalFrequencyClip = null;
      pendingTemporalFrequencyProbe = null;
'''
# It occurs in start and stop failure paths.
camera = camera.replace(old_cleanup, '''      pendingTemporalFrequencyProbe = null;
''')

camera = camera.replace(
    '    HCVTemporalFrequencyClip? frequencyClip;\n',
    '',
)
old_photo_probe = '''      try {
        frequencyClip = await frequencyProbeEngine.capture(controller!);
      } catch (e) {
        temporalFrequencyProbe = HCVTemporalFrequencyProbe.unavailable(
          'PHOTO_TEMPORAL_FREQUENCY_CAPTURE_FAILED',
          error: e,
        );
      }

'''
new_photo_probe = '''      temporalFrequencyProbe =
          await _captureTemporalFrequencyNativeIsolated();

'''
camera = replace_once(camera, old_photo_probe, new_photo_probe, 'photo native probe integration')

old_photo_late_analysis = '''      if (frequencyClip != null) {
        temporalFrequencyProbe =
            await frequencyProbeEngine.analyzeCapturedClip(frequencyClip);
        frequencyClip = null;
      }
      temporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'PHOTO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );

'''
camera = replace_once(
    camera,
    old_photo_late_analysis,
    '''      temporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'PHOTO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );

''',
    'photo late native analysis removal',
)

camera = camera.replace(
    '''      if (frequencyClip != null) {
        await frequencyProbeEngine.discard(frequencyClip.path);
      }
''',
    '',
)
camera_path.write_text(camera)


# ---------------------------------------------------------------------------
# 3. Native iOS collector and isolated AVCaptureSession.
# ---------------------------------------------------------------------------
swift_path = Path('ios/Runner/AppDelegate.swift')
swift = swift_path.read_text()

if 'import CoreVideo\n' not in swift:
    swift = swift.replace('import AVFoundation\n', 'import AVFoundation\nimport CoreVideo\n', 1)

collector = r'''
private final class HCVTemporalFrequencyNativeCollector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let targetFrameCount: Int
  private let rowBins: Int
  private let completion: ([String: Any]) -> Void
  private let lock = NSLock()
  private var frames: [[[Double]]] = []
  private var timestamps: [Double] = []
  private var frameLuma: [Double] = []
  private var finished = false

  init(
    targetFrameCount: Int,
    rowBins: Int,
    completion: @escaping ([String: Any]) -> Void
  ) {
    self.targetFrameCount = targetFrameCount
    self.rowBins = rowBins
    self.completion = completion
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    lock.lock()
    let shouldProcess = !finished && frames.count < targetFrameCount
    lock.unlock()
    guard shouldProcess,
          CMSampleBufferDataIsReady(sampleBuffer),
          let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let extracted = rowProfiles(from: pixelBuffer) else {
      return
    }

    let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    guard pts.isFinite else { return }

    var completedPayload: [String: Any]?
    lock.lock()
    if !finished {
      frames.append(extracted.profiles)
      timestamps.append(pts)
      frameLuma.append(extracted.meanLuma)
      if frames.count >= targetFrameCount {
        finished = true
        completedPayload = snapshotLocked()
      }
    }
    lock.unlock()

    if let completedPayload {
      completion(completedPayload)
    }
  }

  func snapshotAndFinish() -> [String: Any] {
    lock.lock()
    finished = true
    let snapshot = snapshotLocked()
    lock.unlock()
    return snapshot
  }

  private func snapshotLocked() -> [String: Any] {
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
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
          let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
      return nil
    }

    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    guard width >= 3, height >= 3, bytesPerRow >= width else { return nil }

    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    var result: [[Double]] = []
    result.reserveCapacity(9)
    var total = 0.0
    var totalCount = 0

    for gridRow in 0..<3 {
      for gridColumn in 0..<3 {
        let x0 = width * gridColumn / 3
        let x1 = width * (gridColumn + 1) / 3
        let y0 = height * gridRow / 3
        let y1 = height * (gridRow + 1) / 3
        let xStep = max(1, (x1 - x0) / 16)
        var profile: [Double] = []
        profile.reserveCapacity(rowBins)

        for bin in 0..<rowBins {
          let by0 = y0 + (y1 - y0) * bin / rowBins
          let next = y0 + (y1 - y0) * (bin + 1) / rowBins
          let by1 = min(y1, max(by0 + 1, next))
          var sum = 0.0
          var count = 0
          if by0 < y1 {
            for y in by0..<by1 {
              var x = x0
              while x < x1 {
                sum += Double(bytes[y * bytesPerRow + x]) / 255.0
                count += 1
                x += xStep
              }
            }
          }
          let value = count > 0 ? sum / Double(count) : 0.0
          profile.append(value)
          total += value
          totalCount += 1
        }
        result.append(profile)
      }
    }

    return (result, totalCount > 0 ? total / Double(totalCount) : 0.0)
  }
}

'''
swift = replace_once(swift, '@main\n', collector + '@main\n', 'native collector insertion')

property_marker = '''  private var cameraProbeChannel: FlutterMethodChannel?\n'''
property_block = '''  private var cameraProbeChannel: FlutterMethodChannel?\n  private let temporalFrequencyNativeQueue = DispatchQueue(\n    label: "hcv.temporalFrequency.native",\n    qos: .userInitiated\n  )\n  private let temporalFrequencySampleQueue = DispatchQueue(\n    label: "hcv.temporalFrequency.samples",\n    qos: .userInteractive\n  )\n  private let temporalFrequencyFinishLock = NSLock()\n  private var temporalFrequencyNativeBusy = false\n  private var temporalFrequencyResultDelivered = false\n  private var temporalFrequencyNativeSession: AVCaptureSession?\n  private var temporalFrequencyNativeCollector: HCVTemporalFrequencyNativeCollector?\n'''
swift = replace_once(swift, property_marker, property_block, 'native probe properties')

helper_marker = '''  private func handleCameraProbeCall(\n'''
native_helpers = r'''  private func temporalFrequencyFormat(
    for device: AVCaptureDevice,
    requestedMaxFps: Double
  ) -> (format: AVCaptureDevice.Format, fps: Double)? {
    let tiers = [240.0, 120.0, 60.0].filter { $0 <= requestedMaxFps + 0.01 }
    for tier in tiers {
      var bestFormat: AVCaptureDevice.Format?
      var bestArea: Int64 = 0
      for format in device.formats {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        if dimensions.width < 640 || dimensions.height < 480 { continue }
        let supportsTier = format.videoSupportedFrameRateRanges.contains { range in
          range.minFrameRate <= tier + 0.01 && range.maxFrameRate >= tier - 0.01
        }
        if !supportsTier { continue }
        let area = Int64(dimensions.width) * Int64(dimensions.height)
        // High-speed formats are typically 720p/1080p. Prefer the largest
        // native frame that still supports the exact requested tier.
        if bestFormat == nil || area > bestArea {
          bestFormat = format
          bestArea = area
        }
      }
      if let bestFormat {
        return (bestFormat, tier)
      }
    }
    return nil
  }

  private func finishTemporalFrequencyNativeCapture(
    session: AVCaptureSession,
    output: AVCaptureVideoDataOutput,
    payload: [String: Any],
    result: @escaping FlutterResult
  ) {
    temporalFrequencyFinishLock.lock()
    if temporalFrequencyResultDelivered {
      temporalFrequencyFinishLock.unlock()
      return
    }
    temporalFrequencyResultDelivered = true
    temporalFrequencyFinishLock.unlock()

    temporalFrequencyNativeQueue.async { [weak self] in
      output.setSampleBufferDelegate(nil, queue: nil)
      if session.isRunning {
        session.stopRunning()
      }
      self?.temporalFrequencyNativeCollector = nil
      self?.temporalFrequencyNativeSession = nil
      self?.temporalFrequencyNativeBusy = false
      DispatchQueue.main.async {
        result(payload)
      }
    }
  }

  private func captureTemporalFrequencyNative(
    device: AVCaptureDevice,
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    if temporalFrequencyNativeBusy {
      result(FlutterError(
        code: "TEMPORAL_FREQUENCY_NATIVE_BUSY",
        message: "A native temporal-frequency capture is already running",
        details: nil
      ))
      return
    }

    let args = call.arguments as? [String: Any]
    let requestedMaxFps = max(
      60.0,
      min(240.0, args?["targetMaxFps"] as? Double ?? 240.0)
    )
    let requestedDuration = max(
      0.20,
      min(0.75, args?["targetDurationSeconds"] as? Double ?? 0.35)
    )
    let requestedExposure = max(
      0.0001,
      min(0.004, args?["targetExposureSeconds"] as? Double ?? 0.001)
    )
    let rowBins = max(24, min(128, args?["rowProfileBins"] as? Int ?? 96))

    temporalFrequencyNativeBusy = true
    temporalFrequencyFinishLock.lock()
    temporalFrequencyResultDelivered = false
    temporalFrequencyFinishLock.unlock()

    temporalFrequencyNativeQueue.async { [weak self] in
      guard let self else { return }
      do {
        guard let selection = self.temporalFrequencyFormat(
          for: device,
          requestedMaxFps: requestedMaxFps
        ) else {
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No 60/120/240 fps native format available"]
          )
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .inputPriority
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
          session.commitConfiguration()
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Native camera input unavailable"]
          )
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = false
        output.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String:
            Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        guard session.canAddOutput(output) else {
          session.commitConfiguration()
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Native video data output unavailable"]
          )
        }
        session.addOutput(output)

        try device.lockForConfiguration()
        device.activeFormat = selection.format
        let frameDuration = CMTimeMakeWithSeconds(
          1.0 / selection.fps,
          preferredTimescale: 1_000_000_000
        )
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
        if device.isExposureModeSupported(.continuousAutoExposure) {
          device.exposureMode = .continuousAutoExposure
        }
        if device.isFocusModeSupported(.continuousAutoFocus) {
          device.focusMode = .continuousAutoFocus
        }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
          device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        device.unlockForConfiguration()
        session.commitConfiguration()

        self.temporalFrequencyNativeSession = session
        session.startRunning()
        guard session.isRunning else {
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Native high-speed session failed to start"]
          )
        }

        // Let AE settle in the selected high-speed format before locking the
        // optics and applying the requested short shutter.
        Thread.sleep(forTimeInterval: 0.18)
        let baselineDuration = max(
          CMTimeGetSeconds(device.exposureDuration),
          CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        )
        let baselineISO = max(device.iso, device.activeFormat.minISO)
        let minExposure = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        let maxExposure = min(
          CMTimeGetSeconds(device.activeFormat.maxExposureDuration),
          0.9 / selection.fps
        )
        let targetExposure = min(
          maxExposure,
          max(minExposure, requestedExposure)
        )
        let compensation = baselineDuration / max(targetExposure, 0.000001)
        let compensatedISO = min(
          device.activeFormat.maxISO,
          max(device.activeFormat.minISO, baselineISO * Float(compensation))
        )
        let targetDuration = CMTimeMakeWithSeconds(
          targetExposure,
          preferredTimescale: 1_000_000_000
        )

        let exposureSemaphore = DispatchSemaphore(value: 0)
        try device.lockForConfiguration()
        if device.isFocusModeSupported(.locked) {
          device.setFocusModeLocked(
            lensPosition: device.lensPosition,
            completionHandler: nil
          )
        }
        if device.isWhiteBalanceModeSupported(.locked) {
          let gains = self.clampedWhiteBalanceGains(
            device.deviceWhiteBalanceGains,
            for: device
          )
          device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        }
        guard device.isExposureModeSupported(.custom) else {
          device.unlockForConfiguration()
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Custom exposure unavailable"]
          )
        }
        device.setExposureModeCustom(
          duration: targetDuration,
          iso: compensatedISO
        ) { _ in
          exposureSemaphore.signal()
        }
        device.unlockForConfiguration()
        _ = exposureSemaphore.wait(timeout: .now() + 0.8)
        Thread.sleep(forTimeInterval: 0.03)

        let actualExposure = CMTimeGetSeconds(device.exposureDuration)
        let actualISO = Double(device.iso)
        let exposureTolerance = max(0.00015, targetExposure * 0.20)
        let exposureVerified = actualExposure.isFinite &&
          abs(actualExposure - targetExposure) <= exposureTolerance
        let dimensions = CMVideoFormatDescriptionGetDimensions(
          selection.format.formatDescription
        )
        let formatMaxFps = selection.format.videoSupportedFrameRateRanges
          .map { $0.maxFrameRate }
          .max() ?? selection.fps
        let targetFrameCount = max(
          24,
          min(120, Int((requestedDuration * selection.fps).rounded()))
        )

        let metadata: [String: Any] = [
          "analysisStatus": "CAPTURED",
          "captureMode": "ISOLATED_NATIVE_AVCAPTURESESSION_CMSAMPLEBUFFER",
          "requestedTargetFps": requestedMaxFps,
          "configuredFrameRate": selection.fps,
          "frameRateTier": Int(selection.fps.rounded()),
          "frameWidth": Int(dimensions.width),
          "frameHeight": Int(dimensions.height),
          "configuredFormatMaxSupportedFrameRate": formatMaxFps,
          "requestedShortExposureSeconds": requestedExposure,
          "targetShortExposureSecondsAfterClamp": targetExposure,
          "actualShortExposureSeconds": actualExposure,
          "shortExposureVerified": exposureVerified,
          "shortExposureISO": actualISO,
          "shortExposureISOClamped": compensatedISO >= device.activeFormat.maxISO - 0.5,
          "exposureLockedForEntireNativeCapture": true,
          "targetFrameCount": targetFrameCount,
          "rowProfileBins": rowBins,
          "sensorNativeOrientation": true,
          "encodedVideoUsed": false,
        ]

        let collector = HCVTemporalFrequencyNativeCollector(
          targetFrameCount: targetFrameCount,
          rowBins: rowBins
        ) { [weak self] snapshot in
          guard let self else { return }
          var payload = metadata
          for (key, value) in snapshot {
            payload[key] = value
          }
          let timestamps = snapshot["frameTimestampsSeconds"] as? [Double] ?? []
          if timestamps.count >= 2,
             let first = timestamps.first,
             let last = timestamps.last,
             last > first {
            payload["actualFrameRate"] = Double(timestamps.count - 1) / (last - first)
            payload["captureDurationMs"] = Int(((last - first) * 1000.0).rounded())
          }
          self.finishTemporalFrequencyNativeCapture(
            session: session,
            output: output,
            payload: payload,
            result: result
          )
        }
        self.temporalFrequencyNativeCollector = collector
        output.setSampleBufferDelegate(
          collector,
          queue: self.temporalFrequencySampleQueue
        )

        // Timeout protects against a device/format that advertises a tier but
        // does not deliver the requested number of sample buffers in practice.
        self.temporalFrequencyNativeQueue.asyncAfter(
          deadline: .now() + requestedDuration + 0.75
        ) { [weak self, weak collector] in
          guard let self, let collector else { return }
          let snapshot = collector.snapshotAndFinish()
          var payload = metadata
          for (key, value) in snapshot {
            payload[key] = value
          }
          let count = snapshot["frameCount"] as? Int ?? 0
          if count < 6 {
            payload["analysisStatus"] = "NOT_ANALYZED"
            payload["reason"] = "NATIVE_SAMPLEBUFFER_TIMEOUT"
          }
          let timestamps = snapshot["frameTimestampsSeconds"] as? [Double] ?? []
          if timestamps.count >= 2,
             let first = timestamps.first,
             let last = timestamps.last,
             last > first {
            payload["actualFrameRate"] = Double(timestamps.count - 1) / (last - first)
            payload["captureDurationMs"] = Int(((last - first) * 1000.0).rounded())
          }
          self.finishTemporalFrequencyNativeCapture(
            session: session,
            output: output,
            payload: payload,
            result: result
          )
        }
      } catch {
        if let runningSession = self.temporalFrequencyNativeSession,
           runningSession.isRunning {
          runningSession.stopRunning()
        }
        self.temporalFrequencyNativeCollector = nil
        self.temporalFrequencyNativeSession = nil
        self.temporalFrequencyNativeBusy = false
        DispatchQueue.main.async {
          result(FlutterError(
            code: "TEMPORAL_FREQUENCY_NATIVE_CAPTURE_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

'''
swift = replace_once(swift, helper_marker, native_helpers + helper_marker, 'native capture helper insertion')

switch_marker = '''    switch call.method {\n    case "snapshotCameraState":\n'''
switch_replacement = '''    switch call.method {\n    case "captureTemporalFrequencyNative":\n      captureTemporalFrequencyNative(device: device, call: call, result: result)\n\n    case "snapshotCameraState":\n'''
swift = replace_once(swift, switch_marker, switch_replacement, 'native capture method case')
swift_path.write_text(swift)


# ---------------------------------------------------------------------------
# 4. Regression contract for the architecture, not classification thresholds.
# ---------------------------------------------------------------------------
test_path = Path('test/native_temporal_frequency_v2_contract_test.dart')
test_path.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  test('V2 probe is native, consecutive and permanently shadow-only', () {
    final source = File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
    expect(source, contains('captureTemporalFrequencyNative'));
    expect(source, contains('SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2'));
    expect(source, contains('ISOLATED_NATIVE_AVCAPTURESESSION_CMSAMPLEBUFFER'));
    expect(source, contains('SHADOW_ONLY_NEVER_DECISIONAL'));
    expect(source, contains("'encodedVideoUsed': false"));
    expect(source, contains("'ffmpegUsed': false"));
    expect(source, isNot(contains('startVideoRecording()')));
    expect(source, isNot(contains('FFmpegKit')));
  });

  test('camera releases Flutter controller before isolated native capture', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final helperStart = source.indexOf('_captureTemporalFrequencyNativeIsolated');
    expect(helperStart, greaterThanOrEqualTo(0));
    final helper = source.substring(helperStart, source.indexOf('Future<void> _settleCameraAfterLiveProbe', helperStart));
    expect(helper.indexOf('await active.dispose()'), greaterThanOrEqualTo(0));
    expect(helper.indexOf('captureNative('), greaterThan(helper.indexOf('await active.dispose()')));
    expect(helper, contains('CameraController('));
    expect(helper, contains('await replacement.initialize()'));
  });

  test('iOS native path requests real 240 120 60 tiers and CMSampleBuffers', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('[240.0, 120.0, 60.0]'));
    expect(swift, contains('AVCaptureVideoDataOutputSampleBufferDelegate'));
    expect(swift, contains('CMSampleBufferGetPresentationTimeStamp'));
    expect(swift, contains('device.activeVideoMinFrameDuration = frameDuration'));
    expect(swift, contains('device.activeVideoMaxFrameDuration = frameDuration'));
    expect(swift, contains('setExposureModeCustom'));
    expect(swift, contains('shortExposureVerified'));
  });

  test('unavailable V2 evidence cannot change production decision', () {
    final unavailable = HCVTemporalFrequencyProbe.unavailable('TEST');
    expect(unavailable['decisionRole'], 'SHADOW_ONLY_NEVER_DECISIONAL');
    expect(unavailable['productionDecisionChanged'], false);
  });
}
''')
