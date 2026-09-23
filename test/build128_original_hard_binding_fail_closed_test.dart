import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only identical SHA-256 can label photo/video as original', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains('final forensicVerified = actualHash == expectedHash;'));
    expect(source, contains("if (forensicVerified) {"));
    expect(source, contains("'FORENSIC VERIFIED OK'"));
    expect(source, contains("'VISUAL SIMILARITY / ORIGINAL NOT VERIFIED'"));
    expect(source, contains('videoFingerprintMatches == true'));
    expect(source, contains('imageFingerprintMatches == true'));
    expect(
      RegExp(r'_unprovenDerivativeResult,').allMatches(source).length,
      2,
    );
    expect(
      RegExp(r"'SOCIAL VERIFIED OK'").allMatches(source).length,
      1,
      reason: 'Only normalized TEXT can retain the legacy SOCIAL verified label.',
    );
  });

  test('fingerprint similarity cannot trigger verified/green UI', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    final start = source.indexOf('bool get isVerified {');
    final end = source.indexOf('bool get isScreenReplayWarning', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    expect(
      source.substring(start, end),
      isNot(contains('_unprovenDerivativeResult')),
    );
    expect(source, contains('bool get _isUnprovenDerivative'));
    expect(source, contains('_isUnprovenDerivative ||'));
    expect(source, contains("if (_isUnprovenDerivative) return _r('unprovenDerivativeTitle');"));
    expect(source, contains("if (_isUnprovenDerivative) return 'Non verificata';"));
  });

  test('an altered copy cannot inherit the certified original scene verdict', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains('scene: unprovenDerivative'));
    expect(source, contains("if (_isUnprovenDerivative) return false;"));
    expect(source, contains("if (_isUnprovenDerivative) return 'Non verificata';"));
    expect(
      source,
      contains("(axis == 'integrity' || axis == 'scene')"),
    );
    expect(source, contains('color: _isUnprovenDerivative'));
  });

  test('unproven-originality warning exists in all selectable languages', () {
    final copy = File('lib/registry_verify_copy.dart').readAsStringSync();
    for (final key in <String>[
      'unprovenDerivativeTitle',
      'unprovenDerivativeStatus',
      'unprovenDerivativeDetail',
      'unprovenDerivativeProvenance',
      'unprovenDerivativeAxis',
    ]) {
      expect(
        RegExp("'$key'").allMatches(copy).length,
        4,
        reason: '$key must exist for IT, EN, ES and RU',
      );
    }
  });
}
