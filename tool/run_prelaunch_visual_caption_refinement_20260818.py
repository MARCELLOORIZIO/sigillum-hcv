from pathlib import Path

patch_path = Path('tool/apply_prelaunch_visual_caption_refinement_20260818.py')
if not patch_path.exists():
    raise RuntimeError('final visual/caption refinement patch missing')

source = patch_path.read_text(encoding='utf-8')

# The established camera confirmation is a compact top banner. Its height is
# doubled by apply_prelaunch_proceed_anchor_normalization.py (28 -> 56). Skip
# the obsolete AlertDialog replacement embedded in the first draft of the final
# visual patch, and align its own contract with the compact 56px control.
obsolete = "camera = replace_once(camera, proceed_old, proceed_new, 'double-height proceed control')"
if obsolete not in source:
    raise RuntimeError('obsolete proceed replacement anchor missing from final patch')
source = source.replace(
    obsolete,
    "# compact PROSEGUI already doubled to 56px by the preceding presentation-only normalizer",
    1,
)
source = source.replace(
    'minimumSize: const Size(280, 124)',
    'minimumSize: const Size(0, 56)',
)

exec(compile(source, str(patch_path), 'exec'), {'__name__': '__main__'})

# Update the older transcription contract to the newly approved behavior:
# transcript/SRT remain available, and a separate derived mp4 receives timed
# subtitles. The original certified source and HCV engine remain untouched.
contract_path = Path('test/prelaunch_product_refinement_contract_test.dart')
if not contract_path.exists():
    raise RuntimeError('prelaunch product refinement contract missing')
contract = contract_path.read_text(encoding='utf-8')
contract = contract.replace(
    "test('video transcription is a sidecar and leaves HCV engine files untouched'",
    "test('video transcription creates a derived captioned copy and leaves HCV engine files untouched'",
)
contract = contract.replace(
    "expect(camera, contains('TRASCRIVI AUDIO / CREA SOTTOTITOLI'));",
    "expect(camera, contains('CREA VIDEO CON SOTTOTITOLI'));",
)
anchor = "    expect(service, contains(\"_sigillum.srt\"));\n"
addition = (
    "    expect(service, contains(\"_sigillum.srt\"));\n"
    "    expect(service, contains(\"_sottotitolato.mp4\"));\n"
    "    expect(service, contains(\"'burnSubtitles'\"));\n"
    "    expect(scene, contains('call.method == \"burnSubtitles\"'));\n"
)
if "_sottotitolato.mp4" not in contract:
    if anchor not in contract:
        raise RuntimeError('transcription contract SRT anchor missing')
    contract = contract.replace(anchor, addition, 1)
if "expect(service, isNot(contains('HCVEngine')));" not in contract:
    raise RuntimeError('HCV engine isolation assertion missing')
contract_path.write_text(contract, encoding='utf-8')

# The landing now intentionally offers exactly one registration entry:
# "Diventa creator". Keep the existing auth/KYC safety assertions intact.
landing_contract = Path('test/commercial_ux_kyc_identity_contract_test.dart')
if landing_contract.exists():
    test = landing_contract.read_text(encoding='utf-8')
    test = test.replace(
        "test('commercial landing exposes verify, login, account creation and creator registration'",
        "test('commercial landing exposes verify, login and one creator registration entry'",
    )
    test = test.replace("    expect(source, contains('Crea account'));\n", '')
    if "isNot(contains(\"title: 'Crea account'\"))" not in test:
        creator_anchor = "    expect(source, contains('Diventa creator'));\n"
        if creator_anchor not in test:
            raise RuntimeError('creator landing contract anchor missing')
        test = test.replace(
            creator_anchor,
            creator_anchor + "    expect(source, isNot(contains(\"title: 'Crea account'\")));\n",
            1,
        )
    landing_contract.write_text(test, encoding='utf-8')

# Verify the compact banner contract was preserved and only its height changed.
camera = Path('lib/camera_page.dart').read_text(encoding='utf-8')
start = camera.find('_showCaptureReadyMessage')
end = camera.find('_toggleCoordinateStamp', start)
confirmation = camera[start:end]
for token in [
    'showGeneralDialog<void>',
    'Alignment.topCenter',
    'BoxConstraints(maxWidth: 320)',
    "'PROSEGUI'",
    'minimumSize: const Size(0, 56)',
]:
    if token not in confirmation:
        raise RuntimeError(f'final compact proceed contract missing: {token}')
if 'AlertDialog' in confirmation:
    raise RuntimeError('final camera proceed confirmation is no longer compact')

print('Final visual/caption refinement executed with compact 56px PROSEGUI and updated safety contracts')
