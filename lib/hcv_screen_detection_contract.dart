/// Tensor contract for the second, five-class Screen Detection experiment.
///
/// This model is distinct from PHONE_DEVICE V4 and from SIGILLUM's original
/// screen-replay classifier. Nothing here participates in PHOTO decisions.
class HCVScreenDetectionContract {
  const HCVScreenDetectionContract._();

  static const expectedSha256 =
      'eeb5b914fff6f4843e25c562ca78ab3d656bca21d5b9fce062544be4b5f12668';
  static const inputShape = <int>[1, 3, 608, 608];
  static const outputShape = <int>[1, 9, 7581];
  static const classNames = <String>[
    'desktop',
    'laptop',
    'phone',
    'tablet',
    'tv',
  ];

  static bool supportsTensorLayout({
    required List<int> actualInputShape,
    required List<int> actualOutputShape,
    required String inputType,
    required String outputType,
  }) {
    return _matches(actualInputShape, inputShape) &&
        _matches(actualOutputShape, outputShape) &&
        inputType.toLowerCase() == 'float32' &&
        outputType.toLowerCase() == 'float32';
  }

  /// This contract intentionally cannot assert object presence or authenticity.
  static Map<String, Object?> report({
    required bool modelAvailable,
    required bool tensorLayoutVerified,
  }) {
    return <String, Object?>{
      'type': 'SIGILLUM_SCREEN_DETECTION_EXPERIMENT',
      'decisionRole': 'DIAGNOSTIC_ONLY',
      'analysisStatus': modelAvailable && tensorLayoutVerified
          ? 'CONTRACT_VERIFIED'
          : 'NOT_ANALYZED',
      'modelSha256Expected': expectedSha256,
      'devicePresent': null,
      'physicalRecaptureProven': false,
      'displayRiskDecision': null,
      'reason': modelAvailable && tensorLayoutVerified
          ? 'TENSOR_CONTRACT_ONLY_NO_INFERENCE'
          : 'MODEL_OR_TENSOR_CONTRACT_UNAVAILABLE',
    };
  }

  static bool _matches(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }
}
