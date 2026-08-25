from pathlib import Path
import re


def normalize_expected_decision(path: str, test_name: str) -> None:
    file = Path(path)
    if not file.exists():
        raise RuntimeError(f'generated policy test missing: {path}')

    source = file.read_text(encoding='utf-8')
    pattern = re.compile(
        rf"  test\('{re.escape(test_name)}', \(\) \{{.*?^  \}}\);",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(source)
    if match is None:
        raise RuntimeError(f'generated policy test block missing: {test_name}')

    block = match.group(0)
    if "'NON_CONCLUSIVE'" in block and "'STRONG_DISPLAY_RISK'" not in block:
        print(f'policy regression already aligned: {test_name}')
        return
    if block.count("'STRONG_DISPLAY_RISK'") != 1:
        raise RuntimeError(
            f'policy regression unexpected decision contract: {test_name} '
            f'(strong_count={block.count(chr(39) + "STRONG_DISPLAY_RISK" + chr(39))})'
        )

    replacement = block.replace(
        "'STRONG_DISPLAY_RISK'",
        "'NON_CONCLUSIVE'",
        1,
    )
    source = source[:match.start()] + replacement + source[match.end():]
    file.write_text(source, encoding='utf-8')
    print(f'policy regression aligned to independent-family rule: {test_name}')


# These historical generated tests encoded the superseded rule that one
# temporal/static family could produce HIGH. RC2 now requires two independent
# strong display families; one family remains a cautious NON_CONCLUSIVE result.
for path, test_name in [
    (
        'test/monitor_certificate_regression_test.dart',
        'uploaded monitor photo certificate is no longer reduced to no display',
    ),
    (
        'test/monitor_certificate_regression_test.dart',
        'uploaded monitor video certificate becomes strong physical display risk',
    ),
    (
        'test/photo_display_risk_policy_test.dart',
        'temporal live evidence can be corroborated by the captured photo',
    ),
]:
    normalize_expected_decision(path, test_name)

print('RC2 independent-family generated policy tests aligned')
