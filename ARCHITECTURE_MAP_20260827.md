# SIGILLUM / HCV — Architecture map

Snapshot date: 2026-08-27

Production code baseline: `1475658c450155dd9cef9301c1919e8e484600e7`
Final TestFlight publishing commit: `a1ebf53d70e3f07642c8d67738f2167862d936bf`
Distribution checkpoint: `checkpoint/testflight-final-uploaded-20260827`

This document is the operational map to use before changing SIGILLUM. It replaces the old May checkpoint manifest as an architecture reference. A change to one stage must be checked against the downstream stages shown here.

## 1. Application entry and edition routing

```text
main.dart
  -> sigillum_edition.dart
  -> sigillum_theme.dart
  -> lab edition: home_page.dart
  -> user edition: commercial_gate.dart
                         -> user_home_page.dart
```

Core UI/support files:
- `main.dart` — application entry point.
- `sigillum_edition.dart` — selects edition/profile.
- `sigillum_theme.dart` — shared visual theme.
- `sigillum_localization.dart` — localized copy.
- `camera_ui_copy.dart`, `camera_ui_extended_copy.dart`, `verification_ui_copy.dart` — dedicated UI text layers.
- `sigillum_quick_guide_page.dart`, `legal_info_page.dart` — guide/legal surfaces.
- `home_page.dart` — lab/development hub.
- `user_home_page.dart` — commercial user hub and registry-outbox retry entry.

## 2. Capture and HCV creation pipeline

`camera_page.dart` is the principal capture orchestrator. Detection modules must produce evidence; they must not independently decide the public certificate result.

```text
camera_page.dart
  |
  +-> hcv_capture_timestamp.dart
  +-> hcv_capture_location.dart
  +-> hcv_live_signals.dart
  +-> hcv_trust_analyzer.dart
  |
  +-> LIVE / PHYSICAL DISPLAY EVIDENCE
  |     hcv_live_screen_probe.dart
  |       -> hcv_live_screen_probe_core.dart
  |       -> hcv_live_screen_probe_sampling.dart
  |       -> hcv_live_screen_probe_geometry.dart
  |       -> hcv_live_screen_probe_models.dart
  |       -> hcv_planar_motion_model.dart
  |       -> hcv_projective_motion_model.dart
  |       -> hcv_scene_geometry_classifier.dart
  |       -> hcv_active_display_classifier.dart
  |       -> hcv_temporal_capture_probe.dart
  |
  +-> STATIC OPTICAL EVIDENCE
  |     hcv_screen_replay_analyzer.dart
  |
  +-> ML EVIDENCE
  |     hcv_ml_screen_replay_classifier.dart
  |       -> hcv_ml_model_store.dart
  |
  +-> EVIDENCE FUSION
  |     hcv_display_risk_fusion.dart
  |       -> hcv_scene_decision_fusion.dart
  |
  +-> CERTIFICATE / IDENTITY
  |     hcv_engine.dart
  |       -> hcv_identity.dart
  |       -> hcv_keystore_signer.dart
  |       -> hcv_crypto.dart
  |       -> hcv_secure_store.dart
  |
  +-> MEDIA BINDING / PRESENTATION
  |     hcv_location_image_watermark.dart
  |     hcv_image_watermark.dart
  |     hcv_location_video_watermark.dart
  |     hcv_video_watermark.dart
  |     hcv_logo_badge.dart
  |     hcv_social_fingerprint.dart
  |
  +-> PACKAGE
  |     hcv_package.dart
  |
  +-> REGISTRY
        hcv_registry_service.dart
```

### Decision invariant

The final display/reality classification is a fusion problem:

```text
live temporal/active/geometry
        + static optical
        + ML SCREEN/REALITY
              |
              v
hcv_display_risk_fusion.dart
              |
              v
hcv_scene_decision_fusion.dart
              |
              v
signed HCV claims
```

A single temporal family is not equivalent to independently corroborated display evidence. Conversely, a monitor must not be cleared merely because one lower layer reports REALITY. Strong SCREEN ML, structural/static evidence, active emissive evidence and independent corroboration remain conflict/blocking signals.

## 3. Certificate, package and registry verification

```text
incoming file / shared media
        |
        v
hcv_import_router_page.dart
  +-> .hcvpack -> hcvpack_player_page.dart
  |                -> hcv_verifier.dart
  |
  +-> .hcv     -> verify_page.dart
  |                -> hcv_verifier.dart
  |
  +-> photo/video -> quick_hcv_media_gate_page.dart
  |                    -> verification path
  |
  +-> other media/text -> registry_verify_page.dart
                           -> hcv_registry_service.dart
                           -> hcv_verifier.dart
                           -> hcv_social_fingerprint.dart
                           -> hcv_media_id_ocr.dart
```

