from pathlib import Path
import re


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text(encoding='utf-8')

# Authorized defect repair: a video starts passive sensor capture, but the
# previous lifecycle never finalized the sensor summary before certification.
# Keep the existing detector, scoring thresholds, hash/signature and Registry
# logic unchanged; only persist the summary that the trust analyzer already
# expects.
stop_anchor = """      final file = await controller!.stopVideoRecording();
      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
"""
stop_replacement = """      final file = await controller!.stopVideoRecording();

      try {
        lastLiveSignals = await liveSignals.stopAndBuildSummary();
      } catch (_) {
        lastLiveSignals = null;
      }

      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
"""
camera = replace_once(
    camera,
    stop_anchor,
    stop_replacement,
    'video live-signals finalization',
)

# Do not allow a previous recording summary to leak into a new recording. The
# repository source has a one-step start(), while the final prelaunch generator
# rewrites it to the approved two-step arm -> REC flow. Support both shapes
# without changing either flow.
reset_token = "lastLiveSignals = null;\n\n    setState(() {\n      recording = true;"
if reset_token not in camera:
    generated_start_anchor = """    _videoArmZoom = null;

    setState(() {
      recording = true;
"""
    generated_start_replacement = """    _videoArmZoom = null;
    lastLiveSignals = null;

    setState(() {
      recording = true;
"""
    if generated_start_anchor in camera:
        camera = camera.replace(
            generated_start_anchor,
            generated_start_replacement,
            1,
        )
    else:
        source_start_anchor = """    try {
      pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
"""
        source_start_replacement = """    lastLiveSignals = null;

    try {
      pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
"""
        camera = replace_once(
            camera,
            source_start_anchor,
            source_start_replacement,
            'video live-signals reset',
        )

# Small E2E polish already observed: photo HCVPACKs were valid but inherited
# the hcv_video_ filename prefix. Change naming only; package bytes and format
# are untouched. Earlier prelaunch patches can reformat the method before this
# script runs, so locate the method and assignments semantically rather than by
# a byte-for-byte multiline anchor.
package_signature_old = """  Future<String> movePackageToUnifiedName({
    required String currentPath,
    required String hcvId,
  }) async {
"""
package_signature_new = """  Future<String> movePackageToUnifiedName({
    required String currentPath,
    required String hcvId,
    String contentKind = 'video',
  }) async {
"""
camera = replace_once(
    camera,
    package_signature_old,
    package_signature_new,
    'HCVPACK content-kind parameter',
)

method_marker = '  Future<String> movePackageToUnifiedName({' 
method_start = camera.find(method_marker)
if method_start < 0:
    raise RuntimeError('HCVPACK naming method missing')

method_tail_start = method_start + len(method_marker)
next_method = re.search(
    r'\n  (?:Future<[^\n]+>|Future<void>|Widget|void|String|bool|int|double)\s+[_A-Za-z]\w*\s*\(',
    camera[method_tail_start:],
)
method_end = (
    method_tail_start + next_method.start()
    if next_method is not None
    else len(camera)
)
package_method = camera[method_start:method_end]

if "final contentPrefix = contentKind == 'photo' ? 'hcv_photo' : 'hcv_video';" not in package_method:
    new_path_match = re.search(
        r'final\s+newPath\s*=\s*p\.join\(',
        package_method,
    )
    if new_path_match is None:
        raise RuntimeError('HCVPACK newPath assignment missing')
    assignment_start = new_path_match.start()
    assignment_end = package_method.find(');', new_path_match.end())
    if assignment_end < 0:
        raise RuntimeError('HCVPACK newPath assignment is incomplete')
    assignment_end += 2
    old_assignment = package_method[assignment_start:assignment_end]
    if 'hcvpack' not in old_assignment.lower():
        raise RuntimeError('HCVPACK newPath assignment does not target hcvpack')

    replacement_assignment = """final contentPrefix = contentKind == 'photo' ? 'hcv_photo' : 'hcv_video';
    final newPath = p.join(
      dir.path,
      '${contentPrefix}_$safeId.hcvpack',
    );"""
    package_method = (
        package_method[:assignment_start]
        + replacement_assignment
        + package_method[assignment_end:]
    )
    camera = camera[:method_start] + package_method + camera[method_end:]

