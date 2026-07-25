import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_trust_analyzer.dart';

void main() {
  test('standard capture mode no longer exposes studio or field', () {
    final result = HCVTrustAnalyzer.analyze(
      liveSignals: <String, dynamic>{
        'accelerometerSamples': 30,
        'gyroscopeSamples': 30,
        'accelerometerMotionScore': 0.60,
        'gyroscopeMotionScore': 0.12,
        'continuity': 'RECORDED',
      },
      audioCaptured: true,
      captureMode: 'studio',
    );

    expect(result['captureMode'], 'standard');
    expect(result['trustLevel'], 'HCV_LIVE');
    expect(result['liveCaptureTrust'], 'HIGH');
    expect(result['note'].toString(), isNot(contains('Studio')));
    expect(result['note'].toString(), isNot(contains('Field')));
  });
}
