from pathlib import Path


def normalize_expected_policy(path: str, test_name: str) -> None:
    file = Path(path)
    if not file.exists():
        print(f'policy regression not materialized yet; deferred: {path}')
        return

    source = file.read_text(encoding='utf-8')
    title = f"'{test_name}'"
    title_index = source.find(title)
    if title_index < 0:
        print(f'policy regression title not materialized yet; deferred: {test_name}')
        return

    # Work from the test title to the next test declaration instead of parsing
    # generated Dart syntax. This is insensitive to sync/async callbacks,
    # formatter layout and generator-specific indentation.
    next_test = source.find('\n  test(', title_index + len(title))
    segment_end = len(source) if next_test < 0 else next_test
    segment = source[title_index:segment_end]
    replacement = segment

    strong_count = replacement.count("'STRONG_DISPLAY_RISK'")
    if strong_count > 1:
        raise RuntimeError(
            f'policy regression unexpected decision contract: {test_name} '
            f'(strong_count={strong_count})'
        )
    if strong_count == 1:
        replacement = replacement.replace(
            "'STRONG_DISPLAY_RISK'",
            "'NON_CONCLUSIVE'",
            1,
        )

    replacement = replacement.replace(
        'greaterThanOrEqualTo(70)',
        'inInclusiveRange(45, 69)',
    )

    if "'NON_CONCLUSIVE'" not in replacement:
        raise RuntimeError(
            f'policy regression NON_CONCLUSIVE contract missing: {test_name}'
        )
    if "'STRONG_DISPLAY_RISK'" in replacement:
        raise RuntimeError(
            f'policy regression stale STRONG_DISPLAY_RISK survived: {test_name}'
        )
    if 'greaterThanOrEqualTo(70)' in replacement:
        raise RuntimeError(
            f'policy regression stale HIGH score contract survived: {test_name}'
        )

    if replacement == segment:
        print(f'policy regression already aligned: {test_name}')
        return

    source = source[:title_index] + replacement + source[segment_end:]
    file.write_text(source, encoding='utf-8')
    print(f'policy regression aligned to independent-family rule: {test_name}')


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
    normalize_expected_policy(path, test_name)

print('RC2 independent-family generated policy tests aligned')
