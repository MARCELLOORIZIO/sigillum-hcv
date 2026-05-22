import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class HCVImageWatermark {
  Future<String> createPublishedPhoto({
    required String inputPath,
    required String hcvId,
  }) async {
    final inputFile = File(inputPath);

    if (!await inputFile.exists()) {
      throw Exception('Foto non trovata');
    }

    final bytes = await inputFile.readAsBytes();

    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Immagine non valida');
    }

    final overlayHeight = 90;

    img.fillRect(
      image,
      x1: 20,
      y1: image.height - overlayHeight,
      x2: 360,
      y2: image.height - 20,
      color: img.ColorRgb8(0, 0, 0),
    );

    img.drawString(
      image,
      'SIGILLUM',
      font: img.arial24,
      x: 40,
      y: image.height - 78,
      color: img.ColorRgb8(255, 255, 255),
    );

    img.drawString(
      image,
      'HUMAN VERIFIED',
      font: img.arial14,
      x: 40,
      y: image.height - 48,
      color: img.ColorRgb8(220, 220, 220),
    );

    img.drawString(
      image,
      hcvId,
      font: img.arial14,
      x: 40,
      y: image.height - 28,
      color: img.ColorRgb8(180, 180, 180),
    );

    final dir = inputFile.parent;

    final outputPath = p.join(
      dir.path,
      'hcv_photo_$hcvId.jpg',
    );

    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(
      img.encodeJpg(image, quality: 95),
    );

    return outputPath;
  }
}
