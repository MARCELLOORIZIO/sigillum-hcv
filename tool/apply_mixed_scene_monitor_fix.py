from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


# Increase the geometry sampling resolution. The previous 20x15 grid and 3x3
# patches produced many ambiguous matches on monitor text and repeated UI.
sampling_path = Path('lib/hcv_live_screen_probe_sampling.dart')
sampling = sampling_path.read_text()
sampling = replace_once(
    sampling,
    """  const geometryWidth = 20;
  const geometryHeight = 15;""",
    """  const geometryWidth = 32;
  const geometryHeight = 24;""",
    'geometry sampling resolution',
)
sampling_path.write_text(sampling)


# Replace translation-only geometry with robust affine plane fitting. A plane
# viewed from another angle does not move as one constant translation: it has a
# coherent perspective/affine flow. Residual motion after fitting that plane is
# the depth signal. Cross-lighting phase pairs are intentionally excluded.
geometry_path = Path('lib/hcv_live_screen_probe_geometry.dart')
geometry_path.write_text("""part of 'hcv_live_screen_probe.dart';

HCVSceneGeometryClassification _analyzeGeometry(
  List<_FrameStats> frames,
) {
  if (frames.length < 4) {
    return HCVSceneGeometryClassifier.classify(
      motionMagnitude: 0,
      flowReliability: 0,
      directionCoherence: 0,
      depthDispersion: 0,
      planarCoherence: 0,
      matchedRegions: 0,
    );
  }

  final baseline = frames.where((frame) => frame.phase == 0).toList();
  final recovery = frames.where((frame) => frame.phase == 2).toList();
  final candidates = <_GeometryCandidate>[];

  void addPhasePairs(List<_FrameStats> phaseFrames) {
    if (phaseFrames.length < 4) return;
    final indices = <int>{
      0,
      phaseFrames.length ~/ 4,
      phaseFrames.length ~/ 2,
      (phaseFrames.length * 3) ~/ 4,
      phaseFrames.length - 1,
    }.toList()
      ..sort();

    for (var gap = 1; gap <= 2; gap++) {
      for (var index = 0; index + gap < indices.length; index++) {
        final fit = _measureGeometryPair(
          phaseFrames[indices[index]],
          phaseFrames[indices[index + gap]],
        );
        if (fit.matchedRegions < 4 ||
            fit.flowReliability < 0.25 ||
            fit.motionMagnitude < 0.04) {
          continue;
        }

        final motionUsability = fit.motionMagnitude < 0.10
            ? fit.motionMagnitude / 0.10
            : fit.motionMagnitude > 0.88
                ? ((1.0 - fit.motionMagnitude) / 0.12)
                    .clamp(0.0, 1.0)
                    .toDouble()
                : 1.0;
        final modelSignal = max(
          fit.planarCoherence,
          min(0.75, fit.depthDispersion),
        );
        final score = fit.flowReliability * 0.55 +
            motionUsability * 0.30 +
            modelSignal * 0.15 -
            fit.boundarySaturation * 0.25;
        candidates.add(_GeometryCandidate(fit, score));
      }
    }
  }

  // Geometry is measured only within the same OFF-light phase. Pairing the
  // baseline directly with recovery previously mixed viewpoint, torch response
  // and a larger time gap, and systematically selected false depth.
  addPhasePairs(baseline);
  addPhasePairs(recovery);

  if (candidates.isEmpty) {
    return HCVSceneGeometryClassifier.classify(
      motionMagnitude: 0,
      flowReliability: 0,
      directionCoherence: 0,
      depthDispersion: 0,
      planarCoherence: 0,
      matchedRegions: 0,
    );
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  final fit = candidates.first.fit;
  return HCVSceneGeometryClassifier.classify(
    motionMagnitude: fit.motionMagnitude,
    flowReliability: fit.flowReliability,
    directionCoherence: fit.directionCoherence,
    depthDispersion: fit.depthDispersion,
    planarCoherence: fit.planarCoherence,
    matchedRegions: fit.inlierRegions,
  );
}

HCVPlanarMotionFit _measureGeometryPair(
  _FrameStats before,
  _FrameStats after,
) {
  if (before.geometryWidth != after.geometryWidth ||
      before.geometryHeight != after.geometryHeight ||
      before.geometryLuma.length != after.geometryLuma.length ||
      before.geometryLuma.isEmpty) {
    return const HCVPlanarMotionFit.empty();
  }

  final width = before.geometryWidth;
  final height = before.geometryHeight;
  const regionsX = 5;
  const regionsY = 4;
  const patchRadius = 2;
  const maxShift = 5;
  const localSearchRadius = 2;
  final global = _estimateGlobalShift(before, after, maxShift);
  final samples = <HCVPlanarFlowSample>[];

  for (var regionY = 0; regionY < regionsY; regionY++) {
    for (var regionX = 0; regionX < regionsX; regionX++) {
      final margin = patchRadius + maxShift;
      final usableWidth = max(1, width - margin * 2);
      final usableHeight = max(1, height - margin * 2);
      final centerX = margin +
          (((regionX + 0.5) * usableWidth) / regionsX).floor();
      final centerY = margin +
          (((regionY + 0.5) * usableHeight) / regionsY).floor();

      final sourcePatch = _readPatch(
        before.geometryLuma,
        width,
        centerX,
        centerY,
        patchRadius,
      );
      final texture = _standardDeviation(sourcePatch);
      if (texture < 0.012) continue;

      var bestError = double.infinity;
      var secondError = double.infinity;
      var bestDx = global.dx;
      var bestDy = global.dy;
      final minimumDx = max(-maxShift, global.dx - localSearchRadius);
      final maximumDx = min(maxShift, global.dx + localSearchRadius);
      final minimumDy = max(-maxShift, global.dy - localSearchRadius);
      final maximumDy = min(maxShift, global.dy + localSearchRadius);

      for (var dy = minimumDy; dy <= maximumDy; dy++) {
        for (var dx = minimumDx; dx <= maximumDx; dx++) {
          final targetPatch = _readPatch(
            after.geometryLuma,
            width,
            centerX + dx,
            centerY + dy,
            patchRadius,
          );
          final error = _normalizedPatchError(sourcePatch, targetPatch);
          if (error < bestError) {
            secondError = bestError;
            bestError = error;
            bestDx = dx;
            bestDy = dy;
          } else if (error < secondError) {
            secondError = error;
          }
        }
      }

      final fit = (1.0 - bestError / max(0.045, texture * 2.6))
          .clamp(0.0, 1.0)
          .toDouble();
      final uniqueness = secondError.isFinite && secondError > 0
          ? ((secondError - bestError) / secondError * 4.0)
              .clamp(0.0, 1.0)
              .toDouble()
          : 0.0;
      final quality =
          fit * 0.72 + uniqueness * 0.18 + global.quality * 0.10;
      if (quality < 0.34) continue;

      final normalizedX = (centerX - (width - 1) / 2.0) /
          max(1.0, (width - 1) / 2.0);
      final normalizedY = (centerY - (height - 1) / 2.0) /
          max(1.0, (height - 1) / 2.0);
      samples.add(HCVPlanarFlowSample(
        x: normalizedX,
        y: normalizedY,
        dx: bestDx.toDouble(),
        dy: bestDy.toDouble(),
        quality: quality,
        boundaryHit: bestDx.abs() >= maxShift || bestDy.abs() >= maxShift,
      ));
    }
  }

  return HCVPlanarMotionModel.fit(
    samples,
    maxShift: maxShift.toDouble(),
    expectedRegions: regionsX * regionsY,
  );
}

_GlobalShiftEstimate _estimateGlobalShift(
  _FrameStats before,
  _FrameStats after,
  int maxShift,
) {
  var bestError = double.infinity;
  var secondError = double.infinity;
  var bestDx = 0;
  var bestDy = 0;

  for (var dy = -maxShift; dy <= maxShift; dy++) {
    for (var dx = -maxShift; dx <= maxShift; dx++) {
      final error = _gridShiftError(
        before.geometryLuma,
        after.geometryLuma,
        before.geometryWidth,
        before.geometryHeight,
        dx,
        dy,
      );
      if (error < bestError) {
        secondError = bestError;
        bestError = error;
        bestDx = dx;
        bestDy = dy;
      } else if (error < secondError) {
        secondError = error;
      }
    }
  }

  final texture = _standardDeviation(before.geometryLuma);
  final fit = (1.0 - bestError / max(0.035, texture * 2.5))
      .clamp(0.0, 1.0)
      .toDouble();
  final uniqueness = secondError.isFinite && secondError > 0
      ? ((secondError - bestError) / secondError * 5.0)
          .clamp(0.0, 1.0)
          .toDouble()
      : 0.0;
  return _GlobalShiftEstimate(
    dx: bestDx,
    dy: bestDy,
    quality: fit * 0.82 + uniqueness * 0.18,
  );
}

double _gridShiftError(
  List<double> before,
  List<double> after,
  int width,
  int height,
  int dx,
  int dy,
) {
  final startX = max(0, -dx);
  final endX = min(width, width - dx);
  final startY = max(0, -dy);
  final endY = min(height, height - dy);
  var count = 0;
  var beforeTotal = 0.0;
  var afterTotal = 0.0;

  for (var y = startY; y < endY; y++) {
    for (var x = startX; x < endX; x++) {
      beforeTotal += before[y * width + x];
      afterTotal += after[(y + dy) * width + x + dx];
      count++;
    }
  }
  if (count < 20) return 1.0;
  final beforeMean = beforeTotal / count;
  final afterMean = afterTotal / count;
  var error = 0.0;
  for (var y = startY; y < endY; y++) {
    for (var x = startX; x < endX; x++) {
      final a = before[y * width + x] - beforeMean;
      final b = after[(y + dy) * width + x + dx] - afterMean;
      error += (a - b).abs();
    }
  }
  return error / count;
}

List<double> _readPatch(
  List<double> grid,
  int width,
  int centerX,
  int centerY,
  int radius,
) {
  final values = <double>[];
  for (var y = centerY - radius; y <= centerY + radius; y++) {
    for (var x = centerX - radius; x <= centerX + radius; x++) {
      values.add(grid[y * width + x]);
    }
  }
  return values;
}

double _normalizedPatchError(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 1;
  final meanA = a.fold<double>(0, (sum, value) => sum + value) / a.length;
  final meanB = b.fold<double>(0, (sum, value) => sum + value) / b.length;
  var error = 0.0;
  for (var index = 0; index < a.length; index++) {
    error += ((a[index] - meanA) - (b[index] - meanB)).abs();
  }
  return error / a.length;
}

double _standardDeviation(List<double> values) {
  if (values.isEmpty) return 0;
  final mean = values.fold<double>(0, (sum, value) => sum + value) /
      values.length;
  final variance = values
          .map((value) => pow(value - mean, 2).toDouble())
          .fold<double>(0, (sum, value) => sum + value) /
      values.length;
  return sqrt(variance);
}

class _GeometryCandidate {
  const _GeometryCandidate(this.fit, this.score);

  final HCVPlanarMotionFit fit;
  final double score;
}

class _GlobalShiftEstimate {
  const _GlobalShiftEstimate({
    required this.dx,
    required this.dy,
    required this.quality,
  });

  final int dx;
  final int dy;
  final double quality;
}
""")


