from pathlib import Path
import re

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

status_line = "    status = _v('verificationIncomplete');"
path_line = "    final path = widget.initialMediaPath;"

if path_line not in source:
    raise RuntimeError('Registry initial-media path anchor missing')

# Legacy verification patchers insert the same localized initial status before
# initialMediaPath on every invocation. Collapse every consecutive copy at that
# stable boundary, then restore exactly one. This is presentation state only.
pattern = (
    r"(?:    status = _v\('verificationIncomplete'\);\n)*"
    r"    final path = widget\.initialMediaPath;"
)
replacement = status_line + "\n" + path_line
source, count = re.subn(pattern, replacement, source, count=1)
if count != 1:
    raise RuntimeError('Registry initial-status normalization failed')

boundary = source[source.find(status_line):source.find(path_line) + len(path_line)]
if boundary.count(status_line) != 1:
    raise RuntimeError(
        f'Registry initial status must occur once at initial-media boundary; got {boundary.count(status_line)}'
    )

path.write_text(source, encoding='utf-8')
print('Registry initial localized status normalized to exactly one assignment')
