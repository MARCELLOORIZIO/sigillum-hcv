from pathlib import Path
import re
import subprocess

path = Path('lib/import_page.dart')

required = [
    "import 'package:image_picker/image_picker.dart';",
    "pickImage(source: ImageSource.gallery)",
    "pickVideo(source: ImageSource.gallery)",
    "allowedExtensions: const ['hcvpack', 'hcv', 'txt', 'pdf']",
    'onPressed: pickDocument',
    'onPressed: pickPhoto',
    'onPressed: pickVideo',
]


def apply_fast_media_precheck():
    patch = Path('tool/apply_fast_uncertified_media_precheck_20260823.py')
    if not patch.exists():
        raise RuntimeError('fast uncertified-media precheck patch missing')
    exec(
        compile(patch.read_text(encoding='utf-8'), str(patch), 'exec'),
        {'__name__': '__main__'},
    )


def apply_verification_refinement():
    for patch_name in [
        'tool/apply_verification_clarity_localization_ml_fix_20260824.py',
        'tool/apply_verification_language_finalizer_20260824.py',
    ]:
        patch = Path(patch_name)
        if not patch.exists():
            raise RuntimeError(f'verification refinement patch missing: {patch_name}')
        exec(
            compile(patch.read_text(encoding='utf-8'), str(patch), 'exec'),
            {'__name__': '__main__'},
        )

    # RC2: format the materialized Dart source after ALL build-time finalizers.
    # This is also a fast syntax check before flutter analyze/test.
    final_dart_files = [
        'lib/import_page.dart',
        'lib/quick_hcv_media_gate_page.dart',
        'lib/hcv_import_router_page.dart',
        'lib/hcvpack_player_page.dart',
        'lib/registry_verify_page.dart',
        'lib/camera_page.dart',
        'lib/camera_ui_copy.dart',
        'lib/hcv_ml_screen_replay_classifier.dart',
        'lib/hcv_ml_model_store.dart',
    ]
    subprocess.run(['dart', 'format', *final_dart_files], check=True)

    # The first audit inside the language finalizer sees the pre-format source.
    # Re-run it now so the final section of the diagnostic log fingerprints the
    # exact formatted source that proceeds to analysis/tests and the IPA build.
    audit = Path('tool/verify_postpatch_release_20260825.py')
    if not audit.exists():
        raise RuntimeError('RC2 post-format release audit missing')
    exec(
        compile(audit.read_text(encoding='utf-8'), str(audit), 'exec'),
        {'__name__': '__main__'},
    )


# The branch now carries the approved picker implementation directly in Git.
# Tests in this repository may temporarily rewrite lib/import_page.dart while
# running. Always prefer the committed HEAD version when it already satisfies
# the approved media-picker contract. This makes the patch deterministic and
# safe to invoke both before and after the parallel Flutter test suite.
try:
    committed = subprocess.check_output(
        ['git', 'show', 'HEAD:lib/import_page.dart'],
        text=True,
    )
except (subprocess.CalledProcessError, FileNotFoundError):
    committed = ''

if (
    committed
    and all(token in committed for token in required)
    and 'type: FileType.any' not in committed
):
    path.write_text(committed, encoding='utf-8')
    print('Media-specific verification pickers restored from committed HEAD source')
    apply_fast_media_precheck()
    apply_verification_refinement()
    raise SystemExit(0)

source = path.read_text(encoding='utf-8')

if "import 'package:image_picker/image_picker.dart';" not in source:
    source = source.replace(
        "import 'package:file_picker/file_picker.dart';\n",
        "import 'package:file_picker/file_picker.dart';\nimport 'package:image_picker/image_picker.dart';\n",
        1,
    )

# Legacy fallback: replace the single generic FileType.any picker with
# media-specific pickers when building from an older source shape.
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
                    ? 'VERIFICA TESTO'
                    : 'VERIFY TEXT'),
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

for token in required:
    if token not in source:
        raise RuntimeError(f'media-specific picker token missing: {token}')

if 'type: FileType.any' in source:
    raise RuntimeError('generic FileType.any picker still present in verification page')

path.write_text(source, encoding='utf-8')
print('Media-specific verification pickers applied: documents use Files, photos/videos use Photos')
apply_fast_media_precheck()
apply_verification_refinement()
