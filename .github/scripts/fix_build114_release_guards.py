from pathlib import Path

verifier = Path('tool/verify_postpatch_release_20260825.py')
text = verifier.read_text(encoding='utf-8')
old = """    'TFLite runtime:',\n    'Pixel-grid uniformity:',\n    'Fine stripe:',\n"""
new = """    \"ml?['tfliteRuntimeVersion']\",\n    'pixelGridUniformityScore',\n    'liveProbeFineStripeScore',\n"""
if text.count(old) != 1:
    raise RuntimeError(f'unexpected verifier legacy diagnostics block count: {text.count(old)}')
text = text.replace(old, new, 1)
verifier.write_text(text, encoding='utf-8')

build = Path('tool/build_testflight_ipa_rc2_20260825.sh')
text = build.read_text(encoding='utf-8')
old = 'require_source_token lib/registry_verify_page.dart "TFLite runtime:"\n'
new = '''require_source_token lib/registry_verify_page.dart "ml?['tfliteRuntimeVersion']"\nrequire_source_token lib/registry_verify_page.dart "pixelGridUniformityScore"\nrequire_source_token lib/registry_verify_page.dart "liveProbeFineStripeScore"\n'''
if text.count(old) != 1:
    raise RuntimeError(f'unexpected build-script legacy diagnostic guard count: {text.count(old)}')
text = text.replace(old, new, 1)
build.write_text(text, encoding='utf-8')

print('BUILD114 release guards updated; product source unchanged')
