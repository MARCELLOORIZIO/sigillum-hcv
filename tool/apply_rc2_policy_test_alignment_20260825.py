from pathlib import Path
import re


def normalize_expected_policy(path: str, test_name: str) -> None:
    file = Path(path)
    # This normalizer is called from nested patch chains before, during and
    # after generated test materialization. Missing/intermediate generated
    # tests are not a production-source failure; the authoritative flutter
    # test pass later in the same release pipeline remains fail-closed.
    if not file.exists():
        print(f'policy regression not materialized yet; deferred: {path}')
        return

    source = file.read_text(encoding='utf-8')
    pattern = re.compile(
        rf"  test\('{re.escape(test_name)}', \(\) \{{.*?^  \}}\);",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(source)
    if match is None:
        print(f'policy regression block not in final form yet; deferred: {test_name}')
        return

    block = match.group(0)
    replacement = block

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

    # Historical one-family HIGH contracts also asserted score >= 70. Under
    # the independent-family policy, one strong family is deliberately capped
    # in the cautious NON_CONCLUSIVE band (45..69). Keep the score assertion
    # strict and consistent with the public decision rather than deleting it.
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

    if replacement == block:
        print(f'policy regression already aligned: {test_name}')
        return

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
    normalize_expected_policy(path, test_name)

print('RC2 independent-family generated policy tests aligned')