# Planarity remains corroboration only, but the coherence threshold now matches
# a robust dominant-plane fit instead of the previous translation residual.
classifier_path = Path('lib/hcv_scene_geometry_classifier.dart')
classifier = classifier_path.read_text()
classifier = replace_once(
    classifier,
    """    final planarEvidence = enoughRegions &&
        sufficientMotion &&
        reliableFlow &&
        dispersion <= 0.20 &&
        direction >= 0.72 &&
        planar >= 0.70;""",
    """    final planarEvidence = enoughRegions &&
        sufficientMotion &&
        reliableFlow &&
        dispersion <= 0.24 &&
        direction >= 0.68 &&
        planar >= 0.58;""",
    'robust planar coherence thresholds',
)
classifier_path.write_text(classifier)


# Keep the established scene policy unchanged. Strong, reliable real parallax
# can still resolve weak electronic artefacts as reality.
scene_path = Path('lib/hcv_scene_decision_fusion.dart')
scene = scene_path.read_text()
if 'GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS' not in scene:
    raise RuntimeError('Established scene decision policy is missing')
if 'MIXED_DEPTH_SCENE_DOES_NOT_CANCEL_DISPLAY_EVIDENCE' in scene:
    raise RuntimeError('Unstable mixed-scene override is still present')


# Publish raw electronic evidence separately from the geometry-adjusted verdict,
# and keep diffuse torch reflection separate from geometric depth.
core_path = Path('lib/hcv_live_screen_probe_core.dart')
core = core_path.read_text()
core = replace_once(
    core,
    """    final activeDisplayEvidence = sceneDecision.displayEvidence;
    final reflectedRealityEvidence = sceneDecision.realityEvidence;
    final indeterminate = sceneDecision.indeterminate;
""",
    """    final rawActiveDisplayEvidence = active.reasons.contains(
      'EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH',
    );
    final activeDisplayEvidence = sceneDecision.displayEvidence;
    final sceneRealityEvidence = sceneDecision.realityEvidence;
    final reflectedRealityEvidence = active.reasons.contains(
      'DIFFUSE_REFLECTED_SCENE_RESPONSE',
    );
    final indeterminate = sceneDecision.indeterminate;
""",
    'separate raw display flash and geometric evidence',
)
core = replace_once(
    core,
    """        'activeIlluminationDisplayEvidence': activeDisplayEvidence,
        'reflectedRealityEvidence': reflectedRealityEvidence,
        'geometricRealityEvidence': geometry.realityEvidence,
""",
    """        'rawActiveDisplayEvidence': rawActiveDisplayEvidence,
        'activeIlluminationDisplayEvidence': activeDisplayEvidence,
        'reflectedRealityEvidence': reflectedRealityEvidence,
        'sceneRealityEvidence': sceneRealityEvidence,
        'geometricRealityEvidence': geometry.realityEvidence,
        'geometryModelVersion': 'AFFINE_DOMINANT_PLANE_RANSAC_V2',
""",
    'publish distinct physical evidence fields',
)
core_path.write_text(core)


