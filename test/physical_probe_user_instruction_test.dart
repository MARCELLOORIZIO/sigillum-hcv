import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera tells the user to create lateral parallax', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final copy = File('lib/camera_ui_copy.dart').readAsStringSync();
    expect(source, contains("_c('physicalProbe')"));
    expect(copy, contains("'physicalProbe': 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'"));
    expect(copy, contains("'physicalProbe': 'MOVE THE PHONE SLIGHTLY SIDEWAYS...'"));
  });
}
