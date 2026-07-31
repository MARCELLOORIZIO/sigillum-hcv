from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


legacy = Path('tool/apply_camera_account_feedback_fix.py').read_text()
start_marker = "account_path = Path('lib/account_page.dart')"
end_marker = "Path('test/camera_ready_video_evidence_contract_test.dart')"
start = legacy.index(start_marker)
end = legacy.index(end_marker)
account_only = legacy[start:end]
exec(account_only, {'Path': Path, 'replace_once': replace_once})

account_test_path = Path('test/account_page_contract_test.dart')
account_test = account_test_path.read_text()
anchor = "    test('session token uses native secure storage on iOS and Android', () {"
addition = """    test('successful account actions turn their buttons green', () {
      expect(account, contains('_markActionSuccessful'));
      expect(account, contains('_filledSuccessStyle'));
      expect(account, contains('_outlinedSuccessStyle'));
      expect(account, contains('SigillumTheme.verified'));
      expect(account, contains('Icons.check_circle_rounded'));
    });

"""
if addition not in account_test:
    if account_test.count(anchor) != 1:
        raise RuntimeError('account success test anchor not found exactly once')
    account_test = account_test.replace(anchor, addition + anchor, 1)
    account_test_path.write_text(account_test)