Verification-related files:
- `hcv_import_router_page.dart` — file-type routing.
- `hcv_import_service.dart` — import support.
- `quick_hcv_media_gate_page.dart` — fast photo/video gate.
- `verify_page.dart`, `verifier_page.dart` — HCV verification UI layers.
- `registry_verify_page.dart` — public/registry verification; complete signed `displayRiskEvidence` has precedence over lower diagnostic fields.
- `hcvpack_player_page.dart` — HCVPACK extraction and certificate verification.
- `video_verify_page.dart`, `video_player_verify_page.dart` — video verification/player surfaces.
- `hcv_verifier.dart` — cryptographic HCV V2/legacy verifier.
- `hcv_registry_service.dart` — registry upload/read/retry/outbox.
- `hcv_media_id_ocr.dart` — HCV-ID/media OCR support.
- `hcv_social_fingerprint.dart` — resilient media fingerprint support.

## 4. Commercial / StoreKit / entitlement pipeline

```text
main.dart
  -> commercial_gate.dart
       +-> commercial_account_service.dart
       +-> recent_account_service.dart
       +-> commercial_billing_service.dart
       |     -> in_app_purchase purchaseStream
       |     -> native StoreKit 2 method channel on iOS
       |     -> terminal state waiters
       |     -> server/account verification
       +-> commercial_profile_page.dart
       +-> account_page.dart
       +-> user_home_page.dart
```

Commercial files:
- `commercial_gate.dart` — subscription/account gate and commercial orchestration.
- `commercial_billing_service.dart` — product loading, localized StoreKit 2 prices, purchase lifecycle, terminal-state synchronization.
- `commercial_account_service.dart` — account/entitlement service.
- `recent_account_service.dart` — recent-account persistence/support.
- `commercial_profile_page.dart`, `account_page.dart` — user/account UI.
- `hcv_auth_service.dart` — authentication support.

### Billing invariant

The UI result of the Apple purchase sheet must never grant entitlement directly. Entitlement must flow from the purchase transaction stream and verification/account state. `PurchaseStatus.canceled` is terminal for retry lifecycle but grants no access.

Native iOS integration surface includes the Runner lifecycle/StoreKit bridge (notably `ios/Runner/SceneDelegate.swift`) and App Store signing configuration. The release workflow pins the validated iOS/TFLite runtime before IPA creation.

## 5. Text / audio / auxiliary HCV functions

```text
text_cert_page.dart
  -> hcv_text_integrity.dart
  -> certificate/registry path

text_social_verify_page.dart
  -> text verification / registry path

camera/video flow
  -> video_transcription_service.dart
```

Supporting files:
- `hcv_text_integrity.dart` — text integrity/certification logic.
- `text_cert_page.dart` — text certificate UI.
- `text_social_verify_page.dart` — social/text verification UI.
- `video_transcription_service.dart` — video transcription support.
- `hcv_ai_training_service.dart` — AI/training auxiliary service; not a final decision authority.

## 6. Identity / security

```text
identity_page.dart
  -> hcv_identity.dart
       -> hcv_keystore_signer.dart
       -> hcv_secure_store.dart

hcv_engine.dart
  -> identity + signing
  -> SHA-256 event chain / root
  -> signed claims
```

Files:
- `identity_page.dart`
- `hcv_identity.dart`
- `hcv_keystore_signer.dart`
- `hcv_secure_store.dart`
- `hcv_crypto.dart`
- `hcv_engine.dart`

## 7. Calibration and diagnostics

These are diagnostic/support surfaces; they are not allowed to bypass final fusion in production certificates.

- `screen_replay_calibration_page.dart`
- `screen_replay_diagnostics_page.dart`
- `hcv_checkpoint_manifest.json`
- `HCV_CHECKPOINT_MANIFEST.md` — historical/stale architecture manifest; do not use as the current map.

## 8. Legacy / non-authoritative files in lib

These files exist in `lib/` but are not to be treated as the canonical production entry or final decision layer without an explicit review:

- `HcvImportService.txt`
- `Untitled-2.txt`
- `main X ANDROID.dart`
- `camera_service.dart`
- `test_watermark.dart`

Their presence must not be mistaken for runtime authority merely because they are under `lib/`.

