from pathlib import Path


def replace_required(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


model_path = Path('lib/hcv_planar_motion_model.dart')
model = model_path.read_text()
for old, new, label in (
    (
        'weights[first] = max(0.05, a.quality);',
        'weights[first] = max(0.05, a.quality).toDouble();',
        'first RANSAC weight type',
    ),
    (
        'weights[second] = max(0.05, b.quality);',
        'weights[second] = max(0.05, b.quality).toDouble();',
        'second RANSAC weight type',
    ),
    (
        'weights[third] = max(0.05, c.quality);',
        'weights[third] = max(0.05, c.quality).toDouble();',
        'third RANSAC weight type',
    ),
    (
        'final quality = max(0.05, samples[index].quality);',
        'final quality = max(0.05, samples[index].quality).toDouble();',
        'RANSAC quality type',
    ),
    (
        '(index) => inliers[index] ? max(0.05, samples[index].quality) : 0,',
        '(index) => inliers[index]\n            ? max(0.05, samples[index].quality).toDouble()\n            : 0.0,',
        'refinement weight type',
    ),
    (
        'final quality = max(0.05, sample.quality);',
        'final quality = max(0.05, sample.quality).toDouble();',
        'final quality type',
    ),
    (
        'qualityTotal += sample.quality.clamp(0.0, 1.0);',
        'qualityTotal += sample.quality.clamp(0.0, 1.0).toDouble();',
        'quality total type',
    ),
):
    model = replace_required(model, old, new, label)
model_path.write_text(model)


geometry_path = Path('lib/hcv_live_screen_probe_geometry.dart')
geometry = geometry_path.read_text()
for old, new, label in (
    (
        'final minimumDx = max(-maxShift, global.dx - localSearchRadius);',
        'final minimumDx =\n          max(-maxShift, global.dx - localSearchRadius).toInt();',
        'minimum dx integer type',
    ),
    (
        'final maximumDx = min(maxShift, global.dx + localSearchRadius);',
        'final maximumDx =\n          min(maxShift, global.dx + localSearchRadius).toInt();',
        'maximum dx integer type',
    ),
    (
        'final minimumDy = max(-maxShift, global.dy - localSearchRadius);',
        'final minimumDy =\n          max(-maxShift, global.dy - localSearchRadius).toInt();',
        'minimum dy integer type',
    ),
    (
        'final maximumDy = min(maxShift, global.dy + localSearchRadius);',
        'final maximumDy =\n          min(maxShift, global.dy + localSearchRadius).toInt();',
        'maximum dy integer type',
    ),
    (
        'final startX = max(0, -dx);',
        'final startX = max(0, -dx).toInt();',
        'grid start x integer type',
    ),
    (
        'final endX = min(width, width - dx);',
        'final endX = min(width, width - dx).toInt();',
        'grid end x integer type',
    ),
    (
        'final startY = max(0, -dy);',
        'final startY = max(0, -dy).toInt();',
        'grid start y integer type',
    ),
    (
        'final endY = min(height, height - dy);',
        'final endY = min(height, height - dy).toInt();',
        'grid end y integer type',
    ),
    (
        """        final modelSignal = max(
          fit.planarCoherence,
          min(0.75, fit.depthDispersion),
        );""",
        """        final modelSignal = max(
          fit.planarCoherence,
          min(0.75, fit.depthDispersion),
        ).toDouble();""",
        'model signal double type',
    ),
):
    geometry = replace_required(geometry, old, new, label)
geometry_path.write_text(geometry)

print('Planar parallax sources made Dart type-safe')
