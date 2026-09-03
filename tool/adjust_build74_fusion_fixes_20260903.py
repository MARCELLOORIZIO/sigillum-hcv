from pathlib import Path

path = Path('lib/hcv_display_risk_fusion.dart')
text = path.read_text()
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
path.write_text(text.replace(old2, new2, 1))
print('build74 PLANAR semantic REALITY guard refined')
