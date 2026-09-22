import 'dart:math';

import 'package:image/image.dart' as img;

/// Physical-texture guard used only as negative corroboration for strong
/// semantic SCREEN classifications.
///
/// It does not prove REALITY and it must never override positive HFR or
/// structural optical display evidence. The goal is narrower: distinguish
/// globally repetitive physical textures (fabric, perforation, mesh) from
/// display-like lattice evidence when V2 semantics are over-confident.
class HCVDisplayLatticeEvidence {
  const HCVDisplayLatticeEvidence({
    required this.repetitiveTextureScore,
    required this.latticeRegularityScore,
    required this.latticeDefectScore,
    required this.macroPatternScore,
    required this.rgbPhaseConsistencyScore,
    required this.dominantPatternPeriodPx,
    required this.physicalRepeatingTextureLikely,
  });

  final double repetitiveTextureScore;
  final double latticeRegularityScore;
  final double latticeDefectScore;
  final double macroPatternScore;
  final double rgbPhaseConsistencyScore;
  final double dominantPatternPeriodPx;
  final bool physicalRepeatingTextureLikely;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'repetitiveTextureScore': _round(repetitiveTextureScore),
        'latticeRegularityScore': _round(latticeRegularityScore),
        'latticeDefectScore': _round(latticeDefectScore),
        'macroPatternScore': _round(macroPatternScore),
        'rgbPhaseConsistencyScore': _round(rgbPhaseConsistencyScore),
        'dominantPatternPeriodPx': _round(dominantPatternPeriodPx),
        'physicalRepeatingTextureLikely': physicalRepeatingTextureLikely,
      };

  static double _round(double value) =>
      (value * 10000).roundToDouble() / 10000.0;
}

class HCVDisplayLatticeDiscriminator {
  const HCVDisplayLatticeDiscriminator._();

  static HCVDisplayLatticeEvidence analyze(img.Image source) {
    if (source.width < 64 || source.height < 64) {
      return _empty();
    }

    final top = (source.height * 0.12).round().clamp(0, source.height - 1);
    final content = img.copyCrop(
      source,
      x: 0,
      y: top,
      width: source.width,
      height: source.height - top,
    );

    final targetWidth = min(360, content.width);
    final targetHeight = max(
      64,
      (content.height * targetWidth / content.width).round(),
    );
    final working = img.copyResize(
      content,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );

    final horizontal = _axisEvidence(
      working,
      horizontal: true,
      sourceScale: content.width / working.width,
    );
    final vertical = _axisEvidence(
      working,
      horizontal: false,
      sourceScale: content.height / working.height,
    );

    final dominant =
        horizontal.repetitionScore >= vertical.repetitionScore
            ? horizontal
            : vertical;
    final repetitiveTextureScore =
        max(horizontal.repetitionScore, vertical.repetitionScore);
    final latticeRegularityScore = dominant.periodRegularity;
    final latticeDefectScore =
        repetitiveTextureScore < 0.25 ? 0.0 : 1.0 - latticeRegularityScore;
    final dominantPatternPeriodPx = dominant.dominantPeriodSourcePx;

    final macroPatternScore = (repetitiveTextureScore *
            ((dominantPatternPeriodPx - 6.0) / 18.0).clamp(0.0, 1.0))
        .clamp(0.0, 1.0)
        .toDouble();

    final rgbPhaseConsistencyScore = _rgbPhaseConsistencyScore(working);

    // Conservative guard:
    // - requires broad, strong repetitive coverage;
    // - requires little/no repeating RGB sub-pixel phase;
    // - requires either measurable spacing defects or a clearly macro-scale
    //   repeated pattern.
    //
    // Positive HFR/optical display evidence is handled by the fusion policy
    // before this flag is allowed to affect a verdict.
    final physicalRepeatingTextureLikely = repetitiveTextureScore >= 0.55 &&
        rgbPhaseConsistencyScore < 0.30 &&
        (latticeDefectScore >= 0.30 || macroPatternScore >= 0.65);

    return HCVDisplayLatticeEvidence(
      repetitiveTextureScore: repetitiveTextureScore,
      latticeRegularityScore: latticeRegularityScore,
      latticeDefectScore: latticeDefectScore,
      macroPatternScore: macroPatternScore,
      rgbPhaseConsistencyScore: rgbPhaseConsistencyScore,
      dominantPatternPeriodPx: dominantPatternPeriodPx,
      physicalRepeatingTextureLikely: physicalRepeatingTextureLikely,
    );
  }