# A monitor is strong only when three modalities agree: concentrated electronic
# illumination response, coherent planar motion, and temporal display structure.
fusion_path = Path('lib/hcv_display_risk_fusion.dart')
fusion = fusion_path.read_text()
fusion = replace_once(
    fusion,
    """    final reflectedRealityEvidence =
        liveSignals['reflectedRealityEvidence'] == true;
    final activeChallengeIndeterminate =
""",
    """    final reflectedRealityEvidence =
        liveSignals['reflectedRealityEvidence'] == true;
    final rawActiveDisplayEvidence =
        liveSignals['rawActiveDisplayEvidence'] == true;
    final planarSceneEvidence = liveSignals['planarSceneEvidence'] == true;
    final activeChallengeIndeterminate =
""",
    'read raw active and planar evidence',
)
fusion = replace_once(
    fusion,
    """    final liveModerate = live != null &&
        liveScore != null &&
        (liveTemporal ||
            activeDisplayEvidence ||
            activeProbeNonConclusive ||
            liveUnifiedDisplaySignature ||
            liveHighRefreshSignature);
""",
    """    final activePlanarTemporal = !reflectedRealityEvidence &&
        rawActiveDisplayEvidence &&
        planarSceneEvidence &&
        localFlicker >= 0.32 &&
        refreshBand >= 0.13 &&
        persistentPattern >= 0.58;

    final liveModerate = live != null &&
        liveScore != null &&
        (liveTemporal ||
            activePlanarTemporal ||
            activeDisplayEvidence ||
            activeProbeNonConclusive ||
            liveUnifiedDisplaySignature ||
            liveHighRefreshSignature);
""",
    'active planar temporal confirmation',
)
fusion = replace_once(
    fusion,
    """    if (liveModerate) evidenceSources.add('LIVE_PREVIEW');
    if (activeDisplayEvidence || activeProbeNonConclusive) {
      evidenceSources.add('ACTIVE_ILLUMINATION');
    }
""",
    """    if (liveModerate) evidenceSources.add('LIVE_PREVIEW');
    if (activeDisplayEvidence ||
        rawActiveDisplayEvidence ||
        activeProbeNonConclusive) {
      evidenceSources.add('ACTIVE_ILLUMINATION');
    }
    if (activePlanarTemporal) {
      evidenceSources.add('PLANAR_PARALLAX');
      strongSources.add('ACTIVE_PLANAR_TEMPORAL');
      reasons.add('ACTIVE_ELECTRONIC_PLANAR_TEMPORAL_CONFIRMED');
    }
""",
    'publish active planar temporal evidence',
)
fusion_path.write_text(fusion)


