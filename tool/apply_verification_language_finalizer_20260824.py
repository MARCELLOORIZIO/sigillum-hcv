from pathlib import Path

# The Registry finalizer repairs/replaces any legacy diagnostic layout left by
# previous build-time patchers before language assertions are evaluated.
registry_finalizer = Path('tool/apply_verification_registry_finalizer_20260824.py')
if not registry_finalizer.exists():
    raise RuntimeError('Registry verification finalizer missing')
exec(
    compile(registry_finalizer.read_text(encoding='utf-8'), str(registry_finalizer), 'exec'),
    {'__name__': '__main__'},
)

# A compatible derivative is a valid SIGILLUM-linked result but not equivalent
# to a byte-identical certified original, so its public severity is intermediate.
severity_finalizer = Path('tool/apply_verification_social_severity_fix_20260824.py')
if not severity_finalizer.exists():
    raise RuntimeError('Verification severity finalizer missing')
exec(
    compile(severity_finalizer.read_text(encoding='utf-8'), str(severity_finalizer), 'exec'),
    {'__name__': '__main__'},
)

# Verification hub buttons must follow the selected IT/EN/ES/RU language.
path = Path('lib/import_page.dart')
source = path.read_text(encoding='utf-8')
if "import 'verification_ui_copy.dart';" not in source:
    anchor = "import 'sigillum_theme.dart';\n"
    if anchor not in source:
        raise RuntimeError('verification hub theme import missing')
    source = source.replace(anchor, anchor + "import 'verification_ui_copy.dart';\n", 1)
if "String _v(String key)" not in source:
    anchor = "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n"
    if anchor not in source:
        raise RuntimeError('verification hub localization helper missing')
    source = source.replace(
        anchor,
        anchor + "  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);\n",
        1,
    )
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                        ? 'VERIFICA TESTO'\n                        : 'VERIFY TEXT'),",
    "label: Text(_v('verifyText')),",
)
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                        ? 'VERIFICA FOTO'\n                        : 'VERIFY PHOTO'),",
    "label: Text(_v('verifyPhoto')),",
)
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                        ? 'VERIFICA VIDEO'\n                        : 'VERIFY VIDEO'),",
    "label: Text(_v('verifyVideo')),",
)
# Formatter variants used by the legacy fallback.
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                    ? 'VERIFICA TESTO'\n                    : 'VERIFY TEXT'),",
    "label: Text(_v('verifyText')),",
)
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                    ? 'VERIFICA FOTO'\n                    : 'VERIFY PHOTO'),",
    "label: Text(_v('verifyPhoto')),",
)
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                    ? 'VERIFICA VIDEO'\n                    : 'VERIFY VIDEO'),",
    "label: Text(_v('verifyVideo')),",
)
source = source.replace(
    "widget.languageCode == 'it'\n                        ? 'Scegli il tipo di contenuto da verificare.'\n                        : 'Choose the type of content to verify.'",
    "_v('verifyTitle')",
)
if 'VERIFICA TESTO / DOCUMENTO' in source:
    raise RuntimeError('obsolete long verification label survived finalizer')
for token in ["_v('verifyText')", "_v('verifyPhoto')", "_v('verifyVideo')"]:
    if token not in source:
        raise RuntimeError(f'verification hub translation token missing: {token}')
path.write_text(source, encoding='utf-8')

# The 18/08 visual-caption patch generates its own contract before the later
# media-picker/language finalizers run. Align only that generated test with the
# final approved three-action multilingual verification hub.
visual_contract = Path('test/prelaunch_visual_caption_refinement_contract_test.dart')
if visual_contract.exists():
    contract = visual_contract.read_text(encoding='utf-8')
    contract = contract.replace(
        "expect(page, contains('VERIFICA TESTO PUBBLICATO'));",
        "expect(page, contains(\"_v('verifyText')\"));",
    )
    contract = contract.replace(
        "expect(page, contains('TextSocialVerifyPage('));",
        "expect(page, contains('onPressed: pickDocument'));",
    )
    contract = contract.replace(
        "expect(page, contains('Verifica foto, video o documento'));",
        "expect(page, contains('onPressed: pickPhoto'));\n    expect(page, contains('onPressed: pickVideo'));",
    )
    visual_contract.write_text(contract, encoding='utf-8')

# Ensure the quick gate contains no residual binary IT/EN selector.
quick = Path('lib/quick_hcv_media_gate_page.dart')
quick_source = quick.read_text(encoding='utf-8')
if '_isItalian' in quick_source:
    raise RuntimeError('quick verification gate still uses IT/EN-only language branching')

# Registry, router and HCVPACK must all receive the original chosen language.
for file_name in [
    'lib/registry_verify_page.dart',
    'lib/hcv_import_router_page.dart',
    'lib/hcvpack_player_page.dart',
]:
    text = Path(file_name).read_text(encoding='utf-8')
    if "VerificationUiCopy.t(widget.languageCode, key)" not in text:
        raise RuntimeError(f'{file_name}: selected-language verification copy missing')

print('Verification language now propagates through hub, quick check, Registry, router and HCVPACK')