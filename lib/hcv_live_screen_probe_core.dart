part of 'hcv_live_screen_probe.dart';

class HCVLiveScreenProbe {
  Future<Map<String, dynamic>> analyzePreview(
    CameraController controller, {
    Duration duration = const Duration(milliseconds: 3000),
    int maxFrames = 45,
    double? restoreZoomLevel,
    bool useOpticalProbeZoom = true,
  }) async {
    if (!controller.value.isInitialized) {
      return _unknown('CAMERA_NOT_READY');
    }
    if (controller.value.isRecordingVideo) {
      return _unknown('CAMERA_RECORDING');
    }
    if (controller.value.isStreamingImages) {
      return _unknown('STREAM_ALREADY_ACTIVE');
    }

    final baselineFrames = <_FrameStats>[];
    final torchFrames = <_FrameStats>[];
    final recoveryFrames = <_FrameStats>[];
    final phaseFrames = max(8, maxFrames ~/ 3);
    final phaseTimeout = Duration(
      milliseconds: max(750, duration.inMilliseconds ~/ 3),
    );

    var exposureLocked = false;
    var focusLocked = false;
    var torchChallengeCompleted = false;
    String? challengeError;
    var processing = false;
    var activePhase = 0;
    var discardUntil = DateTime.fromMillisecondsSinceEpoch(0);

    List<_FrameStats> targetForPhase() {
      switch (activePhase) {
        case 1:
          return torchFrames;
        case 2:
          return recoveryFrames;
        default:
          return baselineFrames;
      }
    }

    Future<void> waitForPhase(List<_FrameStats> target) async {
      final deadline = DateTime.now().add(phaseTimeout);
      while (target.length < phaseFrames && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    try {
      await controller.setFlashMode(FlashMode.off);
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 450));

      try {
        await controller.setExposureMode(ExposureMode.locked);
        exposureLocked = true;
      } catch (_) {
        exposureLocked = false;
      }
      try {
        await controller.setFocusMode(FocusMode.locked);
        focusLocked = true;
      } catch (_) {
        focusLocked = false;
      }
      await Future.delayed(const Duration(milliseconds: 220));

      await controller.startImageStream((image) {
        if (processing || DateTime.now().isBefore(discardUntil)) return;
        final target = targetForPhase();
        if (target.length >= phaseFrames) return;

        processing = true;
        try {
          final stats = _readFrameStats(image, activePhase);
          if (stats != null && target.length < phaseFrames) {
            target.add(stats);
          }
        } finally {
          processing = false;
        }
      });

      activePhase = 0;
      discardUntil = DateTime.now().add(const Duration(milliseconds: 120));
      await waitForPhase(baselineFrames);

      await controller.setFlashMode(FlashMode.torch);
      activePhase = 1;
      discardUntil = DateTime.now().add(const Duration(milliseconds: 320));
      await Future.delayed(const Duration(milliseconds: 320));
      await waitForPhase(torchFrames);
      torchChallengeCompleted = torchFrames.length >= 6;

      await controller.setFlashMode(FlashMode.off);
      activePhase = 2;
      discardUntil = DateTime.now().add(const Duration(milliseconds: 320));
      await Future.delayed(const Duration(milliseconds: 320));
      await waitForPhase(recoveryFrames);
    } catch (e) {
      challengeError = 'ACTIVE_PROBE_FAILED: $e';
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        if (restoreZoomLevel != null && controller.value.isInitialized) {
          await controller.setZoomLevel(restoreZoomLevel);
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final allFrames = <_FrameStats>[
      ...baselineFrames,
      ...torchFrames,
      ...recoveryFrames,
    ];
    if (allFrames.length < 8) {
      return _unknown(
        'NOT_ENOUGH_PREVIEW_FRAMES',
        framesAnalyzed: allFrames.length,
        error: challengeError,
      );
    }

    final passiveFrames = <_FrameStats>[...baselineFrames, ...recoveryFrames];
    final passive = _analyzePassive(
      passiveFrames.length >= 8 ? passiveFrames : allFrames,
    );
    final baseline = _phaseRepresentative(baselineFrames);
    final torch = _phaseRepresentative(torchFrames);
    final recovery = _phaseRepresentative(recoveryFrames);
    final flash = _flashResponseProfile(baseline, torch, recovery);

    final active = HCVActiveDisplayClassifier.classify(
      framesAnalyzed: allFrames.length,
      exposureLocked: exposureLocked,
      torchChallengeCompleted: torchChallengeCompleted,
      baselineMeanLuma: baseline?.meanLuma ?? 0,
      torchMeanLuma: torch?.meanLuma ?? 0,
      recoveryMeanLuma: recovery?.meanLuma ?? 0,
      responsiveTileFraction: flash.responsiveTileFraction,
      flashLiftRatio: flash.globalLiftRatio,
      flashResponseEntropy: flash.responseEntropy,
      flashHotspotConcentration: flash.hotspotConcentration,
      localFlicker: passive.localFlicker,
      refreshBand: passive.refreshBand,
      fineStripe: passive.fineStripe,
      fineGrid: passive.fineGrid,
      moire: passive.moire,
    );

    final persistentPattern = _persistentPattern(baseline, recovery);
    final geometry = _analyzeGeometry(<_FrameStats>[
      ...baselineFrames,
      ...recoveryFrames,
    ]);
    final sceneDecision = HCVSceneDecisionFusion.fuse(
      illumination: active,
      geometry: geometry,
    );
    final rawActiveDisplayEvidence = active.reasons.contains(
      'EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH',
    );
    final activeDisplayEvidence = sceneDecision.displayEvidence;
    final sceneRealityEvidence = sceneDecision.realityEvidence;
    final reflectedRealityEvidence = active.reasons.contains(
      'DIFFUSE_REFLECTED_SCENE_RESPONSE',
    );
    final indeterminate = sceneDecision.indeterminate;
    final sceneClass = sceneDecision.sceneClass;
    final finalReasons = sceneDecision.reasons;

    final compactReason = <String>[
      'ACTIVE_V5',
      ...finalReasons,
      'LOCK=${exposureLocked ? 1 : 0}',
      'LIFT=${_round(flash.globalLiftRatio)}',
      'COV=${_round(flash.responsiveTileFraction)}',
      'ENT=${_round(flash.responseEntropy)}',
      'HOT=${_round(flash.hotspotConcentration)}',
      'GEOM=${geometry.sceneClass}',
      'MOT=${_round(geometry.motionMagnitude)}',
      'REL=${_round(geometry.flowReliability)}',
      'DEP=${_round(geometry.depthDispersion)}',
      'PLN=${_round(geometry.planarCoherence)}',
      if (challengeError != null) challengeError!,
    ].join('|');

    final activeLiveAnalysis = <String, dynamic>{
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': allFrames.length,
      'screenReplayRisk': sceneDecision.risk,
      'screenReplayRiskScore': sceneDecision.score,
      'displayRiskDecision': sceneDecision.decision,
      'displayProbability': _round(sceneDecision.displayProbability),
      'sceneClass': sceneClass,
      'globalFlickerScore': _round(passive.globalFlicker),
      'localTemporalFlickerScore': _round(passive.localFlicker),
      'refreshBandScore': _round(passive.refreshBand),
      'fineStripeScore': _round(passive.fineStripe),
      'fineGridScore': _round(passive.fineGrid),
      'moireFrequencyScore': _round(passive.moire),
      'dynamicChallengeScore': _round(active.illuminationResponseScore),
      'persistentPatternScore': _round(persistentPattern),
      'bandTemporalScore': _round(passive.bandTemporal),
      'electronicLightScore': _round(active.electronicCueScore),
      'stableExposureScore': _round(passive.stableExposure),
      'reason': compactReason,
      'illuminationChallenge': {
        'completed': torchChallengeCompleted,
        'continuousStream': true,
        'exposureLocked': exposureLocked,
        'focusLocked': focusLocked,
        'baselineFrames': baselineFrames.length,
        'torchFrames': torchFrames.length,
        'recoveryFrames': recoveryFrames.length,
        'baselineMeanLuma': _round(baseline?.meanLuma ?? 0),
        'torchMeanLuma': _round(torch?.meanLuma ?? 0),
        'recoveryMeanLuma': _round(recovery?.meanLuma ?? 0),
        'globalLiftRatio': _round(flash.globalLiftRatio),
        'responsiveTileFraction': _round(flash.responsiveTileFraction),
        'responseEntropy': _round(flash.responseEntropy),
        'hotspotConcentration': _round(flash.hotspotConcentration),
        'illuminationResponseScore': _round(active.illuminationResponseScore),
        'emissiveIndependenceScore': _round(active.emissiveIndependenceScore),
        if (challengeError != null) 'error': challengeError,
      },
      'geometryChallenge': geometry.toJson(),
      'signals': {
        'livePreviewAnalyzed': true,
        'activeIlluminationChallenge': torchChallengeCompleted,
        'activeIlluminationContinuousStream': true,
        'rawActiveDisplayEvidence': rawActiveDisplayEvidence,
        'activeIlluminationDisplayEvidence': activeDisplayEvidence,
        'reflectedRealityEvidence': reflectedRealityEvidence,
        'sceneRealityEvidence': sceneRealityEvidence,
        'geometricRealityEvidence': geometry.realityEvidence,
        'geometryModelVersion': 'PROJECTIVE_DOMINANT_PLANE_RANSAC_V3',
        'planarSceneEvidence': geometry.planarEvidence,
        'geometryChallengeCompleted': geometry.sceneClass != 'UNKNOWN',
        'activeChallengeIndeterminate': indeterminate,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': passive.electronicLight > 0.58,
        'strongRefreshTrace': passive.refreshBand > 0.22,
        'displayBandTrace':
            passive.localFlicker > 0.34 && passive.refreshBand > 0.18,
        'opticalStripeTrace': passive.fineStripe > 0.30,
        'opticalCorroboratedTrace':
            passive.fineStripe > 0.30 &&
            (passive.refreshBand > 0.14 || passive.localFlicker > 0.34),
        'moireFrequencyTrace': passive.moire > 0.42,
        'globalDisplayPulse':
            passive.globalFlicker > 0.16 && passive.localFlicker > 0.38,
        'pairedFlickerTrace':
            passive.localFlicker > 0.18 && passive.refreshBand > 0.14,
        'uncorroboratedDisplayPattern':
            !activeDisplayEvidence && !reflectedRealityEvidence,
        'dynamicScreenChallengeTrace': activeDisplayEvidence,
        'globalFlicker': passive.globalFlicker > 0.16,
        'localRefreshFlicker': passive.localFlicker > 0.18,
        'horizontalRefreshBands': passive.refreshBand > 0.12,
        'movingRefreshBands': passive.bandTemporal > 0.04,
      },
      'activeReasons': finalReasons,
      'geometryReasons': geometry.reasons,
      'note': 'Active display probe V5 combines OFF/ON/OFF illumination response, low-resolution camera-motion geometry, and a disposable pre-capture mini-video analyzed through the same optical and ML pipeline used for recorded video.',
    };

    final temporalProbe = await const HCVTemporalCaptureProbe().analyze(
      controller,
    );
    final temporalOptical = _stringMap(temporalProbe['screenReplayAnalysis']);
    final temporalMl = _stringMap(temporalProbe['mlScreenReplayAnalysis']);
    final temporalAnalyzed =
        temporalProbe['analysisStatus'] == 'ANALYZED' &&
        (temporalOptical != null || temporalMl != null);

    HCVDisplayRiskResult? videoEquivalentRisk;
    if (temporalAnalyzed) {
      videoEquivalentRisk = HCVDisplayRiskFusion.combine([
        activeLiveAnalysis,
        temporalOptical,
        temporalMl,
      ]);
    }

    activeLiveAnalysis['photoTemporalVideoProbe'] = temporalProbe;
    activeLiveAnalysis['photoDecisionMethod'] =
        'VIDEO_EQUIVALENT_PRE_CAPTURE_TEMPORAL_ANALYSIS';
    activeLiveAnalysis['videoEquivalentAvailable'] =
        videoEquivalentRisk != null;
    if (videoEquivalentRisk != null) {
      activeLiveAnalysis['videoEquivalentDisplayRisk'] = videoEquivalentRisk
          .toJson();
    }

    final signals = activeLiveAnalysis['signals'];
    if (signals is Map<String, dynamic>) {
      signals['photoTemporalVideoAnalyzed'] = temporalAnalyzed;
      signals['photoTemporalVideoDeletedAfterAnalysis'] =
          temporalProbe['temporaryVideoDeletedAfterAnalysis'] == true;
    }
    activeLiveAnalysis['reason'] =
        '$compactReason|TEMP=${temporalAnalyzed ? 1 : 0}';

    return activeLiveAnalysis;
  }

  Map<String, dynamic>? _stringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  Map<String, dynamic> _unknown(
    String reason, {
    int framesAnalyzed = 0,
    String? error,
  }) {
    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'NOT_ANALYZED',
      'framesAnalyzed': framesAnalyzed,
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'displayRiskDecision': 'NOT_ANALYZED',
      'reason': reason,
      if (error != null && error.isNotEmpty) 'error': error,
    };
  }

  double _round(double value) =>
      double.parse(value.clamp(0.0, 1.0).toStringAsFixed(4));
}
