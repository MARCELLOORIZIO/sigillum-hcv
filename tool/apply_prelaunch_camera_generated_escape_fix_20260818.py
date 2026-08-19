from pathlib import Path

path = Path('lib/camera_page.dart')
source = path.read_text(encoding='utf-8')

broken = "registryStatus = registryStatus == null ? label : '$registryStatus\n$label';"
# The preceding regex-based generator can materialize the replacement escape as
# a literal line break inside a Dart single-quoted string. Normalize it back to
# the intended escaped newline for the UI message only.
fixed = "registryStatus = registryStatus == null ? label : '$registryStatus\\n$label';"

count = source.count(broken)
if count:
    source = source.replace(broken, fixed)

if fixed not in source:
    raise RuntimeError('camera registry status newline normalization anchor missing')

path.write_text(source, encoding='utf-8')
print(f'Camera generated status newline escaping normalized ({count} replacement(s))')

# User-authorized E2E repair: execute only after the generated camera source has
# reached its final prelaunch shape. The repair itself owns strict invariants and
# writes only camera_page.dart plus presentation copy in registry_verify_page.dart.
e2e_repair = Path('tool/apply_e2e_video_livesignals_polish_20260819.py')
if not e2e_repair.exists():
    raise RuntimeError('authorized E2E video live-signals repair missing')
exec(
    compile(e2e_repair.read_text(encoding='utf-8'), str(e2e_repair), 'exec'),
    {'__name__': '__main__'},
)
