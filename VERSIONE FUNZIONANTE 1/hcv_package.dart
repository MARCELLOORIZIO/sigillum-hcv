import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

class HCVPackage {
  Future<String> createPackage({
    required String videoPath,
    required String hcvPath,
  }) async {
    final videoFile = File(videoPath);
    final hcvFile = File(hcvPath);

    final videoBytes = await videoFile.readAsBytes();
    final hcvJson = await hcvFile.readAsString();

    final videoBase64 = base64Encode(videoBytes);
    final certificate = jsonDecode(hcvJson);

    final pack = {
      "video": videoBase64,
      "certificate": certificate,
    };

    // 🔥 SALVATAGGIO IN DOWNLOAD (VISIBILE)
    final dir = Directory("/storage/emulated/0/Download");

    final filePath = p.join(
      dir.path,
      "package_${DateTime.now().millisecondsSinceEpoch}.hcvpack",
    );

    final file = File(filePath);

    await file.writeAsString(jsonEncode(pack));

    return filePath;
  }
}