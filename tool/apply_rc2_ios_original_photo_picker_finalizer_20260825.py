from pathlib import Path
import re

IMPORT = Path('lib/import_page.dart')
source = IMPORT.read_text(encoding='utf-8')

if "import 'dart:io';" not in source:
    source = "import 'dart:io';\n\n" + source
if "import 'package:flutter/services.dart';" not in source:
    anchor = "import 'package:flutter/material.dart';\n"
    if anchor not in source:
        raise RuntimeError('ImportPage Flutter material import anchor missing')
    source = source.replace(
        anchor,
        anchor + "import 'package:flutter/services.dart';\n",
        1,
    )

if "static const _mediaChannel = MethodChannel('hcv.media');" not in source:
    anchor = 'class _ImportPageState extends State<ImportPage> {\n'
    if anchor not in source:
        raise RuntimeError('ImportPage state-class anchor missing')
    source = source.replace(
        anchor,
        anchor + "  static const _mediaChannel = MethodChannel('hcv.media');\n",
        1,
    )

final_pick = '''  Future<void> pickPhoto() async {
    try {
      String? path;
      if (Platform.isIOS) {
        path = await _mediaChannel.invokeMethod<String>('pickOriginalPhoto');
      } else {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        path = file?.path;
      }
      if (path == null || path.isEmpty) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      await _openPickedPath(path);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => status = "${_t('importError')}: ${e.message ?? e.code}");
      }
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    }
  }

'''

if "invokeMethod<String>('pickOriginalPhoto')" not in source:
    pattern = re.compile(
        r"  Future<void> pickPhoto\(\) async \{.*?(?=  Future<void> pickVideo\(\) async \{)",
        re.S,
    )
    source, count = pattern.subn(final_pick, source, count=1)
    if count != 1:
        raise RuntimeError('ImportPage pickPhoto semantic region missing')

for token in [
    "import 'dart:io';",
    "import 'package:flutter/services.dart';",
    "MethodChannel('hcv.media')",
    'Platform.isIOS',
    "invokeMethod<String>('pickOriginalPhoto')",
]:
    if token not in source:
        raise RuntimeError(f'iOS original-photo picker contract missing: {token}')

IMPORT.write_text(source, encoding='utf-8')
print('RC2 iOS original-photo picker finalizer PASS')
