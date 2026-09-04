import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  test('active physical probe removes legacy live-probe missing penalty', () {
    final result = HCVDisplayRiskFusion.combine(
      const <Map<String, dynamic>?>[],
      alternativePhysicalProbeAvailable: true,
    );

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, isNot(contains('LIVE_PROBE_MISSING')));
    expect(
      result.reasons,
      contains('ACTIVE_PHYSICAL_PROBE_REPLACES_LEGACY_LIVE_PROBE'),
    );
    expect(result.analysisStatus, 'COMPLETE');
  });
}
