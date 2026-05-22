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

    final overlayHeight = (image.height * 0.22).toInt();

    final topY = image.height - overlayHeight - 180;

    img.fillRect(
      image,
      x1: 0,
      y1: topY,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(0, 0, 0, 140),
    );

    final titleSize = (image.width * 0.035).toInt();
    final smallSize = (image.width * 0.018).toInt();

    img.drawString(
      image,
      'SIGILLUM',
      font: img.arial48,
      x: 40,
      y: topY + 26,
      color: img.ColorRgb8(255, 255, 255),
    );

    img.drawString(
      image,
      'HUMAN VERIFIED',
      font: img.arial24,
      x: 42,
      y: topY + 92,
      color: img.ColorRgb8(220, 220, 220),
    );

    img.drawString(
      image,
      hcvId,
      font: img.arial24,
      x: 42,
      y: topY + 132,
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
