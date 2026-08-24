from pathlib import Path

camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text(encoding='utf-8')

start_marker = '  Future<void> _showCaptureReadyMessage() async {'
end_marker = '  Future<void> _toggleCoordinateStamp() async {'
start = camera.find(start_marker)
end = camera.find(end_marker, start)
if start < 0 or end < 0:
    raise RuntimeError('compact camera proceed section missing')

section = camera[start:end]
required = [
    'showGeneralDialog<void>',
    'Alignment.topCenter',
    'BoxConstraints(maxWidth: 320)',
    "italian ? 'PROSEGUI' : 'CONTINUE'",
]
for token in required:
    if token not in section:
        raise RuntimeError(f'compact proceed contract missing before resize: {token}')

if 'minimumSize: const Size(0, 56)' not in section:
    if 'minimumSize: const Size(0, 28)' not in section:
        raise RuntimeError('compact proceed height anchor missing')
    section = section.replace(
        'minimumSize: const Size(0, 28)',
        'minimumSize: const Size(0, 56)',
        1,
    )

# Improve legibility while retaining exactly the same top-banner interaction.
section = section.replace(
    'fontSize: 10,\n                            fontWeight: FontWeight.bold,',
    'fontSize: 16,\n                            fontWeight: FontWeight.w900,',
    1,
)

if 'AlertDialog' in section:
    raise RuntimeError('compact proceed flow was unexpectedly converted to AlertDialog')
if 'minimumSize: const Size(0, 56)' not in section:
    raise RuntimeError('compact proceed control was not doubled')

camera = camera[:start] + section + camera[end:]
camera_path.write_text(camera, encoding='utf-8')

# Align only the generated presentation contract. Geometry/detector assertions
# remain untouched.
test_path = Path('test/mixed_scene_monitor_regression_test.dart')
if test_path.exists():
    test = test_path.read_text(encoding='utf-8')
    test = test.replace(
        "expect(confirmation, contains('minimumSize: const Size(0, 28)'));",
        "expect(confirmation, contains('minimumSize: const Size(0, 56)'));",
        1,
    )
    test_path.write_text(test, encoding='utf-8')

print('Compact camera PROSEGUI height doubled from 28 to 56 without changing capture flow')
