import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  test('BUILD107 native source contains same-session exposure sweep and spatial snapshot', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(source, contains('captureTemporalFrequencyDiagnosticStage'));
    expect(source, contains('SHORT_X2'));
    expect(source, contains('SHORT_X4'));
    expect(source, contains('spatialLumaGridByCell'));
    expect(source, contains('spatialGridBins: 24'));
    expect(source, contains('rowBins: 128'));
    expect(source, contains('DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION'));
  });

  test('spatial lattice diagnostic reacts to coherent 2-D periodic structure', () {
    final grid = List<List<double>>.generate(24, (y) {
      return List<double>.generate(24, (x) {
        return 0.5 + 0.2 * sin(2 * pi * x / 4) + 0.2 * sin(2 * pi * y / 6);
      });
    });
    final result = HCVTemporalFrequencyMath.analyzeSpatialLattice(grid);
    expect(result['analysisStatus'], 'ANALYZED');
    expect((result['latticeStrength'] as num).toDouble(), greaterThan(0.30));
    expect((result['horizontalPeakLag'] as num).toInt(), greaterThan(0));
    expect((result['verticalPeakLag'] as num).toInt(), greaterThan(0));
  });

  test('flat field is not a spatial lattice', () {
    final grid = List<List<double>>.generate(
      24,
      (_) => List<double>.filled(24, 0.5),
    );
    final result = HCVTemporalFrequencyMath.analyzeSpatialLattice(grid);
    expect((result['latticeStrength'] as num).toDouble(), 0.0);
  });

  test('quiet temporal signature is explicitly not positive physical reality', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesNoTemporalDisplaySignatureV31(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 2.8645,
        medianCellPeriodicityStrength: 0.007,
        medianCellFrequencyStability: 0.17,
        periodicCellCount: 0,
        stableCellCount: 0,
      ),
      isTrue,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 2.8645,
        medianCellPeriodicityStrength: 0.007,
        medianCellFrequencyStability: 0.17,
        periodicCellCount: 0,
        stableCellCount: 0,
      ),
      isFalse,
    );
  });
}
