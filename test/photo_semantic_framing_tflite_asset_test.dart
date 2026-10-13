import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_photo_semantic_framing_inference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PHOTO framing TFLite bundled asset matches parity-verified artifact',
      () async {
    final bytes = await rootBundle.load(
      HCVPhotoSemanticFramingInference.assetPath,
    );
    final data = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    expect(data.length, 3816772);
    expect(
      sha256.convert(data).toString(),
      HCVPhotoSemanticFramingInference.parityApprovedSha256,
    );
    expect(data.sublist(4, 8), <int>[84, 70, 76, 51]); // "TFL3"
  });
}
