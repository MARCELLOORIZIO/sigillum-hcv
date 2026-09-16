from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected exactly one patch target, found {count}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


# ---------------------------------------------------------------------------
# OCR: add a bounded Registry-recovery helper. This deliberately does NOT
# normalize C/0 or B/8 globally because both sides are valid hexadecimal. Only
# one character is changed per candidate and the global candidate count is
# capped, so recovery cannot explode combinatorially.
# ---------------------------------------------------------------------------
ocr_path = 'lib/hcv_media_id_ocr.dart'
ocr_old = '''  static Future<String?> extractFromImage(String path) async {
    final candidates = await extractCandidatesFromImage(path);
    return candidates.isEmpty ? null : candidates.first;
  }

  static Future<String?> _recognizePath(String path) async {
'''
ocr_new = '''  static Future<String?> extractFromImage(String path) async {
    final candidates = await extractCandidatesFromImage(path);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Builds a deterministic, bounded set of one-character alternatives for
  /// Registry recovery after OCR has produced a syntactically valid HCV-ID
  /// that is absent online. C/0 and B/8 are both valid hexadecimal pairs, so
  /// changing them during normal OCR parsing would silently rewrite valid IDs.
  /// Recovery therefore changes exactly one ambiguous character at a time.
  static List<String> buildRegistryRecoveryVariants(
    Iterable<String> candidateIds, {
    int maxVariants = 16,
  }) {
    if (maxVariants <= 0) return const <String>[];

    final seen = <String>{};
    final bases = <String>[];
    for (final raw in candidateIds) {
      final id = raw.trim().toUpperCase();
      if (!RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(id)) continue;
      if (seen.add(id)) bases.add(id);
    }

    final variants = <String>[];
    for (final base in bases) {
      final payload = base.substring(4).split('');
      for (var i = 0; i < payload.length; i++) {
        final alternate = switch (payload[i]) {
          '0' => 'C',
          'C' => '0',
          '8' => 'B',
          'B' => '8',
          _ => null,
        };
        if (alternate == null) continue;

        final changed = List<String>.from(payload);
        changed[i] = alternate;
        final candidate = 'HCV-${changed.join()}';
        if (!seen.add(candidate)) continue;
        variants.add(candidate);
        if (variants.length >= maxVariants) return variants;
      }
    }
    return variants;
  }

  static Future<String?> _recognizePath(String path) async {
'''
replace_once(ocr_path, ocr_old, ocr_new)


# ---------------------------------------------------------------------------
# Registry verification: leave the generic/video/text recovery unchanged.
# PHOTO verification gets an exact-fetch path so robust OCR candidates are
# tried before any bounded one-edit fallback. Variant attempts happen only
# after real Registry notFound responses; network/server errors are rethrown.
# ---------------------------------------------------------------------------
registry_path = 'lib/registry_verify_page.dart'
registry_fetch_old = '''  Future<MapEntry<String, Map<String, dynamic>>> _fetchCertificate(
    String hcvId,
  ) async {
    try {
      return MapEntry(hcvId, await registry.fetchCertificate(hcvId));
    } catch (originalError) {
      for (final candidate in _b8Variants(hcvId)) {
        try {
          return MapEntry(
            candidate,
            await registry.fetchCertificate(candidate),
          );
        } catch (_) {}
      }

      throw originalError;
    }
  }

  Future<File?> _findLocalCertificate(String hcvId) async {
'''
registry_fetch_new = '''  Future<MapEntry<String, Map<String, dynamic>>> _fetchCertificate(
    String hcvId,
  ) async {
    try {
      return MapEntry(hcvId, await registry.fetchCertificate(hcvId));
    } catch (originalError) {
      for (final candidate in _b8Variants(hcvId)) {
        try {
          return MapEntry(
            candidate,
            await registry.fetchCertificate(candidate),
          );
        } catch (_) {}
      }

      throw originalError;
    }
  }

  Future<MapEntry<String, Map<String, dynamic>>> _fetchCertificateExact(
    String hcvId,
  ) async {
    return MapEntry(hcvId, await registry.fetchCertificate(hcvId));
  }

  Future<File?> _findLocalCertificate(String hcvId) async {
'''
replace_once(registry_path, registry_fetch_old, registry_fetch_new)

