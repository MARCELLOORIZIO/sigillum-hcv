from pathlib import Path

path = Path('ios/Runner/AppDelegate.swift')
s = path.read_text()

start = s.index('  private func temporalFrequencyFormat(')
end = s.index('  private func finishTemporalFrequencyNativeCapture(', start)
new_format = '''  private func temporalFrequencyFormat(
    for device: AVCaptureDevice,
    requestedMaxFps: Double
  ) -> (format: AVCaptureDevice.Format, range: AVFrameRateRange, fps: Double)? {
    let tiers = [240.0, 120.0, 60.0].filter { $0 <= requestedMaxFps + 0.01 }
    for tier in tiers {
      var bestFormat: AVCaptureDevice.Format?
      var bestRange: AVFrameRateRange?
      var bestArea: Int64 = Int64.max
      let tolerance = max(0.5, tier * 0.01)

      for format in device.formats {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        if dimensions.width < 640 || dimensions.height < 480 { continue }

        for range in format.videoSupportedFrameRateRanges {
          // Use an endpoint duration supplied by AVFoundation itself. BUILD 90
          // constructed 1/fps as a new CMTime; iOS may reject that value with
          // NSInvalidArgumentException even when the numeric fps looks valid.
          if abs(range.maxFrameRate - tier) > tolerance { continue }
          let area = Int64(dimensions.width) * Int64(dimensions.height)
          if bestFormat == nil || area < bestArea {
            bestFormat = format
            bestRange = range
            bestArea = area
          }
        }
      }

      if let bestFormat, let bestRange {
        return (bestFormat, bestRange, bestRange.maxFrameRate)
      }
    }
    return nil
  }

'''
s = s[:start] + new_format + s[end:]

cap_start = s.index('  private func captureTemporalFrequencyNative(')
cap_end = s.index('  private func handleCameraProbeCall(', cap_start)
cap = s[cap_start:cap_end]

needle = '    temporalFrequencyNativeQueue.async { [weak self] in\n      guard let self else { return }\n      do {\n'
replacement = '    temporalFrequencyNativeQueue.async { [weak self] in\n      guard let self else { return }\n      let captureDevice = self.temporalFrequencyPhysicalDevice(for: device)\n      do {\n'
if needle not in cap:
    raise SystemExit('guard insertion point not found')
cap = cap.replace(needle, replacement, 1)

cap = cap.replace('for: device,\n          requestedMaxFps:', 'for: captureDevice,\n          requestedMaxFps:', 1)
cap = cap.replace('AVCaptureDeviceInput(device: device)', 'AVCaptureDeviceInput(device: captureDevice)', 1)
cap = cap.replace('        session.sessionPreset = .inputPriority\n', '', 1)

# From this point the native probe must configure/read the physical device, not
# the Flutter virtual dual/triple camera identifier.
cap = cap.replace('device.', 'captureDevice.')

old_duration = '''        let frameDuration = CMTimeMakeWithSeconds(
          1.0 / selection.fps,
          preferredTimescale: 1_000_000_000
        )
        captureDevice.activeVideoMinFrameDuration = frameDuration
        captureDevice.activeVideoMaxFrameDuration = frameDuration
'''
new_duration = '''        // Use the exact hardware-supported CMTime from AVFrameRateRange.
        // Assigning a reconstructed reciprocal can raise NSInvalidArgumentException.
        let frameDuration = selection.range.minFrameDuration
        captureDevice.activeVideoMinFrameDuration = frameDuration
        captureDevice.activeVideoMaxFrameDuration = frameDuration
'''
if old_duration not in cap:
    raise SystemExit('old frame-duration block not found')
cap = cap.replace(old_duration, new_duration, 1)

# Preserve both identifiers in the shadow certificate so on-device evidence
# proves whether a virtual Flutter device was mapped to a physical camera.
meta_needle = '          "captureMode": "ISOLATED_NATIVE_AVCAPTURESESSION_CMSAMPLEBUFFER",\n'
meta_repl = meta_needle + '          "requestedDeviceUniqueId": device.uniqueID,\n          "physicalCaptureDeviceUniqueId": captureDevice.uniqueID,\n          "physicalDeviceSubstitutionUsed": captureDevice.uniqueID != device.uniqueID,\n'
if meta_needle not in cap:
    raise SystemExit('metadata insertion point not found')
cap = cap.replace(meta_needle, meta_repl, 1)

s = s[:cap_start] + cap + s[cap_end:]
path.write_text(s)
