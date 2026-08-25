from pathlib import Path

PACKAGE = Path('lib/hcv_package.dart')
PLAYER = Path('lib/hcvpack_player_page.dart')
IMPORT = Path('lib/import_page.dart')
SCENE = Path('ios/Runner/SceneDelegate.swift')

required = {
    PACKAGE: [
        'Future<String> createPhotoPackage({',
        "'version': 3",
        "'mediaType': 'photo'",
        "'contentSha256': contentSha256",
    ],
    PLAYER: [
        'version != 2 && version != 3',
        'meta["contentSha256"] != contentSha256',
        "contentFile.startsWith('photo.')",
    ],
    IMPORT: [
        "MethodChannel('hcv.media')",
        'Platform.isIOS',
        "invokeMethod<String>('pickOriginalPhoto')",
    ],
    SCENE: [
        'PHPickerViewControllerDelegate',
        'call.method == "pickOriginalPhoto"',
        'PHAssetResource.assetResources(for: asset)',
        'PHAssetResourceManager.default().writeData(',
    ],
}

complete = True
for path, tokens in required.items():
    if not path.exists():
        complete = False
        break
    source = path.read_text(encoding='utf-8')
    if any(token not in source for token in tokens):
        complete = False
        break

if complete:
    print('RC2 photo integrity already semantically finalized; patcher skipped')
else:
    script = Path('tool/apply_rc2_photo_integrity_finalizer_20260825.py')
    if not script.exists():
        raise RuntimeError('RC2 photo integrity implementation missing')
    exec(
        compile(script.read_text(encoding='utf-8'), str(script), 'exec'),
        {'__name__': '__main__'},
    )

# Fail closed on the semantic outcome, independent of dart-format layout.
for path, tokens in required.items():
    source = path.read_text(encoding='utf-8')
    for token in tokens:
        if token not in source:
            raise RuntimeError(f'photo integrity semantic contract missing in {path}: {token}')

print('RC2 photo integrity semantic wrapper PASS')