registry_photo_old = '''  Future<MapEntry<String, Map<String, dynamic>>>
  _fetchCertificateWithPhotoOcrRecovery(String hcvId) async {
    try {
      return await _fetchCertificateWithLocalRecovery(hcvId);
    } on HCVRegistryException catch (originalError) {
      final path = mediaPath;
      if (originalError.kind != HCVRegistryFailureKind.notFound ||
          path == null) {
        rethrow;
      }

      final lower = path.toLowerCase();
      final isPhoto =
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png');
      if (!isPhoto) rethrow;

      final candidates = await HCVMediaIdOcr.extractCandidatesFromImage(path);
      for (final candidate in candidates) {
        if (candidate == hcvId) continue;
        try {
          return await _fetchCertificate(candidate);
        } on HCVRegistryException catch (candidateError) {
          if (candidateError.kind == HCVRegistryFailureKind.notFound) {
            continue;
          }
          rethrow;
        }
      }

      throw originalError;
    }
  }
'''
registry_photo_new = '''  Future<MapEntry<String, Map<String, dynamic>>>
  _fetchCertificateWithPhotoOcrRecovery(String hcvId) async {
    final path = mediaPath;
    if (path == null) {
      return await _fetchCertificateWithLocalRecovery(hcvId);
    }

    final lower = path.toLowerCase();
    final isPhoto =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    if (!isPhoto) {
      return await _fetchCertificateWithLocalRecovery(hcvId);
    }

    late HCVRegistryException originalNotFound;
    try {
      return await _fetchCertificateExact(hcvId);
    } on HCVRegistryException catch (error) {
      if (error.kind != HCVRegistryFailureKind.notFound) rethrow;
      originalNotFound = error;
    }

    // A Registry 404 from the first OCR reading is the only condition that
    // enables deeper PHOTO recovery. Re-read independent crops first because
    // they can directly recover the correct visible ID without guessing.
    final rankedCandidates =
        await HCVMediaIdOcr.extractCandidatesFromImage(path);
    final attemptedIds = <String>{hcvId};
    final recoveryBases = <String>[hcvId];

    for (final rawCandidate in rankedCandidates) {
      final candidate = rawCandidate.trim().toUpperCase();
      if (!RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(candidate)) continue;
      if (!recoveryBases.contains(candidate)) recoveryBases.add(candidate);
      if (!attemptedIds.add(candidate)) continue;
      try {
        return await _fetchCertificateExact(candidate);
      } on HCVRegistryException catch (candidateError) {
        if (candidateError.kind == HCVRegistryFailureKind.notFound) continue;
        rethrow;
      }
    }

    // Only after ranked OCR candidates are absent online, try a bounded set of
    // single-character alternatives. This covers the physical Messenger case
    // C -> 0 without the previous Cartesian B/8 explosion.
    final variants = HCVMediaIdOcr.buildRegistryRecoveryVariants(
      recoveryBases,
      maxVariants: 16,
    );
    for (final candidate in variants) {
      if (!attemptedIds.add(candidate)) continue;
      try {
        return await _fetchCertificateExact(candidate);
      } on HCVRegistryException catch (candidateError) {
        if (candidateError.kind == HCVRegistryFailureKind.notFound) continue;
        rethrow;
      }
    }

    // Preserve pending/local-certificate recovery, but only after the bounded
    // online PHOTO search. Retry the queue once, then re-check exactly the IDs
    // already attempted; never re-enter the generic combinatorial fallback.
    try {
      await registry.retryPendingUploads();
      for (final candidate in attemptedIds) {
        try {
          return await _fetchCertificateExact(candidate);
        } on HCVRegistryException catch (candidateError) {
          if (candidateError.kind == HCVRegistryFailureKind.notFound) continue;
          rethrow;
        }
      }
    } catch (_) {}

    for (final candidate in attemptedIds) {
      final localCertificate = await _findLocalCertificate(candidate);
      if (localCertificate == null) continue;
      try {
        await registry.uploadCertificateFile(localCertificate.path);
        return await _fetchCertificateExact(candidate);
      } catch (_) {}
    }

    throw originalNotFound;
  }
'''
replace_once(registry_path, registry_photo_old, registry_photo_new)


