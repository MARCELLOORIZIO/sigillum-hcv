import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_screen_replay_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real Archive 13 monitor and physical scene remain separable', () async {
    final temp = await Directory.systemTemp.createTemp('sigillum_archive13_');
    try {
      final monitor = await _decodeFixture(
        const [
          'test/fixtures/archive13_monitor.part1.b64',
          'test/fixtures/archive13_monitor.part2.b64',
          'test/fixtures/archive13_monitor.part3.b64',
          'test/fixtures/archive13_monitor.part4.b64',
          'test/fixtures/archive13_monitor.part5.b64',
        ],
        '${temp.path}/monitor.jpg',
      );
      final reality = await _decodeFixture(
        const ['test/fixtures/archive13_reality.part1.b64'],
        '${temp.path}/reality.jpg',
      );

      final analyzer = HCVScreenReplayAnalyzer();
      final monitorResult = await analyzer.analyzeImage(monitor.path);
      final realityResult = await analyzer.analyzeImage(reality.path);

      final monitorScore =
          (monitorResult['screenReplayRiskScore'] as num?)?.toInt();
      final realityScore =
          (realityResult['screenReplayRiskScore'] as num?)?.toInt();
      final monitorSignals = monitorResult['signals'];
      final realitySignals = realityResult['signals'];
      final monitorStructural = monitorSignals is Map &&
          monitorSignals['structuralDisplayTrace'] == true;
      final realityStructural = realitySignals is Map &&
          realitySignals['structuralDisplayTrace'] == true;

      expect(
        monitorScore,
        isNotNull,
        reason: 'Monitor non analizzato: $monitorResult',
      );
      expect(
        realityScore,
        isNotNull,
        reason: 'Scena fisica non analizzata: $realityResult',
      );
      expect(
        monitorStructural,
        isTrue,
        reason: 'Il monitor reale non mostra traccia strutturale: $monitorResult',
      );
      expect(
        monitorScore!,
        greaterThanOrEqualTo(45),
        reason: 'Punteggio monitor troppo basso: $monitorResult',
      );
      expect(
        realityStructural,
        isFalse,
        reason: 'La scena fisica produce una falsa traccia: $realityResult',
      );
      expect(
        realityScore!,
        lessThanOrEqualTo(30),
        reason: 'Punteggio scena fisica troppo alto: $realityResult',
      );
      expect(
        monitorScore,
        greaterThan(realityScore),
        reason:
            'Le due immagini reali non sono separate: monitor=$monitorResult reality=$realityResult',
      );
    } finally {
      await temp.delete(recursive: true);
    }
  });
}

Future<File> _decodeFixture(List<String> sourcePaths, String targetPath) async {
  final buffer = StringBuffer();
  for (final sourcePath in sourcePaths) {
    buffer.write((await File(sourcePath).readAsString()).trim());
  }
  final target = File(targetPath);
  await target.writeAsBytes(
    base64Decode(buffer.toString()),
    flush: true,
  );
  return target;
}
