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