  static HCVDisplayLatticeEvidence analyzeSequence(List<img.Image> images) {
    if (images.isEmpty) return _empty();

    final sampled = <img.Image>[];
    if (images.length <= 3) {
      sampled.addAll(images);
    } else {
      sampled
        ..add(images.first)
        ..add(images[images.length ~/ 2])
        ..add(images.last);
    }

    final evidence = sampled.map(analyze).toList();
    double mean(double Function(HCVDisplayLatticeEvidence e) pick) =>
        evidence.map(pick).reduce((a, b) => a + b) / evidence.length;

    final likelyCount =
        evidence.where((item) => item.physicalRepeatingTextureLikely).length;
    final required = max(2, (evidence.length / 2).ceil());

    final periods = evidence
        .map((item) => item.dominantPatternPeriodPx)
        .where((value) => value > 0)
        .toList()
      ..sort();
    final medianPeriod = periods.isEmpty
        ? 0.0
        : periods.length.isOdd
            ? periods[periods.length ~/ 2]
            : (periods[periods.length ~/ 2 - 1] +
                    periods[periods.length ~/ 2]) /
                2.0;

    return HCVDisplayLatticeEvidence(
      repetitiveTextureScore: mean((e) => e.repetitiveTextureScore),
      latticeRegularityScore: mean((e) => e.latticeRegularityScore),
      latticeDefectScore: mean((e) => e.latticeDefectScore),
      macroPatternScore: mean((e) => e.macroPatternScore),
      rgbPhaseConsistencyScore: mean((e) => e.rgbPhaseConsistencyScore),
      dominantPatternPeriodPx: medianPeriod,
      physicalRepeatingTextureLikely: likelyCount >= required,
    );
  }

  static _AxisEvidence _axisEvidence(
    img.Image image, {
    required bool horizontal,
    required double sourceScale,
  }) {
    const stripCount = 12;
    final correlations = <double>[];
    final strongPeriods = <double>[];

    final outerLimit = horizontal ? image.height : image.width;
    final innerLimit = horizontal ? image.width : image.height;
    if (outerLimit < stripCount * 2 || innerLimit < 48) {
      return const _AxisEvidence();
    }

    for (var strip = 0; strip < stripCount; strip++) {
      final start = (outerLimit * strip / stripCount).floor();
      final end =
          max(start + 1, (outerLimit * (strip + 1) / stripCount).floor());
      final profile = <double>[];

      for (var inner = 0; inner < innerLimit; inner++) {
        var total = 0.0;
        var count = 0;
        for (var outer = start; outer < min(end, outerLimit); outer += 2) {
          final pixel = horizontal
              ? image.getPixel(inner, outer)
              : image.getPixel(outer, inner);
          total += img.getLuminance(pixel);
          count++;
        }
        profile.add(count == 0 ? 0.0 : total / count);
      }

      if (profile.length < 32) continue;
      final diffs = <double>[
        for (var i = 1; i < profile.length; i++)
          (profile[i] - profile[i - 1]).abs(),
      ];
      final best = _bestPeriodCorrelation(diffs);
      if (best.correlation <= 0) continue;
      correlations.add(best.correlation);
      if (best.correlation >= 0.58 && best.period > 0) {
        strongPeriods.add(best.period.toDouble());
      }
    }

    if (correlations.isEmpty) return const _AxisEvidence();

    final coverage = strongPeriods.length / correlations.length;
    final strongCorrelations = <double>[];
    for (var i = 0; i < correlations.length; i++) {
      if (correlations[i] >= 0.58) strongCorrelations.add(correlations[i]);
    }
    final meanStrong = strongCorrelations.isEmpty
        ? 0.0
        : strongCorrelations.reduce((a, b) => a + b) /
            strongCorrelations.length;
    final repetitionScore =
        (coverage * meanStrong).clamp(0.0, 1.0).toDouble();

    double periodRegularity = 0.0;
    double dominantPeriod = 0.0;
    if (strongPeriods.isNotEmpty) {
      strongPeriods.sort();
      dominantPeriod = _median(strongPeriods);
      if (strongPeriods.length >= 2 && dominantPeriod > 0) {
        final mean =
            strongPeriods.reduce((a, b) => a + b) / strongPeriods.length;
        final variance = strongPeriods
                .map((value) => pow(value - mean, 2).toDouble())
                .reduce((a, b) => a + b) /
            strongPeriods.length;
        final cv = sqrt(variance) / max(mean, 1.0);
        periodRegularity =
            (1.0 - (cv / 0.30)).clamp(0.0, 1.0).toDouble();
      } else if (strongPeriods.length == 1) {
        periodRegularity = 0.25;
      }
    }

    return _AxisEvidence(
      repetitionScore: repetitionScore,
      periodRegularity: periodRegularity,
      dominantPeriodSourcePx: dominantPeriod * sourceScale,
    );
  }