# Mark only the photo package call. Locate it after the published-photo context
# so the video package call keeps the default contentKind='video'.
if "contentKind: 'photo'," not in camera:
    photo_context = camera.find('publishedPhoto')
    if photo_context < 0:
        raise RuntimeError('photo HCVPACK context missing')
    photo_call_start = camera.find('movePackageToUnifiedName(', photo_context)
    if photo_call_start < 0:
        raise RuntimeError('photo HCVPACK naming call missing')
    photo_call_end = camera.find(');', photo_call_start)
    if photo_call_end < 0:
        raise RuntimeError('photo HCVPACK naming call is incomplete')
    photo_call_end += 2
    photo_call = camera[photo_call_start:photo_call_end]
    if 'hcvId' not in photo_call or 'preparedHcvId' not in photo_call:
        raise RuntimeError('photo HCVPACK naming call has unexpected arguments')

    hcv_arg = re.search(r'hcvId\s*:\s*preparedHcvId\s*,?', photo_call)
    if hcv_arg is None:
        raise RuntimeError('photo HCVPACK hcvId argument missing')
    photo_call = (
        photo_call[:hcv_arg.end()]
        + "\n          contentKind: 'photo',"
        + photo_call[hcv_arg.end():]
    )
    camera = camera[:photo_call_start] + photo_call + camera[photo_call_end:]

# Postconditions: the repair must remain narrow and deterministic.
required_camera = [
    'lastLiveSignals = await liveSignals.stopAndBuildSummary();',
    'lastLiveSignals = null;',
    "String contentKind = 'video',",
    "contentKind: 'photo',",
    "final contentPrefix = contentKind == 'photo' ? 'hcv_photo' : 'hcv_video';",
    "'${contentPrefix}_$safeId.hcvpack'",
]
for token in required_camera:
    if token not in camera:
        raise RuntimeError(f'authorized E2E camera repair token missing: {token}')

if camera.count('lastLiveSignals = await liveSignals.stopAndBuildSummary();') != 1:
    raise RuntimeError('video live-signals finalization must occur exactly once')
if camera.count("contentKind: 'photo',") != 1:
    raise RuntimeError('photo HCVPACK content kind must be applied exactly once')

stop_pos = camera.index('final file = await controller!.stopVideoRecording();')
summary_pos = camera.index('lastLiveSignals = await liveSignals.stopAndBuildSummary();')
process_pos = camera.index('await processVideo(', stop_pos)
if not (stop_pos < summary_pos < process_pos):
    raise RuntimeError('video live-signals summary is not finalized before certification')

for forbidden in [
    'HCVDisplayRiskFusion.combine =',
    'HCVEngine().setClaims =',
    'verifyFile =',
    'sha256 =',
]:
    if forbidden in camera:
        raise RuntimeError(f'forbidden core mutation marker found: {forbidden}')

camera_path.write_text(camera, encoding='utf-8')

# Small copy defect previously observed in the Registry warning. Presentation
# only; verification semantics are unchanged.
registry_path = Path('lib/registry_verify_page.dart')
registry = registry_path.read_text(encoding='utf-8')
registry = registry.replace(
    "'($screenReplayRisk). Il media e collegato al certificato, '",
    "'($screenReplayRisk). Il media è collegato al certificato, '",
    1,
)
registry = registry.replace(
    "'ma la scena non va trattata come ripresa diretta della realta.';",
    "'ma la scena non va trattata come ripresa diretta della realtà.';",
    1,
)

if 'Il media e collegato al certificato' in registry:
    raise RuntimeError('Registry warning typo remains')
if 'Il media è collegato al certificato' not in registry:
    raise RuntimeError('Registry warning corrected copy missing')

registry_path.write_text(registry, encoding='utf-8')

print('Authorized E2E repair applied: video live signals finalized, photo HCVPACK naming corrected, Registry warning copy polished')
