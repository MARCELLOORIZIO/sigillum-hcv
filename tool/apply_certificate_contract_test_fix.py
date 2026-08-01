from pathlib import Path


path = Path('test/mixed_scene_monitor_regression_test.dart')
source = path.read_text()
old = "expect(geometry, contains('HCVPlanarMotionModel.fit'));"
new = "expect(geometry, contains('HCVProjectiveMotionModel.fit'));"
if new not in source:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(
            f'Expected one legacy geometry contract assertion, found {count}'
        )
    source = source.replace(old, new, 1)
path.write_text(source)

print('Certificate architecture contract tests aligned')