  static _PeriodCorrelation _bestPeriodCorrelation(List<double> values) {
    if (values.length < 32) return const _PeriodCorrelation();

    final mean = values.reduce((a, b) => a + b) / values.length;
    final centered = values.map((value) => value - mean).toList();
    final maxPeriod = min(40, max(3, centered.length ~/ 3));

    var bestCorrelation = 0.0;
    var bestPeriod = 0;

    for (var period = 3; period <= maxPeriod; period++) {
      var dot = 0.0;
      var leftEnergy = 0.0;
      var rightEnergy = 0.0;
      for (var i = period; i < centered.length; i++) {
        final a = centered[i];
        final b = centered[i - period];
        dot += a * b;
        leftEnergy += a * a;
        rightEnergy += b * b;
      }

      if (leftEnergy <= 1e-9 || rightEnergy <= 1e-9) continue;
      final correlation = dot / sqrt(leftEnergy * rightEnergy);
      if (correlation > bestCorrelation) {
        bestCorrelation = correlation;
        bestPeriod = period;
      }
    }

    return _PeriodCorrelation(
      correlation: bestCorrelation.clamp(0.0, 1.0).toDouble(),
      period: bestPeriod,
    );
  }

  static double _rgbPhaseConsistencyScore(img.Image image) {
    final lineScores = <double>[];

    void analyzeLine(List<img.Pixel> pixels) {
      if (pixels.length < 40) return;
      final labels = <int>[];
      final present = <int>{};
      final channelCounts = <int, int>{1: 0, 2: 0, 3: 0};

      for (final pixel in pixels) {
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final maxChannel = max(r, max(g, b));
        final minChannel = min(r, min(g, b));
        if (maxChannel - minChannel < 18.0) {
          labels.add(0);
          continue;
        }
        final label = r >= g && r >= b
            ? 1
            : g >= r && g >= b
                ? 2
                : 3;
        labels.add(label);
        present.add(label);
        channelCounts[label] = (channelCounts[label] ?? 0) + 1;
      }

      if (present.length < 2) return;
      final activeCounts = channelCounts.values
          .where((count) => count > 0)
          .toList()
        ..sort();
      if (activeCounts.length < 2) return;
      final channelBalance =
          activeCounts.first / max(activeCounts.last, 1);
      if (channelBalance < 0.12) return;

      final colored =
          labels.where((label) => label != 0).length / labels.length;
      if (colored < 0.08) return;

      var best = 0.0;
      for (var period = 2; period <= 12; period++) {
        var compared = 0;
        var matched = 0;
        for (var i = period; i < labels.length; i++) {
          final a = labels[i];
          final b = labels[i - period];
          if (a == 0 || b == 0) continue;
          compared++;
          if (a == b) matched++;
        }
        if (compared < 12) continue;
        final score = (matched / compared) * min(1.0, colored * 2.5);
        best = max(best, score);
      }
      lineScores.add(best);
    }

    final horizontalStep = max(1, image.height ~/ 8);
    for (var y = horizontalStep ~/ 2;
        y < image.height;
        y += horizontalStep) {
      analyzeLine(<img.Pixel>[for (var x = 0; x < image.width; x++) image.getPixel(x, y)]);
    }

    final verticalStep = max(1, image.width ~/ 8);
    for (var x = verticalStep ~/ 2; x < image.width; x += verticalStep) {
      analyzeLine(<img.Pixel>[for (var y = 0; y < image.height; y++) image.getPixel(x, y)]);
    }

    if (lineScores.isEmpty) return 0.0;
    lineScores.sort();
    final topCount = max(1, (lineScores.length * 0.25).ceil());
    final top = lineScores.sublist(lineScores.length - topCount);
    return (top.reduce((a, b) => a + b) / top.length)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static double _median(List<double> sorted) {
    if (sorted.isEmpty) return 0.0;
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  static HCVDisplayLatticeEvidence _empty() =>
      const HCVDisplayLatticeEvidence(
        repetitiveTextureScore: 0,
        latticeRegularityScore: 0,
        latticeDefectScore: 0,
        macroPatternScore: 0,
        rgbPhaseConsistencyScore: 0,
        dominantPatternPeriodPx: 0,
        physicalRepeatingTextureLikely: false,
      );
}

class _AxisEvidence {
  const _AxisEvidence({
    this.repetitionScore = 0,
    this.periodRegularity = 0,
    this.dominantPeriodSourcePx = 0,
  });

  final double repetitionScore;
  final double periodRegularity;
  final double dominantPeriodSourcePx;
}

class _PeriodCorrelation {
  const _PeriodCorrelation({
    this.correlation = 0,
    this.period = 0,
  });

  final double correlation;
  final int period;
}
