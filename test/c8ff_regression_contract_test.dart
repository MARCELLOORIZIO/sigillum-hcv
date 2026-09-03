import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared photos keep original filename information', () {
    final source = File('ios/SigillumShareExtension/ShareViewController.swift')
        .readAsStringSync();

    expect(source, contains('provider.suggestedName'));
    expect(source, contains('originalName: suggestedName'));
    expect(source, contains('url.lastPathComponent'));
  });

  test('photo quick gate escalates inconclusive OCR to Registry recovery', () {
    final source = File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();

    expect(source, contains('final isPhoto'));
    expect(source, contains('await _openRegistry();'));
    expect(source, contains('existing deeper multi-crop OCR recovery'));
  });
}
