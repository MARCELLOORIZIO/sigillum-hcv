from pathlib import Path

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

status_line = "    status = _v('verificationIncomplete');"
path_line = "    final path = widget.initialMediaPath;"

lines = source.splitlines()
try:
    path_index = lines.index(path_line)
except ValueError as exc:
    raise RuntimeError('Registry initial-media path anchor missing') from exc

# Older verification patchers append the same localized initial status before
# initialMediaPath every time they run. Remove every consecutive copy directly
# preceding that stable boundary, then restore exactly one. This operation is
# deterministic and idempotent: N copies -> 1 copy for every N >= 0.
start = path_index
while start > 0 and lines[start - 1] == status_line:
    start -= 1

removed = path_index - start
lines[start:path_index] = [status_line]

# Re-resolve the boundary after the edit and prove the local invariant.
path_index = lines.index(path_line)
if path_index == 0 or lines[path_index - 1] != status_line:
    raise RuntimeError('Registry initial status missing at initial-media boundary')
if path_index > 1 and lines[path_index - 2] == status_line:
    raise RuntimeError('Registry duplicate initial status survived normalization')

path.write_text('\n'.join(lines) + ('\n' if source.endswith('\n') else ''), encoding='utf-8')
print(
    'Registry initial localized status normalized to exactly one assignment '
    f'(removed={removed}, final=1)'
)
