import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  bool gate({
    required double frequencyHz,
    required double modulation,
    required double concentration,
    required double periodicity,
    required double stability,
    double phase = 0.55,
    int periodicCells = 8,
    int stableCells = 8,
  }) {
    return HCVTemporalFrequencyProbe.qualifiesCoherentDisplayPeriodicity(
      actualFps: 240.62,
      framesAnalyzed: 84,
      shortExposureVerified: true,
      exposureLocked: true,
      dominantTemporalFrequencyHz: frequencyHz,
      globalModulationDepth: modulation,
      globalSpectralConcentration: concentration,
      medianCellPeriodicityStrength: periodicity,
      medianCellFrequencyStability: stability,
      medianCellPhaseStepConsistency: phase,
      periodicCellCount: periodicCells,
      stableCellCount: stableCells,
    );
  }

  test('B6D full-frame TV signature remains strong', () {
    expect(
      gate(
        frequencyHz: 100.26,
        modulation: 1.19,
        concentration: 0.909,
        periodicity: 0.184,
        stability: 0.916,
      ),
      isTrue,
    );
  });

  test('3A3 full-frame TV signature remains strong', () {
    expect(
      gate(
        frequencyHz: 100.26,
        modulation: 1.44,
        concentration: 0.902,
        periodicity: 0.167,
        stability: 0.928,
      ),
      isTrue,
    );
  });

  test('D7A semantic reality false negative is recovered physically', () {
    expect(
      gate(
        frequencyHz: 100.26,
        modulation: 0.98,
        concentration: 0.895,
        periodicity: 0.208,
        stability: 0.916,
      ),
      isTrue,
    );
  });

  test('4300 semantic reality false negative is recovered physically', () {
    expect(
      gate(
        frequencyHz: 100.26,
        modulation: 1.15,
        concentration: 0.899,
        periodicity: 0.223,
        stability: 0.928,
      ),
      isTrue,
    );
  });

  test('reflective framed artwork does not satisfy HFR display gate', () {
    expect(
      gate(
        frequencyHz: 2.86,
        modulation: 0.026,
        concentration: 0.95,
        periodicity: 0.008,
        stability: 0.92,
        periodicCells: 0,
      ),
      isFalse,
    );
  });

  test(
    'TV visible only as part of a real room does not satisfy full-frame gate',
    () {
      expect(
        gate(
          frequencyHz: 100.26,
          modulation: 0.108,
          concentration: 0.90,
          periodicity: 0.022,
          stability: 0.90,
          periodicCells: 2,
        ),
        isFalse,
      );
    },
  );

  test('gate requires verified short locked exposure', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesCoherentDisplayPeriodicity(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: false,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.26,
        globalModulationDepth: 1.0,
        globalSpectralConcentration: 0.90,
        medianCellPeriodicityStrength: 0.20,
        medianCellFrequencyStability: 0.92,
        medianCellPhaseStepConsistency: 0.55,
        periodicCellCount: 8,
        stableCellCount: 8,
      ),
      isFalse,
    );
  });
}
