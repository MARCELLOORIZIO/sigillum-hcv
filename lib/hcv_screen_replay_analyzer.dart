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
            "-vf \"fps=15,scale=720:720:force_original_aspect_ratio=decrease,"
            "pad=720:720:(ow-iw)/2:(oh-ih)/2\" "
            "-frames:v 30 '$framePattern'";

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
      final pixelGridUniformityScore = _pixelGridUniformityScore(decoded);
      final bandScore = _profileContrast(_horizontalBandProfile(image, 16));

      final flatSceneUniformity = uniformityScore > 0.74;
      final rectangularDisplayEdges = rectangleEdgeScore > 0.62;
      final strongRectangularDisplayEdges = rectangleEdgeScore > 0.70;
      final pixelGridOrMoireHint = gridScore > 0.34;
      final weakUniformPixelGrid = pixelGridUniformityScore > 0.12;
      final uniformPixelGrid = pixelGridUniformityScore > 0.20;
      final strongHorizontalBands = bandScore > 0.22;
      final mediumHorizontalBands = bandScore > 0.16;
      final structuralDisplayTrace = uniformPixelGrid ||
          pixelGridOrMoireHint ||
          strongRectangularDisplayEdges ||
          (weakUniformPixelGrid && mediumHorizontalBands);

      var riskScore = 0;
      if (structuralDisplayTrace) {
        if (flatSceneUniformity) riskScore += 10;
        if (rectangularDisplayEdges) riskScore += 20;
        if (pixelGridOrMoireHint) riskScore += 30;
        if (uniformPixelGrid) {
          riskScore += 40;
        } else if (weakUniformPixelGrid) {
          riskScore += 20;
        }
        if (strongHorizontalBands) {
          riskScore += 30;
        } else if (mediumHorizontalBands) {
          riskScore += 15;
        }
      } else if (mediumHorizontalBands && rectangularDisplayEdges) {
        riskScore = 25;
      }

      if (!structuralDisplayTrace && bandScore < 0.28) {
        riskScore = min(riskScore, 30);
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
        'pixelGridUniformityScore': _round(pixelGridUniformityScore),
        'refreshBandScore': _round(bandScore),
        'localTemporalFlickerScore': null,
        'signals': {
          'rectangularDisplayEdges': rectangularDisplayEdges,
          'flatSceneUniformity': flatSceneUniformity,
          'pixelGridOrMoireHint': pixelGridOrMoireHint,
          'uniformPixelGrid': uniformPixelGrid,
          'horizontalRefreshBands': mediumHorizontalBands,
          'structuralDisplayTrace': structuralDisplayTrace,
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
        images.map(_rectangleEdgeScore).reduce((a, b) => a + b) / images.length;
    final microVariationScore = _microVariationScore(images);
    final gridScore =
        images.map(_gridLikeScore).reduce((a, b) => a + b) / images.length;
    final pixelGridImages = _sampleImages(images, maxSamples: 6);
    final pixelGridUniformityScore =
        pixelGridImages.map(_pixelGridUniformityScore).reduce((a, b) => a + b) /
            pixelGridImages.length;
    final localTemporalFlickerScore = _localTemporalFlickerScore(images);
    final refreshBandScore = _refreshBandScore(images);

    final displayFlicker = flickerScore > 0.12;
    final rectangularDisplayEdges = rectangleEdgeScore > 0.62;
    final strongRectangularDisplayEdges = rectangleEdgeScore > 0.70;
    final flatSceneUniformity = uniformityScore > 0.74;
    final lowMicroVariation = microVariationScore < 0.035;
    final pixelGridOrMoireHint = gridScore > 0.34;
    final uniformPixelGrid = pixelGridUniformityScore > 0.20;
    final localRefreshFlicker = localTemporalFlickerScore > 0.24;
    final horizontalRefreshBands = refreshBandScore > 0.16;
    final pairedLocalRefresh =
        localTemporalFlickerScore > 0.28 && refreshBandScore > 0.11;
    final structuralDisplayTrace = uniformPixelGrid ||
        pixelGridOrMoireHint ||
        strongRectangularDisplayEdges ||
        (rectangularDisplayEdges && refreshBandScore > 0.14);
    final strongDisplayTrace = uniformPixelGrid ||
        horizontalRefreshBands ||
        (pairedLocalRefresh && structuralDisplayTrace) ||
        (pixelGridOrMoireHint && rectangularDisplayEdges);

    var riskScore = 0;
    if (strongDisplayTrace) {
      if (displayFlicker) riskScore += 15;
      if (rectangularDisplayEdges) riskScore += 20;
      if (flatSceneUniformity) riskScore += 10;
      if (lowMicroVariation) riskScore += 5;
      if (pixelGridOrMoireHint) riskScore += 20;
      if (uniformPixelGrid) riskScore += 35;
      if (pairedLocalRefresh) riskScore += 30;
      if (horizontalRefreshBands) riskScore += 35;
    } else if ((localRefreshFlicker && refreshBandScore > 0.08) ||
        lowMicroVariation ||
        flatSceneUniformity) {
      riskScore = 20;
    }
    if (!structuralDisplayTrace && refreshBandScore < 0.14) {
      riskScore = min(riskScore, 30);
    }
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
      'pixelGridUniformityScore': _round(pixelGridUniformityScore),
      'localTemporalFlickerScore': _round(localTemporalFlickerScore),
      'refreshBandScore': _round(refreshBandScore),
      'signals': {
        'displayFlicker': displayFlicker,
        'rectangularDisplayEdges': rectangularDisplayEdges,
        'flatSceneUniformity': flatSceneUniformity,
        'lowMicroVariation': lowMicroVariation,
        'pixelGridOrMoireHint': pixelGridOrMoireHint,
        'uniformPixelGrid': uniformPixelGrid,
        'localRefreshFlicker': localRefreshFlicker,
        'horizontalRefreshBands': horizontalRefreshBands,
        'pairedLocalRefresh': pairedLocalRefresh,
        'structuralDisplayTrace': structuralDisplayTrace,
        'strongDisplayTrace': strongDisplayTrace,
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
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
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
            .map((image) =>
                _profileContrast(_horizontalBandProfile(image, bands)))
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
    final energy =
        centered.map((value) => value.abs()).reduce((a, b) => a + b) /
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

  double _pixelGridUniformityScore(img.Image image) {
    if (image.width < 80 || image.height < 80) return 0;

    final cropScores = <double>[];
    final minSide = min(image.width, image.height);
    final cropSizes = <int>{
      min(360, max(96, (minSide * 0.32).round())),
      min(240, max(80, (minSide * 0.22).round())),
      min(160, max(72, (minSide * 0.16).round())),
    }.where((size) => size < image.width && size < image.height).toList();

    final centers = <Point<double>>[
      for (final y in [0.18, 0.34, 0.50, 0.66, 0.82])
        for (final x in [0.18, 0.34, 0.50, 0.66, 0.82]) Point(x, y),
    ];

    for (final cropSize in cropSizes) {
      for (final center in centers) {
        final x = (image.width * center.x - cropSize / 2)
            .round()
            .clamp(0, image.width - cropSize)
            .toInt();
        final y = (image.height * center.y - cropSize / 2)
            .round()
            .clamp(0, image.height - cropSize)
            .toInt();
        final crop = img.copyCrop(
          image,
          x: x,
          y: y,
          width: cropSize,
          height: cropSize,
        );
        final zoomed = img.copyResize(
          crop,
          width: 320,
          height: 320,
          interpolation: img.Interpolation.nearest,
        );

        final horizontal = _axisPeriodicityScore(zoomed, horizontal: true);
        final vertical = _axisPeriodicityScore(zoomed, horizontal: false);
        final colorGrid = _colorSubpixelPeriodicityScore(zoomed);
        final pairedScore = max(sqrt(horizontal * vertical), colorGrid);
        if (pairedScore > 0) {
          cropScores.add(pairedScore);
        }
      }
    }

    if (cropScores.isEmpty) return 0;

    cropScores.sort();
    final topCount = min(8, cropScores.length);
    final top = cropScores.sublist(cropScores.length - topCount);
    final topMean = top.reduce((a, b) => a + b) / top.length;
    final repeatedStrongCrops =
        cropScores.where((score) => score > 0.16).length / cropScores.length;

    return ((topMean * 0.75) + (repeatedStrongCrops * 0.25))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _axisPeriodicityScore(
    img.Image image, {
    required bool horizontal,
  }) {
    final values = <double>[];
    final outerLimit = horizontal ? image.height : image.width;
    final innerLimit = horizontal ? image.width : image.height;

    for (var outer = 10; outer < outerLimit - 10; outer += 6) {
      final diffs = <double>[];

      for (var inner = 2; inner < innerLimit - 2; inner++) {
        final current = horizontal
            ? img.getLuminance(image.getPixel(inner, outer))
            : img.getLuminance(image.getPixel(outer, inner));
        final previous = horizontal
            ? img.getLuminance(image.getPixel(inner - 1, outer))
            : img.getLuminance(image.getPixel(outer, inner - 1));

        diffs.add((current - previous).abs() / 255.0);
      }

      values.add(_periodicEdgeScore(diffs));
    }

    if (values.isEmpty) return 0;

    values.sort();
    final topCount = max(1, (values.length * 0.25).ceil());
    final top = values.sublist(values.length - topCount);

    return top.reduce((a, b) => a + b) / top.length;
  }

  double _colorSubpixelPeriodicityScore(img.Image image) {
    final horizontal = _axisColorPeriodicityScore(image, horizontal: true);
    final vertical = _axisColorPeriodicityScore(image, horizontal: false);

    return max(horizontal, vertical).clamp(0.0, 1.0).toDouble();
  }

  double _axisColorPeriodicityScore(
    img.Image image, {
    required bool horizontal,
  }) {
    final values = <double>[];
    final outerLimit = horizontal ? image.height : image.width;
    final innerLimit = horizontal ? image.width : image.height;

    for (var outer = 12; outer < outerLimit - 12; outer += 8) {
      final diffs = <double>[];

      for (var inner = 2; inner < innerLimit - 2; inner++) {
        final current = horizontal
            ? image.getPixel(inner, outer)
            : image.getPixel(outer, inner);
        final previous = horizontal
            ? image.getPixel(inner - 1, outer)
            : image.getPixel(outer, inner - 1);

        final currentChroma = _pixelChroma(current);
        final previousChroma = _pixelChroma(previous);
        diffs.add((currentChroma - previousChroma).abs());
      }

      values.add(_periodicEdgeScore(diffs));
    }

    if (values.isEmpty) return 0;

    values.sort();
    final topCount = max(1, (values.length * 0.20).ceil());
    final top = values.sublist(values.length - topCount);

    return top.reduce((a, b) => a + b) / top.length;
  }

  double _pixelChroma(img.Pixel pixel) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    final maxChannel = max(r, max(g, b));
    final minChannel = min(r, min(g, b));

    return (maxChannel - minChannel) / 255.0;
  }

  double _periodicEdgeScore(List<double> diffs) {
    if (diffs.length < 24) return 0;

    var best = 0.0;

    for (var period = 2; period <= 10; period++) {
      var aligned = 0.0;
      var total = 0.0;
      var count = 0;

      for (var i = period; i < diffs.length; i++) {
        final a = diffs[i];
        final b = diffs[i - period];
        aligned += min(a, b);
        total += max(a, b);
        count++;
      }

      if (count == 0 || total <= 0) continue;

      final periodicity = aligned / total;
      final contrast = diffs.reduce((a, b) => a + b) / diffs.length;
      final score = periodicity * min(1.0, contrast * 8.0);
      best = max(best, score);
    }

    return best.clamp(0.0, 1.0).toDouble();
  }

  List<img.Image> _sampleImages(
    List<img.Image> images, {
    required int maxSamples,
  }) {
    if (images.length <= maxSamples) return images;

    final sampled = <img.Image>[];
    final step = (images.length - 1) / (maxSamples - 1);
    for (var i = 0; i < maxSamples; i++) {
      sampled.add(images[(i * step).round()]);
    }
    return sampled;
  }

  double _round(double value) => double.parse(value.toStringAsFixed(4));
}
