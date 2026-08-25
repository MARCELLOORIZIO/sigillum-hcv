from pathlib import Path
import re

path = Path('lib/camera_page.dart')
source = path.read_text(encoding='utf-8')

selector = r"widget\.languageCode\.toLowerCase\(\)\.startsWith\('it'\)"

rules = [
    (
        rf"String get _physicalProbeStatus\s*=>\s*{selector}\s*\?\s*'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE\.\.\.'\s*:\s*'MOVE THE PHONE SLIGHTLY SIDEWAYS\.\.\.'\s*;",
        "String get _physicalProbeStatus => _c('physicalProbe');",
        'physicalProbe',
    ),
    (
        rf"{selector}\s*\?\s*'Coordinate non stampate\.'\s*:\s*'Coordinates will not be printed\.'",
        "_c('coordinatesOff')",
        'coordinatesOff',
    ),
    (
        rf"status\s*=\s*{selector}\s*\?\s*'ACQUISIZIONE COORDINATE\.\.\.'\s*:\s*'ACQUIRING COORDINATES\.\.\.'\s*;",
        "status = _c('acquiringCoordinates');",
        'acquiringCoordinates',
    ),
    (
        rf"status\s*=\s*{selector}\s*\?\s*'PRONTO — PREMI REGISTRA PER INIZIARE'\s*:\s*'READY — PRESS RECORD TO START'\s*;",
        "status = _c('armedVideoReady');",
        'armedVideoReady',
    ),
    (
        rf"status\s*=\s*{selector}\s*\?\s*'INQUADRA E PREMI IL PULSANTE DI SCATTO'\s*:\s*'COMPOSE AND PRESS THE SHUTTER BUTTON'\s*;",
        "status = _c('armedPhotoReady');",
        'armedPhotoReady',
    ),
    (
        rf"tooltip\s*:\s*{selector}\s*\?\s*'Stampa coordinate GPS'\s*:\s*'Print GPS coordinates'\s*,",
        "tooltip: _c('printGpsCoordinates'),",
        'printGpsCoordinates',
    ),
]

for pattern, replacement, label in rules:
    source, count = re.subn(pattern, replacement, source, count=1, flags=re.MULTILINE)
    # A rule may already have been normalized by a prior pass. In that case the
    # final token is sufficient; otherwise the legacy selector must have matched.
    final_token = replacement.split(';')[0].strip()
    if count == 0 and final_token not in source:
        raise RuntimeError(f'camera localization normalization anchor missing: {label}')

# The six known public binary selectors above are the only selected-language
# branches permitted in this finalization stage. If another one appears, fail
# with line context instead of silently changing camera logic.
remaining = []
for number, line in enumerate(source.splitlines(), start=1):
    if "widget.languageCode.toLowerCase().startsWith('it')" in line:
        remaining.append((number, line.strip()))
if remaining:
    details = '; '.join(f'{number}:{line}' for number, line in remaining)
    raise RuntimeError(f'unclassified Camera IT/EN selector remains after normalization: {details}')

path.write_text(source, encoding='utf-8')
print('Camera localization anchors normalized independently of dart-format layout')
