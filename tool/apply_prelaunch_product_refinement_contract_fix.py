from pathlib import Path

# Fix the shared-text route after the full prelaunch patch stack has run.
home_path = Path('lib/user_home_page.dart')
home = home_path.read_text(encoding='utf-8')

if "import 'dart:io';" not in home:
    home = "import 'dart:io';\n\n" + home
if "import 'text_social_verify_page.dart';" not in home:
    anchor = "import 'text_cert_page.dart';\n"
    if anchor not in home:
        raise RuntimeError('text social verifier import anchor missing')
    home = home.replace(
        anchor,
        anchor + "import 'text_social_verify_page.dart';\n",
        1,
    )

if 'initialText: sharedText' not in home:
    anchor = "    final lower = path.toLowerCase();\n"
    if home.count(anchor) != 1:
        raise RuntimeError(
            f'shared text route anchor: expected 1, found {home.count(anchor)}'
        )
    route = """    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) {
      File(path).readAsString().then((sharedText) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextSocialVerifyPage(
              languageCode: languageCode,
              initialText: sharedText,
            ),
          ),
        );
      }).catchError((_) {});
      return;
    }
"""
    home = home.replace(anchor, route, 1)

for token in [
    "lower.endsWith('.txt')",
    'TextSocialVerifyPage(',
    'initialText: sharedText',
]:
    if token not in home:
        raise RuntimeError(f'shared text verification token missing: {token}')

home_path.write_text(home, encoding='utf-8')

# Align the older generated UI contract with the approved larger Pancake-style
# controls instead of shrinking the implementation back to the old values.
legacy_contract = Path('test/prelaunch_ui_camera_refinement_contract_test.dart')
if not legacy_contract.exists():
    raise RuntimeError('legacy prelaunch UI contract missing')
contract = legacy_contract.read_text(encoding='utf-8')
replacements = {
    'minimumSize: const Size.fromHeight(58)':
        'minimumSize: const Size.fromHeight(62)',
    'padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)':
        'padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18)',
}
for old, new in replacements.items():
    contract = contract.replace(old, new)
for token in [
    'minimumSize: const Size.fromHeight(62)',
    'padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18)',
]:
    if token not in contract:
        raise RuntimeError(f'approved CTA contract token missing: {token}')
legacy_contract.write_text(contract, encoding='utf-8')

# Apply the approved high-fidelity consumer landing composition after all older
# commercial patches have run, so legacy generated UI cannot overwrite it.
visual_patch = Path('tool/apply_prelaunch_landing_visual_match.py')
if not visual_patch.exists():
    raise RuntimeError('approved landing visual patch missing')
exec(
    compile(
        visual_patch.read_text(encoding='utf-8'),
        str(visual_patch),
        'exec',
    ),
    {'__name__': '__main__'},
)

# Normalize the presentation-only demo HCV-ID literal generated above.
visual_compile_fix = Path('tool/apply_prelaunch_landing_visual_compile_fix.py')
if not visual_compile_fix.exists():
    raise RuntimeError('approved landing visual compile fix missing')
exec(
    compile(
        visual_compile_fix.read_text(encoding='utf-8'),
        str(visual_compile_fix),
        'exec',
    ),
    {'__name__': '__main__'},
)

gate_source = Path('lib/commercial_gate.dart').read_text(encoding='utf-8')
for token in [
    'Benvenuto in ',
    'SIGILLUM!',
    'Verifica in pochi secondi',
    'VERIFICA CONTENUTO GRATIS',
    'Accedi al tuo account',
    'Crea account',
    'Diventa creator',
    'Insieme costruiamo fiducia',
    'ID SIGILLUM\\nF80B0A573FBB4940',
]:
    if token not in gate_source:
        raise RuntimeError(f'approved landing visual token missing: {token}')

# Double only the established compact camera confirmation CTA. Capture,
# detector, evidence and HCV logic stay untouched.
proceed_normalizer = Path('tool/apply_prelaunch_proceed_anchor_normalization.py')
if not proceed_normalizer.exists():
    raise RuntimeError('camera proceed normalization patch missing')
exec(
    compile(
        proceed_normalizer.read_text(encoding='utf-8'),
        str(proceed_normalizer),
        'exec',
    ),
    {'__name__': '__main__'},
)

# Prepare the final visual/caption patch so it preserves that compact top
# banner instead of replacing it, and align the generated safety contracts.
final_prepare = Path('tool/prepare_prelaunch_visual_caption_refinement_20260818.py')
if not final_prepare.exists():
    raise RuntimeError('final visual/caption preparation patch missing')
exec(
    compile(
        final_prepare.read_text(encoding='utf-8'),
        str(final_prepare),
        'exec',
    ),
    {'__name__': '__main__'},
)

print('Shared text routing, CTA contract and approved landing visual aligned')
