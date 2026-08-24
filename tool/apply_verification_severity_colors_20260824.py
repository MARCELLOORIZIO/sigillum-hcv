from pathlib import Path

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

# Presentation only: do not change certificate, capture, ML or risk thresholds.
# Severity policy requested for the public verification UI:
#   green  = verified with no warning
#   orange = incomplete / non-conclusive / Registry warning
#   red    = invalid, media mismatch, or strong display risk
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

old_icon = """              Icon(
                result == null
                    ? Icons.cloud_sync
                    : isVerified
                        ? Icons.verified
                        : isScreenReplayWarning || _isRegistryWarningResult
                            ? Icons.warning_amber
                            : Icons.error,
                size: 72,
                color: result == null
                    ? Colors.grey
                    : isVerified
                        ? Colors.green
                        : isScreenReplayWarning || _isRegistryWarningResult
                            ? Colors.orange
                            : Colors.red,
              ),"""
new_icon = """              Icon(
                _verificationResultIcon,
                size: 72,
                color: _verificationResultColor,
              ),"""
if old_icon in source:
    source = source.replace(old_icon, new_icon, 1)
elif new_icon not in source:
    raise RuntimeError('verification result icon anchor missing')

old_result_color = """                    color: isVerified
                        ? Colors.green
                        : isScreenReplayWarning || _isRegistryWarningResult
                            ? Colors.orange
                            : Colors.red,"""
new_result_color = """                    color: _verificationResultColor,"""
if old_result_color in source:
    source = source.replace(old_result_color, new_result_color, 1)
elif new_result_color not in source:
    raise RuntimeError('verification result text color anchor missing')

# The scene axis must follow risk severity independently of the selected language.
old_scene_color = "color: _axisColor(_effectiveSceneState),"
new_scene_color = """color: _isStrongDisplayRisk
                      ? Colors.red
                      : _isDisplayNonConclusive
                          ? Colors.orange
                          : _axisColor(_effectiveSceneState),"""
if old_scene_color in source:
    source = source.replace(old_scene_color, new_scene_color, 1)
elif new_scene_color not in source:
    raise RuntimeError('scene severity color anchor missing')

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
print('Verification severity colors applied: green / orange / red')
