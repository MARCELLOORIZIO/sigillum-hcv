import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_capture_timestamp.dart';

void main() {
  test('formats capture time with date, seconds and UTC offset', () {
    final timestamp = HCVCaptureTimestamp.format(
      DateTime(2026, 7, 21, 14, 5, 9),
    );

    expect(timestamp, startsWith('21/07/2026 14:05:09 UTC'));
    expect(timestamp, matches(RegExp(r'UTC[+-]\d{2}:\d{2}$')));
  });
}
