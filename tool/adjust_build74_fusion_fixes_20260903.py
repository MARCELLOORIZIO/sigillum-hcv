from pathlib import Path

path = Path('lib/hcv_display_risk_fusion.dart')
text = path.read_text()

# Keep the new PLANAR override limited to the actual build74 profile: the
# aggregate ML class is SCREEN but weak, while at least half the individual
# frames are semantic REALITY. Historical aggregate-REALITY cases keep their
# existing decision path and reason semantics.
old = """  static bool hasPlanarSemanticRealityWithoutHardDisplayEvidence(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
"""
new = """  static bool hasPlanarSemanticRealityWithoutHardDisplayEvidence(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
"""
if text.count(old) != 1:
    raise SystemExit('PLANAR semantic REALITY helper marker not found exactly once')
text = text.replace(old, new, 1)

old2 = """    return realityFrames * 2 >= frames &&
        strong == 0 &&
"""
new2 = """    return predictedClass.startsWith('SCREEN_') &&
        realityFrames * 2 >= frames &&
        strong == 0 &&
"""
if text.count(old2) != 1:
    raise SystemExit('PLANAR semantic REALITY return marker not found exactly once')
text = text.replace(old2, new2, 1)

# Preserve the pre-two-frame photo contract. Build69 certificates/profiles had
# one temporal ML frame; when BOTH still and temporal ML are extremely strong
# REALITY (old <=2 score / <=.02 screen probability gate), retain the legacy
# dual-REALITY resolution. New captures still use the stricter two-frame
# temporal agreement introduced by the build74 patch.
old3 = """    final photoStrongScreenFamilyAgreement = liveCaptureOnly &&
        _hasPhotoTemporalScreenFamilyAgreement(photoTemporalMl) &&
        _hasPhotoStillScreenFamilyAgreement(postCaptureMl);
    final photoDualRealityAgreement = liveCaptureOnly &&
        _isCredibleRealityMl(
          postCaptureMl,
          maxScore: 12,
          maxScreenProbability: 0.12,
          minConfidence: 0.30,
        ) &&
        _hasPhotoTemporalRealityAgreement(photoTemporalMl);
"""
new3 = """    final photoStrongScreenFamilyAgreement = liveCaptureOnly &&
        _hasPhotoTemporalScreenFamilyAgreement(photoTemporalMl) &&
        _hasPhotoStillScreenFamilyAgreement(postCaptureMl);
    final photoLegacyDualRealityAgreement = liveCaptureOnly &&
        _isCredibleRealityMl(
          postCaptureMl,
          maxScore: 2,
          maxScreenProbability: 0.02,
          minConfidence: 0.40,
        ) &&
        _isCredibleRealityMl(
          photoTemporalMl,
          maxScore: 2,
          maxScreenProbability: 0.02,
          minConfidence: 0.60,
        );
    final photoDualRealityAgreement = photoLegacyDualRealityAgreement ||
        (liveCaptureOnly &&
            _isCredibleRealityMl(
              postCaptureMl,
              maxScore: 12,
              maxScreenProbability: 0.12,
              minConfidence: 0.30,
            ) &&
            _hasPhotoTemporalRealityAgreement(photoTemporalMl));
"""
if text.count(old3) != 1:
    raise SystemExit('photo dual REALITY block not found exactly once')
text = text.replace(old3, new3, 1)

path.write_text(text)
print('build74 guards refined; legacy photo dual-REALITY preserved')
