from pathlib import Path

PACKAGE = Path('lib/hcv_package.dart')
PLAYER = Path('lib/hcvpack_player_page.dart')
IMPORT = Path('lib/import_page.dart')
SCENE = Path('ios/Runner/SceneDelegate.swift')

# Deliberately use semantic substrings that survive dart-format line wrapping.
# The raw implementation patcher is only needed while any final contract is
# absent; once these markers exist, repeated release finalization must be a
# pure verification step rather than another source rewrite.
required = {
    PACKAGE: [
        'Future<String> createPhotoPackage({',
        "'version': 3",
        "'mediaType': 'photo'",
        "'contentSha256': contentSha256",
    ],
    PLAYER: [
        'final version = (meta["version"] as num?)?.toInt();',
        'version != 2',
        'version != 3',
        'meta["contentSha256"]',
        'contentFile.startsWith',
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


def missing_contracts() -> list[str]:
    missing = []
    for path, tokens in required.items():
        if not path.exists():
            missing.append(f'{path}:<missing-file>')
            continue
        source = path.read_text(encoding='utf-8')
        for token in tokens:
            if token not in source:
                missing.append(f'{path}:{token}')
    return missing


before = missing_contracts()
if not before:
    print('RC2 photo integrity already semantically finalized; patcher skipped')
else:
    print('RC2 photo integrity materialization required: ' + ' | '.join(before))
    script = Path('tool/apply_rc2_photo_integrity_finalizer_20260825.py')
    if not script.exists():
        raise RuntimeError('RC2 photo integrity implementation missing')
    exec(
        compile(script.read_text(encoding='utf-8'), str(script), 'exec'),
        {'__name__': '__main__'},
    )

# Fail closed on the semantic outcome, independent of dart-format layout.
after = missing_contracts()
if after:
    raise RuntimeError(
        'photo integrity semantic contract incomplete after finalization: '
        + ' | '.join(after)
    )

print('RC2 photo integrity semantic wrapper PASS')
