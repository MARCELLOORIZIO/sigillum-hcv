from pathlib import Path


def replace_required(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


model = Path('lib/hcv_planar_motion_model.dart').read_text()
if 'PLANAR_MODEL_TYPES_SAFE_V1' not in model:
    raise RuntimeError('Direct planar motion model is not the type-safe version')
if 'max(0.05, samples[first].quality).toDouble()' not in model:
    raise RuntimeError('Planar motion model RANSAC weights are not type-safe')
if 'sample.quality.clamp(0.0, 1.0).toDouble()' not in model:
    raise RuntimeError('Planar motion model quality accumulation is not type-safe')


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

print('Planar parallax sources validated and generated geometry made type-safe')
