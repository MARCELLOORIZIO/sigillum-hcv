import 'dart:math';

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
      return {
        ...unavailable(
            (raw['reason'] as String?) ?? 'ILLUMINATION_CAPTURE_NOT_AVAILABLE'),
        'nativeCaptureMetadata': _withoutFrames(raw)
      };
    }
    final rawPhases = raw['phaseFrames'];
    if (rawPhases is! List || rawPhases.length != 3)
      return unavailable('ILLUMINATION_PHASES_INVALID');
    final phases = <List<List<double>>>[];
    for (final rawPhase in rawPhases) {
      if (rawPhase is! List || rawPhase.length < 3)
        return unavailable('ILLUMINATION_PHASE_TOO_SHORT');
      final frames = <List<double>>[];
      for (final rawFrame in rawPhase) {
        if (rawFrame is! List || rawFrame.length != 9) continue;
        final frame = rawFrame
            .whereType<num>()
            .map((e) => e.toDouble())
            .toList(growable: false);
        if (frame.length == 9) frames.add(frame);
      }
      if (frames.length < 3)
        return unavailable('ILLUMINATION_VALID_FRAMES_TOO_SHORT');
      phases.add(frames);
    }

    final cellResults = <Map<String, dynamic>>[];
    final relative = <double>[];
    final reversibility = <double>[];
    for (var cell = 0; cell < 9; cell++) {
      final off1 =
          _median(phases[0].map((f) => f[cell]).toList()..sort()) ?? 0.0;
      final on = _median(phases[1].map((f) => f[cell]).toList()..sort()) ?? 0.0;
      final off2 =
          _median(phases[2].map((f) => f[cell]).toList()..sort()) ?? 0.0;
      final baseline = (off1 + off2) / 2.0;
      final delta = on - baseline;
      final rel = delta / max(baseline.abs(), 0.03);
      final rev = (1.0 - (off2 - off1).abs() / max(delta.abs(), 0.03))
          .clamp(0.0, 1.0)
          .toDouble();
      relative.add(rel);
      reversibility.add(rev);
      cellResults.add({
        'row': cell ~/ 3,
        'column': cell % 3,
        'off1Luma': off1,
        'torchOnLuma': on,
        'off2Luma': off2,
        'relativeTorchResponse': rel,
        'reversibility': rev
      });
    }
    final sortedRelative = List<double>.from(relative)..sort();
    final sortedReversibility = List<double>.from(reversibility)..sort();
    final count20 = relative.where((v) => v >= 0.20).length;
    final count35 = relative.where((v) => v >= 0.35).length;
    final medianResponse = _median(sortedRelative) ?? 0.0;
    final medianRev = _median(sortedReversibility) ?? 0.0;
    final reflectiveCandidate =
        medianResponse >= 0.35 && count20 >= 6 && medianRev >= 0.55;

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
      'maximumCellRelativeTorchResponse':
          sortedRelative.isEmpty ? null : sortedRelative.last,
      'medianCellReversibility': medianRev,
      'reflectiveCellsAt20Percent': count20,
      'reflectiveCellsAt35Percent': count35,
      'strongReflectiveResponseCandidate': reflectiveCandidate,
      'cellResults': cellResults,
      'nativeCaptureMetadata': _withoutFrames(raw),
      'note':
          'A strong reversible OFF→ON→OFF response is evidence of externally illuminated/reflected scene content. Weak response is inconclusive and never proves DISPLAY.',
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
