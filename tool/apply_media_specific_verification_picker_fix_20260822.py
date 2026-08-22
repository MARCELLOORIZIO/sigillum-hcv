from pathlib import Path
import re

path = Path('lib/import_page.dart')
source = path.read_text(encoding='utf-8')

if "import 'package:image_picker/image_picker.dart';" not in source:
    source = source.replace(
        "import 'package:file_picker/file_picker.dart';\n",
        "import 'package:file_picker/file_picker.dart';\nimport 'package:image_picker/image_picker.dart';\n",
        1,
    )

# Replace the single generic FileType.any picker with media-specific pickers.
method_pattern = re.compile(
    r"  Future<void> pickFile\(\) async \{.*?\n  \}\n\n  bool isSupported",
    re.S,
)
method_replacement = r'''  Future<void> _openPickedPath(String path) async {
    if (!mounted) return;
    setState(() {
      selectedPath = path;
      status = "${_t('fileSelected')}:\n$path";
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HCVImportRouterPage(
          path: path,
          languageCode: widget.languageCode,
        ),
      ),
    );
  }

  Future<void> pickDocument() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['hcvpack', 'hcv', 'txt', 'pdf'],
        allowMultiple: false,
      );
      if (res == null) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      final path = res.files.single.path;
      if (path == null) {
        if (mounted) setState(() => status = _t('filePathUnavailable'));
        return;
      }
      await _openPickedPath(path);
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    }
  }

  Future<void> pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      await _openPickedPath(file.path);
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    }
  }

  Future<void> pickVideo() async {
    try {
      final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (file == null) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      await _openPickedPath(file.path);
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    }
  }

  bool isSupported'''
source, count = method_pattern.subn(method_replacement, source, count=1)
if count != 1 and 'Future<void> pickPhoto() async' not in source:
    raise RuntimeError('generic verification picker anchor missing')

# Replace the one generic SELECT FILE button with explicit media choices.
button_pattern = re.compile(
    r"              ElevatedButton\(\n"
    r"                onPressed: pickFile,\n"
    r"                child: Text\(_t\('selectFile'\)\),\n"
    r"              \),",
    re.S,
)
buttons = r'''              ElevatedButton.icon(
                onPressed: pickDocument,
                icon: const Icon(Icons.description_outlined),
                label: Text(widget.languageCode == 'it'
                    ? 'VERIFICA TESTO / DOCUMENTO'
                    : 'VERIFY TEXT / DOCUMENT'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: pickPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(widget.languageCode == 'it'
                    ? 'VERIFICA FOTO'
                    : 'VERIFY PHOTO'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: pickVideo,
                icon: const Icon(Icons.video_library_outlined),
                label: Text(widget.languageCode == 'it'
                    ? 'VERIFICA VIDEO'
                    : 'VERIFY VIDEO'),
              ),'''
source, button_count = button_pattern.subn(buttons, source, count=1)
if button_count != 1 and 'onPressed: pickPhoto' not in source:
    raise RuntimeError('verification picker button anchor missing')

required = [
    "import 'package:image_picker/image_picker.dart';",
    "pickImage(source: ImageSource.gallery)",
    "pickVideo(source: ImageSource.gallery)",
    "allowedExtensions: const ['hcvpack', 'hcv', 'txt', 'pdf']",
    'onPressed: pickDocument',
    'onPressed: pickPhoto',
    'onPressed: pickVideo',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'media-specific picker token missing: {token}')

if 'type: FileType.any' in source:
    raise RuntimeError('generic FileType.any picker still present in verification page')

path.write_text(source, encoding='utf-8')
print('Media-specific verification pickers applied: documents use Files, photos/videos use Photos')
