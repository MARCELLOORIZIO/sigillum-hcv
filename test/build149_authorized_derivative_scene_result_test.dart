import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BUILD149 shows the certified original scene result on authorized video derivatives',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final verifier =
          File('lib/registry_verify_page.dart').readAsStringSync();

      final versionMatch =
          RegExp(r'^version:\s*1\.0\.0\+(\d+)\s*$', multiLine: true)
              .firstMatch(pubspec);
      expect(versionMatch, isNotNull);
      expect(int.parse(versionMatch!.group(1)!), greaterThanOrEqualTo(149));

      final authorizedStart = verifier.indexOf(
        "result = 'AUTHORIZED SUBTITLE DERIVATIVE VERIFIED';",
      );
      expect(authorizedStart, greaterThanOrEqualTo(0));

      final authorizedEnd = verifier.indexOf(
        "} else if (contentType == 'video'",
        authorizedStart,
      );
      expect(authorizedEnd, greaterThan(authorizedStart));

      final authorizedBlock =
          verifier.substring(authorizedStart, authorizedEnd);

      expect(
        authorizedBlock,
        contains('_certifiedOriginalSceneState'),
      );
      expect(
        authorizedBlock,
        contains('_authorizedSubtitleOriginalSceneDetail'),
      );
      expect(
        authorizedBlock,
        isNot(contains("scene: 'Scena originale certificata'")),
      );

      final localizedSceneBlock = verifier.substring(
        verifier.indexOf('String _localizedAxisState'),
        verifier.indexOf('String _localizedAxisDetail'),
      );
      expect(
        localizedSceneBlock,
        contains('_localizedCertifiedOriginalSceneState'),
      );

      expect(
        verifier,
        contains('String get _authorizedSubtitleOriginalSceneDetail'),
      );
      for (final detailKey in <String>[
        'realityDetail',
        'screenDetail',
        'uncertainDetail',
        'noScreenDetail',
        'notAnalyzed',
      ]) {
        expect(
          verifier,
          contains("_v('$detailKey')"),
          reason: 'Missing scene detail mapping for $detailKey',
        );
      }

      expect(
        verifier,
        contains("_r('authorizedSubtitleSceneDetail')"),
      );
    },
  );
}
