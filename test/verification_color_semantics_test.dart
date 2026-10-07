import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification colors keep integrity separate from scene risk', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();

    const severeBlock =
        "  bool get _hasSevereVerificationIssue =>\n"
        "      _isInvalidResult ||\n"
        "      _isMediaNotVerified ||\n"
        "      _isUnprovenDerivative ||\n"
        "      _isOfficialReferenceModified;";

    expect(source, contains(severeBlock));
    expect(
      source,
      isNot(
        contains(
          "_isOfficialReferenceModified ||\n      _isStrongDisplayRisk",
        ),
      ),
    );

    final axisStart = source.indexOf('  Color _axisColor(String? value) {');
    final axisEnd = source.indexOf('\n  bool get _signedRealityScene', axisStart);
    expect(axisStart, greaterThanOrEqualTo(0));
    expect(axisEnd, greaterThan(axisStart));
    final axis = source.substring(axisStart, axisEnd);

    final redReturn = axis.indexOf('return Colors.red;');
    final nonVerified = axis.indexOf("normalized.contains('non verificata')");
    final orangeReturn = axis.indexOf('return Colors.orange;');

    expect(redReturn, greaterThanOrEqualTo(0));
    expect(nonVerified, greaterThan(redReturn));
    expect(orangeReturn, greaterThan(nonVerified));
    expect(axis, contains("normalized.contains('non determinata')"));
    expect(axis, contains("normalized.contains('conclusiva')"));
  });

  test('scene card remains independently red for strong display risk', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(
      source,
      contains(
        "_isStrongDisplayRisk\n"
        "                           ? Colors.red",
      ),
    );
  });
}
