import 'dart:io';

import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  final cases = <_ReplayCase>[
    _ReplayCase(
      name: 'archive13 monitor photo',
      expectedDecision: 'NON_CONCLUSIVE',
      expectedScore: 45,
      liveCaptureOnly: true,
      analyses: [
        _liveProbe(
          score: 30,
          localFlicker: 0.6672,
          refresh: 0.1600,
          fineGrid: 0.8782,
          moire: 0.5103,
        ),
      ],
    ),
    _ReplayCase(
      name: 'archive13 monitor video',
      expectedDecision: 'NON_CONCLUSIVE',
      expectedScore: 45,
      analyses: [
        _liveProbe(
          score: 30,
          localFlicker: 0.4922,
          refresh: 0.1962,
          fineGrid: 0.8002,
          moire: 0.4169,
        ),
      ],
    ),
    _ReplayCase(
      name: 'archive13 real selfie photo',
      expectedDecision: 'NO_DISPLAY_EVIDENCE',
      expectedScore: 30,
      liveCaptureOnly: true,
      analyses: [
        _liveProbe(
          score: 69,
          localFlicker: 0.1871,
          refresh: 0.1459,
          fineGrid: 0.8783,
          moire: 0.4704,
          signals: const {
            'pairedFlickerTrace': true,
            'uncorroboratedDisplayPattern': true,
          },
        ),
      ],
    ),
    _ReplayCase(
      name: 'archive13 real selfie video',
      expectedDecision: 'NO_DISPLAY_EVIDENCE',
      expectedScore: 30,
      analyses: [
        _liveProbe(
          score: 30,
          localFlicker: 0.1936,
          refresh: 0.1460,
          fineGrid: 0.8716,
          moire: 0.4676,
        ),
      ],
    ),
    _ReplayCase(
      name: 'archive11 real selfie photo',
      expectedDecision: 'NO_DISPLAY_EVIDENCE',
      expectedScore: 30,
      liveCaptureOnly: true,
      analyses: [
        _liveProbe(
          score: 70,
          localFlicker: 0.4364,
          refresh: 0.0640,
          fineGrid: 0.5254,
          moire: 0.3464,
        ),
      ],
    ),
    _ReplayCase(
      name: 'archive12 real desk photo',
      expectedDecision: 'NO_DISPLAY_EVIDENCE',
      expectedScore: 30,
      liveCaptureOnly: true,
      analyses: [
        _liveProbe(
          score: 70,
          frames: 32,
          localFlicker: 0.2688,
          refresh: 0.0512,
          fineGrid: 0.7872,
          moire: 0.3345,
        ),
      ],
    ),
    _ReplayCase(
      name: 'close paper photo',
      expectedDecision: 'NO_DISPLAY_EVIDENCE',
      expectedScore: 30,
      liveCaptureOnly: true,
      analyses: [
        _liveProbe(
          score: 70,
          frames: 38,
          localFlicker: 0.1246,
          refresh: 0.1009,
          fineGrid: 0.9863,
          moire: 0.2940,
          signals: const {'uncorroboratedDisplayPattern': true},
        ),
      ],
    ),
  ];

  var failures = 0;
  for (final replayCase in cases) {
    final result = HCVDisplayRiskFusion.combine(
      replayCase.analyses,
      liveCaptureOnly: replayCase.liveCaptureOnly,
    );
    final passed =
        result.decision == replayCase.expectedDecision &&
        result.score == replayCase.expectedScore;
    if (!passed) failures++;
    stdout.writeln(
      '${passed ? 'PASS' : 'FAIL'} | ${replayCase.name} | '
      '${result.decision} | ${result.score} | ${result.reasons.join(',')}',
    );
  }

  if (failures > 0) {
    stderr.writeln('$failures replay cases failed.');
    exitCode = 1;
  }
}

class _ReplayCase {
  const _ReplayCase({
    required this.name,
    required this.expectedDecision,
    required this.expectedScore,
    required this.analyses,
    this.liveCaptureOnly = false,
  });

  final String name;
  final String expectedDecision;
  final int expectedScore;
  final List<Map<String, dynamic>?> analyses;
  final bool liveCaptureOnly;
}

Map<String, dynamic> _liveProbe({
  required int score,
  int frames = 45,
  required double localFlicker,
  required double refresh,
  required double fineGrid,
  required double moire,
  Map<String, dynamic> signals = const {},
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'framesAnalyzed': frames,
    'displayRiskDecision': score >= 70
        ? 'STRONG_DISPLAY_RISK'
        : score >= 45
        ? 'NON_CONCLUSIVE'
        : 'NO_DISPLAY_EVIDENCE',
    'localTemporalFlickerScore': localFlicker,
    'refreshBandScore': refresh,
    'fineGridScore': fineGrid,
    'moireFrequencyScore': moire,
    'signals': signals,
  };
}
