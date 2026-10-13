import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both account and fallback creator wipe enumerate encrypted subtitle derivatives', () {
    final source = File('lib/hcv_secure_media_vault.dart').readAsStringSync();
    final account = source.split('Future<void> wipeAccountVault(String accountId) async {')[1].split('Future<void> wipeCreatorVault(String creatorId) async {')[0];
    final creator = source.split('Future<void> wipeCreatorVault(String creatorId) async {')[1].split('Future<void> wipeLocalVault() async {')[0];
    for (final segment in [account, creator]) {
      expect(segment, contains('item.encryptedCaptionedMediaPath!'));
      expect(segment, contains('item.encryptedSubtitlePath!'));
      expect(segment, contains('item.encryptedMediaPath'));
      expect(segment, contains('item.encryptedHcvpackPath'));
      expect(segment, contains('item.certificatePath'));
    }
  });
}
