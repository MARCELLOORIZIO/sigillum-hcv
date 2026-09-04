import 'dart:math';

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
            intervals.map((value) => (value - medianInterval).abs()).toList()
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
    final framePeriod =
        configuredFps != null && configuredFps > 0 ? 1.0 / configuredFps : null;

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
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2.0;
  }
}

class HCVTemporalFrequencyMath {
  const HCVTemporalFrequencyMath._();

  static Map<String, dynamic> analyzeRowProfileSequence(
    List<List<double>> frames,
  ) {
    if (frames.length < 3 || frames.any((profile) => profile.length < 16)) {
      return const {
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'ROW_PROFILE_SEQUENCE_TOO_SHORT',
      };
    }

    final spectra = <Map<String, double>>[];
    final differenceRms = <double>[];
    for (var i = 1; i < frames.length; i++) {
      final n = min(frames[i - 1].length, frames[i].length);
      final difference = List<double>.generate(
        n,
        (j) => frames[i][j] - frames[i - 1][j],
      );
      final mean = _mean(difference);
      for (var j = 0; j < difference.length; j++) {
        difference[j] -= mean;
      }
      final rms = sqrt(
        difference.fold<double>(0.0, (sum, x) => sum + x * x) /
            difference.length,
      );
      differenceRms.add(rms);
      spectra.add(_dominantSpatialSpectrum(difference));
    }

    final weightedBins = <int, double>{};
    for (var i = 0; i < spectra.length; i++) {
      final bin = spectra[i]['bin']?.round() ?? 0;
      if (bin <= 0) continue;
      final weight =
          (spectra[i]['concentration'] ?? 0.0) * (differenceRms[i] + 1e-9);
      weightedBins[bin] = (weightedBins[bin] ?? 0.0) + weight;
    }
    var modalBin = 0;
    var modalWeight = -1.0;
    for (final entry in weightedBins.entries) {
      if (entry.value > modalWeight) {
        modalWeight = entry.value;
        modalBin = entry.key;
      }
    }

    final matching = <int>[];
    for (var i = 0; i < spectra.length; i++) {
      final bin = spectra[i]['bin']?.round() ?? 0;
      if (modalBin > 0 && (bin - modalBin).abs() <= 1) matching.add(i);
    }
    final frequencyStability =
        spectra.isEmpty ? 0.0 : matching.length / spectra.length;

    final phases = matching
        .map((index) => spectra[index]['phase'] ?? 0.0)
        .toList(growable: false);
    final phaseStepConsistency = _phaseStepConsistency(phases);
    final concentrations =
        spectra.map((s) => s['concentration'] ?? 0.0).toList()..sort();
    differenceRms.sort();
    final medianConcentration = _median(concentrations) ?? 0.0;
    final medianDifferenceRms = _median(differenceRms) ?? 0.0;
    final periodicityStrength =
        medianConcentration * frequencyStability * phaseStepConsistency;

    return {
      'analysisStatus': 'ANALYZED',
      'framePairCount': spectra.length,
      'dominantRowFrequencyBin': modalBin,
      'approximateDominantPeriodRows':
          modalBin <= 0 ? null : frames.first.length / modalBin,
      'dominantFrequencyStability': frequencyStability,
      'medianSpatialSpectralConcentration': medianConcentration,
      'phaseStepConsistency': phaseStepConsistency,
      'medianTemporalDifferenceRms': medianDifferenceRms,
      'periodicityStrength': periodicityStrength,
    };
  }

  static Map<String, dynamic> analyzeScalarSequence(List<double> values) {
    if (values.length < 6) {
      return const {
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'SCALAR_SEQUENCE_TOO_SHORT',
      };
    }
    final mean = _mean(values);
    final sorted = List<double>.from(values)..sort();
    final p10 = sorted[((sorted.length - 1) * 0.10).round()];
    final p90 = sorted[((sorted.length - 1) * 0.90).round()];
    final modulationDepth =
        mean.abs() < 1e-9 ? 0.0 : (p90 - p10).abs() / mean.abs();
    final centered = values.map((v) => v - mean).toList();
    final spectrum = _dominantTemporalSpectrum(centered);
    return {
      'analysisStatus': 'ANALYZED',
      'meanLuma': mean,
      'robustFrameLumaModulationDepth': modulationDepth,
      'dominantTemporalFrequencyBin': spectrum['bin']?.round(),
      'temporalSpectralConcentration': spectrum['concentration'],
      'dominantTemporalPhase': spectrum['phase'],
    };
  }

  static Map<String, double> _dominantSpatialSpectrum(List<double> values) {
    final n = values.length;
    if (n < 16) return const {'bin': 0, 'concentration': 0, 'phase': 0};
    final maxBin = min(32, n ~/ 3);
    return _dominantSpectrum(values, minBin: 2, maxBin: maxBin);
  }

  static Map<String, double> _dominantTemporalSpectrum(List<double> values) {
    final n = values.length;
    if (n < 6) return const {'bin': 0, 'concentration': 0, 'phase': 0};
    return _dominantSpectrum(values, minBin: 1, maxBin: max(1, n ~/ 2));
  }

  static Map<String, double> _dominantSpectrum(
    List<double> values, {
    required int minBin,
    required int maxBin,
  }) {
    final n = values.length;
    var totalPower = 0.0;
    var bestPower = -1.0;
    var bestBin = 0;
    var bestPhase = 0.0;
    for (var k = minBin; k <= maxBin; k++) {
      var re = 0.0;
      var im = 0.0;
      for (var j = 0; j < n; j++) {
        final angle = 2 * pi * k * j / n;
        re += values[j] * cos(angle);
        im -= values[j] * sin(angle);
      }
      final power = re * re + im * im;
      totalPower += power;
      if (power > bestPower) {
        bestPower = power;
        bestBin = k;
        bestPhase = atan2(im, re);
      }
    }
    return {
      'bin': bestBin.toDouble(),
      'concentration': totalPower <= 1e-18 ? 0.0 : bestPower / totalPower,
      'phase': bestPhase,
    };
  }

  static double _phaseStepConsistency(List<double> phases) {
    if (phases.length < 3) return 0.0;
    var sumCos = 0.0;
    var sumSin = 0.0;
    var count = 0;
    for (var i = 1; i < phases.length; i++) {
      final delta = _wrapAngle(phases[i] - phases[i - 1]);
      sumCos += cos(delta);
      sumSin += sin(delta);
      count++;
    }
    if (count == 0) return 0.0;
    return sqrt(sumCos * sumCos + sumSin * sumSin) / count;
  }

  static double _wrapAngle(double value) {
    var x = value;
    while (x > pi) x -= 2 * pi;
    while (x < -pi) x += 2 * pi;
    return x;
  }

  static double _mean(List<double> values) =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

  static double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2;
  }
}
