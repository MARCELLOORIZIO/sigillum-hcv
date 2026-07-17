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
      throw Exception('Photo not found');
    }

    final bytes = await inputFile.readAsBytes();

    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Invalid image');
    }

    const overlayHeight = 78;

    const topY = 18;

    img.fillRect(
      image,
      x1: 0,
      y1: topY,
      x2: image.width,
      y2: topY + overlayHeight,
      color: img.ColorRgba8(0, 0, 0, 118),
    );

    img.drawString(
      image,
      'SIGILLUM CAPTURE',
      font: img.arial14,
      x: 20,
      y: topY + 10,
      color: img.ColorRgb8(255, 255, 255),
    );

    img.drawString(
      image,
      'VERIFY IN APP',
      font: img.arial14,
      x: 20,
      y: topY + 30,
      color: img.ColorRgb8(220, 220, 220),
    );

    img.drawString(
      image,
      hcvId,
      font: img.arial24,
      x: 20,
      y: topY + 48,
      color: img.ColorRgb8(255, 215, 0),
    );

    final outputPath = p.join(
      inputFile.parent.path,
      'hcv_photo_$hcvId.jpg',
    );

    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(
      img.encodeJpg(image, quality: 95),
    );

    return outputPath;
  }
}
