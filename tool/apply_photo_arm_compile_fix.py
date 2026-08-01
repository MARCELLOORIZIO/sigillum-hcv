from pathlib import Path

path = Path('lib/camera_page.dart')
source = path.read_text(encoding='utf-8')
old = '        liveScreenProbe = armedProbe;'
new = '        liveScreenProbe = armedProbe!;'
count = source.count(old)
if count != 1:
    raise RuntimeError(f'photo arm nullability: expected one anchor, found {count}')
path.write_text(source.replace(old, new, 1), encoding='utf-8')
print('Photo arm nullability validated')
