import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'hcv_yolo_diagnostic_runner.dart';

/// Opt-in experiment. Produces a JSON payload accepted by
/// ml/check_flutter_yolo_parity.py from ACTUAL model inference.
///
/// Call only from an explicitly requested diagnostic session. This is not
/// connected to PHOTO decisions, camera capture or production assets.
class HCVYoloParityReport {
  const HCVYoloParityReport._();

  static Future<Map<String, Object?>> generate({
    required List<String> imagePaths,
    required String screenModelPath,
    required String phoneModelPath,
  }) async {
    final images = <Map<String, Object?>>[];
    for (final imagePath in imagePaths) {
      final file = File(imagePath);
      if (!await file.exists()) {
        images.add(<String, Object?>{
          'image': imagePath,
          'imageSha256': null,
          'models': <String, Object?>{},
          'analysisStatus': 'NOT_ANALYZED',
          'reason': 'IMAGE_NOT_FOUND',
        });
        continue;
      }
      final digest = (await sha256.bind(file.openRead()).first).toString();
      final screen = await HCVYoloDiagnosticRunner.inspectImage(
        modelFilePath: screenModelPath,
        imageFilePath: imagePath,
        useScreenDetection: true,
      );
      final phone = await HCVYoloDiagnosticRunner.inspectImage(
        modelFilePath: phoneModelPath,
        imageFilePath: imagePath,
        useScreenDetection: false,
      );
      images.add(<String, Object?>{
        'image': file.uri.pathSegments.last,
        'imageSha256': digest,
        'models': <String, Object?>{
          'screen_detection': screen,
          'phone_device_v4': phone,
        },
      });
    }
    return <String, Object?>{
      'type': 'SIGILLUM_YOLO_FLUTTER_PARITY',
      'decisionRole': 'DIAGNOSTIC_ONLY',
      'images': images,
    };
  }

  static Future<void> saveJson({
    required String outputPath,
    required Map<String, Object?> report,
  }) async {
    final output = File(outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
  }
}
