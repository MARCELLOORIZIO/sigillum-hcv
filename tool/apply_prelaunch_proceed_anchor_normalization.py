from pathlib import Path
import re

path = Path('lib/camera_page.dart')
source = path.read_text(encoding='utf-8')

pattern = re.compile(
    r"  Future<void> _showCaptureReadyMessage\(\) async \{.*?\n  \}\n\n  Future<void> _toggleCoordinateStamp\(\) async \{",
    re.S,
)
replacement = r'''  Future<void> _showCaptureReadyMessage() async {
    if (!mounted) return;
    final italian = widget.languageCode.toLowerCase().startsWith('it');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          italian ? 'VERIFICA COMPLETATA' : 'VERIFICATION COMPLETE',
        ),
        content: Text(
          italian
              ? 'Riporta il telefono sull’inquadratura desiderata. Ora puoi procedere con la foto o il video.'
              : 'Return the phone to the desired composition. You can now proceed with the photo or video.',
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              italian ? 'ORA PUOI PROCEDERE' : 'PROCEED NOW',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCoordinateStamp() async {'''

source, count = pattern.subn(replacement, source, count=1)
if count != 1 and "italian ? 'ORA PUOI PROCEDERE' : 'PROCEED NOW'" not in source:
    raise RuntimeError('camera proceed dialog normalization anchor missing')

path.write_text(source, encoding='utf-8')
print('Camera proceed dialog normalized for final presentation refinement')
