import subprocess
from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


# Camera changes are now limited to the safe confirmation dialog, optional
# coordinate stamping, and reuse of the already-computed pre-capture result.
safe_patch = Path('tool/apply_safe_capture_location_fix.py').read_text()
exec(safe_patch, {'Path': Path, '__name__': '__main__'})

# Preserve only the Account success-feedback part from the previous verified
# script. The old camera section is intentionally never executed again.
legacy = subprocess.check_output(
    [
        'git',
        'show',
        '166ce71bea82ce661353abf4f5c7888653f15e79:tool/apply_camera_account_feedback_fix.py',
    ],
    text=True,
)
start = legacy.index("account_path = Path('lib/account_page.dart')")
end = legacy.index("Path('test/camera_ready_video_evidence_contract_test.dart')")
account_only = legacy[start:end]
exec(account_only, {'Path': Path, 'replace_once': replace_once})
