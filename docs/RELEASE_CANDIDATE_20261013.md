# SIGILLUM release candidate — 2026-10-13

Candidate branch: release/testflight-candidate-20261013, exact app commit fe52264622aa0b08cc61b525efc5bac7761e53be. It includes the merged VIDEO initial scene/anti-trim and UI/paywall corrections. Experimental PHOTO framing PR139 remains separate; semantic framing is DIAGNOSTIC_ONLY and is not promoted to this candidate.

Readiness run38372626893 checks the pinned candidate: locked dependencies, Flutter analyze, complete regression suite and native unsigned iOS compile. Analyze and all regression tests passed; native compile pending at this checkpoint. Guarded TestFlight trigger run38372978802 waits for this exact successful run and requires candidate branch SHA unchanged. Codemagic app6a0747e8d58afdcf30d2793c, workflow ios-testflight. Secret token remains within GitHub Actions. No App Store review submission is included.

Build numbering is max(source build149, latest TestFlight build+1), checked against archived CFBundleVersion and signed software attestation by tool/build_testflight_ipa_rc2_20260825.sh. Thus source149 does not establish distributed build149; actual artifact identity remains to be obtained from Codemagic/App Store build evidence.

## Required iPhone acceptance after new TestFlight artifact exists

| Flow | Acceptance |
| --- | --- |
| Original photo and video | Identical content verifies integrity; provenance, integrity, derivation and scene remain separately understandable |
| Changed photo | Meaningful alteration is not silently described as identical original; ambiguous comparisons remain nonconclusive |
| Social copies | Messenger compression and authorized subtitle derivation tested against actual originals; original hashes are not falsely asserted for derivatives |
| Scene | Screen-present and screen-absent cases tied to exact artifact and raw diagnostics; no semantic-only display verdict |
| Video opening | Prohibited initial trim rejected without applying this video rule to photos |
| Subtitles | Complete duration, usable progress/actions and consistent button layout; protected original unchanged |
| Premium comparison | Purchase entry, return after purchase and account/device-bound entitlement; weekly/monthly/annual and restore tested in Apple sandbox |
| GPS and Photos | Fresh/denied/granted location permissions; explicit save behavior and protected vault retention |
| Text | Pasted social text can be verified against certificate without camera requirement |
| Recovery | Network loss, expired session, unavailable reference and account switching fail clearly and safely |

These are device acceptance requirements, not completed results. Native compile and automated tests cannot establish StoreKit purchases, camera scene behavior or UI usability on the user's iPhone.

Registry OAuth connector has been deployed and activated independently. Current callback connector_platform_oauth_redirect. User supplied screenshot from another ChatGPT conversation reports actual receipt/rendering of two screen-present originals; this repo session has not directly viewed those original image bytes. No false-positive diagnosis follows from those two positive cases.

## Verified readiness and distribution checkpoint — 2026-10-13 09:05 UTC

Readiness38372626893 completed SUCCESS: 852 tests passed, post-patch audit PASS, native iOS Runner.app compiled185.9MB. Guarded API trigger38372978802 failed CODEMAGIC_TOKEN_MISSING_NO_BUILD; no API build was created. CM_API_TOKEN and CODEMAGIC_API_TOKEN were absent in that runner; no secret values retrieved or requested in chat.

Fallback: enabled the existing native Codemagic push trigger for branch release/testflight-candidate-20261013 by adding exactly that pattern to ios-testflight. Candidate head0e18ec123be279d7165e094aac92a23253db0afa differs from verified fe52264622aa0b08cc61b525efc5bac7761e53be only in codemagic.yaml trigger configuration. Existing full analyze/tests/audit and signed build/attestation remain in the Codemagic pipeline. This push may be consumed by the existing Codemagic webhook; acceptance/start is not yet established. GitHub check-runs and status were empty immediately afterwards. No signed IPA, upload, TestFlight availability or App Store submission claimed. The candidate branch moved intentionally for this trigger; the failed original SHA guard must not be rerun unchanged.
