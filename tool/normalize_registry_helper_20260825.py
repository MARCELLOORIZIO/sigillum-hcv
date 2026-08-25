from pathlib import Path


path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

LEGACY = 'Il certificato viene recuperato automaticamente dal Registry HCV. Devi selezionare SOLO il file originale.'
LOCALIZED = "_v('registryHelper')"


def remove_enclosing_text_widget(text: str, marker: str) -> tuple[str, int]:
    removed = 0
    while marker in text:
        marker_pos = text.index(marker)
        starts = [
            text.rfind('\n              const Text(', 0, marker_pos),
            text.rfind('\n              Text(', 0, marker_pos),
        ]
        start = max(starts)
        if start < 0:
            raise RuntimeError(f'Registry helper widget start not found for marker: {marker}')

        text_call = text.find('Text(', start, marker_pos + 1)
        if text_call < 0:
            raise RuntimeError(f'Registry helper Text call not found for marker: {marker}')

        paren = text.find('(', text_call)
        depth = 0
        end = None
        for index in range(paren, len(text)):
            char = text[index]
            if char == '(':
                depth += 1
            elif char == ')':
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break
        if end is None:
            raise RuntimeError(f'Unbalanced Registry helper Text widget for marker: {marker}')

        while end < len(text) and text[end] in ' \t':
            end += 1
        if end < len(text) and text[end] == ',':
            end += 1
        if end < len(text) and text[end] == '\n':
            end += 1

        text = text[:start] + '\n' + text[end:]
        removed += 1
    return text, removed


# Normalize all historical variants. Repeated patch chains may leave more than
# one helper widget; release output must contain exactly one localized helper.
source, legacy_removed = remove_enclosing_text_widget(source, LEGACY)
source, localized_removed = remove_enclosing_text_widget(source, LOCALIZED)

if "String _v(String key)" not in source and 'VerificationUiCopy.t(widget.languageCode, key)' not in source:
    raise RuntimeError('Registry selected-language helper unavailable')

anchor = '              if (_hasVerificationAxes) ...['
if anchor not in source:
    raise RuntimeError('Registry helper stable insertion anchor missing')

helper = """              Text(
                _v('registryHelper'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
"""
source = source.replace(anchor, helper + anchor, 1)

if source.count(LOCALIZED) != 1:
    raise RuntimeError(f'Registry helper normalization produced {source.count(LOCALIZED)} localized widgets')
if LEGACY in source:
    raise RuntimeError('Legacy Italian Registry helper survived normalization')

path.write_text(source, encoding='utf-8')
print(
    'Registry helper normalized to exactly one localized widget '
    f'(legacy_removed={legacy_removed}, localized_removed={localized_removed})'
)
