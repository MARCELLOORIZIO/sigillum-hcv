import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commercial profile persists selected language to the server', () {
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();
    final profile = File('lib/commercial_profile_page.dart').readAsStringSync();

    expect(auth, contains('String? languageCode'));
    expect(auth, contains("'languageCode': languageCode.trim()"));
    expect(profile, contains('languageCode: _languageCode'));

    for (final language in const ['it', 'en', 'es', 'ru']) {
      expect(profile, contains("'$language': {"));
    }
  });
}
