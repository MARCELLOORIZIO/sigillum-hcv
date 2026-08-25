from pathlib import Path

PACKAGE = Path('lib/hcv_package.dart')
PLAYER = Path('lib/hcvpack_player_page.dart')
IMPORT = Path('lib/import_page.dart')
SCENE = Path('ios/Runner/SceneDelegate.swift')

# Semantic markers deliberately survive dart-format line wrapping. Package,
# player and native iOS resource handling form the stable photo-integrity core.
# ImportPage is separate because an older release patch restores that file from
# committed HEAD during repeated finalization.
core_required = {
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
    SCENE: [
        'PHPickerViewControllerDelegate',
        'call.method == "pickOriginalPhoto"',
        'PHAssetResource.assetResources(for: asset)',
        'PHAssetResourceManager.default().writeData(',
    ],
}

import_required = {
    IMPORT: [
        "MethodChannel('hcv.media')",
        'Platform.isIOS',
        "invokeMethod<String>('pickOriginalPhoto')",
    ],
}


def missing_contracts(required: dict[Path, list[str]]) -> list[str]:
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


def run_script(path: str, label: str) -> None:
    script = Path(path)
    if not script.exists():
        raise RuntimeError(f'{label} implementation missing: {path}')
    exec(
        compile(script.read_text(encoding='utf-8'), str(script), 'exec'),
        {'__name__': '__main__'},
    )


core_before = missing_contracts(core_required)
import_before = missing_contracts(import_required)

if core_before:
    # First materialization: install the complete v3 package/player/native
    # contract together. This patcher is intentionally never rerun once the
    # core contract exists, avoiding collisions with its legacy anchors.
    print('RC2 photo integrity core materialization required: ' + ' | '.join(core_before))
    run_script(
        'tool/apply_rc2_photo_integrity_finalizer_20260825.py',
        'RC2 photo integrity core',
    )
elif import_before:
    # Repeated release materialization can restore only ImportPage from HEAD.
    # Repair only that component and leave the already-final HCVPACK v3 and
    # native PHAssetResource implementation untouched.
    print('RC2 iOS original-photo picker rematerialization required: ' + ' | '.join(import_before))
    run_script(
        'tool/apply_rc2_ios_original_photo_picker_finalizer_20260825.py',
        'RC2 iOS original-photo picker',
    )
else:
    print('RC2 photo integrity already semantically finalized; patchers skipped')

# A first full materialization may still need the isolated ImportPage repair if
# another nested historical patch restores ImportPage after the full patcher.
core_after = missing_contracts(core_required)
if core_after:
    raise RuntimeError(
        'photo integrity core contract incomplete after finalization: '
        + ' | '.join(core_after)
    )

import_after = missing_contracts(import_required)
if import_after:
    print('RC2 iOS picker still incomplete; applying isolated finalizer: ' + ' | '.join(import_after))
    run_script(
        'tool/apply_rc2_ios_original_photo_picker_finalizer_20260825.py',
        'RC2 iOS original-photo picker',
    )
    import_after = missing_contracts(import_required)

if import_after:
    raise RuntimeError(
        'iOS original-photo picker contract incomplete after finalization: '
        + ' | '.join(import_after)
    )

print('RC2 photo integrity semantic wrapper PASS')
