/// PHOTO framing is distinct from the question "does this image contain a
/// screen?" and from media integrity. No absence-of-border inference is allowed.
class HCVPhotoFramingEvidence {
  const HCVPhotoFramingEvidence._();

  static const String fullFrameDisplay = 'FULL_FRAME_DISPLAY';
  static const String displayInRealScene = 'DISPLAY_IN_REAL_SCENE';
  static const String physicalSurface = 'PHYSICAL_SURFACE';
  static const String unknown = 'UNKNOWN';

  /// Only *positive* evidence of an embedded display is accepted here.
  /// Geometry is not proof that the pixels came from a genuine live scene;
  /// it merely prevents semantic screen detection from turning an embedded
  /// scene into a full-frame screen recapture.
  static Map<String, dynamic> fromSceneContext(
    Map<String, dynamic>? context,
  ) {
    if (context == null ||
        context['analysisStatus'] != 'ANALYZED' ||
        context['contextClass'] != 'DISPLAY_EMBEDDED_IN_REALITY' ||
        context['positiveRealityEvidence'] != true) {
      return <String, dynamic>{
        'type': 'SIGILLUM_PHOTO_FRAMING_V1',
        'analysisStatus': 'NOT_DETERMINED',
        'sceneFraming': unknown,
        'reason': 'NO_CORROBORATED_EMBEDDED_GEOMETRY',
      };
    }

    return <String, dynamic>{
      'type': 'SIGILLUM_PHOTO_FRAMING_V1',
      'analysisStatus': 'ANALYZED',
      'sceneFraming': displayInRealScene,
      'reason': 'CORROBORATED_MULTI_DEPTH_EMBEDDED_DISPLAY',
      'positiveEmbeddedRealityEvidence': true,
    };
  }

  static bool isCorroboratedEmbedded(Map<String, dynamic>? evidence) =>
      evidence != null &&
      evidence['analysisStatus'] == 'ANALYZED' &&
      evidence['sceneFraming'] == displayInRealScene &&
      evidence['positiveEmbeddedRealityEvidence'] == true;
}
