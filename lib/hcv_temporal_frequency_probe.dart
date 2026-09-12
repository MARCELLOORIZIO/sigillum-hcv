import 'dart:math';

import 'package:flutter/services.dart';

/// Native HFR V3.1 physical display probe.
///
/// BUILD107 preserves the validated V3 full-frame display decision and adds a
/// same-session short-exposure sweep, higher-resolution row-by-time diagnostics,
/// and 2-D spatial lattice/moire diagnostics. New V3.1 physics is diagnostic
/// until physically validated. Absence of temporal display evidence is never
/// treated as positive proof of physical reality.
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
      final rolling = HCVTemporalFrequencyMath.analyzeRowProfileSequence(
        cellSequences[cell],
      );
      final rowTime = HCVTemporalFrequencyMath.analyzeRowTimeMatrix(
        cellSequences[cell],
      );
      cellResults.add({
        'row': cell ~/ 3,
        'column': cell % 3,
        ...rolling,
        ...rowTime,
      });
    }

    final timestamps =
        (raw['frameTimestampsSeconds'] as List?)
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

    final periodicityStrengths =
        cellResults
            .map((e) => (e['periodicityStrength'] as num?)?.toDouble())
            .whereType<double>()
            .toList()
          ..sort();
    final frequencyStabilities =
        cellResults
            .map((e) => (e['dominantFrequencyStability'] as num?)?.toDouble())
            .whereType<double>()
            .toList()
          ..sort();
    final phaseConsistencies =
        cellResults
            .map((e) => (e['phaseStepConsistency'] as num?)?.toDouble())
            .whereType<double>()
            .toList()
          ..sort();
    final rowTimeCoherences =
        cellResults
            .map((e) => (e['rowTimeCoherenceScore'] as num?)?.toDouble())
            .whereType<double>()
            .toList()
          ..sort();

    final configuredFps = (raw['configuredFrameRate'] as num?)?.toDouble();
    final actualExposure = (raw['actualShortExposureSeconds'] as num?)
        ?.toDouble();
    final framePeriod = configuredFps != null && configuredFps > 0
        ? 1.0 / configuredFps
        : null;

    final globalTemporalSpectrum =
        HCVTemporalFrequencyMath.analyzeScalarSequence(frameLuma);
    final dominantTemporalBin =
        (globalTemporalSpectrum['dominantTemporalFrequencyBin'] as num?)
            ?.toInt() ??
        0;
    final dominantTemporalFrequencyHz =
        actualFps != null &&
            actualFps > 0 &&
            dominantTemporalBin > 0 &&
            acceptedFrames > 0
        ? dominantTemporalBin * actualFps / acceptedFrames
        : null;
    final globalModulationDepth =
        (globalTemporalSpectrum['robustFrameLumaModulationDepth'] as num?)
            ?.toDouble() ??
        0.0;
    final globalSpectralConcentration =
        (globalTemporalSpectrum['temporalSpectralConcentration'] as num?)
            ?.toDouble() ??
        0.0;
    final medianCellPeriodicity = _median(periodicityStrengths) ?? 0.0;
    final medianCellStability = _median(frequencyStabilities) ?? 0.0;
    final medianCellPhase = _median(phaseConsistencies) ?? 0.0;
    final periodicCellCount = cellResults.where((entry) {
      return ((entry['periodicityStrength'] as num?)?.toDouble() ?? 0.0) >=
          0.10;
    }).length;
    final stableCellCount = cellResults.where((entry) {
      return ((entry['dominantFrequencyStability'] as num?)?.toDouble() ??
              0.0) >=
          0.80;
    }).length;
    final displayLikeCellCount = cellResults.where(_isV3DisplayLikeCell).length;
    final realityLikeCellCount = cellResults.where(_isV3RealityLikeCell).length;
    final indeterminateCellCount = 9 - displayLikeCellCount - realityLikeCellCount;
    final spatialBins = cellResults
        .map((entry) => (entry['dominantRowFrequencyBin'] as num?)?.toInt() ?? 0)
        .toList(growable: false);
    final rowTimeBins = cellResults
        .map((entry) =>
            (entry['rowTimeDominantTemporalFrequencyBin'] as num?)?.toInt() ?? 0)
        .toList(growable: false);
    final spatialFamilyCellCount = _compatibleModalBinCount(spatialBins);
    final rowTimeFamilyCellCount = _compatibleModalBinCount(rowTimeBins);
    final medianRowTimeCoherence = _median(rowTimeCoherences) ?? 0.0;

    final legacyHfrCandidate = qualifiesCoherentDisplayPeriodicity(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      globalModulationDepth: globalModulationDepth,
      globalSpectralConcentration: globalSpectralConcentration,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      medianCellPhaseStepConsistency: medianCellPhase,
      periodicCellCount: periodicCellCount,
      stableCellCount: stableCellCount,
    );
    // BUILD106: the global physical display proof keeps every strict median,
    // spectral, phase, exposure and periodic-cell gate from V2. The old
    // stableCellCount >= 6 veto is not reused once V3 can prove that all nine
    // cells belong to the same spatial + row-time frequency family. This is a
    // family-coherence correction, not a generic threshold reduction.
    final displayFamilyGlobalHfrCandidate =
        qualifiesDisplayFamilyGlobalHfrV3(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      globalModulationDepth: globalModulationDepth,
      globalSpectralConcentration: globalSpectralConcentration,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      medianCellPhaseStepConsistency: medianCellPhase,
      periodicCellCount: periodicCellCount,
    );
    final allNineCellsSameDisplayFamily =
        displayFamilyGlobalHfrCandidate &&
        spatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20;
    final fullFrameDisplayV3 = qualifiesFullFrameDisplayV3(
      legacyHfrCandidate: displayFamilyGlobalHfrCandidate,
      spatialFamilyCellCount: spatialFamilyCellCount,
      rowTimeFamilyCellCount: rowTimeFamilyCellCount,
      medianRowTimeCoherence: medianRowTimeCoherence,
    );
    final mixedSceneDetected =
        displayLikeCellCount > 0 && !fullFrameDisplayV3;
    final noTemporalDisplaySignatureV31 =
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

    return {
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V31_ADVANCED_PHYSICS_DIAGNOSTIC_ONLY',
      'productionDecisionChanged': fullFrameDisplayV3 || mixedSceneDetected,
      'coherentDisplayPeriodicity': coherentDisplayPeriodicity,
      'coherentDisplayPeriodicityEvidence': {
        'dominantTemporalFrequencyHz': dominantTemporalFrequencyHz,
        'globalModulationDepth': globalModulationDepth,
        'globalSpectralConcentration': globalSpectralConcentration,
        'medianCellPeriodicityStrength': medianCellPeriodicity,
        'medianCellFrequencyStability': medianCellStability,
        'medianCellPhaseStepConsistency': medianCellPhase,
        'medianRowTimeCoherence': medianRowTimeCoherence,
        'periodicCellCount': periodicCellCount,
        'stableCellCount': stableCellCount,
        'displayLikeCellCount': displayLikeCellCount,
        'realityLikeCellCount': realityLikeCellCount,
        'indeterminateCellCount': indeterminateCellCount,
        'requiredDisplayLikeCells': 9,
        'requiredSpatialFamilyCells': 9,
        'requiredRowTimeFamilyCells': 9,
        'legacyV2HfrCandidate': legacyHfrCandidate,
        'displayFamilyGlobalHfrCandidateV3': displayFamilyGlobalHfrCandidate,
        'localDisplayLikeCellCountDecisionGate': false,
      },
      'displayRealityEvidenceV3': {
        'fullFrameDisplay': fullFrameDisplayV3,
        'fullFrameReality': fullFrameRealityV3,
        'positivePhysicalRealityEvidence': false,
        'noTemporalDisplaySignature': noTemporalDisplaySignatureV31,
        'noTemporalDisplaySignatureIsRealityEvidence': false,
        'mixedSceneDetected': mixedSceneDetected,
        'allNineCellsSameDisplayFamily': allNineCellsSameDisplayFamily,
        'displayLikeCellCount': displayLikeCellCount,
        'realityLikeCellCount': realityLikeCellCount,
        'indeterminateCellCount': indeterminateCellCount,
        'spatialFamilyCellCount': spatialFamilyCellCount,
        'rowTimeFamilyCellCount': rowTimeFamilyCellCount,
        'medianRowTimeCoherence': medianRowTimeCoherence,
        'classificationPolicy':
            'BUILD107_VALIDATED_V3_DISPLAY_UNCHANGED;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE;V31_ADVANCED_DISPLAY_PHYSICS_DIAGNOSTIC_ONLY',
      },
      'advancedDisplayPhysicsV31': advancedPhysicsV31,
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
      'globalFrameLumaTemporalSpectrum': globalTemporalSpectrum,
      'globalDominantTemporalFrequencyHz': dominantTemporalFrequencyHz,
      'cellResults': cellResults,
      'minimumCellPeriodicityStrength': periodicityStrengths.isEmpty
          ? null
          : periodicityStrengths.first,
      'medianCellPeriodicityStrength': _median(periodicityStrengths),
      'minimumCellFrequencyStability': frequencyStabilities.isEmpty
          ? null
          : frequencyStabilities.first,
      'medianCellFrequencyStability': _median(frequencyStabilities),
      'minimumCellPhaseStepConsistency': phaseConsistencies.isEmpty
          ? null
          : phaseConsistencies.first,
      'medianCellPhaseStepConsistency': _median(phaseConsistencies),
      'spatialPolicy': const {
        'gridRows': 3,
        'gridColumns': 3,
        'decisionEnabled': true,
        'requiredSameDisplayFamilyCells': 9,
        'partialDisplayCoverageMeansMixedReality': true,
        'decisionGate': 'HFR_V3_FULL_FRAME_DISPLAY_VS_MIXED_REAL_SCENE',
      },
      'nativeCaptureMetadata': _withoutRawFrames(raw),
      'note': 'V3.1 BUILD107 preserves validated V3 full-frame display/mixed-scene decisions and adds same-session exposure sweep, 128-bin row-time diagnostics, and 2-D microtexture lattice diagnostics. New advanced physics is diagnostic-only pending iPhone validation. A quiet temporal signature is explicitly not positive reality evidence.',
    };
  }

  static bool qualifiesCoherentDisplayPeriodicity({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required double? dominantTemporalFrequencyHz,
    required double globalModulationDepth,
    required double globalSpectralConcentration,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int periodicCellCount,
    required int stableCellCount,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    if (dominantTemporalFrequencyHz == null ||
        dominantTemporalFrequencyHz < 40.0 ||
        dominantTemporalFrequencyHz > 120.0 ||
        dominantTemporalFrequencyHz > actualFps / 2.0 + 1.0) {
      return false;
    }
    return globalModulationDepth >= 0.75 &&
        globalSpectralConcentration >= 0.85 &&
        medianCellPeriodicityStrength >= 0.12 &&
        medianCellFrequencyStability >= 0.85 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6 &&
        stableCellCount >= 6;
  }

  static bool qualifiesDisplayFamilyGlobalHfrV3({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required double? dominantTemporalFrequencyHz,
    required double globalModulationDepth,
    required double globalSpectralConcentration,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int periodicCellCount,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    if (dominantTemporalFrequencyHz == null ||
        dominantTemporalFrequencyHz < 40.0 ||
        dominantTemporalFrequencyHz > 120.0 ||
        dominantTemporalFrequencyHz > actualFps / 2.0 + 1.0) {
      return false;
    }
    return globalModulationDepth >= 0.75 &&
        globalSpectralConcentration >= 0.85 &&
        medianCellPeriodicityStrength >= 0.12 &&
        medianCellFrequencyStability >= 0.85 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6;
  }

  static bool qualifiesFullFrameDisplayV3({
    required bool legacyHfrCandidate,
    required int spatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
  }) {
    return legacyHfrCandidate &&
        spatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20;
  }

  static bool qualifiesNoTemporalDisplaySignatureV31({
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

  static bool _isV3DisplayLikeCell(Map<String, dynamic> entry) {
    final periodicity =
        (entry['periodicityStrength'] as num?)?.toDouble() ?? 0.0;
    final stability =
        (entry['dominantFrequencyStability'] as num?)?.toDouble() ?? 0.0;
    final phase =
        (entry['phaseStepConsistency'] as num?)?.toDouble() ?? 0.0;
    final rowTime =
        (entry['rowTimeCoherenceScore'] as num?)?.toDouble() ?? 0.0;
    return periodicity >= 0.10 &&
        stability >= 0.80 &&
        phase >= 0.35 &&
        rowTime >= 0.20;
  }

  static bool _isV3RealityLikeCell(Map<String, dynamic> entry) {
    final periodicity =
        (entry['periodicityStrength'] as num?)?.toDouble() ?? 1.0;
    final stability =
        (entry['dominantFrequencyStability'] as num?)?.toDouble() ?? 1.0;
    final rowTime =
        (entry['rowTimeCoherenceScore'] as num?)?.toDouble() ?? 1.0;
    return periodicity < 0.02 && stability < 0.45 && rowTime < 0.15;
  }

  static int _compatibleModalBinCount(List<int> bins) {
    final positive = bins.where((bin) => bin > 0).toList(growable: false);
    if (positive.isEmpty) return 0;
    var best = 0;
    for (final candidate in positive) {
      final count = positive.where((bin) => (bin - candidate).abs() <= 1).length;
      if (count > best) best = count;
    }
    return best;
  }


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

  static Map<String, dynamic> unavailable(String reason, {Object? error}) {
    return {
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole':
          'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V31_ADVANCED_PHYSICS_DIAGNOSTIC_ONLY',
      'productionDecisionChanged': false,
      'coherentDisplayPeriodicity': false,
      'reason': reason,
      if (error != null) 'error': error.toString(),
    };
  }

  Map<String, dynamic> _withoutRawFrames(Map<String, dynamic> raw) {
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
    final frequencyStability = spectra.isEmpty
        ? 0.0
        : matching.length / spectra.length;

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
      'approximateDominantPeriodRows': modalBin <= 0
          ? null
          : frames.first.length / modalBin,
      'dominantFrequencyStability': frequencyStability,
      'medianSpatialSpectralConcentration': medianConcentration,
      'phaseStepConsistency': phaseStepConsistency,
      'medianTemporalDifferenceRms': medianDifferenceRms,
      'periodicityStrength': periodicityStrength,
      'rollingShutterBandCoherence':
          medianConcentration * frequencyStability,
      'rollingShutterPhaseDriftConsistency': phaseStepConsistency,
    };
  }

  static Map<String, dynamic> analyzeRowTimeMatrix(
    List<List<double>> frames,
  ) {
    if (frames.length < 6 || frames.any((profile) => profile.length < 16)) {
      return const {
        'rowTimeAnalysisStatus': 'NOT_ANALYZED',
        'rowTimeReason': 'ROW_TIME_MATRIX_TOO_SHORT',
      };
    }
    final bins = frames.map((profile) => profile.length).reduce(min);
    final spectra = <Map<String, double>>[];
    for (var row = 0; row < bins; row++) {
      final sequence = frames.map((frame) => frame[row]).toList(growable: false);
      final mean = _mean(sequence);
      final centered = sequence.map((value) => value - mean).toList(growable: false);
      spectra.add(_dominantTemporalSpectrum(centered));
    }

    final weightedBins = <int, double>{};
    for (final spectrum in spectra) {
      final bin = spectrum['bin']?.round() ?? 0;
      if (bin <= 0) continue;
      final weight = spectrum['concentration'] ?? 0.0;
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
    final matching = spectra.where((spectrum) {
      final bin = spectrum['bin']?.round() ?? 0;
      return modalBin > 0 && (bin - modalBin).abs() <= 1;
    }).length;
    final stabilityAcrossRows =
        spectra.isEmpty ? 0.0 : matching / spectra.length;
    final concentrations =
        spectra.map((spectrum) => spectrum['concentration'] ?? 0.0).toList()
          ..sort();
    final medianConcentration = _median(concentrations) ?? 0.0;
    final coherence = stabilityAcrossRows * medianConcentration;
    return {
      'rowTimeAnalysisStatus': 'ANALYZED',
      'rowTimeDominantTemporalFrequencyBin': modalBin,
      'rowTimeFrequencyStabilityAcrossRows': stabilityAcrossRows,
      'rowTimeMedianTemporalSpectralConcentration': medianConcentration,
      'rowTimeCoherenceScore': coherence,
      'rowTimeRowsAnalyzed': spectra.length,
    };
  }

  static Map<String, dynamic> analyzeSpatialLattice(List<List<double>> grid) {
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
    final modulationDepth = mean.abs() < 1e-9
        ? 0.0
        : (p90 - p10).abs() / mean.abs();
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
