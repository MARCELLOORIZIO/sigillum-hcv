from pathlib import Path

path = Path('tool/apply_prelaunch_visual_caption_refinement_20260818.py')
if not path.exists():
    raise RuntimeError('final visual/caption refinement patch missing')

source = path.read_text(encoding='utf-8')
obsolete = "camera = replace_once(camera, proceed_old, proceed_new, 'double-height proceed control')"
if obsolete in source:
    source = source.replace(
        obsolete,
        "# compact PROSEGUI already doubled to 56px by the preceding presentation-only normalizer",
        1,
    )
source = source.replace(
    'minimumSize: const Size(280, 124)',
    'minimumSize: const Size(0, 56)',
)

post_contract = r'''

# Align older generated presentation contracts with the approved final UX.
legacy_product_contract = Path('test/prelaunch_product_refinement_contract_test.dart')
if legacy_product_contract.exists():
    contract = legacy_product_contract.read_text(encoding='utf-8')
    contract = contract.replace(
        "test('video transcription is a sidecar and leaves HCV engine files untouched'",
        "test('video transcription creates a derived captioned copy and leaves HCV engine files untouched'",
    )
    contract = contract.replace(
        "expect(camera, contains('TRASCRIVI AUDIO / CREA SOTTOTITOLI'));",
        "expect(camera, contains('CREA VIDEO CON SOTTOTITOLI'));",
    )
    srt_anchor = "    expect(service, contains(\"_sigillum.srt\"));\n"
    if '_sottotitolato.mp4' not in contract and srt_anchor in contract:
        contract = contract.replace(
            srt_anchor,
            srt_anchor
            + "    expect(service, contains(\"_sottotitolato.mp4\"));\n"
            + "    expect(service, contains(\"'burnSubtitles'\"));\n"
            + "    expect(scene, contains('call.method == \"burnSubtitles\"'));\n",
            1,
        )
    if "expect(service, isNot(contains('HCVEngine')));" not in contract:
        raise RuntimeError('legacy transcription HCV isolation assertion missing')
    legacy_product_contract.write_text(contract, encoding='utf-8')

legacy_landing_contract = Path('test/commercial_ux_kyc_identity_contract_test.dart')
if legacy_landing_contract.exists():
    contract = legacy_landing_contract.read_text(encoding='utf-8')
    contract = contract.replace(
        "test('commercial landing exposes verify, login, account creation and creator registration'",
        "test('commercial landing exposes verify, login and one creator registration entry'",
    )
    contract = contract.replace("    expect(source, contains('Crea account'));\n", '')
    creator_anchor = "    expect(source, contains('Diventa creator'));\n"
    no_duplicate = "    expect(source, isNot(contains(\"title: 'Crea account'\")));\n"
    if no_duplicate not in contract and creator_anchor in contract:
        contract = contract.replace(creator_anchor, creator_anchor + no_duplicate, 1)
    legacy_landing_contract.write_text(contract, encoding='utf-8')

camera_source = Path('lib/camera_page.dart').read_text(encoding='utf-8')
confirmation_start = camera_source.find('_showCaptureReadyMessage')
confirmation_end = camera_source.find('_toggleCoordinateStamp', confirmation_start)
confirmation = camera_source[confirmation_start:confirmation_end]
for final_token in [
    'showGeneralDialog<void>',
    'Alignment.topCenter',
    'BoxConstraints(maxWidth: 320)',
    "'PROSEGUI'",
    'minimumSize: const Size(0, 56)',
]:
    if final_token not in confirmation:
        raise RuntimeError(f'compact final proceed token missing: {final_token}')
if 'AlertDialog' in confirmation:
    raise RuntimeError('compact final proceed unexpectedly became an AlertDialog')

print('Legacy visual/transcription contracts aligned with final approved UX')
'''

marker = "print('Legacy visual/transcription contracts aligned with final approved UX')"
if marker not in source:
    source = source.rstrip() + post_contract + '\n'

path.write_text(source, encoding='utf-8')
print('Final visual/caption patch prepared for compact 56px PROSEGUI and derived captions')
