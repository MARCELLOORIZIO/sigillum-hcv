import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Account operations expose temporary green success feedback', () {
    final account = File('lib/account_page.dart').readAsStringSync();

    expect(account, contains("import 'dart:async';"));
    expect(account, contains('String? _successAction;'));
    expect(account, contains('Timer? _successTimer;'));
    expect(account, contains('void _markActionSuccess(String actionId)'));
    expect(account, contains('Timer(const Duration(seconds: 3)'));
    expect(account, contains('backgroundColor: SigillumTheme.verified'));
    expect(account, contains('Icons.check_circle_rounded'));

    for (final actionId in const [
      'register',
      'login',
      'saveProfile',
      'logout',
      'logoutAll',
      'changePassword',
      'devices',
      'deleteAccount',
      'identity',
    ]) {
      expect(account, contains("'$actionId'"), reason: actionId);
    }
  });

  test('Account feedback patch is isolated from capture and classifiers', () {
    final patch =
        File('tool/apply_account_success_feedback.py').readAsStringSync();

    expect(patch, contains("Path('lib/account_page.dart')"));
    expect(patch, isNot(contains('camera_page.dart')));
    expect(patch, isNot(contains('hcv_live_screen_probe')));
    expect(patch, isNot(contains('hcv_scene_geometry')));
    expect(patch, isNot(contains('hcv_display_risk')));
  });
}
