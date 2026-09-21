import 'dart:math';

import 'package:flutter/services.dart';

/// Native HFR V3.2 physical display probe.
///
/// BUILD108 preserves the validated V3 full-frame display decision, adds a
/// tightly corroborated harmonic-family recovery path, upgrades short-exposure
/// microtexture diagnostics, and adds an active illumination reality challenge.
/// Absence of temporal display evidence is never treated as positive proof of
/// physical reality; positive-reality physics remains diagnostic until iPhone validation.
class HCVTemporalFrequencyProbe {
  const HCVTemporalFrequencyProbe();

  static const MethodChannel _channel = MethodChannel('hcv.cameraProbe');
  static const double targetMaxFps = 240.0;
  static const double requestedShortExposureSeconds = 1.0 / 1000.0;
  static const double targetCaptureDurationSeconds = 0.35;
  static const int rowProfileBins = 96;

  Future<Map<String, dynamic>?> snapshotNativeCameraState(
    String deviceUniqueId,
  ) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'snapshotCameraState',
        <String, dynamic>{'deviceUniqueId': deviceUniqueId},
      );
      return raw == null ? null : Map<String, dynamic>.from(raw);
    } catch (_) {
      return null;
    }
  }

  /// BUILD126: the actual REC session may use a different AVFoundation
  /// activeFormat from the preview snapshotted before HFR. Never promote a
  /// previously non-comparable probe; additionally fail closed if REC changes
  /// the physical device, effective zoom, format FOV or aspect ratio.
  static Map<String, dynamic> attestVideoRecordingGeometry(
    Map<String, dynamic>? probe,
    Map<String, dynamic>? recordingCameraState,
  ) {
    final attested = Map<String, dynamic>.from(
      probe ?? unavailable('VIDEO_TEMPORAL_FREQUENCY_NOT_AVAILABLE'),
    );
    attested['recordingCameraState'] = recordingCameraState;

    final prior = attested['hfrSpatialComparability'];
    if (prior != 'COMPARABLE') {
      attested['videoRecordingSpatialComparability'] =
          prior == 'NOT_COMPARABLE' ? 'NOT_COMPARABLE' : 'UNKNOWN';
      attested['videoRecordingSpatialComparabilityReason'] =
          'PRE_HFR_FOV_NOT_COMPARABLE_OR_UNKNOWN';
      return attested;
    }

    final hfrDevice = attested['physicalCaptureDeviceUniqueId'];
    final hfrFov =
        (attested['hfrVideoFieldOfView'] as num?)?.toDouble();
    final hfrZoom =
        (attested['effectiveZoomFactor'] as num?)?.toDouble();
    final hfrWidth =
        (attested['configuredHighSpeedFormatWidth'] as num?)?.toInt();
    final hfrHeight =
        (attested['configuredHighSpeedFormatHeight'] as num?)?.toInt();
    final recordingDevice = recordingCameraState?['deviceUniqueId'];
    final recordingFov =
        (recordingCameraState?['activeFormatVideoFieldOfView'] as num?)
            ?.toDouble();
    final recordingZoom =
        (recordingCameraState?['zoomFactor'] as num?)?.toDouble();
    final recordingWidth =
        (recordingCameraState?['activeFormatWidth'] as num?)?.toInt();
    final recordingHeight =
        (recordingCameraState?['activeFormatHeight'] as num?)?.toInt();

    final fovDelta =
        hfrFov != null && recordingFov != null
            ? (hfrFov - recordingFov).abs()
            : null;
    final fovMatched = fovDelta == 0.0;
    final zoomMatched =
        hfrZoom != null &&
        recordingZoom != null &&
        (hfrZoom - recordingZoom).abs() <=
            max(0.02, hfrZoom * 0.02);
    final aspectMatched =
        hfrWidth != null &&
        hfrHeight != null &&
        recordingWidth != null &&
        recordingHeight != null &&
        hfrWidth > 0 &&
        hfrHeight > 0 &&
        recordingWidth > 0 &&
        recordingHeight > 0 &&
        hfrWidth * recordingHeight == recordingWidth * hfrHeight;

    attested['recordingFieldOfViewDelta'] = fovDelta;
    attested['recordingFieldOfViewMatchWithinTolerance'] = fovMatched;
    attested['recordingZoomMatchWithinTolerance'] = zoomMatched;
    attested['recordingAspectRatioMatch'] = aspectMatched;

    final complete =
        hfrDevice is String &&
        hfrDevice.isNotEmpty &&
        recordingDevice is String &&
        recordingDevice.isNotEmpty &&
        hfrFov != null &&
        hfrFov.isFinite &&
        hfrFov > 0 &&
        recordingFov != null &&
        recordingFov.isFinite &&
        recordingFov > 0 &&
        hfrZoom != null &&
        hfrZoom.isFinite &&
        hfrZoom > 0 &&
        recordingZoom != null &&
        recordingZoom.isFinite &&
        recordingZoom > 0 &&
        hfrWidth != null &&
        hfrHeight != null &&
        recordingWidth != null &&
        recordingHeight != null &&
        hfrWidth > 0 &&
        hfrHeight > 0 &&
        recordingWidth > 0 &&
        recordingHeight > 0;

    String state;
    String reason;
    if (!complete) {
      state = 'UNKNOWN';
      reason = 'RECORDING_CAMERA_STATE_MISSING_OR_INCOMPLETE';
    } else if (hfrDevice != recordingDevice) {
      state = 'NOT_COMPARABLE';
      reason = 'RECORDING_PHYSICAL_DEVICE_MISMATCH';
    } else if (!zoomMatched) {
      state = 'NOT_COMPARABLE';
      reason = 'RECORDING_NATIVE_ZOOM_MISMATCH';
    } else if (!fovMatched) {
      state = 'NOT_COMPARABLE';
      reason = 'RECORDING_ACTIVE_FORMAT_FOV_MISMATCH';
    } else if (!aspectMatched) {
      state = 'NOT_COMPARABLE';
      reason = 'RECORDING_ACTIVE_FORMAT_ASPECT_RATIO_MISMATCH';
    } else {
      state = 'COMPARABLE';
      reason = 'PRE_HFR_AND_RECORDING_NATIVE_GEOMETRY_MATCHED';
    }

    attested['videoRecordingSpatialComparability'] = state;
    attested['videoRecordingSpatialComparabilityReason'] = reason;
    attested['hfrSpatialComparability'] = state;
    attested['hfrSpatialComparabilityReason'] = reason;
    return attested;
  }

  Future<Map<String, dynamic>> captureNative(
    String deviceUniqueId, {
    double requestedZoomFactor = 1.0,
    Map<String, dynamic>? preHfrCameraState,
  }) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'captureTemporalFrequencyNative',
        {
          'deviceUniqueId': deviceUniqueId,
          'targetMaxFps': targetMaxFps,
          'targetDurationSeconds': targetCaptureDurationSeconds,
          'targetExposureSeconds': requestedShortExposureSeconds,
          'rowProfileBins': rowProfileBins,
          'requestedZoomFactor': requestedZoomFactor,
          if (preHfrCameraState != null) 'preHfrCameraState': preHfrCameraState,
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
    final rowTimeCoherences = cellResults
        .map((e) => (e['rowTimeCoherenceScore'] as num?)?.toDouble())
        .whereType<double>()
        .toList()
      ..sort();

    final configuredFps = (raw['configuredFrameRate'] as num?)?.toDouble();
    final actualExposure =
        (raw['actualShortExposureSeconds'] as num?)?.toDouble();
    final framePeriod =
        configuredFps != null && configuredFps > 0 ? 1.0 / configuredFps : null;

    final globalTemporalSpectrum =
        HCVTemporalFrequencyMath.analyzeScalarSequence(frameLuma);
    final dominantTemporalBin =
        (globalTemporalSpectrum['dominantTemporalFrequencyBin'] as num?)
                ?.toInt() ??
            0;
    final dominantTemporalFrequencyHz = actualFps != null &&
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
    final indeterminateCellCount =
        9 - displayLikeCellCount - realityLikeCellCount;
    final spatialBins = cellResults
        .map(
          (entry) => (entry['dominantRowFrequencyBin'] as num?)?.toInt() ?? 0,
        )
        .toList(growable: false);
    final rowTimeBins = cellResults
        .map(
          (entry) =>
              (entry['rowTimeDominantTemporalFrequencyBin'] as num?)?.toInt() ??
              0,
        )
        .toList(growable: false);
    final spatialFamilyCellCount = _compatibleModalBinCount(spatialBins);
    final harmonicAwareSpatialFamilyCellCount = harmonicAwareModalBinCount(
      spatialBins,
    );
    final rowTimeFamilyCellCount = _compatibleModalBinCount(rowTimeBins);
    final medianRowTimeCoherence = _median(rowTimeCoherences) ?? 0.0;
    final advancedPhysicsV32 = _analyzeAdvancedDisplayPhysicsV32(raw);

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
    final displayFamilyGlobalHfrCandidate = qualifiesDisplayFamilyGlobalHfrV3(
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
    final strictFullFrameDisplayV3 = qualifiesFullFrameDisplayV3(
      legacyHfrCandidate: displayFamilyGlobalHfrCandidate,
      spatialFamilyCellCount: spatialFamilyCellCount,
      rowTimeFamilyCellCount: rowTimeFamilyCellCount,
      medianRowTimeCoherence: medianRowTimeCoherence,
    );
    final harmonicRecoveryGlobalHfrCandidate =
        qualifiesHarmonicRecoveredGlobalHfrV32(
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
    final harmonicExposureCorroborated =
        advancedPhysicsV32['harmonicRecoveryExposureCorroborated'] == true;
    final harmonicRecoveryCorroborationStageCount =
        (advancedPhysicsV32['harmonicRecoveryCorroborationStageCount'] as num?)
                ?.toInt() ??
            0;
    final harmonicFullFrameDisplayRecovery = !strictFullFrameDisplayV3 &&
        harmonicRecoveryGlobalHfrCandidate &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20 &&
        harmonicExposureCorroborated;
    final lowModulationDisplayRecoveryBuild109 = !strictFullFrameDisplayV3 &&
        !harmonicFullFrameDisplayRecovery &&
        qualifiesLowModulationCorroboratedGlobalHfrBuild109(
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
          displayLikeCellCount: displayLikeCellCount,
          harmonicAwareSpatialFamilyCellCount:
              harmonicAwareSpatialFamilyCellCount,
          rowTimeFamilyCellCount: rowTimeFamilyCellCount,
          medianRowTimeCoherence: medianRowTimeCoherence,
          exposureCorroborationStageCount:
              harmonicRecoveryCorroborationStageCount,
        );
    // BUILD116: some modern automotive panels can expose a coherent display
    // signature in every 3x3 cell while their global frame-luma spectrum stays
    // below the legacy 40 Hz gate. Recover only the strongest display-only
    // case: all nine cells must independently look display-like, all nine must
    // be periodic and stable, and both spatial + row-time coverage must span
    // the complete grid. This is deliberately narrower than the normal V3
    // display-family rule and cannot fire for a TV/monitor embedded in a room.
    final displayOnlyFullGridRecoveryBuild116 = !strictFullFrameDisplayV3 &&
        !harmonicFullFrameDisplayRecovery &&
        !lowModulationDisplayRecoveryBuild109 &&
        qualifiesDisplayOnlyFullGridRecoveryBuild116(
          actualFps: actualFps,
          framesAnalyzed: acceptedFrames,
          shortExposureVerified: raw['shortExposureVerified'] == true,
          exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
          displayLikeCellCount: displayLikeCellCount,
          realityLikeCellCount: realityLikeCellCount,
          indeterminateCellCount: indeterminateCellCount,
          periodicCellCount: periodicCellCount,
          stableCellCount: stableCellCount,
          medianCellPeriodicityStrength: medianCellPeriodicity,
          medianCellFrequencyStability: medianCellStability,
          medianCellPhaseStepConsistency: medianCellPhase,
          spatialFamilyCellCount: spatialFamilyCellCount,
          harmonicAwareSpatialFamilyCellCount:
              harmonicAwareSpatialFamilyCellCount,
          rowTimeFamilyCellCount: rowTimeFamilyCellCount,
          medianRowTimeCoherence: medianRowTimeCoherence,
        );
    final nearFullGridDisplayRecoveryBuild122 = actualFps != null &&
        actualFps >= 120.0 &&
        acceptedFrames >= 60 &&
        raw['shortExposureVerified'] == true &&
        raw['exposureLockedForEntireNativeCapture'] == true &&
        !strictFullFrameDisplayV3 &&
        !harmonicFullFrameDisplayRecovery &&
        !lowModulationDisplayRecoveryBuild109 &&
        !displayOnlyFullGridRecoveryBuild116 &&
        displayLikeCellCount >= 8 &&
        realityLikeCellCount == 0 &&
        periodicCellCount == 9 &&
        stableCellCount == 9 &&
        medianCellPeriodicity >= 0.50 &&
        medianCellStability >= 0.95 &&
        medianCellPhase >= 0.90 &&
        spatialFamilyCellCount == 9 &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.25;

    final fullFrameDisplayV3 = strictFullFrameDisplayV3 ||
        harmonicFullFrameDisplayRecovery ||
        lowModulationDisplayRecoveryBuild109 ||
        displayOnlyFullGridRecoveryBuild116 ||
        nearFullGridDisplayRecoveryBuild122;
    final allNineCellsSameDisplayFamily = fullFrameDisplayV3 &&
        rowTimeFamilyCellCount == 9 &&
        (spatialFamilyCellCount == 9 ||
            harmonicAwareSpatialFamilyCellCount == 9);

    // BUILD116: mixedSceneDetected must mean actual mixed spatial coverage, not
    // merely "some cells did not clear the local display threshold". When no
    // cell contains reality evidence and the entire 3x3 grid shares the same
    // spatial and row-time family, retain the uncertainty but do not assert a
    // real-scene veto. Strong ML/optical evidence may then resolve the sample.
    final displayOnlyFullGridCoverageBuild116 =
        qualifiesDisplayOnlyFullGridCoverageBuild116(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      displayLikeCellCount: displayLikeCellCount,
      realityLikeCellCount: realityLikeCellCount,
      periodicCellCount: periodicCellCount,
      stableCellCount: stableCellCount,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      medianCellPhaseStepConsistency: medianCellPhase,
      spatialFamilyCellCount: spatialFamilyCellCount,
      harmonicAwareSpatialFamilyCellCount: harmonicAwareSpatialFamilyCellCount,
      rowTimeFamilyCellCount: rowTimeFamilyCellCount,
      medianRowTimeCoherence: medianRowTimeCoherence,
    );
    final mixedSceneDetected = displayLikeCellCount > 0 &&
        !fullFrameDisplayV3 &&
        !displayOnlyFullGridCoverageBuild116;
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
    final activeIlluminationV32 = _analyzeActiveIlluminationRealityV32(raw);
    final coherentDisplayPeriodicity = fullFrameDisplayV3;

    return {
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'decisionRole':
          'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V32_HARMONIC_DISPLAY_RECOVERY_CANDIDATE;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',
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
        'harmonicRecoveryGlobalHfrCandidateV32':
            harmonicRecoveryGlobalHfrCandidate,
        'harmonicFullFrameDisplayRecoveryV32': harmonicFullFrameDisplayRecovery,
        'harmonicRecoveryExposureCorroboratedV32': harmonicExposureCorroborated,
        'harmonicRecoveryCorroborationStageCountV32':
            harmonicRecoveryCorroborationStageCount,
        'lowModulationDisplayRecoveryBuild109':
            lowModulationDisplayRecoveryBuild109,
        'displayOnlyFullGridRecoveryBuild116':
            displayOnlyFullGridRecoveryBuild116,
        'nearFullGridDisplayRecoveryBuild122':
            nearFullGridDisplayRecoveryBuild122,
        'displayOnlyFullGridCoverageBuild116':
            displayOnlyFullGridCoverageBuild116,
        'harmonicAwareSpatialFamilyCellCount':
            harmonicAwareSpatialFamilyCellCount,
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
        'harmonicAwareSpatialFamilyCellCount':
            harmonicAwareSpatialFamilyCellCount,
        'rowTimeFamilyCellCount': rowTimeFamilyCellCount,
        'medianRowTimeCoherence': medianRowTimeCoherence,
        'harmonicDisplayRecovery': harmonicFullFrameDisplayRecovery,
        'lowModulationDisplayRecoveryBuild109':
            lowModulationDisplayRecoveryBuild109,
        'displayOnlyFullGridRecoveryBuild116':
            displayOnlyFullGridRecoveryBuild116,
        'nearFullGridDisplayRecoveryBuild122':
            nearFullGridDisplayRecoveryBuild122,
        'displayOnlyFullGridCoverageBuild116':
            displayOnlyFullGridCoverageBuild116,
        'displayFamilyMode': harmonicFullFrameDisplayRecovery
            ? 'HARMONIC_2_TO_1_CORROBORATED'
            : lowModulationDisplayRecoveryBuild109
                ? 'LOW_MODULATION_MULTI_AXIS_CORROBORATED'
                : displayOnlyFullGridRecoveryBuild116
                    ? 'DISPLAY_ONLY_FULL_GRID_CORROBORATED'
                    : 'STRICT_SINGLE_FAMILY',
        'classificationPolicy':
            'BUILD116_PRESERVES_VALIDATED_V3_AND_BUILD109_GATES;DISPLAY_ONLY_9_OF_9_RECOVERY_REQUIRES_PERIODIC_STABLE_FULL_GRID_PHYSICS;DISPLAY_ONLY_PARTIAL_LOCAL_CELLS_WITH_9_OF_9_SPATIAL_AND_ROW_TIME_COVERAGE_DO_NOT_ASSERT_MIXED_REALITY;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',
      },
      'advancedDisplayPhysicsV32': advancedPhysicsV32,
      'activeIlluminationRealityV32': activeIlluminationV32,
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
      'requestedDeviceUniqueId': raw['requestedDeviceUniqueId'],
      'physicalCaptureDeviceUniqueId': raw['physicalCaptureDeviceUniqueId'],
      'physicalDeviceSubstitutionUsed':
          raw['physicalDeviceSubstitutionUsed'] == true,
      'requestedZoomFactor': raw['requestedZoomFactor'],
      'effectiveZoomFactor': raw['effectiveZoomFactor'],
      'hfrMinAvailableZoomFactor': raw['hfrMinAvailableZoomFactor'],
      'hfrMaxAvailableZoomFactor': raw['hfrMaxAvailableZoomFactor'],
      'zoomClampedForHfr': raw['zoomClampedForHfr'],
      'zoomMatchWithinTolerance': raw['zoomMatchWithinTolerance'],
      'zoomSpatialEquivalence': raw['zoomSpatialEquivalence'],
      'preHfrDeviceUniqueId': raw['preHfrDeviceUniqueId'],
      'preHfrNativeZoomFactor': raw['preHfrNativeZoomFactor'],
      'preHfrActiveFormatIndex': raw['preHfrActiveFormatIndex'],
      'preHfrFormatWidth': raw['preHfrFormatWidth'],
      'preHfrFormatHeight': raw['preHfrFormatHeight'],
      'preHfrVideoFieldOfView': raw['preHfrVideoFieldOfView'],
      'hfrActiveFormatIndex': raw['hfrActiveFormatIndex'],
      'hfrVideoFieldOfView': raw['hfrVideoFieldOfView'],
      'fieldOfViewDelta': raw['fieldOfViewDelta'],
      'fieldOfViewToleranceDegrees': raw['fieldOfViewToleranceDegrees'],
      'fieldOfViewMatchWithinTolerance': raw['fieldOfViewMatchWithinTolerance'],
      'preHfrNativeZoomMatchWithinTolerance':
          raw['preHfrNativeZoomMatchWithinTolerance'],
      'aspectRatioMatch': raw['aspectRatioMatch'],
      'hfrSpatialComparability': raw['hfrSpatialComparability'],
      'hfrSpatialComparabilityReason': raw['hfrSpatialComparabilityReason'],
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
        'decisionEnabled': true,
        'requiredSameDisplayFamilyCells': 9,
        'partialDisplayCoverageMeansMixedReality': true,
        'decisionGate': 'HFR_V3_FULL_FRAME_DISPLAY_VS_MIXED_REAL_SCENE',
      },
      'nativeCaptureMetadata': _withoutRawFrames(raw),
      'note':
          'V3.2 BUILD108 preserves validated V3 decisions, adds a tightly corroborated 2:1 harmonic display-family recovery, 64x64 short-exposure microtexture diagnostics, and an active illumination reality challenge. Quiet temporal signatures remain non-evidence for reality; active reality physics is diagnostic-only pending iPhone validation.',
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

  static bool qualifiesHarmonicRecoveredGlobalHfrV32({
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
        medianCellFrequencyStability >= 0.80 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6;
  }

  // BUILD109: narrow recovery for a physically corroborated full-frame display
  // whose global modulation falls below the validated 0.75 production gate.
  // This does not lower the normal HFR threshold: it only admits the 0.50-0.75
  // band when several independent spatial, row-time and exposure axes agree.
  static bool qualifiesLowModulationCorroboratedGlobalHfrBuild109({
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
    required int displayLikeCellCount,
    required int harmonicAwareSpatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
    required int exposureCorroborationStageCount,
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
    return globalModulationDepth >= 0.50 &&
        globalModulationDepth < 0.75 &&
        globalSpectralConcentration >= 0.85 &&
        medianCellPeriodicityStrength >= 0.12 &&
        medianCellFrequencyStability >= 0.80 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6 &&
        stableCellCount >= 7 &&
        displayLikeCellCount >= 7 &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.75 &&
        exposureCorroborationStageCount >= 2;
  }

  /// BUILD116 narrow physical recovery for modern displays whose global
  /// frame-luma rhythm is weak/slow but whose complete 3x3 grid is independently
  /// and persistently display-like. This never accepts partial display coverage.
  static bool qualifiesDisplayOnlyFullGridRecoveryBuild116({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required int displayLikeCellCount,
    required int realityLikeCellCount,
    required int indeterminateCellCount,
    required int periodicCellCount,
    required int stableCellCount,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int spatialFamilyCellCount,
    required int harmonicAwareSpatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    return displayLikeCellCount == 9 &&
        realityLikeCellCount == 0 &&
        indeterminateCellCount == 0 &&
        periodicCellCount == 9 &&
        stableCellCount == 9 &&
        medianCellPeriodicityStrength >= 0.50 &&
        medianCellFrequencyStability >= 0.95 &&
        medianCellPhaseStepConsistency >= 0.90 &&
        spatialFamilyCellCount == 9 &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.40;
  }

  /// BUILD116 coverage guard. It does not itself declare a display. It only
  /// prevents the mixed-real-scene veto when physical frequency families span
  /// all nine cells and no cell contains positive reality-like evidence.
  static bool qualifiesDisplayOnlyFullGridCoverageBuild116({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required int displayLikeCellCount,
    required int realityLikeCellCount,
    required int periodicCellCount,
    required int stableCellCount,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int spatialFamilyCellCount,
    required int harmonicAwareSpatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    return displayLikeCellCount >= 5 &&
        realityLikeCellCount == 0 &&
        periodicCellCount >= 5 &&
        stableCellCount >= 5 &&
        medianCellPeriodicityStrength >= 0.10 &&
        medianCellFrequencyStability >= 0.90 &&
        medianCellPhaseStepConsistency >= 0.50 &&
        spatialFamilyCellCount == 9 &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.40;
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
    if (dominantTemporalFrequencyHz == null ||
        dominantTemporalFrequencyHz >= 10.0) {
      return false;
    }
    return medianCellPeriodicityStrength < 0.05 &&
        medianCellFrequencyStability < 0.60 &&
        periodicCellCount <= 1 &&
        stableCellCount <= 1;
  }

  @Deprecated(
    'Absence of temporal display evidence is not positive reality evidence.',
  )
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
  }) =>
      false;

  static bool _isV3DisplayLikeCell(Map<String, dynamic> entry) {
    final periodicity =
        (entry['periodicityStrength'] as num?)?.toDouble() ?? 0.0;
    final stability =
        (entry['dominantFrequencyStability'] as num?)?.toDouble() ?? 0.0;
    final phase = (entry['phaseStepConsistency'] as num?)?.toDouble() ?? 0.0;
    final rowTime = (entry['rowTimeCoherenceScore'] as num?)?.toDouble() ?? 0.0;
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
    final rowTime = (entry['rowTimeCoherenceScore'] as num?)?.toDouble() ?? 1.0;
    return periodicity < 0.02 && stability < 0.45 && rowTime < 0.15;
  }

  static int _compatibleModalBinCount(List<int> bins) {
    final positive = bins.where((bin) => bin > 0).toList(growable: false);
    if (positive.isEmpty) return 0;
    var best = 0;
    for (final candidate in positive) {
      final count =
          positive.where((bin) => (bin - candidate).abs() <= 1).length;
      if (count > best) best = count;
    }
    return best;
  }

  static int harmonicAwareModalBinCount(List<int> bins) {
    final positive = bins.where((bin) => bin > 0).toList(growable: false);
    if (positive.isEmpty) return 0;
    bool compatible(int a, int b) {
      if ((a - b).abs() <= 1) return true;
      final lower = min(a, b);
      final upper = max(a, b);
      if (lower < 2) return false;
      return (upper - 2 * lower).abs() <= 1;
    }

    var best = 0;
    for (final candidate in positive) {
      final count = positive.where((bin) => compatible(bin, candidate)).length;
      if (count > best) best = count;
    }
    return best;
  }

  static int _compatibleLatticeSignatureCount(
    List<Map<String, dynamic>> lattice,
  ) {
    if (lattice.isEmpty) return 0;
    var best = 0;
    for (final candidate in lattice) {
      final hx = (candidate['horizontalPeakLag'] as num?)?.toInt() ?? 0;
      final vy = (candidate['verticalPeakLag'] as num?)?.toInt() ?? 0;
      if (hx <= 0 || vy <= 0) continue;
      final count = lattice.where((entry) {
        final ex = (entry['horizontalPeakLag'] as num?)?.toInt() ?? 0;
        final ey = (entry['verticalPeakLag'] as num?)?.toInt() ?? 0;
        return ex > 0 && ey > 0 && (ex - hx).abs() <= 1 && (ey - vy).abs() <= 1;
      }).length;
      if (count > best) best = count;
    }
    return best;
  }

  static Map<String, dynamic> _analyzeAdvancedDisplayPhysicsV32(
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
          final parsed =
              rawCell.whereType<num>().map((n) => n.toDouble()).toList();
          if (parsed.length == rawCell.length && parsed.length >= 16) {
            sequences[cell].add(parsed);
          }
        }
      }
      final rolling = <Map<String, dynamic>>[];
      final rowTime = <Map<String, dynamic>>[];
      for (var cell = 0; cell < 9; cell++) {
        rolling.add(
          HCVTemporalFrequencyMath.analyzeRowProfileSequence(sequences[cell]),
        );
        rowTime.add(
          HCVTemporalFrequencyMath.analyzeRowTimeMatrix(sequences[cell]),
        );
      }
      final spatialBins = rolling
          .map((m) => (m['dominantRowFrequencyBin'] as num?)?.toInt() ?? 0)
          .toList();
      final rowTimeBins = rowTime
          .map(
            (m) =>
                (m['rowTimeDominantTemporalFrequencyBin'] as num?)?.toInt() ??
                0,
          )
          .toList();
      final band = rolling
          .map(
            (m) => (m['rollingShutterBandCoherence'] as num?)?.toDouble(),
          )
          .whereType<double>()
          .toList()
        ..sort();
      final phase = rolling
          .map(
            (m) =>
                (m['rollingShutterPhaseDriftConsistency'] as num?)?.toDouble(),
          )
          .whereType<double>()
          .toList()
        ..sort();
      final rt = rowTime
          .map((m) => (m['rowTimeCoherenceScore'] as num?)?.toDouble())
          .whereType<double>()
          .toList()
        ..sort();

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
          .toList()
        ..sort();
      final latticeSharpness = lattice
          .map((m) => (m['latticePeakSharpness'] as num?)?.toDouble())
          .whereType<double>()
          .toList()
        ..sort();
      final latticeFamily = _compatibleLatticeSignatureCount(lattice);
      final spatialFamily = _compatibleModalBinCount(spatialBins);
      final rowTimeFamily = _compatibleModalBinCount(rowTimeBins);
      final medianBand = _medianStatic(band) ?? 0.0;
      final medianPhase = _medianStatic(phase) ?? 0.0;
      final medianRt = _medianStatic(rt) ?? 0.0;
      final medianLattice = _medianStatic(latticeStrengths) ?? 0.0;
      final medianLatticeSharpness = _medianStatic(latticeSharpness) ?? 0.0;
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
        'medianSpatialLatticePeakSharpness': medianLatticeSharpness,
        'latticeFamilyCellCount': latticeFamily,
        'rollingShutterHighFrequencyCandidate':
            spatialFamily >= 8 && medianBand >= 0.45 && medianPhase >= 0.20,
        'harmonicRecoveryCorroborationCandidate': spatialFamily == 9 &&
            rowTimeFamily >= 8 &&
            medianBand >= 0.20 &&
            medianRt >= 0.20,
        'spatialLatticeCandidate':
            latticeStrengths.length >= 6 && medianLattice >= 0.30,
        'coherentSpatialLatticeCandidate': latticeFamily >= 8 &&
            medianLattice >= 0.30 &&
            medianLatticeSharpness >= 0.03,
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
    final rollingCandidates = stages
        .where((s) => s['rollingShutterHighFrequencyCandidate'] == true)
        .length;
    final latticeCandidates =
        stages.where((s) => s['spatialLatticeCandidate'] == true).length;
    final coherentLatticeCandidates = stages
        .where((s) => s['coherentSpatialLatticeCandidate'] == true)
        .length;
    final harmonicCorroborations = stages
        .where((s) => s['harmonicRecoveryCorroborationCandidate'] == true)
        .length;
    return {
      'analysisStatus': stages.isEmpty ? 'NOT_ANALYZED' : 'ANALYZED',
      'decisionRole': 'DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION',
      'productionDecisionChanged': false,
      'exposureSweepStageCount': stages.length,
      'rollingShutterCandidateStageCount': rollingCandidates,
      'spatialLatticeCandidateStageCount': latticeCandidates,
      'coherentSpatialLatticeCandidateStageCount': coherentLatticeCandidates,
      'harmonicRecoveryCorroborationStageCount': harmonicCorroborations,
      'harmonicRecoveryExposureCorroborated': harmonicCorroborations >= 2,
      'persistentHighFrequencyRollingShutterCandidate': rollingCandidates >= 2,
      'persistentSpatialLatticeCandidate': latticeCandidates >= 2,
      'persistentCoherentSpatialLatticeCandidate':
          coherentLatticeCandidates >= 2,
      'advancedPhysicalDisplayCandidate':
          rollingCandidates >= 2 || coherentLatticeCandidates >= 2,
      'stages': stages,
      'note':
          'V3.2 advanced signatures are diagnostic except the narrow harmonic display-family recovery, which additionally requires global HFR, row-time 9/9, harmonic-aware 9/9, and two independent short-exposure corroborations.',
    };
  }

  static Map<String, dynamic> _analyzeActiveIlluminationRealityV32(
    Map<String, dynamic> raw,
  ) {
    final challenge = raw['activeIlluminationChallenge'];
    if (challenge is! Map || challenge['analysisStatus'] != 'CAPTURED') {
      return {
        'analysisStatus': 'NOT_ANALYZED',
        'decisionRole': 'DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION',
        'positivePhysicalRealityEvidence': false,
        'reason': challenge is Map
            ? challenge['reason'] ?? 'ILLUMINATION_CHALLENGE_NOT_CAPTURED'
            : 'ILLUMINATION_CHALLENGE_MISSING',
      };
    }

    List<double> cellMeans(Object? snapshot) {
      if (snapshot is! Map) return const <double>[];
      final frames = snapshot['frames'];
      if (frames is! List) return const <double>[];
      final perCell = List.generate(9, (_) => <double>[]);
      for (final frame in frames) {
        if (frame is! List || frame.length != 9) continue;
        for (var cell = 0; cell < 9; cell++) {
          final profile = frame[cell];
          if (profile is! List) continue;
          final values =
              profile.whereType<num>().map((n) => n.toDouble()).toList();
          if (values.isNotEmpty) {
            perCell[cell].add(values.reduce((a, b) => a + b) / values.length);
          }
        }
      }
      return perCell.map((values) {
        if (values.isEmpty) return 0.0;
        values.sort();
        return _medianStatic(values) ?? 0.0;
      }).toList(growable: false);
    }

    final off = cellMeans(challenge['torchOff']);
    final on = cellMeans(challenge['torchOn']);
    if (off.length != 9 || on.length != 9) {
      return {
        'analysisStatus': 'NOT_ANALYZED',
        'decisionRole': 'DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION',
        'positivePhysicalRealityEvidence': false,
        'reason': 'ILLUMINATION_CELL_RESPONSE_INCOMPLETE',
      };
    }
    final responses = <double>[];
    for (var i = 0; i < 9; i++) {
      responses.add((on[i] - off[i]) / max(0.03, off[i].abs()));
    }
    final sorted = List<double>.from(responses)..sort();
    final medianResponse = _medianStatic(sorted) ?? 0.0;
    final responsiveCells = responses.where((value) => value >= 0.08).length;
    final candidate = medianResponse >= 0.08 && responsiveCells >= 7;
    return {
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION',
      'positivePhysicalRealityEvidence': false,
      'activeIlluminationRealityCandidate': candidate,
      'medianRelativeLumaResponse': medianResponse,
      'responsiveCellCount': responsiveCells,
      'cellRelativeLumaResponses': responses,
      'torchLevel': challenge['torchLevel'],
      'note':
          'Active illumination is candidate positive reality physics only; it cannot change production verdicts until physically validated.',
    };
  }

  static double? _medianStatic(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2.0;
  }

  static Map<String, dynamic> unavailable(String reason, {Object? error}) {
    return {
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole':
          'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V32_HARMONIC_DISPLAY_RECOVERY_CANDIDATE;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',
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
      'rollingShutterBandCoherence': medianConcentration * frequencyStability,
      'rollingShutterPhaseDriftConsistency': phaseStepConsistency,
    };
  }

  static Map<String, dynamic> analyzeRowTimeMatrix(List<List<double>> frames) {
    if (frames.length < 6 || frames.any((profile) => profile.length < 16)) {
      return const {
        'rowTimeAnalysisStatus': 'NOT_ANALYZED',
        'rowTimeReason': 'ROW_TIME_MATRIX_TOO_SHORT',
      };
    }
    final bins = frames.map((profile) => profile.length).reduce(min);
    final spectra = <Map<String, double>>[];
    for (var row = 0; row < bins; row++) {
      final sequence =
          frames.map((frame) => frame[row]).toList(growable: false);
      final mean = _mean(sequence);
      final centered =
          sequence.map((value) => value - mean).toList(growable: false);
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
    final concentrations = spectra
        .map((spectrum) => spectrum['concentration'] ?? 0.0)
        .toList()
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

    final maxLag = min(24, min(width, height) ~/ 3);
    final hByLag = <int, double>{};
    final vByLag = <int, double>{};
    var bestH = 0.0;
    var bestHLag = 0;
    var bestV = 0.0;
    var bestVLag = 0;
    for (var lag = 2; lag <= maxLag; lag++) {
      final h = correlation(lag, 0).abs();
      final v = correlation(0, lag).abs();
      hByLag[lag] = h;
      vByLag[lag] = v;
      if (h > bestH) {
        bestH = h;
        bestHLag = lag;
      }
      if (v > bestV) {
        bestV = v;
        bestVLag = lag;
      }
    }
    double secondBestOutsideNeighborhood(Map<int, double> values, int peakLag) {
      var second = 0.0;
      for (final entry in values.entries) {
        if ((entry.key - peakLag).abs() <= 1) continue;
        if (entry.value > second) second = entry.value;
      }
      return second;
    }

    final hSharpness = max(
      0.0,
      bestH - secondBestOutsideNeighborhood(hByLag, bestHLag),
    );
    final vSharpness = max(
      0.0,
      bestV - secondBestOutsideNeighborhood(vByLag, bestVLag),
    );
    final latticeStrength = sqrt(bestH * bestV);
    final latticePeakSharpness = sqrt(hSharpness * vSharpness);
    return {
      'analysisStatus': 'ANALYZED',
      'latticeStrength': latticeStrength,
      'horizontalAutocorrelationPeak': bestH,
      'verticalAutocorrelationPeak': bestV,
      'horizontalPeakLag': bestHLag,
      'verticalPeakLag': bestVLag,
      'horizontalPeakSharpness': hSharpness,
      'verticalPeakSharpness': vSharpness,
      'latticePeakSharpness': latticePeakSharpness,
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
