from pathlib import Path

PATH = Path('lib/commercial_gate.dart')
source = PATH.read_text(encoding='utf-8')

# The approved landing replaces the original first child of _brand with
# _sigillumMark(). The legal/localization patch deliberately anchors on the
# original presentation-only Container. Add a zero-size presentation anchor so
# the localization patch can insert the selector without rewriting the approved
# brand or touching any HCV/capture component.
if "ValueKey('landing-visual-v2')" in source:
    old = """  Widget _brand({String? subtitle}) {
    return Column(
      children: [
        _sigillumMark(size: 66),
"""
    new = """  Widget _brand({String? subtitle}) {
    return Column(
      children: [
        Container(width: 0, height: 0),
        _sigillumMark(size: 66),
"""
    if old in source and 'Container(width: 0, height: 0)' not in source:
        source = source.replace(old, new, 1)
    elif 'Container(width: 0, height: 0)' not in source:
        raise RuntimeError('approved landing brand bridge anchor missing')

PATH.write_text(source, encoding='utf-8')
print('Approved landing bridged to multilingual selector without HCV/capture changes')
