import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  test('periodic row phase sequence is detected as stable periodic structure', () {
    const bins = 96;
    const frames = 24;
    const spatialBin = 8;
    final sequence = <List<double>>[];
    for (var frame = 0; frame < frames; frame++) {
      final phase = frame * 0.55;
      sequence.add(
        List<double>.generate(
          bins,
          (i) => 0.5 + 0.08 * sin(2 * pi * spatialBin * i / bins + phase),
        ),
      );
    }

    final result = HCVTemporalFrequencyMath.analyzeRowProfileSequence(sequence);
    expect(result['analysisStatus'], 'ANALYZED');
    expect((result['dominantRowFrequencyBin'] as int), inInclusiveRange(7, 9));
    expect((result['dominantFrequencyStability'] as double), greaterThan(0.80));
    expect((result['phaseStepConsistency'] as double), greaterThan(0.80));
    expect((result['medianTemporalDifferenceRms'] as double), greaterThan(0.005));
  });

  test('static row profile has negligible temporal difference energy', () {
    final profile = List<double>.generate(96, (i) => 0.4 + i / 10000.0);
    final sequence = List<List<double>>.generate(
      24,
      (_) => List<double>.from(profile),
    );

    final result = HCVTemporalFrequencyMath.analyzeRowProfileSequence(sequence);
    expect(result['analysisStatus'], 'ANALYZED');
    expect((result['medianTemporalDifferenceRms'] as double), lessThan(1e-9));
    expect((result['periodicityStrength'] as double), lessThan(1e-9));
  });

  test('scalar luminance modulation exposes temporal spectral concentration', () {
    final values = List<double>.generate(
      32,
      (i) => 0.5 + 0.08 * sin(2 * pi * 4 * i / 32),
    );
    final result = HCVTemporalFrequencyMath.analyzeScalarSequence(values);
    expect(result['analysisStatus'], 'ANALYZED');
    expect((result['robustFrameLumaModulationDepth'] as double), greaterThan(0.15));
    expect((result['temporalSpectralConcentration'] as double), greaterThan(0.90));
  });

  test('probe contract is explicitly shadow-only and non-decisional', () {
    final unavailable = HCVTemporalFrequencyProbe.unavailable('TEST');
    expect(unavailable['decisionRole'], 'SHADOW_ONLY_NEVER_DECISIONAL');
    expect(unavailable['productionDecisionChanged'], false);
  });
}
