/// Explicit contract for a future three-class iOS visual framing model.
///
/// Until a real TFLite model is converted and parity-tested against the
/// trained TorchScript checkpoint, only UNKNOWN may be published. An image
/// classifier is *never* independent evidence of physical screen recapture.
class HCVPhotoSemanticFramingContract {
  const HCVPhotoSemanticFramingContract._();

  static const labels = <String>[
    'PHYSICAL_SURFACE_OR_SCENE',
    'DISPLAY_IN_REAL_SCENE',
    'POSSIBLE_FULL_FRAME_DISPLAY',
  ];

  static Map<String, dynamic> unavailable([String reason = 'MODEL_NOT_INSTALLED']) =>
      <String, dynamic>{
        'type': 'SIGILLUM_PHOTO_SEMANTIC_FRAMING_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'decisionRole': 'DIAGNOSTIC_ONLY',
        'sceneFraming': 'UNKNOWN',
        'reason': reason,
      };

  /// Parity-tested model scores only. Deliberately no red/green output.
  static Map<String, dynamic> diagnosticProbabilities(
    List<double> probabilities, {
    required bool modelParityVerified,
  }) {
    if (!modelParityVerified) return unavailable('MODEL_PARITY_NOT_VERIFIED');
    if (probabilities.length != labels.length ||
        probabilities.any((x) => !x.isFinite || x < 0 || x > 1)) {
      return unavailable('INVALID_MODEL_PROBABILITIES');
    }
    final sum = probabilities.fold<double>(0, (a, b) => a + b);
    if ((sum - 1).abs() > 0.01) {
      return unavailable('MODEL_PROBABILITIES_NOT_NORMALIZED');
    }
    var best = 0;
    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[best]) best = i;
    }
    return <String, dynamic>{
      'type': 'SIGILLUM_PHOTO_SEMANTIC_FRAMING_V1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DIAGNOSTIC_ONLY',
      'sceneFraming': 'UNKNOWN',
      'predictedClass': labels[best],
      'confidence': probabilities[best],
      'probabilities': <String, double>{
        for (var i = 0; i < labels.length; i++) labels[i]: probabilities[i],
      },
      'reason': 'VISUAL_CLASSIFICATION_NOT_PHYSICAL_PROOF',
    };
  }
}