## 9. Complete lib inventory grouped by responsibility

### Entry/UI/navigation
`main.dart`, `home_page.dart`, `user_home_page.dart`, `account_page.dart`, `identity_page.dart`, `import_page.dart`, `legal_info_page.dart`, `sigillum_quick_guide_page.dart`, `sigillum_edition.dart`, `sigillum_theme.dart`, `sigillum_localization.dart`, `camera_ui_copy.dart`, `camera_ui_extended_copy.dart`, `verification_ui_copy.dart`.

### Capture/detection/fusion
`camera_page.dart`, `hcv_capture_location.dart`, `hcv_capture_timestamp.dart`, `hcv_live_signals.dart`, `hcv_live_screen_probe.dart`, `hcv_live_screen_probe_core.dart`, `hcv_live_screen_probe_sampling.dart`, `hcv_live_screen_probe_geometry.dart`, `hcv_live_screen_probe_models.dart`, `hcv_planar_motion_model.dart`, `hcv_projective_motion_model.dart`, `hcv_scene_geometry_classifier.dart`, `hcv_active_display_classifier.dart`, `hcv_temporal_capture_probe.dart`, `hcv_screen_replay_analyzer.dart`, `hcv_ml_screen_replay_classifier.dart`, `hcv_ml_model_store.dart`, `hcv_display_risk_fusion.dart`, `hcv_scene_decision_fusion.dart`, `hcv_trust_analyzer.dart`.

### Certificate/security/package/registry
`hcv_engine.dart`, `hcv_identity.dart`, `hcv_keystore_signer.dart`, `hcv_crypto.dart`, `hcv_secure_store.dart`, `hcv_package.dart`, `hcv_registry_service.dart`, `hcv_verifier.dart`, `hcv_social_fingerprint.dart`, `hcv_media_id_ocr.dart`.

### Watermark/media
`hcv_image_watermark.dart`, `hcv_location_image_watermark.dart`, `hcv_video_watermark.dart`, `hcv_location_video_watermark.dart`, `hcv_logo_badge.dart`, `video_transcription_service.dart`.

### Import/verification UI
`hcv_import_router_page.dart`, `hcv_import_service.dart`, `quick_hcv_media_gate_page.dart`, `verify_page.dart`, `verifier_page.dart`, `registry_verify_page.dart`, `hcvpack_player_page.dart`, `video_verify_page.dart`, `video_player_verify_page.dart`.

### Commercial/account
`commercial_gate.dart`, `commercial_billing_service.dart`, `commercial_account_service.dart`, `commercial_profile_page.dart`, `recent_account_service.dart`, `hcv_auth_service.dart`.

### Text/AI support
`hcv_text_integrity.dart`, `text_cert_page.dart`, `text_social_verify_page.dart`, `hcv_ai_training_service.dart`.

### Calibration/diagnostic/historical
`screen_replay_calibration_page.dart`, `screen_replay_diagnostics_page.dart`, `hcv_checkpoint_manifest.json`, `HCV_CHECKPOINT_MANIFEST.md`, `camera_service.dart`, `test_watermark.dart`, `HcvImportService.txt`, `Untitled-2.txt`, `main X ANDROID.dart`.

## 10. Release dependency chain

```text
committed materialized source
  -> flutter pub get / locked dependencies
  -> validated TFLite iOS 2.17.0 runtime
  -> flutter analyze
  -> flutter test
  -> post-materialization audit
  -> App Store signing profiles
  -> build_testflight_ipa_rc2_20260825.sh
  -> signed IPA proof
  -> Codemagic Publishing
  -> App Store Connect / TestFlight
```

Production release code `1475658c450155dd9cef9301c1919e8e484600e7` passed diagnostics, Ubuntu materialized-source validation, macOS analyze/tests/CocoaPods and unsigned iOS Release build. The final TestFlight publishing commit `a1ebf53d70e3f07642c8d67738f2167862d936bf` passed Codemagic validation, App Store signing, IPA proof and Publishing.

## 11. Change-control rules

1. Do not reintroduce build-time Python patch chains into the final build.
2. Do not change detector thresholds to solve a fusion problem unless detector evidence itself is proven wrong.
3. Do not let lower-level REALITY labels override signed display conflicts in verification UI.
4. Do not let temporal-only noise count as multiple independent display families.
5. Do not let purchase-sheet completion grant entitlement.
6. For any change to capture/fusion, run both REALITY false-positive and monitor/mixed-scene regression suites.
7. For any iOS release, validate exact committed source before signing and publishing.
