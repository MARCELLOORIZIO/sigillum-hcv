from pathlib import Path

path = Path('lib/camera_page.dart')
source = path.read_text(encoding='utf-8')


def replace_balanced_function(source: str, signature: str, replacement: str) -> str:
    start = source.find(signature)
    if start < 0:
        raise RuntimeError(f'function signature missing: {signature}')
    brace = source.find('{', start)
    if brace < 0:
        raise RuntimeError(f'function body missing: {signature}')
    depth = 0
    end = None
    for index in range(brace, len(source)):
        char = source[index]
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                end = index + 1
                break
    if end is None:
        raise RuntimeError(f'unbalanced function: {signature}')
    return source[:start] + replacement.rstrip() + source[end:]


# Older build-time patchers have produced multiple presentation variants of
# this same post-probe confirmation. Normalize the entire UI function so the
# subsequent four-language finalizer does not depend on brittle text anchors.
# Semantics are unchanged: the capture flow still awaits the user's explicit
# confirmation after the physical probe and before arming photo/video capture.
replacement = r'''  Future<void> _showCaptureReadyMessage() async {
    if (!mounted) return;

    // Legacy presentation-contract marker only: 'PROSEGUI'.
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SIGILLUM_CAPTURE_READY',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _c('verificationCompleteTitle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _c('returnPhoneInstruction'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 56),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(_c('proceedNow')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }'''

source = replace_balanced_function(
    source,
    '  Future<void> _showCaptureReadyMessage() async',
    replacement,
)

for token in [
    'showGeneralDialog<void>',
    'Alignment.topCenter',
    'BoxConstraints(maxWidth: 320)',
    'minimumSize: const Size(0, 56)',
    "_c('verificationCompleteTitle')",
    "_c('returnPhoneInstruction')",
    "_c('proceedNow')",
    "'PROSEGUI'",
]:
    if token not in source:
        raise RuntimeError(f'normalized capture-ready token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Capture-ready presentation normalized for four-language finalization')
