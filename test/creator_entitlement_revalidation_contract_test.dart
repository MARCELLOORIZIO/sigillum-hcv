import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Creator home revalidates on resume and before certification routes', () {
    final source = File('lib/user_home_page.dart').readAsStringSync();
    expect(source, contains('with WidgetsBindingObserver'));
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('await _account.billingStatus()'));
    expect(source, contains('_openCreatorFeature('));
    expect(source, contains('CameraPage('));
    expect(source, contains('TextCertPage('));
    expect(source, contains('onSubscriptionInactive: widget.onSubscriptionInactive'));
  });

  test('subscription expiry returns to billing without logging the account out', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final start = gate.indexOf('Future<void> _onSubscriptionInactive() async');
    final end = gate.indexOf('Future<void> _logout() async', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final section = gate.substring(start, end);
    expect(section, contains('_stage = _GateStage.billing'));
    expect(section, contains('await _prepareBilling()'));
    expect(section, isNot(contains('.logout()')));
    expect(section, isNot(contains('_resetLoggedOutState()')));
  });

  test('camera checks entitlement at photo and video capture boundaries', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final startVideo = camera.indexOf('Future<void> start() async');
    final stopVideo = camera.indexOf('Future<void> stop() async', startVideo);
    final photo = camera.indexOf('Future<void> takePhoto() async');
    expect(camera.substring(startVideo, stopVideo),
        contains('if (!await _ensureCreatorEntitlement()) return;'));
    expect(camera.substring(photo),
        contains('if (!await _ensureCreatorEntitlement()) return;'));
  });

  test('text certification checks entitlement at creation boundary', () {
    final text = File('lib/text_cert_page.dart').readAsStringSync();
    final create = text.indexOf('Future<void> createTextCertificate() async');
    expect(create, greaterThanOrEqualTo(0));
    expect(text.substring(create),
        contains('if (!await _ensureCreatorEntitlement()) return;'));
  });
}
