import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD149 shows the certified original scene result on authorized video derivatives', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final verifier = File('lib/registry_verify_page.dart').readAsStringSync();

    final versionMatch =
        RegExp(r'^version:\s*1\.0\.0\+(\d+)\s*$', multiLine: true)
            .firstMatch(pubspec);
    expect(versionMatch, isNotNull);
    expect(int.parse(versionMatch!.group(1)!), greaterThanOrEqualTo(149));

    expect(
      verifier,
      contains("scene: _signedRealityScene"),
    );
    expect(
      verifier,
      contains(": _certifiedOriginalSceneState"),
    );
    expect(
      verifier,
      contains("return _localizedCertifiedOriginalSceneState;"),
    );
    expect(
      verifier,
      contains("return _authorizedSubtitleOriginalSceneDetail;"),
    );
    expect(
      verifier,
      contains("detail = _v('realityDetail');"),
    );
    expect(
      verifier,
      contains("detail = _v('screenDetail');"),
    );
    expect(
      verifier,
      contains("detail = _v('uncertainDetail');"),
    );
    expect(
      verifier,
      contains("detail = _v('noScreenDetail');"),
    );
    expect(
      verifier,
      contains("_r('authorizedSubtitleSceneDetail')"),
    );
  });
}
