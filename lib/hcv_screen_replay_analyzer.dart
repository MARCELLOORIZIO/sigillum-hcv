import 'dart:io';
import 'dart:math';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVScreenReplayAnalyzer {
  Future<Map<String, dynamic>> analyzeVideo(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      return _unknown('VIDEO_NOT_FOUND');
    }

    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempDir.path,
        'hcv_screen_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    try {
      await workDir.create(recursive: true);
      final segments = <Map<String, dynamic>>[];

      for (var second = 0; second <= 600; second += 15) {
        final segmentDir = Directory(p.join(workDir.path, 'segment_$second'));
        await segmentDir.create(recursive: true);

        final framePattern = p.join(segmentDir.path, 'frame_%03d.jpg');
        final command = "-y -ss $second -i '$videoPath' "
            "-t 2 "
            "-vf \"fps=30,scale=120:120:force_original_aspect_ratio=decrease,"
            "pad=120:120:(ow-iw)/2:(oh-ih)/2,format=gray\" "
            "-frames:v 60 '$framePattern'";

        final session = await FFmpegKit.execute(command);
        final code = await session.getReturnCode();

        if (code == null || !ReturnCode.isSuccess(code)) {
          if (second == 0) {
            return _unknown('FRAME_EXTRACTION_FAILED');
          }
          break;
        }

        final frames = segmentDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.jpg'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

        if (frames.isEmpty) {
          if (second == 0) {
            return _unknown('NOT_ENOUGH_FRAMES');
          }
          break;
        }

        final images = <img.Image>[];
        for (final frame in frames) {
          final decoded = img.decodeImage(await frame.readAsBytes());
          if (decoded != null) {
            images.add(decoded);
          }
        }

        if (images.length < 3) {
          if (second == 0) {
            return _unknown('NOT_ENOUGH_FRAMES');
          }
          break;
        }

        final analysis = _analyzeImages(images);
        analysis['startSecond'] = second;
        segments.add(analysis);
      }

      if (segments.isEmpty) {
        return _unknown('NOT_ENOUGH_SEGMENTS');
      }

      segments.sort((a, b) => (b['screenReplayRiskScore'] as int)
          .compareTo(a['screenReplayRiskScore'] as int));
      final worst = segments.first;
      final riskScore = worst['screenReplayRiskScore'] as int;
      final risk = _riskLabel(riskScore);

      return {
        'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
        'scanMode': 'EVERY_15_SECONDS',
        'segmentsAnalyzed': segments.length,
        'worstSegmentSecond': worst['startSecond'],
        'framesAnalyzed': segments.fold<int>(
          0,
          (total, segment) => total + (segment['framesAnalyzed'] as int),
        ),
        'screenReplayRisk': risk,
        'screenReplayRiskScore': riskScore,
        'flickerScore': worst['flickerScore'],
        'uniformityScore': worst['uniformityScore'],
        'rectangleEdgeScore': worst['rectangleEdgeScore'],
        'microVariationScore': worst['microVariationScore'],
        'gridLikeScore': worst['gridLikeScore'],
        'localTemporalFlickerScore': worst['localTemporalFlickerScore'],
        'refreshBandScore': worst['refreshBandScore'],
        'signals': worst['signals'],
        'segments': segments.take(12).toList(),
        'note':
            'Passive screen replay analysis sampled every 15 seconds. This lowers or raises risk but is not absolute proof.',
      };
    } catch (e) {
      return _unknown('ANALYSIS_ERROR');
    } finally {
      try {
        if (await workDir.exists()) {
          await workDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return _unknown('IMAGE_NOT_FOUND');
    }

    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        return _unknown('IMAGE_DECODE_FAILED');
      }

      final image = img.copyResize(
        decoded,
        width: 160,
        height: 160,
        interpolation: img.Interpolation.average,
      );

      final uniformityScore = _uniformityScore(image);
      final rectangleEdgeScore = _rectangleEdgeScore(image);
      final gridScore = _gridLikeScore(image);
      final bandScore = _profileContrast(_horizontalBandProfile(image, 16));

      var riskScore = 0;
      if (uniformityScore > 0.72) riskScore += 20;
      if (rectangleEdgeScore > 0.58) riskScore += 30;
      if (gridScore > 0.35) riskScore += 30;
      if (bandScore > 0.22) {
        riskScore += 60;
      } else if (bandScore > 0.16) {
        riskScore += 40;
      } else if (bandScore > 0.10) {
        riskScore += 25;
      }
      riskScore = riskScore.clamp(0, 100).toInt();

      return {
        'type': 'SIGILLUM_SCREEN_REPLAY_IMAGE_ANALYSIS_V1',
        'scanMode': 'STILL_IMAGE_STATIC_SCREEN_ANALYSIS',
        'framesAnalyzed': 1,
        'screenReplayRisk': _riskLabel(riskScore),
        'screenReplayRiskScore': riskScore,
        'uniformityScore': _round(uniformityScore),
        'rectangleEdgeScore': _round(rectangleEdgeScore),
        'gridLikeScore': _round(gridScore),
        'refreshBandScore': _round(bandScore),
        'localTemporalFlickerScore': null,
        'signals': {
          'rectangularDisplayEdges': rectangleEdgeScore > 0.58,
          'flatSceneUniformity': uniformityScore > 0.72,
          'pixelGridOrMoireHint': gridScore > 0.35,
          'horizontalRefreshBands': bandScore > 0.10,
          'temporalFrequencyUnavailable': true,
        },
        'note':
            'Still image screen analysis uses static traces only. Frequency can be measured only in video.',
      };
    } catch (_) {
      return _unknown('IMAGE_ANALYSIS_ERROR');
    }
  }

  Map<String, dynamic> _unknown(String reason) {
    return {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'reason': reason,
    };
  }

  Map<String, dynamic> _analyzeImages(List<img.Image> images) {
    final brightness = images.map(_meanLuma).toList();
    final flickerScore = _flickerScore(brightness);
    final uniformityScore =
        images.map(_uniformityScore).reduce((a, b) => a + b) / images.length;
    final rectangleEdgeScore =
        images.map(_rectangleEdgeScore).reduce((a, b) => a + b) /
            images.length;
    final microVariationScore = _microVariationScore(images);
    final gridScore =
        images.map(_gridLikeScore).reduce((a, b) => a + b) / images.length;
    final localTemporalFlickerScore = _localTemporalFlickerScore(images);
    final refreshBandScore = _refreshBandScore(images);

    var riskScore = 0;
    if (flickerScore > 0.10) riskScore += 25;
    if (uniformityScore > 0.72) riskScore += 20;
    if (rectangleEdgeScore > 0.58) riskScore += 25;
    if (microVariationScore < 0.035) riskScore += 15;
    if (gridScore > 0.35) riskScore += 15;
    if (localTemporalFlickerScore > 0.16) riskScore += 25;
    if (refreshBandScore > 0.12) riskScore += 25;
    riskScore = riskScore.clamp(0, 100).toInt();

    return {
      'framesAnalyzed': images.length,
      'screenReplayRisk': _riskLabel(riskScore),
      'screenReplayRiskScore': riskScore,
      'flickerScore': _round(flickerScore),
      'uniformityScore': _round(uniformityScore),
      'rectangleEdgeScore': _round(rectangleEdgeScore),
      'microVariationScore': _round(microVariationScore),
      'gridLikeScore': _round(gridScore),
      'localTemporalFlickerScore': _round(localTemporalFlickerScore),
      'refreshBandScore': _round(refreshBandScore),
      'signals': {
        'displayFlicker': flickerScore > 0.10,
        'rectangularDisplayEdges': rectangleEdgeScore > 0.58,
        'flatSceneUniformity': uniformityScore > 0.72,
        'lowMicroVariation': microVariationScore < 0.035,
        'pixelGridOrMoireHint': gridScore > 0.35,
        'localRefreshFlicker': localTemporalFlickerScore > 0.16,
        'horizontalRefreshBands': refreshBandScore > 0.12,
      },
    };
  }

  String _riskLabel(int riskScore) {
    return riskScore >= 60
        ? 'HIGH'
        : riskScore >= 35
            ? 'MEDIUM'
            : 'LOW';
  }

  double _meanLuma(img.Image image) {
    var total = 0.0;
    var count = 0;

    for (var y = 0; y < image.height; y += 2) {
      for (var x = 0; x < image.width; x += 2) {
        total += img.getLuminance(image.getPixel(x, y));
        count++;
      }
    }

    return total / max(count, 1) / 255.0;
  }

  double _flickerScore(List<double> brightness) {
    if (brightness.length < 3) return 0;

    var totalDelta = 0.0;
    for (var i = 1; i < brightness.length; i++) {
      totalDelta += (brightness[i] - brightness[i - 1]).abs();
    }

    return totalDelta / (brightness.length - 1);
  }

  double _uniformityScore(img.Image image) {
    final values = <double>[];

    for (var y = 0; y < image.height; y += 4) {
      for (var x = 0; x < image.width; x += 4) {
        values.add(img.getLuminance(image.getPixel(x, y)) / 255.0);
      }
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        values.length;

    return (1.0 - sqrt(variance).clamp(0.0, 1.0)).toDouble();
  }

  double _rectangleEdgeScore(img.Image image) {
    final w = image.width;
    final h = image.height;
    final margin = max(8, (min(w, h) * 0.08).round());

    var borderEdges = 0.0;
    var centerEdges = 0.0;
    var borderCount = 0;
    var centerCount = 0;

    for (var y = 1; y < h - 1; y += 2) {
      for (var x = 1; x < w - 1; x += 2) {
        final gx = (img.getLuminance(image.getPixel(x + 1, y)) -
                img.getLuminance(image.getPixel(x - 1, y)))
            .abs();
        final gy = (img.getLuminance(image.getPixel(x, y + 1)) -
                img.getLuminance(image.getPixel(x, y - 1)))
            .abs();
        final edge = (gx + gy) / 510.0;

        final nearBorder =
            x < margin || x > w - margin || y < margin || y > h - margin;
        if (nearBorder) {
          borderEdges += edge;
          borderCount++;
        } else {
          centerEdges += edge;
          centerCount++;
        }
      }
    }

    final border = borderEdges / max(borderCount, 1);
    final center = centerEdges / max(centerCount, 1);

    if (border <= center) return 0;
    return ((border - center) * 8).clamp(0.0, 1.0).toDouble();
  }

  double _microVariationScore(List<img.Image> images) {
    var total = 0.0;
    var pairs = 0;

    for (var i = 1; i < images.length; i++) {
      total += _frameDifference(images[i - 1], images[i]);
      pairs++;
    }

    return total / max(pairs, 1);
  }

  double _frameDifference(img.Image a, img.Image b) {
    final w = min(a.width, b.width);
    final h = min(a.height, b.height);
    var total = 0.0;
    var count = 0;

    for (var y = 0; y < h; y += 4) {
      for (var x = 0; x < w; x += 4) {
        final left = img.getLuminance(a.getPixel(x, y));
        final right = img.getLuminance(b.getPixel(x, y));
        total += (left - right).abs() / 255.0;
        count++;
      }
    }

    return total / max(count, 1);
  }

  double _localTemporalFlickerScore(List<img.Image> images) {
    if (images.length < 12) return 0;

    const tiles = 4;
    final w = images.first.width;
    final h = images.first.height;
    var strongestTile = 0.0;

    for (var ty = 0; ty < tiles; ty++) {
      for (var tx = 0; tx < tiles; tx++) {
        final series = <double>[];

        for (final image in images) {
          final x0 = (tx * w / tiles).floor();
          final x1 = ((tx + 1) * w / tiles).floor();
          final y0 = (ty * h / tiles).floor();
          final y1 = ((ty + 1) * h / tiles).floor();
          series.add(_regionMeanLuma(image, x0, y0, x1, y1));
        }

        strongestTile = max(strongestTile, _temporalPulseScore(series));
      }
    }

    return strongestTile.clamp(0.0, 1.0).toDouble();
  }

  double _refreshBandScore(List<img.Image> images) {
    if (images.length < 12) return 0;

    const bands = 12;
    var temporalBandChange = 0.0;
    var pairs = 0;

    for (var i = 1; i < images.length; i++) {
      final previous = _horizontalBandProfile(images[i - 1], bands);
      final current = _horizontalBandProfile(images[i], bands);

      var bandDelta = 0.0;
      for (var j = 0; j < bands; j++) {
        bandDelta += (current[j] - previous[j]).abs();
      }

      temporalBandChange += bandDelta / bands;
      pairs++;
    }

    final meanBandDelta = temporalBandChange / max(pairs, 1);
    final bandContrast = images
            .map((image) => _profileContrast(_horizontalBandProfile(image, bands)))
            .reduce((a, b) => a + b) /
        images.length;

    return ((meanBandDelta * 2.5) + (bandContrast * 0.6))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  List<double> _horizontalBandProfile(img.Image image, int bands) {
    final profile = <double>[];
    final h = image.height;

    for (var band = 0; band < bands; band++) {
      final y0 = (band * h / bands).floor();
      final y1 = ((band + 1) * h / bands).floor();
      profile.add(_regionMeanLuma(image, 0, y0, image.width, y1));
    }

    return profile;
  }

  double _profileContrast(List<double> profile) {
    if (profile.isEmpty) return 0;

    final mean = profile.reduce((a, b) => a + b) / profile.length;
    final variance = profile
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        profile.length;

    return sqrt(variance).clamp(0.0, 1.0).toDouble();
  }

  double _regionMeanLuma(
    img.Image image,
    int x0,
    int y0,
    int x1,
    int y1,
  ) {
    var total = 0.0;
    var count = 0;

    for (var y = y0; y < y1; y += 3) {
      for (var x = x0; x < x1; x += 3) {
        total += img.getLuminance(image.getPixel(x, y)) / 255.0;
        count++;
      }
    }

    return total / max(count, 1);
  }

  double _temporalPulseScore(List<double> series) {
    if (series.length < 6) return 0;

    final mean = series.reduce((a, b) => a + b) / series.length;
    final centered = series.map((value) => value - mean).toList();
    final energy = centered.map((value) => value.abs()).reduce((a, b) => a + b) /
        centered.length;

    if (energy < 0.01) return 0;

    var alternating = 0.0;
    var repeatedPairs = 0.0;
    var transitions = 0;

    for (var i = 1; i < centered.length; i++) {
      if (centered[i].sign != centered[i - 1].sign) {
        transitions++;
      }
      alternating += (centered[i] - centered[i - 1]).abs();
    }

    for (var i = 2; i < centered.length; i++) {
      repeatedPairs += (centered[i] - centered[i - 2]).abs();
    }

    final transitionRatio = transitions / (centered.length - 1);
    final alternatingStrength = alternating / (centered.length - 1);
    final twoFrameStability =
        1.0 - (repeatedPairs / max(centered.length - 2, 1)).clamp(0.0, 1.0);

    return ((energy * 3.0) +
            (alternatingStrength * 2.0) +
            (transitionRatio * 0.35) +
            (twoFrameStability * 0.25))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _gridLikeScore(img.Image image) {
    var alternating = 0;
    var count = 0;

    for (var y = 2; y < image.height - 2; y += 2) {
      for (var x = 2; x < image.width - 2; x += 2) {
        final center = img.getLuminance(image.getPixel(x, y));
        final horizontal = img.getLuminance(image.getPixel(x + 1, y));
        final vertical = img.getLuminance(image.getPixel(x, y + 1));

        if ((center - horizontal).abs() > 18 &&
            (center - vertical).abs() > 18) {
          alternating++;
        }
        count++;
      }
    }

    return alternating / max(count, 1);
  }

  double _round(double value) => double.parse(value.toStringAsFixed(4));
}
