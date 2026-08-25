from pathlib import Path

PACKAGE = Path('lib/hcv_package.dart')
source = PACKAGE.read_text(encoding='utf-8')

if 'Future<String> createPhotoPackage({' not in source:
    raise RuntimeError('photo package method missing before path_provider finalization')

required_import = "import 'package:path_provider/path_provider.dart';"
if required_import not in source:
    anchor = "import 'package:path/path.dart' as p;\n"
    if anchor not in source:
        raise RuntimeError('HCVPackage path import anchor missing')
    source = source.replace(anchor, anchor + required_import + '\n', 1)
    print('HCVPACK photo path_provider import applied')
else:
    print('HCVPACK photo path_provider import already applied')

if required_import not in source:
    raise RuntimeError('HCVPACK photo path_provider import contract missing')

PACKAGE.write_text(source, encoding='utf-8')
print('RC2 photo package compile-import finalizer PASS')
