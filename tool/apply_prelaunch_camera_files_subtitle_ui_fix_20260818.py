from pathlib import Path
import re


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


def replace_regex(source: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count == 1:
        return updated
    if replacement in source:
        return source
    raise RuntimeError(f'{label}: regex anchor missing')


path = Path('lib/camera_page.dart')
source = path.read_text(encoding='utf-8')

if "import 'sigillum_quick_guide_page.dart';" not in source:
    source = replace_once(
        source,
        "import 'video_transcription_service.dart';\n",
        "import 'video_transcription_service.dart';\nimport 'sigillum_quick_guide_page.dart';\n",
        'camera quick-guide import',
    )

# Apple Speech must use the app language instead of whichever system locale happens to be active.
source = source.replace(
    'final transcript = await const VideoTranscriptionService().transcribe(path);',
    'final transcript = await const VideoTranscriptionService().transcribe(\n        path,\n        languageCode: widget.languageCode,\n      );',
    1,
)

# Distinguish the certified original from the derived captioned copy in Photos.
gallery_pattern = r'''  Future<void> saveContentToGallery\(String path\) async \{.*?\n  \}\n\n  Future<void> sharePackage'''
gallery_replacement = r'''  Future<bool> saveContentToGallery(String path) async {
    if (!Platform.isIOS) return false;

    final lower = path.toLowerCase();
    final isCaptioned = lower.contains('_sottotitolato');
    final isPhoto = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');

    try {
      final saved = await _mediaChannel.invokeMethod<bool>(
        'saveToPhotos',
        {'path': path},
      );
      if (saved == true && mounted) {
        final label = isCaptioned
            ? 'Video SOTTOTITOLATO salvato in Foto'
            : isPhoto
                ? 'Foto certificata salvata in Foto'
                : 'Originale certificato salvato in Foto (senza sottotitoli)';
        setState(() {
          registryStatus = registryStatus == null ? label : '$registryStatus\n$label';
        });
        return true;
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          final label = isCaptioned
              ? 'Video sottotitolato disponibile in File; salvataggio in Foto non riuscito'
              : 'Non salvato in Foto: permesso non disponibile';
          registryStatus = registryStatus == null ? label : '$registryStatus\n$label';
        });
      }
      return false;
    }
  }

  Future<void> _saveCaptionedVideoToPhotos() async {
    final path = _captionedVideoPath;
    if (path == null) return;
    final saved = await saveContentToGallery(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Video sottotitolato salvato in Foto.'
              : 'Non è stato possibile salvare il video sottotitolato in Foto.',
        ),
      ),
    );
  }

  void _openCameraQuickGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SigillumQuickGuidePage(languageCode: widget.languageCode),
      ),
    );
  }

  Future<void> sharePackage'''
source = replace_regex(source, gallery_pattern, gallery_replacement, 'gallery save semantics')

# The derived copy is saved after rendering and the UI tells the user which copy reached Photos.
save_anchor = """      await saveContentToGallery(transcript.captionedVideoPath);
      if (!mounted) return;
      await showDialog<void>(
"""
if 'savedCaptionedToPhotos' not in source:
    source = replace_once(
        source,
        save_anchor,
        """      final savedCaptionedToPhotos =
          await saveContentToGallery(transcript.captionedVideoPath);
      if (!mounted) return;
      setState(() {
        status = savedCaptionedToPhotos
            ? 'VIDEO SOTTOTITOLATO PRONTO — SALVATO IN FOTO'
            : 'VIDEO SOTTOTITOLATO PRONTO — DISPONIBILE IN FILE';
      });
      await showDialog<void>(
""",
        'captioned Photos result',
    )

# Give the user an explicit retry/save control and make SRT sharing fully readable.
old_buttons = r'''          if (_captionedVideoPath != null)
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                onPressed: _shareCaptionedVideo,
                icon: const Icon(Icons.closed_caption_rounded),
                label: const Text('CONDIVIDI VIDEO SOTTOTITOLATO'),
              ),
            ),
          if (_captionedVideoPath != null) const SizedBox(height: 10),
          if (_subtitlePath != null)
            SizedBox(
              width: 340,
              child: OutlinedButton.icon(
                onPressed: _shareSubtitleFile,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('CONDIVIDI SOTTOTITOLI .SRT'),
              ),
            ),'''
new_buttons = r'''          if (_captionedVideoPath != null)
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                onPressed: _saveCaptionedVideoToPhotos,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('SALVA VIDEO SOTTOTITOLATO IN FOTO'),
              ),
            ),
          if (_captionedVideoPath != null) const SizedBox(height: 10),
          if (_captionedVideoPath != null)
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                onPressed: _shareCaptionedVideo,
                icon: const Icon(Icons.closed_caption_rounded),
                label: const Text('CONDIVIDI VIDEO SOTTOTITOLATO'),
              ),
            ),
          if (_captionedVideoPath != null) const SizedBox(height: 10),
          if (_subtitlePath != null)
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1FC7D4),
                  foregroundColor: const Color(0xFF280D5F),
                  minimumSize: const Size.fromHeight(64),
                ),
                onPressed: _shareSubtitleFile,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('CONDIVIDI SOTTOTITOLI .SRT'),
              ),
            ),'''
source = replace_once(source, old_buttons, new_buttons, 'readable subtitle actions')

# Replace internal container paths with the path users can actually open in Apple Files.
files_pattern = r'''  Widget _createdFilesCard\(\) \{.*?\n  \}\n\n  Widget _actionButtons\(\)'''
files_replacement = r'''  Widget _createdFilesCard() {
    if (videoPath == null &&
        hcvPath == null &&
        packagePath == null &&
        _captionedVideoPath == null &&
        _subtitlePath == null) {
      return const SizedBox.shrink();
    }

    String fileName(String? value) => value == null ? '-' : p.basename(value);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7E3EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.folder_outlined, color: Color(0xFF0098A1), size: 34),
          const SizedBox(height: 8),
          const Text(
            'DOVE TROVI I FILE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF280D5F),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'File > Sul mio iPhone > Fotocamera Sigillum',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF280D5F),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'SIGILLUM salva automaticamente qui i file principali. Non devi scegliere manualmente la cartella.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7A6EAA),
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
          const Divider(height: 24),
          if (videoPath != null)
            Text('Originale certificato: ${fileName(videoPath)}', textAlign: TextAlign.center),
          if (hcvPath != null) ...[
            const SizedBox(height: 5),
            Text('Certificato HCV: ${fileName(hcvPath)}', textAlign: TextAlign.center),
          ],
          if (packagePath != null) ...[
            const SizedBox(height: 5),
            Text('HCVPACK: ${fileName(packagePath)}', textAlign: TextAlign.center),
          ],
          if (_captionedVideoPath != null) ...[
            const SizedBox(height: 5),
            Text(
              'Video sottotitolato: ${fileName(_captionedVideoPath)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          if (_subtitlePath != null) ...[
            const SizedBox(height: 5),
            Text('Sottotitoli SRT: ${fileName(_subtitlePath)}', textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _openCameraQuickGuide,
            icon: const Icon(Icons.help_outline_rounded),
            label: const Text('GUIDA RAPIDA'),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons()'''
source = replace_regex(source, files_pattern, files_replacement, 'friendly Files card')

# The result page always exposes GUIDA RAPIDA. Add an app-bar help icon only if
# the generated camera app bar still matches the legacy anchor; do not fail if
# another presentation patch has already reshaped the app bar.
actions_anchor = r'''        actions: [
          IconButton(
            icon: Icon(
              currentFlashMode == FlashMode.off'''
if "tooltip: 'Guida rapida'" not in source and actions_anchor in source:
    source = source.replace(
        actions_anchor,
        r'''        actions: [
          IconButton(
            tooltip: 'Guida rapida',
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
            onPressed: _openCameraQuickGuide,
          ),
          IconButton(
            icon: Icon(
              currentFlashMode == FlashMode.off''',
        1,
    )

for token in [
    'SALVA VIDEO SOTTOTITOLATO IN FOTO',
    'minimumSize: const Size.fromHeight(64)',
    'File > Sul mio iPhone > Fotocamera Sigillum',
    'Originale certificato salvato in Foto (senza sottotitoli)',
    'languageCode: widget.languageCode',
    'SigillumQuickGuidePage',
]:
    if token not in source:
        raise RuntimeError(f'camera usability token missing: {token}')

for forbidden in [
    'HCVDisplayRiskFusion.combine =',
    'HCVEngine().setClaims =',
    'verifyFile =',
]:
    if forbidden in source:
        raise RuntimeError(f'engine mutation marker found in camera usability patch: {forbidden}')

path.write_text(source, encoding='utf-8')
print('Camera subtitle buttons, Photos copy and Apple Files guidance applied')
