import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera tells the user to create lateral parallax', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE'));
    expect(source, contains('MOVE THE PHONE SLIGHTLY SIDEWAYS'));
    expect(source, contains('MOVIMENTO SUFFICIENTE. RIPORTA IL TELEFONO'));
    expect(source, contains('MOVIMENTO NON SUFFICIENTE. NESSUNO SCATTO ESEGUITO'));
  });
}