# ---------------------------------------------------------------------------
# Unit test: prove the exact physical C->0 failure is recoverable, that every
# generated fallback is one edit only, and that the list is globally bounded.
# ---------------------------------------------------------------------------
ocr_test = Path('test/hcv_media_id_ocr_test.dart')
ocr_test_text = ocr_test.read_text(encoding='utf-8')
ocr_test_anchor = '''    test('ties keep the first reading deterministically', () {
      expect(
        HCVMediaIdOcr.selectConsensusCandidate(const [
          'HCV-D2BEECE9BB114783',
          'HCV-80DF7C6F1B6B4B36',
        ]),
        'HCV-D2BEECE9BB114783',
      );
    });
'''
ocr_test_insert = ocr_test_anchor + '''

    test('Registry recovery covers the physical Messenger C-to-0 OCR error', () {
      final variants = HCVMediaIdOcr.buildRegistryRecoveryVariants(const [
        'HCV-58499808ECB04900',
      ]);

      expect(variants, contains('HCV-58499808ECB049C0'));
      expect(variants.length, lessThanOrEqualTo(16));

      const base = '58499808ECB04900';
      for (final variant in variants) {
        final payload = variant.substring(4);
        var changed = 0;
        for (var i = 0; i < base.length; i++) {
          if (base[i] != payload[i]) changed++;
        }
        expect(changed, 1, reason: '$variant must be one OCR edit only');
      }
    });

    test('Registry recovery is deterministic and respects its global cap', () {
      final first = HCVMediaIdOcr.buildRegistryRecoveryVariants(
        const ['HCV-58499808ECB04900'],
        maxVariants: 3,
      );
      final second = HCVMediaIdOcr.buildRegistryRecoveryVariants(
        const ['HCV-58499808ECB04900'],
        maxVariants: 3,
      );

      expect(first, second);
      expect(first, hasLength(3));
      expect(first, [
        'HCV-5B499808ECB04900',
        'HCV-58499B08ECB04900',
        'HCV-584998C8ECB04900',
      ]);
    });
'''
if ocr_test_text.count(ocr_test_anchor) != 1:
    raise RuntimeError('hcv_media_id_ocr_test.dart: anchor mismatch')
ocr_test.write_text(
    ocr_test_text.replace(ocr_test_anchor, ocr_test_insert, 1),
    encoding='utf-8',
)


# ---------------------------------------------------------------------------
# Contract test: PHOTO is exact/404-driven and bounded; non-photo behavior stays
# on the pre-existing local/generic path.
# ---------------------------------------------------------------------------
contract = Path('test/photo_ocr_registry_recovery_contract_test.dart')
contract.write_text(
    '''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo Registry recovery is 404-driven, OCR-first and bounded', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();
    final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

    expect(ocr, contains('extractCandidatesFromImage(String path)'));
    expect(ocr, contains('buildRegistryRecoveryVariants('));
    expect(ocr, contains("'0' => 'C'"));
    expect(ocr, contains("'C' => '0'"));
    expect(ocr, contains('maxVariants = 16'));

    expect(registry, contains('_fetchCertificateExact(String hcvId)'));
    expect(
      registry,
      contains('_fetchCertificateWithPhotoOcrRecovery(String hcvId)'),
    );
    expect(
      registry,
      contains('await HCVMediaIdOcr.extractCandidatesFromImage(path)'),
    );
    expect(
      registry,
      contains('HCVMediaIdOcr.buildRegistryRecoveryVariants('),
    );
    expect(
      registry,
      contains(
        'final resolved = await _fetchCertificateWithPhotoOcrRecovery(hcvId);',
      ),
    );

    final helperStart = registry.indexOf(
      '_fetchCertificateWithPhotoOcrRecovery(String hcvId)',
    );
    final helperEnd = registry.indexOf('int _hexDistance', helperStart);
    expect(helperStart, greaterThanOrEqualTo(0));
    expect(helperEnd, greaterThan(helperStart));
    final helper = registry.substring(helperStart, helperEnd);

    expect(helper, contains("lower.endsWith('.jpg')"));
    expect(helper, contains("lower.endsWith('.jpeg')"));
    expect(helper, contains("lower.endsWith('.png')"));
    expect(helper, isNot(contains("lower.endsWith('.mp4')")));
    expect(helper, contains('return await _fetchCertificateExact(hcvId);'));
    expect(helper, contains('candidateError.kind == HCVRegistryFailureKind.notFound'));
    expect(helper, contains('maxVariants: 16'));
    expect(helper, isNot(contains('_b8Variants(')));
    expect(helper, isNot(contains('_fetchCertificate(candidate)')));

    final firstExact = helper.indexOf('_fetchCertificateExact(hcvId)');
    final robustOcr = helper.indexOf('extractCandidatesFromImage(path)');
    final boundedVariants = helper.indexOf('buildRegistryRecoveryVariants(');
    final pendingRetry = helper.indexOf('registry.retryPendingUploads()');
    expect(firstExact, greaterThanOrEqualTo(0));
    expect(robustOcr, greaterThan(firstExact));
    expect(boundedVariants, greaterThan(robustOcr));
    expect(pendingRetry, greaterThan(boundedVariants));

    // Video/text keep their existing path; this fix is PHOTO-only.
    expect(
      helper,
      contains('return await _fetchCertificateWithLocalRecovery(hcvId);'),
    );
  });
}
''',
    encoding='utf-8',
)

print('BUILD114 PHOTO social Registry OCR recovery patch prepared')
