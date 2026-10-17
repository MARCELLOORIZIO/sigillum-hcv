/// Diagnostic-only contract for the experimental PHONE_DEVICE V4 model.
///
/// No model is bundled by this file and no PHOTO decision is changed.
/// The candidate was exported by LiteRT with a channel-first input tensor
/// [1, 3, 416, 416] and raw output tensor [1, 5, 3549].
///
/// IMPORTANT: These dimensions establish only the *tensor shape*. The
/// spatial-coordinate convention and calibration of scores require comparison
/// with Ultralytics reference outputs before interpreting detections.
class HCVPhoneDeviceV4Contract {
  const HCVPhoneDeviceV4Contract._();

  static const String modelSha256 =
      '69a68829f3328f3580dcd3fca7326f4b363c3579a58d558d9ffe0bfa1957ae85';
  static const String className = 'PHONE_DEVICE';

  static const List<int> inputShape = <int>[1, 3, 416, 416];
  static const List<int> outputShape = <int>[1, 5, 3549];

  static const String decisionRole = 'DIAGNOSTIC_ONLY';
  static const String unavailable = 'NOT_ANALYZED';
  static const String ready = 'CONTRACT_VERIFIED';

  /// An explicit fail-closed check avoids silently running a classifier model
  /// or a differently exported YOLO model through the wrong tensor adapter.
  static bool matches({
    required List<int> actualInputShape,
    required List<int> actualOutputShape,
    required String inputType,
    required String outputType,
  }) {
    return _sameShape(actualInputShape, inputShape) &&
        _sameShape(actualOutputShape, outputShape) &&
        inputType.toLowerCase() == 'float32' &&
        outputType.toLowerCase() == 'float32';
  }

  static Map<String, Object?> diagnosticStatus({
    required bool modelAvailable,
    List<int>? actualInputShape,
    List<int>? actualOutputShape,
    String? inputType,
    String? outputType,
  }) {
    final contractVerified = modelAvailable &&
        actualInputShape != null &&
        actualOutputShape != null &&
        inputType != null &&
        outputType != null &&
        matches(
          actualInputShape: actualInputShape,
          actualOutputShape: actualOutputShape,
          inputType: inputType,
          outputType: outputType,
        );
    return <String, Object?>{
      'type': 'SIGILLUM_PHONE_DEVICE_V4_DIAGNOSTIC',
      'analysisStatus': contractVerified ? ready : unavailable,
      'decisionRole': decisionRole,
      'modelSha256Expected': modelSha256,
      'modelBundled': modelAvailable,
      'tensorContractVerified': contractVerified,
      'physicalRecaptureProven': false,
      'devicePresent': null,
      'screenReplayRiskDecision': null,
      'reason': contractVerified
          ? 'TENSOR_CONTRACT_ONLY_NO_INFERENCE'
          : 'MODEL_OR_TENSOR_CONTRACT_UNAVAILABLE',
    };
  }

  static bool _sameShape(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }
}
