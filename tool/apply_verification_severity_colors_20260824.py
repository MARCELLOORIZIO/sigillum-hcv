from pathlib import Path
import re

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')


def call_end(text: str, call_start: int) -> int:
    paren = text.find('(', call_start)
    if paren < 0:
        raise RuntimeError('widget call opening parenthesis missing')
    depth = 0
    for index in range(paren, len(text)):
        char = text[index]
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                end = index + 1
                while end < len(text) and text[end] in ' \t':
                    end += 1
                if end < len(text) and text[end] == ',':
                    end += 1
                return end
    raise RuntimeError('unbalanced widget call')


# Presentation only: no certificate, capture, ML or risk-threshold changes.
helper_marker = "  bool get _hasSevereVerificationIssue =>"
if helper_marker not in source:
    anchor = "  @override\n  Widget build(BuildContext context) {\n"
    if anchor not in source:
        raise RuntimeError('verification build anchor missing')
    helpers = """  bool get _hasSevereVerificationIssue =>
      _isInvalidResult || _isMediaNotVerified || _isStrongDisplayRisk;

  bool get _hasIntermediateVerificationIssue =>
      !_hasSevereVerificationIssue &&
      (_isRegistryWarningResult ||
          _isDisplayNonConclusive ||
          isScreenReplayWarning);

  Color get _verificationResultColor {
    if (result == null) return Colors.grey;
    if (_hasSevereVerificationIssue) return Colors.red;
    if (_hasIntermediateVerificationIssue) return Colors.orange;
    if (isVerified) return Colors.green;
    return Colors.red;
  }

  IconData get _verificationResultIcon {
    if (result == null) return Icons.cloud_sync;
    if (_hasSevereVerificationIssue) return Icons.error;
    if (_hasIntermediateVerificationIssue) return Icons.warning_amber;
    if (isVerified) return Icons.verified;
    return Icons.error;
  }

"""
    source = source.replace(anchor, helpers + anchor, 1)

# Normalize the large result icon by its stable position immediately before the
# HCV-ID TextField. This is independent of how older formatters laid out the
# ternary icon/color expression.
textfield = source.find('              TextField(')
if textfield < 0:
    raise RuntimeError('verification HCV-ID TextField anchor missing')
icon_start = source.rfind('              Icon(', 0, textfield)
if icon_start < 0:
    raise RuntimeError('verification result Icon widget missing')
icon_end = call_end(source, icon_start)
new_icon = """              Icon(
                _verificationResultIcon,
                size: 72,
                color: _verificationResultColor,
              ),"""
source = source[:icon_start] + new_icon + source[icon_end:]

# Normalize the public result headline color regardless of the old ternary
# formatting. Only the Text widget containing _publicResultTitle is touched.
headline_marker = '_publicResultTitle,'
headline_pos = source.find(headline_marker)
if headline_pos < 0:
    raise RuntimeError('verification public result headline missing')
headline_start = source.rfind('                Text(', 0, headline_pos)
if headline_start < 0:
    raise RuntimeError('verification public result Text widget missing')
headline_end = call_end(source, headline_start)
headline = source[headline_start:headline_end]
headline = re.sub(
    r"                    color:\s*[\s\S]*?,\n                  \),",
    "                    color: _verificationResultColor,\n                  ),",
    headline,
    count=1,
)
if 'color: _verificationResultColor,' not in headline:
    raise RuntimeError('verification result text color normalization failed')
source = source[:headline_start] + headline + source[headline_end:]

# Normalize the Scene axis severity color. Find the card containing either the
# localized or legacy Scene title and rewrite only its color field.
scene_markers = ["title: _v('scene')", "title: 'Scena'"]
scene_pos = next((source.find(marker) for marker in scene_markers if marker in source), -1)
if scene_pos < 0:
    raise RuntimeError('scene verification card missing')
scene_start = source.rfind('                _VerificationAxisCard(', 0, scene_pos)
if scene_start < 0:
    scene_start = source.rfind('              _VerificationAxisCard(', 0, scene_pos)
if scene_start < 0:
    raise RuntimeError('scene verification card start missing')
scene_end = call_end(source, scene_start)
scene_card = source[scene_start:scene_end]
scene_card = re.sub(
    r"color:\s*[\s\S]*?,\n\s*\),$",
    "color: _isStrongDisplayRisk\n                      ? Colors.red\n                      : _isDisplayNonConclusive\n                          ? Colors.orange\n                          : _axisColor(_effectiveSceneState),\n                ),",
    scene_card,
    count=1,
)
if '_isStrongDisplayRisk' not in scene_card or '_isDisplayNonConclusive' not in scene_card:
    raise RuntimeError('scene severity color normalization failed')
source = source[:scene_start] + scene_card + source[scene_end:]

required = [
    '_hasSevereVerificationIssue',
    '_hasIntermediateVerificationIssue',
    '_verificationResultColor',
    '_verificationResultIcon',
    '_isStrongDisplayRisk',
    '_isDisplayNonConclusive',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'verification severity token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Verification severity colors normalized: green / orange / red')
