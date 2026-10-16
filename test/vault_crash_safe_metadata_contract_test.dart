import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();

  test('vault index and journal replace the previous file without a delete gap', () {
    final indexStart = vault.indexOf('Future<void> _saveIndex(');
    final indexEnd = vault.indexOf('Future<T> _withIndexLock', indexStart);
    final journalStart = vault.indexOf('Future<void> _savePendingSeals(');
    final journalEnd = vault.indexOf('Future<void> _upsertPendingSeal(', journalStart);
    expect(indexStart, greaterThanOrEqualTo(0));
    expect(journalStart, greaterThanOrEqualTo(0));
    for (final body in [
      vault.substring(indexStart, indexEnd),
      vault.substring(journalStart, journalEnd),
    ]) {
      expect(body, contains('await temp.rename(file.path);'));
      expect(body, isNot(contains('await file.delete();')));
      expect(body, contains('flush: true'));
    }
  });

  test('missing metadata may recover only a schema-valid temp document', () {
    expect(vault, contains('Future<void> _restoreMissingJsonFromTemp('));
    expect(vault, contains("decoded['schema'] != schema"));
    expect(vault, contains('await temp.rename(file.path);'));
    expect(vault, contains("'SIGILLUM_PENDING_SEALS'"));
    expect(vault, contains("'SIGILLUM_SECURE_ORIGINALS_INDEX'"));
  });

  test('corrupted pending seals fail closed rather than becoming an empty list', () {
    final start = vault.indexOf('Future<List<Map<String, dynamic>>> _loadPendingSeals()');
    final end = vault.indexOf('Future<void> _savePendingSeals(', start);
    final body = vault.substring(start, end);
    expect(body, contains('SECURE_VAULT_PENDING_SEALS_UNREADABLE'));
    expect(body, isNot(contains('catch (_)')));
    expect(body, contains("decoded['schema'] != 'SIGILLUM_PENDING_SEALS'"));
  });

  test('existing encrypted originals are not deleted before a replacement exists', () {
    final start = vault.indexOf('final encryptedMedia = File(');
    final end = vault.indexOf('final record = HCVSecureOriginalRecord(', start);
    final body = vault.substring(start, end);
    expect(body, contains('SECURE_VAULT_UNINDEXED_ENCRYPTED_FILE'));
    expect(body, isNot(contains('await target.delete();')));
  });
  test('subtitle ciphertext is never deleted before replacement', () {
    final start = vault.indexOf('final encryptedCaptioned = File(');
    final end = vault.indexOf('final oldCaptionedPath =', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = vault.substring(start, end);
    expect(body, contains('SECURE_VAULT_SUBTITLE_CIPHERTEXT_ALREADY_EXISTS'));
    expect(body, isNot(contains('await target.delete();')));
  });

  test('cold startup purges abandoned plaintext subtitle scratch directory', () {
    final start = vault.indexOf('Future<void> purgeMaterializedPlaintext()');
    expect(start, greaterThanOrEqualTo(0));
    final body = vault.substring(start);
    expect(body, contains('sigillum_private_derivations'));
    expect(body, contains('await scratch.delete(recursive: true);'));
    final appStart = File('lib/main.dart').readAsStringSync();
    expect(appStart, contains('purgeMaterializedPlaintext()'));
  });

  test('invalid indexed records fail closed rather than disappearing on rewrite', () {
    final start = vault.indexOf('Future<List<HCVSecureOriginalRecord>> _loadIndex()');
    final end = vault.indexOf('Future<void> _saveIndex(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = vault.substring(start, end);
    expect(body, contains('SECURE_VAULT_INDEX_RECORD_INVALID'));
    expect(body, isNot(contains('.whereType<Map>()')));
  });

  test('missing index with encrypted payload does not create a new empty vault', () {
    final start = vault.indexOf('Future<List<HCVSecureOriginalRecord>> _loadIndex()');
    final end = vault.indexOf('Future<void> _saveIndex(', start);
    final body = vault.substring(start, end);
    expect(body, contains('SECURE_VAULT_INDEX_MISSING_WITH_CIPHERTEXT'));
    expect(body, contains("entity.path.endsWith('.enc')"));
  });

  test('master key cannot be regenerated while ciphertext survives', () {
    final start = vault.indexOf('Future<SecretKey> _masterKey()');
    final end = vault.indexOf('Future<String> _sha256File(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = vault.substring(start, end);
    expect(body, contains('SECURE_VAULT_MASTER_KEY_MISSING_WITH_CIPHERTEXT'));
    expect(body.indexOf('SECURE_VAULT_MASTER_KEY_MISSING_WITH_CIPHERTEXT'),
        lessThan(body.indexOf('Random.secure()')));
  });

  test('missing recovery source preserves the pending-seal journal', () {
    final start = vault.indexOf('Future<int> recoverPendingSeals()');
    final end = vault.indexOf('Future<List<HCVSecureOriginalRecord>> list()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = vault.substring(start, end);
    final missingSourceStart = body.indexOf("!await File(certificatePath).exists()");
    final retryStart = body.indexOf('try {', missingSourceStart);
    expect(missingSourceStart, greaterThanOrEqualTo(0));
    expect(retryStart, greaterThan(missingSourceStart));
    expect(body.substring(missingSourceStart, retryStart),
        isNot(contains('await _removePendingSeal(hcvId);')));
  });

  test('existing sealed payloads are authenticated before recovery accepts them', () {
    final start = vault.indexOf('if (existingBefore != null &&\\n        await File(existingBefore.encryptedMediaPath).exists()');
    final end = vault.indexOf('final dir = await _vaultDirectory();', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = vault.substring(start, end);
    expect(body, contains('await _verifyExistingCiphertext('));
    expect(body, contains('existingBefore.mediaSha256'));
    expect(body, contains('existingBefore.hcvpackSha256'));
    expect(body.indexOf('await _verifyExistingCiphertext('),
        lessThan(body.indexOf('await media.delete();')));
    expect(vault, contains('await _decryptFile('));
  });

}