# Replace the large modal alert with a compact top banner, away from zoom.
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()
start_marker = '  Future<void> _showCaptureReadyMessage() async {'
end_marker = '  Future<void> _toggleCoordinateStamp() async {'
start = camera.find(start_marker)
end = camera.find(end_marker, start)
if start < 0 or end < 0:
    raise RuntimeError('compact confirmation: safe capture patch not found')
compact_confirmation = """  Future<void> _showCaptureReadyMessage() async {
    if (!mounted) return;
    final italian = widget.languageCode.toLowerCase().startsWith('it');
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.10),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 58, 14, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(11, 7, 5, 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          italian
                              ? 'Verifica completata. Ricomponi.'
                              : 'Verification complete. Recompose.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          italian ? 'PROSEGUI' : 'CONTINUE',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

"""
camera = camera[:start] + compact_confirmation + camera[end:]
camera_path.write_text(camera)


Path('test/hcv_planar_motion_model_test.dart').write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_planar_motion_model.dart';

void main() {
  test('perspective change on one plane remains planar', () {
    final samples = <HCVPlanarFlowSample>[];
    for (var row = 0; row < 4; row++) {
      final y = -1.0 + row * (2.0 / 3.0);
      for (var column = 0; column < 5; column++) {
        final x = -1.0 + column * 0.5;
        samples.add(HCVPlanarFlowSample(
          x: x,
          y: y,
          dx: 2.0 + 0.35 * x + 0.15 * y,
          dy: 0.4 - 0.10 * x + 0.20 * y,
          quality: 0.90,
          boundaryHit: false,
        ));
      }
    }

    final result = HCVPlanarMotionModel.fit(
      samples,
      maxShift: 5,
      expectedRegions: 20,
    );
    expect(result.motionMagnitude, greaterThan(0.16));
    expect(result.flowReliability, greaterThan(0.70));
    expect(result.depthDispersion, lessThan(0.20));
    expect(result.planarCoherence, greaterThan(0.58));
  });

  test('independent depth layers remain non-planar', () {
    final samples = <HCVPlanarFlowSample>[];
    for (var row = 0; row < 4; row++) {
      final y = -1.0 + row * (2.0 / 3.0);
      for (var column = 0; column < 5; column++) {
        final x = -1.0 + column * 0.5;
        final dx = column == 0 || column == 4
            ? 3.30
            : column == 1 || column == 3
                ? 1.60
                : 2.20;
        samples.add(HCVPlanarFlowSample(
          x: x,
          y: y,
          dx: dx,
          dy: 0.30 + 0.10 * y,
          quality: 0.90,
          boundaryHit: false,
        ));
      }
    }

    final result = HCVPlanarMotionModel.fit(
      samples,
      maxShift: 5,
      expectedRegions: 20,
    );
    expect(result.depthDispersion, greaterThan(0.28));
    expect(result.planarCoherence, lessThan(0.58));
  });
}
""")

Path('test/mixed_scene_monitor_regression_test.dart').write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  test('archive 20 monitor profile is strong when planar parallax agrees', () {
    final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
      <String, dynamic>{
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'framesAnalyzed': 45,
        'screenReplayRiskScore': 45,
        'displayRiskDecision': 'NON_CONCLUSIVE',
        'localTemporalFlickerScore': 0.5525,
        'refreshBandScore': 0.1647,
        'persistentPatternScore': 0.6759,
        'signals': <String, dynamic>{
          'rawActiveDisplayEvidence': true,
          'activeIlluminationDisplayEvidence': true,
          'planarSceneEvidence': true,
          'reflectedRealityEvidence': false,
          'geometricRealityEvidence': false,
        },
      },
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.strongSources, contains('ACTIVE_PLANAR_TEMPORAL'));
    expect(result.evidenceSources, contains('PLANAR_PARALLAX'));
  });

  test('depth without planar agreement does not become a strong display', () {
    final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
      <String, dynamic>{
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'framesAnalyzed': 45,
        'screenReplayRiskScore': 20,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'localTemporalFlickerScore': 0.55,
        'refreshBandScore': 0.17,
        'persistentPatternScore': 0.70,
        'signals': <String, dynamic>{
          'rawActiveDisplayEvidence': true,
          'activeIlluminationDisplayEvidence': false,
          'planarSceneEvidence': false,
          'reflectedRealityEvidence': false,
          'geometricRealityEvidence': true,
        },
      },
    ]);

    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('geometry source never compares different lighting phases', () {
    final geometry =
        File('lib/hcv_live_screen_probe_geometry.dart').readAsStringSync();
    expect(geometry, isNot(contains('baseline.first, recovery.last')));
    expect(geometry, isNot(contains('baseline.last, recovery.first')));
    expect(geometry, isNot(contains('min(0.30, metrics.depthDispersion)')));
    expect(geometry, contains('HCVPlanarMotionModel.fit'));
  });

  test('capture confirmation is compact and above the zoom strip', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final start = camera.indexOf('_showCaptureReadyMessage');
    final end = camera.indexOf('_toggleCoordinateStamp', start);
    final confirmation = camera.substring(start, end);

    expect(confirmation, contains('Alignment.topCenter'));
    expect(confirmation, contains("'PROSEGUI'"));
    expect(confirmation, contains('BoxConstraints(maxWidth: 320)'));
    expect(confirmation, contains('minimumSize: const Size(0, 28)'));
    expect(confirmation, isNot(contains('AlertDialog')));
  });

  test('raw display flash and geometric depth stay distinct', () {
    final core = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    expect(core, contains("'rawActiveDisplayEvidence'"));
    expect(core, contains("'geometryModelVersion'"));
    expect(
      core,
      contains("final reflectedRealityEvidence = active.reasons.contains("),
    );
    expect(
      core,
      isNot(contains(
        'final reflectedRealityEvidence = sceneDecision.realityEvidence',
      )),
    );
  });
}
""")
