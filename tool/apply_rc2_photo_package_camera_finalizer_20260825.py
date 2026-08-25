from pathlib import Path

CAMERA = Path('lib/camera_page.dart')
source = CAMERA.read_text(encoding='utf-8')

old = """        pack = await packer.createPackage(
          videoPath: publishedPhoto,
          hcvPath: hcv,
        );
"""
new = """        pack = await packer.createPhotoPackage(
          photoPath: publishedPhoto,
          hcvPath: hcv,
        );
"""

if new not in source:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(
            f'photo HCVPACK Camera anchor mismatch: expected one, got {count}'
        )
    source = source.replace(old, new, 1)
    print('Camera photo HCVPACK v3 call applied')
else:
    print('Camera photo HCVPACK v3 call already applied')

if 'createPhotoPackage(' not in source or 'photoPath: publishedPhoto' not in source:
    raise RuntimeError('Camera photo HCVPACK v3 production contract missing')

CAMERA.write_text(source, encoding='utf-8')
print('RC2 Camera photo-package finalizer PASS')
