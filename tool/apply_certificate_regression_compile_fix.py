from pathlib import Path


fusion_path = Path('lib/hcv_display_risk_fusion.dart')
fusion = fusion_path.read_text()

for declaration in (
    """    final rawActiveDisplayEvidence =
        liveSignals['rawActiveDisplayEvidence'] == true;
""",
    """    final planarSceneEvidence = liveSignals['planarSceneEvidence'] == true;
""",
):
    first = fusion.find(declaration)
    if first < 0:
        raise RuntimeError(f'Missing expected declaration: {declaration.strip()}')
    second = fusion.find(declaration, first + len(declaration))
    while second >= 0:
        fusion = fusion[:second] + fusion[second + len(declaration):]
        second = fusion.find(declaration, first + len(declaration))

fusion_path.write_text(fusion)

geometry_path = Path('lib/hcv_live_screen_probe_geometry.dart')
geometry = geometry_path.read_text()
geometry = geometry.replace(
    '_standardDeviation(',
    '_geometryStandardDeviation(',
)
helper = """
double _geometryStandardDeviation(List<double> values) {
  if (values.isEmpty) return 0.0;
  final mean =
      values.fold<double>(0.0, (sum, value) => sum + value) / values.length;
  final variance = values
          .map((value) => pow(value - mean, 2).toDouble())
          .fold<double>(0.0, (sum, value) => sum + value) /
      values.length;
  return sqrt(variance);
}

"""
anchor = 'class _ProjectiveGeometryCandidate {'
if helper.strip() not in geometry:
    if geometry.count(anchor) != 1:
        raise RuntimeError('Projective geometry helper anchor missing')
    geometry = geometry.replace(anchor, helper + anchor, 1)
geometry_path.write_text(geometry)

print('Certificate regression compile corrections applied')
