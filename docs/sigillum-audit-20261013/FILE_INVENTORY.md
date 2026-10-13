# Inventario e registro di lettura

Snapshot app: `f7023853bcdfce927fd760357fe427e9d92ad34b` (base 157 indicata nel documento utente).
Snapshot backend: `7e3bcbd694a75079e605277ce81535f4d9785c54` (HEAD documentale; deploy distinto).

**La revisione integrale non è conclusa.** Tutti i file tracciati sono indicizzati; solo le righe con stato `source-read-complete` attestano lettura semantica completa. `source-read-partial` indica gli intervalli letti; `indexed-only` indica soltanto indicizzazione. Asset binari e dipendenze vendorizzate non sono equiparati a sorgente esaminato.

Gli import, canali, metodi nativi e stringhe API sono in [SOURCE_INDEX.json.gz](SOURCE_INDEX.json.gz). Sono relazioni statiche: non provano che ogni ramo sia eseguito nell’edizione User.

## app

File: 1186. Stati: indexed-only: 1124, source-read-complete: 58, source-read-partial: 4.

| File | Ruolo/categoria | Lettura |
| --- | --- | --- |
| `.github/CODEMAGIC_BUILD129_VERIFIED_ORIGINALS_TRIGGER` | build-or-operations | indexed-only |
| `.github/CODEMAGIC_FINAL_TRIGGER` | build-or-operations | indexed-only |
| `.github/COMMERCIAL_VALIDATION_TRIGGER` | build-or-operations | indexed-only |
| `.github/COMMERCIAL_VALIDATION_TRIGGER_2` | build-or-operations | indexed-only |
| `.github/workflows/build117-architecture-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build118-photo-preview-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build119-photo-rotation-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build120-passive-scene-context-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build121-unified-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build122-corpus-wide-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build123-context-free-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build124-multi-evidence-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build125-zoom-coherent-hfr-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build126-video-fov-persistence-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build127-convert-v3-dualbranch.yml` | build-or-operations | indexed-only |
| `.github/workflows/build127-export-v2-model.yml` | build-or-operations | indexed-only |
| `.github/workflows/build127-ml-hard-negative-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build127-v3-tflite.yml` | build-or-operations | indexed-only |
| `.github/workflows/build128-derivative-integrity-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build128-original-hard-binding-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build128-photo-video-preview-fov-parity.yml` | build-or-operations | indexed-only |
| `.github/workflows/build129-ios-verified-originals-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/build133-closed-chain-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/diagnose-ml-rc2-20260825.yml` | build-or-operations | indexed-only |
| `.github/workflows/diagnose-rc2-generated-policy-tests.yml` | build-or-operations | indexed-only |
| `.github/workflows/flutter-ci.yml` | build-or-operations | indexed-only |
| `.github/workflows/materialize-rc2-source-20260826.yml` | build-or-operations | indexed-only |
| `.github/workflows/photo-framing-conversion-probe.yml` | build-or-operations | indexed-only |
| `.github/workflows/photo-framing-final-model-conversion.yml` | build-or-operations | indexed-only |
| `.github/workflows/photo-framing-install-verified-model.yml` | build-or-operations | indexed-only |
| `.github/workflows/photo-framing-ios-experimental-build.yml` | build-or-operations | indexed-only |
| `.github/workflows/photo-framing-ios-unsigned-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/photo-framing-pretrained-weights.yml` | build-or-operations | indexed-only |
| `.github/workflows/trigger-codemagic-build129.yml` | build-or-operations | indexed-only |
| `.github/workflows/validate-commercial-localization.yml` | build-or-operations | indexed-only |
| `.github/workflows/validate-planar-parallax.yml` | build-or-operations | indexed-only |
| `.github/workflows/validate-rc2-20260825.yml` | build-or-operations | indexed-only |
| `.github/workflows/validate-rc2-macos-preipa-20260825.yml` | build-or-operations | indexed-only |
| `.github/workflows/verified-originals-v02-app.yml` | build-or-operations | indexed-only |
| `.gitignore` | source/configuration; see dependency edges | indexed-only |
| `.metadata` | source/configuration; see dependency edges | indexed-only |
| `APP_STORE_PRIVACY_POLICY_DRAFT.md` | documentation | indexed-only |
| `APP_STORE_READINESS.md` | documentation | indexed-only |
| `APP_STORE_TERMS_DRAFT.md` | documentation | indexed-only |
| `BILLING_E2E_CHECKPOINT_20260829.md` | documentation | indexed-only |
| `BUILD133_CLOSED_CHAIN_CHECKPOINT.md` | documentation | indexed-only |
| `MATERIALIZATION_STATUS_20260826.md` | documentation | indexed-only |
| `MODIFICHE/HCV_CHECKPOINT_MANIFEST.md` | historical-copy | indexed-only |
| `MODIFICHE/HcvImportService.txt` | historical-copy | indexed-only |
| `MODIFICHE/camera_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/camera_service.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_checkpoint_audio_live_patch.zip` | source/configuration; see dependency edges | indexed-only |
| `MODIFICHE/hcv_checkpoint_manifest.json` | historical-copy | indexed-only |
| `MODIFICHE/hcv_crypto.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_engine.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_identity.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_import_router_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_import_service.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_live_signals.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_package.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_registry_service.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_trust_analyzer.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_verifier.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcv_video_watermark.dart` | historical-copy | indexed-only |
| `MODIFICHE/hcvpack_player_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/home_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/import_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/main.dart` | historical-copy | indexed-only |
| `MODIFICHE/registry_verify_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/text_cert_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/verifier_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/verify_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/video_player_verify_page.dart` | historical-copy | indexed-only |
| `MODIFICHE/video_verify_page.dart` | historical-copy | indexed-only |
| `README.md` | documentation | indexed-only |
| `RELEASE_HARDENING_NOTES_20260826.md` | documentation | indexed-only |
| `SIGILLUM_PATENT_INVENTION_MAP.md` | documentation | indexed-only |
| `SIGILLUM_PRODUCT_COMMUNICATION.md` | documentation | indexed-only |
| `VERSIONE FUNZIONANTE/camera_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/camera_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/hcv_engine.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/hcv_verifier.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/home_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/main.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/text_cert_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/verifier_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/video_player_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE/video_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/HcvImportService.txt` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/camera_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/camera_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_crypto.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_engine.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_identity.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_import_router_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_import_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_live_signals.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_package.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_registry_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_trust_analyzer.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_verifier.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcv_video_watermark.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/hcvpack_player_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/home_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/identity_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/import_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/main.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/registry_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/text_cert_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/verifier_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/video_player_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE  LOCALE 5/video_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/HcvImportService.txt` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/camera_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/camera_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/hcv_engine.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/hcv_import_router_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/hcv_import_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/hcv_package.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/hcv_verifier.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/hcvpack_player_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/home_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/import_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/main.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/text_cert_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/verifier_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/video_player_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 1/video_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/HcvImportService.txt` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/camera_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/camera_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/hcv_engine.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/hcv_import_router_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/hcv_import_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/hcv_package.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/hcv_verifier.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/hcvpack_player_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/home_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/import_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/main.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/text_cert_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/verifier_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/video_player_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 2/video_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/HcvImportService.txt` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/camera_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/camera_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/hcv_crypto.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/hcv_engine.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/hcv_identity.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/hcv_import_router_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/hcv_import_service.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/hcv_package.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/hcv_verifier.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/hcvpack_player_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/home_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/identity_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/import_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/main.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/text_cert_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/verifier_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/video_player_verify_page.dart` | historical-copy | indexed-only |
| `VERSIONE FUNZIONANTE 3/video_verify_page.dart` | historical-copy | indexed-only |
| `ai_trainer_server/.env.example` | source/configuration; see dependency edges | indexed-only |
| `ai_trainer_server/.gitignore` | source/configuration; see dependency edges | indexed-only |
| `ai_trainer_server/README.md` | documentation | indexed-only |
| `ai_trainer_server/package-lock.json` | source/configuration; see dependency edges | indexed-only |
| `ai_trainer_server/package.json` | source/configuration; see dependency edges | indexed-only |
| `ai_trainer_server/server.js` | source/configuration; see dependency edges | indexed-only |
| `analysis_options.yaml` | source/configuration; see dependency edges | indexed-only |
| `android/.gitignore` | source/configuration; see dependency edges | indexed-only |
| `android/app/build.gradle.kts` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/debug/AndroidManifest.xml` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/AndroidManifest.xml` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/kotlin/com/example/hcv_app/MainActivity.kt` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/kotlin/com/example/hcv_app/hcv_keystore_signer.dart` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/drawable/launch_background.xml` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/drawable-v21/launch_background.xml` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/values/colors.xml` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/values/styles.xml` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/main/res/values-night/styles.xml` | source/configuration; see dependency edges | indexed-only |
| `android/app/src/profile/AndroidManifest.xml` | source/configuration; see dependency edges | indexed-only |
| `android/build.gradle.kts` | source/configuration; see dependency edges | indexed-only |
| `android/gradle/wrapper/gradle-wrapper.properties` | source/configuration; see dependency edges | indexed-only |
| `android/gradle.properties` | source/configuration; see dependency edges | indexed-only |
| `android/settings.gradle.kts` | source/configuration; see dependency edges | indexed-only |
| `assets/icon/icon.png` | source/configuration; see dependency edges | indexed-only |
| `assets/ml/sigillum_photo_framing_v1.tflite` | source/configuration; see dependency edges | indexed-only |
| `assets/ml/sigillum_screen_replay_model_update.zip` | source/configuration; see dependency edges | indexed-only |
| `assets/ml/sigillum_screen_replay_v1.tflite` | source/configuration; see dependency edges | indexed-only |
| `assets/ml/sigillum_screen_replay_v1_labels.json` | source/configuration; see dependency edges | indexed-only |
| `assets/ml/sigillum_screen_replay_v2.tflite` | source/configuration; see dependency edges | indexed-only |
| `assets/ml/sigillum_screen_replay_v3_dualbranch.tflite` | source/configuration; see dependency edges | indexed-only |
| `assets/ml/sigillum_screen_replay_v3_multihead.tflite` | source/configuration; see dependency edges | indexed-only |
| `codemagic.yaml` | source/configuration; see dependency edges | source-read-complete |
| `docs/.nojekyll` | documentation | indexed-only |
| `docs/COMMERCIAL_PRELAUNCH_GUARDRAILS.md` | documentation | indexed-only |
| `docs/SIGILLUM_ORIGINAL_DERIVATION_CHAIN_V1.md` | documentation | indexed-only |
| `docs/delete-data/index.html` | documentation | indexed-only |
| `docs/index.html` | documentation | indexed-only |
| `docs/privacy/index.html` | documentation | indexed-only |
| `docs/styles.css` | documentation | indexed-only |
| `docs/support/index.html` | documentation | indexed-only |
| `docs/terms/index.html` | documentation | indexed-only |
| `hcv_1777814592219.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777822971987.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777824393237.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777824622312.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777824905288.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777825052503.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777825054083.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777825890781.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777835122824.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_1777835323548.hcv` | source/configuration; see dependency edges | indexed-only |
| `hcv_modifiche_complete/hcv_modifiche/camera_page.dart` | historical-copy | indexed-only |
| `hcv_modifiche_complete/hcv_modifiche/hcv_import_router_page.dart` | historical-copy | indexed-only |
| `hcv_modifiche_complete/hcv_modifiche/hcv_import_service.dart` | historical-copy | indexed-only |
| `hcv_modifiche_complete/hcv_modifiche/hcvpack_player_page.dart` | historical-copy | indexed-only |
| `hcv_modifiche_complete/hcv_modifiche/home_page.dart` | historical-copy | indexed-only |
| `hcv_modifiche_complete/hcv_modifiche/verify_page.dart` | historical-copy | indexed-only |
| `hcv_modifiche_complete/hcv_modifiche/video_verify_page.dart` | historical-copy | indexed-only |
| `hcv_modifiche_complete.zip` | source/configuration; see dependency edges | indexed-only |
| `hcv_registry_server.zip` | source/configuration; see dependency edges | indexed-only |
| `ios/.gitignore` | native iOS/configuration | indexed-only |
| `ios/Flutter/AppFrameworkInfo.plist` | native iOS/configuration | indexed-only |
| `ios/Flutter/Debug.xcconfig` | native iOS/configuration | indexed-only |
| `ios/Flutter/Release.xcconfig` | native iOS/configuration | indexed-only |
| `ios/Flutter/SigillumEdition.xcconfig` | native iOS/configuration | indexed-only |
| `ios/Podfile` | native iOS/configuration | indexed-only |
| `ios/Runner/AppDelegate.swift` | native iOS/configuration | source-read-complete |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png` | native iOS/configuration | indexed-only |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | documentation | indexed-only |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | native iOS/configuration | indexed-only |
| `ios/Runner/Base.lproj/Main.storyboard` | native iOS/configuration | indexed-only |
| `ios/Runner/Info.plist` | native iOS/configuration | indexed-only |
| `ios/Runner/Runner-Bridging-Header.h` | native iOS/configuration | indexed-only |
| `ios/Runner/Runner.entitlements` | native iOS/configuration | indexed-only |
| `ios/Runner/SceneDelegate.swift` | native iOS/configuration | source-read-complete |
| `ios/Runner/en.lproj/InfoPlist.strings` | native iOS/configuration | indexed-only |
| `ios/Runner/es.lproj/InfoPlist.strings` | native iOS/configuration | indexed-only |
| `ios/Runner/it.lproj/InfoPlist.strings` | native iOS/configuration | indexed-only |
| `ios/Runner/ru.lproj/InfoPlist.strings` | native iOS/configuration | indexed-only |
| `ios/Runner.xcodeproj/project.pbxproj` | native iOS/configuration | indexed-only |
| `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | native iOS/configuration | indexed-only |
| `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | native iOS/configuration | indexed-only |
| `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | native iOS/configuration | indexed-only |
| `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | native iOS/configuration | indexed-only |
| `ios/Runner.xcworkspace/contents.xcworkspacedata` | native iOS/configuration | indexed-only |
| `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | native iOS/configuration | indexed-only |
| `ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | native iOS/configuration | indexed-only |
| `ios/RunnerTests/RunnerTests.swift` | native iOS/configuration | indexed-only |
| `ios/SigillumShareExtension/Info.plist` | native iOS/configuration | indexed-only |
| `ios/SigillumShareExtension/ShareViewController.swift` | native iOS/configuration | source-read-complete |
| `ios/SigillumShareExtension/SigillumShareExtension.entitlements` | native iOS/configuration | indexed-only |
| `lib/HCV_CHECKPOINT_MANIFEST.md` | documentation | indexed-only |
| `lib/HcvImportService.txt` | certification/import/verification | indexed-only |
| `lib/Untitled-2.txt` | app source; see import edges | indexed-only |
| `lib/account_page.dart` | account/device/entitlement | indexed-only |
| `lib/camera_page.dart` | capture/finalization/native media | source-read-partial; 440–660,663–2665 |
| `lib/camera_service.dart` | capture/finalization/native media | indexed-only |
| `lib/camera_ui_copy.dart` | UI copy/localization/theme | indexed-only |
| `lib/camera_ui_extended_copy.dart` | UI copy/localization/theme | indexed-only |
| `lib/commercial_account_service.dart` | account/device/entitlement | source-read-complete |
| `lib/commercial_billing_service.dart` | account/device/entitlement | source-read-complete |
| `lib/commercial_gate.dart` | account/device/entitlement | source-read-partial; 564–1415 |
| `lib/commercial_profile_page.dart` | account/device/entitlement | source-read-partial; 465–539 |
| `lib/hcv_active_display_classifier.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_ai_training_service.dart` | app source; see import edges | indexed-only |
| `lib/hcv_audio_fingerprint.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_auth_service.dart` | account/device/entitlement | source-read-complete |
| `lib/hcv_capture_location.dart` | capture/finalization/native media | source-read-complete |
| `lib/hcv_capture_provenance.dart` | capture/finalization/native media | source-read-complete |
| `lib/hcv_capture_timestamp.dart` | capture/finalization/native media | indexed-only |
| `lib/hcv_checkpoint_manifest.json` | app source; see import edges | indexed-only |
| `lib/hcv_context_free_display_policy.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_crypto.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_display_final_policy.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_display_lattice_discriminator.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_display_risk_fusion.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_engine.dart` | app source; see import edges | source-read-complete |
| `lib/hcv_file_provenance_gate_page.dart` | certification/import/verification | indexed-only |
| `lib/hcv_id_lookup_page.dart` | app source; see import edges | indexed-only |
| `lib/hcv_identity.dart` | account/device/entitlement | source-read-complete |
| `lib/hcv_image_watermark.dart` | capture/finalization/native media | indexed-only |
| `lib/hcv_import_router_page.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_import_service.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_keystore_signer.dart` | app source; see import edges | source-read-complete |
| `lib/hcv_live_screen_probe.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_live_screen_probe_core.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_live_screen_probe_geometry.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_live_screen_probe_models.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_live_screen_probe_sampling.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_live_signals.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_location_image_watermark.dart` | capture/finalization/native media | indexed-only |
| `lib/hcv_location_video_watermark.dart` | capture/finalization/native media | indexed-only |
| `lib/hcv_logo_badge.dart` | app source; see import edges | indexed-only |
| `lib/hcv_media_id_ocr.dart` | certification/import/verification | indexed-only |
| `lib/hcv_ml_model_store.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_ml_screen_replay_classifier.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_ml_v3_photo_residual.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_multi_evidence_display_policy.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_package.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_photo_detail_compare.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_photo_framing_evidence.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_photo_semantic_framing_contract.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_photo_semantic_framing_inference.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_photo_semantic_framing_runner.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_photo_visual_framing.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_planar_motion_model.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_projective_motion_model.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_provenance_chain.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_reference_visual_fingerprint_v3.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_registry_provenance.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_registry_service.dart` | app source; see import edges | source-read-complete |
| `lib/hcv_scene_context_evidence.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_scene_decision_fusion.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_scene_geometry_classifier.dart` | scene/ML/optical evidence | source-read-complete |
| `lib/hcv_screen_replay_analyzer.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_secure_media_vault.dart` | local custody/reference/export | source-read-complete |
| `lib/hcv_secure_preview_service.dart` | app source; see import edges | source-read-complete |
| `lib/hcv_secure_store.dart` | account/device/entitlement | source-read-complete |
| `lib/hcv_social_fingerprint.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_software_attestation.dart` | app source; see import edges | source-read-complete |
| `lib/hcv_spatial_fingerprint_v2.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_temporal_capture_probe.dart` | capture/finalization/native media | indexed-only |
| `lib/hcv_temporal_frequency_probe.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_text_integrity.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_trust_analyzer.dart` | app source; see import edges | indexed-only |
| `lib/hcv_verifier.dart` | certification/import/verification | source-read-complete |
| `lib/hcv_video_photo_spatial_evidence.dart` | scene/ML/optical evidence | indexed-only |
| `lib/hcv_video_watermark.dart` | capture/finalization/native media | indexed-only |
| `lib/hcvpack_player_page.dart` | app source; see import edges | indexed-only |
| `lib/hcvpack_provenance_gate_page.dart` | certification/import/verification | indexed-only |
| `lib/home_page.dart` | app source; see import edges | indexed-only |
| `lib/identity_page.dart` | account/device/entitlement | indexed-only |
| `lib/import_page.dart` | certification/import/verification | indexed-only |
| `lib/lab_ui_copy.dart` | UI copy/localization/theme | indexed-only |
| `lib/legal_info_page.dart` | app source; see import edges | indexed-only |
| `lib/main X ANDROID.dart` | app source; see import edges | indexed-only |
| `lib/main.dart` | app source; see import edges | source-read-complete |
| `lib/manual_reference_compare_page.dart` | app source; see import edges | source-read-complete |
| `lib/quick_hcv_media_gate_page.dart` | app source; see import edges | indexed-only |
| `lib/recent_account_service.dart` | account/device/entitlement | indexed-only |
| `lib/registry_verify_copy.dart` | UI copy/localization/theme | indexed-only |
| `lib/registry_verify_page.dart` | certification/import/verification | source-read-partial; 830–1004,1296–1957,2068–2305,2494–2613 |
| `lib/screen_replay_calibration_page.dart` | scene/ML/optical evidence | indexed-only |
| `lib/screen_replay_diagnostics_page.dart` | scene/ML/optical evidence | indexed-only |
| `lib/secure_originals_page.dart` | local custody/reference/export | indexed-only |
| `lib/sigillum_edition.dart` | app source; see import edges | source-read-complete |
| `lib/sigillum_localization.dart` | UI copy/localization/theme | indexed-only |
| `lib/sigillum_quick_guide_page.dart` | app source; see import edges | indexed-only |
| `lib/sigillum_theme.dart` | UI copy/localization/theme | indexed-only |
| `lib/test_watermark.dart` | capture/finalization/native media | indexed-only |
| `lib/text_cert_page.dart` | certification/import/verification | indexed-only |
| `lib/text_social_verify_page.dart` | certification/import/verification | indexed-only |
| `lib/user_home_page.dart` | app source; see import edges | indexed-only |
| `lib/verification_ui_copy.dart` | UI copy/localization/theme | indexed-only |
| `lib/verified_originals_consent_page.dart` | local custody/reference/export | indexed-only |
| `lib/verified_originals_page.dart` | local custody/reference/export | indexed-only |
| `lib/verified_originals_publish_service.dart` | local custody/reference/export | source-read-complete |
| `lib/verified_originals_reference.dart` | local custody/reference/export | source-read-complete |
| `lib/verified_reference_viewer_page.dart` | local custody/reference/export | source-read-complete |
| `lib/verifier_page.dart` | certification/import/verification | indexed-only |
| `lib/verify_page.dart` | certification/import/verification | indexed-only |
| `lib/video_player_verify_page.dart` | certification/import/verification | indexed-only |
| `lib/video_transcription_service.dart` | capture/finalization/native media | source-read-complete |
| `lib/video_verify_page.dart` | certification/import/verification | indexed-only |
| `linux/.gitignore` | source/configuration; see dependency edges | indexed-only |
| `linux/CMakeLists.txt` | source/configuration; see dependency edges | indexed-only |
| `linux/flutter/CMakeLists.txt` | source/configuration; see dependency edges | indexed-only |
| `linux/flutter/generated_plugin_registrant.cc` | source/configuration; see dependency edges | indexed-only |
| `linux/flutter/generated_plugin_registrant.h` | source/configuration; see dependency edges | indexed-only |
| `linux/flutter/generated_plugins.cmake` | source/configuration; see dependency edges | indexed-only |
| `linux/runner/CMakeLists.txt` | source/configuration; see dependency edges | indexed-only |
| `linux/runner/main.cc` | source/configuration; see dependency edges | indexed-only |
| `linux/runner/my_application.cc` | source/configuration; see dependency edges | indexed-only |
| `linux/runner/my_application.h` | source/configuration; see dependency edges | indexed-only |
| `macos/.gitignore` | source/configuration; see dependency edges | indexed-only |
| `macos/Flutter/Flutter-Debug.xcconfig` | source/configuration; see dependency edges | indexed-only |
| `macos/Flutter/Flutter-Release.xcconfig` | source/configuration; see dependency edges | indexed-only |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | source/configuration; see dependency edges | indexed-only |
| `macos/Podfile` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/AppDelegate.swift` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Base.lproj/MainMenu.xib` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Configs/AppInfo.xcconfig` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Configs/Debug.xcconfig` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Configs/Release.xcconfig` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Configs/Warnings.xcconfig` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/DebugProfile.entitlements` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Info.plist` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/MainFlutterWindow.swift` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner/Release.entitlements` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner.xcodeproj/project.pbxproj` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner.xcworkspace/contents.xcworkspacedata` | source/configuration; see dependency edges | indexed-only |
| `macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | source/configuration; see dependency edges | indexed-only |
| `macos/RunnerTests/RunnerTests.swift` | source/configuration; see dependency edges | indexed-only |
| `ml/AI_TRAINER_SERVER_CONTRACT.md` | documentation | indexed-only |
| `ml/HARD_NEGATIVES_BUILD127.md` | documentation | indexed-only |
| `ml/V3_BENCHMARK_20260921.md` | documentation | indexed-only |
| `ml/V3_MULTIHEAD_REAL_IMAGE_AUDIT_20260922.md` | documentation | indexed-only |
| `ml/V3_PHOTO_RESIDUAL_CANDIDATE_20260922.md` | documentation | indexed-only |
| `ml/hard_negative_sets/build127_texture_hard_negatives_20260921.json` | source/configuration; see dependency edges | indexed-only |
| `ml/hard_negative_sets/build127_training_corpus_final_v1.json` | source/configuration; see dependency edges | indexed-only |
| `ml/photo_framing_fused_head_fp16.b85` | source/configuration; see dependency edges | indexed-only |
| `ml/prepare_dataset.py` | source/configuration; see dependency edges | indexed-only |
| `ml/requirements.txt` | source/configuration; see dependency edges | indexed-only |
| `ml/sigillum_photo_framing_v1_PARITY.json` | source/configuration; see dependency edges | source-read-complete |
| `ml/test_prepare_dataset_hard_negatives.py` | source/configuration; see dependency edges | indexed-only |
| `ml/train_tflite.py` | source/configuration; see dependency edges | indexed-only |
| `ml/v3/convert_v3_to_tflite.py` | source/configuration; see dependency edges | indexed-only |
| `ml/v3/v3_hard_negative_head_172a_fp16.json` | source/configuration; see dependency edges | indexed-only |
| `ml/v3/v3_multihead_tflite_manifest.json` | source/configuration; see dependency edges | indexed-only |
| `ml/v3/v3_multihead_weights_fp16.json` | source/configuration; see dependency edges | indexed-only |
| `ml/v3/v3_parity_vectors.json` | source/configuration; see dependency edges | indexed-only |
| `ml/v3_export/v3_dualbranch_litert_parity.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/prebuild-install` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/prebuild-install.cmd` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/prebuild-install.ps1` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/rc` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/rc.cmd` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/rc.ps1` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/semver` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/semver.cmd` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.bin/semver.ps1` | source/configuration; see dependency edges | indexed-only |
| `node_modules/.package-lock.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/base64-js/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/base64-js/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/base64-js/base64js.min.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/base64-js/index.d.ts` | source/configuration; see dependency edges | indexed-only |
| `node_modules/base64-js/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/base64-js/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/binding.gyp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/build/Release/better_sqlite3.node` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/common.gypi` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/copy.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/defines.gypi` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/download.sh` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/patches/1208.patch` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/sqlite3/sqlite3.c` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/sqlite3/sqlite3.h` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/sqlite3/sqlite3ext.h` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/sqlite3.gyp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/deps/test_extension.c` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/database.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/aggregate.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/backup.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/function.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/inspect.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/pragma.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/serialize.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/table.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/transaction.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/methods/wrappers.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/sqlite-error.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/lib/util.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/addon.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/better_sqlite3.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/objects/backup.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/objects/backup.hpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/objects/database.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/objects/database.hpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/objects/statement-iterator.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/objects/statement-iterator.hpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/objects/statement.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/objects/statement.hpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/bind-map.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/binder.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/constants.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/custom-aggregate.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/custom-function.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/custom-table.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/data-converter.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/data.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/helpers.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/macros.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/query-macros.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/better-sqlite3/src/util/row-builder.cpp` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bindings/LICENSE.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bindings/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bindings/bindings.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bindings/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/.travis.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/BufferList.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/LICENSE.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/bl.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/test/convert.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/test/indexOf.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/test/isBufferList.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/bl/test/test.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/buffer/AUTHORS.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/buffer/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/buffer/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/buffer/index.d.ts` | source/configuration; see dependency edges | indexed-only |
| `node_modules/buffer/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/buffer/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/chownr/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/chownr/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/chownr/chownr.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/chownr/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/decompress-response/index.d.ts` | source/configuration; see dependency edges | indexed-only |
| `node_modules/decompress-response/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/decompress-response/license` | source/configuration; see dependency edges | indexed-only |
| `node_modules/decompress-response/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/decompress-response/readme.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/deep-extend/CHANGELOG.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/deep-extend/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/deep-extend/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/deep-extend/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/deep-extend/lib/deep-extend.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/deep-extend/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/detect-libc/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/detect-libc/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/detect-libc/index.d.ts` | source/configuration; see dependency edges | indexed-only |
| `node_modules/detect-libc/lib/detect-libc.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/detect-libc/lib/elf.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/detect-libc/lib/filesystem.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/detect-libc/lib/process.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/detect-libc/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/end-of-stream/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/end-of-stream/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/end-of-stream/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/end-of-stream/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/expand-template/.travis.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/expand-template/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/expand-template/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/expand-template/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/expand-template/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/expand-template/test.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/.npmignore` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/.travis.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/History.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/index.d.ts` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/test/test.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/file-uri-to-path/test/tests.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/fs-constants/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/fs-constants/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/fs-constants/browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/fs-constants/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/fs-constants/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/.travis.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/example/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/example/url.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/readme.markdown` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/test/a.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/test/b.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/test/c.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/test/d.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/test/e.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/github-from-package/test/url.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ieee754/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ieee754/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ieee754/index.d.ts` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ieee754/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ieee754/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/inherits/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/inherits/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/inherits/inherits.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/inherits/inherits_browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/inherits/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ini/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ini/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ini/ini.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/ini/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mimic-response/index.d.ts` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mimic-response/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mimic-response/license` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mimic-response/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mimic-response/readme.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/.eslintrc` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/.github/FUNDING.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/.nycrc` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/CHANGELOG.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/example/parse.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/all_bool.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/bool.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/dash.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/default_bool.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/dotted.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/kv_short.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/long.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/num.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/parse.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/parse_modified.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/proto.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/short.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/stop_early.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/unknown.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/minimist/test/whitespace.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mkdirp-classic/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mkdirp-classic/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mkdirp-classic/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/mkdirp-classic/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/napi-build-utils/.github/workflows/run-npm-tests.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/napi-build-utils/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/napi-build-utils/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/napi-build-utils/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/napi-build-utils/index.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/napi-build-utils/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/node-abi/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/node-abi/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/node-abi/abi_registry.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/node-abi/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/node-abi/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/once/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/once/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/once/once.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/once/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/CHANGELOG.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/CONTRIBUTING.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/asset.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/bin.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/download.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/error.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/help.txt` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/log.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/proxy.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/rc.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/prebuild-install/util.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/.github/FUNDING.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/.travis.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/SECURITY.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/empty.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/test-browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/pump/test-node.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/LICENSE.APACHE2` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/LICENSE.BSD` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/LICENSE.MIT` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/cli.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/lib/utils.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/test/ini.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/test/nested-env-vars.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/rc/test/test.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/CONTRIBUTING.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/GOVERNANCE.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/errors-browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/errors.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/experimentalWarning.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/_stream_duplex.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/_stream_passthrough.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/_stream_readable.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/_stream_transform.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/_stream_writable.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/async_iterator.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/buffer_list.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/destroy.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/end-of-stream.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/from-browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/from.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/pipeline.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/state.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/stream-browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/lib/internal/streams/stream.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/readable-browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/readable-stream/readable.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/safe-buffer/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/safe-buffer/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/safe-buffer/index.d.ts` | source/configuration; see dependency edges | indexed-only |
| `node_modules/safe-buffer/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/safe-buffer/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/bin/semver.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/classes/comparator.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/classes/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/classes/range.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/classes/semver.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/clean.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/cmp.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/coerce.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/compare-build.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/compare-loose.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/compare.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/diff.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/eq.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/gt.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/gte.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/inc.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/lt.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/lte.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/major.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/minor.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/neq.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/parse.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/patch.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/prerelease.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/rcompare.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/rsort.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/satisfies.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/sort.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/truncate.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/functions/valid.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/internal/constants.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/internal/debug.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/internal/identifiers.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/internal/lrucache.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/internal/parse-options.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/internal/re.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/preload.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/range.bnf` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/gtr.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/intersects.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/ltr.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/max-satisfying.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/min-satisfying.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/min-version.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/outside.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/simplify.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/subset.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/to-comparators.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/semver/ranges/valid.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-concat/.travis.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-concat/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-concat/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-concat/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-concat/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-concat/test/basic.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-get/.github/dependabot.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-get/.github/workflows/ci.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-get/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-get/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-get/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/simple-get/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/string_decoder/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/string_decoder/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/string_decoder/lib/string_decoder.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/string_decoder/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/strip-json-comments/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/strip-json-comments/license` | source/configuration; see dependency edges | indexed-only |
| `node_modules/strip-json-comments/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/strip-json-comments/readme.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/.travis.yml` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/a/hello.txt` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/b/a/test.txt` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/d/file1` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/d/file2` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/d/sub-dir/file5` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/d/sub-files/file3` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/d/sub-files/file4` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/e/directory/.ignore` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/e/file` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/fixtures/invalid.tar` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-fs/test/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-stream/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-stream/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-stream/extract.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-stream/headers.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-stream/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-stream/pack.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-stream/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tar-stream/sandbox.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tunnel-agent/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tunnel-agent/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tunnel-agent/index.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/tunnel-agent/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/util-deprecate/History.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/util-deprecate/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/util-deprecate/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/util-deprecate/browser.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/util-deprecate/node.js` | source/configuration; see dependency edges | indexed-only |
| `node_modules/util-deprecate/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/wrappy/LICENSE` | source/configuration; see dependency edges | indexed-only |
| `node_modules/wrappy/README.md` | source/configuration; see dependency edges | indexed-only |
| `node_modules/wrappy/package.json` | source/configuration; see dependency edges | indexed-only |
| `node_modules/wrappy/wrappy.js` | source/configuration; see dependency edges | indexed-only |
| `package-lock.json` | source/configuration; see dependency edges | indexed-only |
| `package.json` | source/configuration; see dependency edges | indexed-only |
| `pubspec.lock` | source/configuration; see dependency edges | indexed-only |
| `pubspec.yaml` | source/configuration; see dependency edges | indexed-only |
| `test/account_page_contract_test.dart` | test | indexed-only |
| `test/account_success_feedback_contract_test.dart` | test | indexed-only |
| `test/active_probe_v4_contract_test.dart` | test | indexed-only |
| `test/active_probe_zoom_wait_contract_test.dart` | test | indexed-only |
| `test/apple_current_entitlement_reconciliation_contract_test.dart` | test | indexed-only |
| `test/apple_foreign_entitlement_purchase_preflight_contract_test.dart` | test | indexed-only |
| `test/archive15_display_risk_test.dart` | test | indexed-only |
| `test/archive17_display_risk_test.dart` | test | indexed-only |
| `test/archive18_display_risk_test.dart` | test | indexed-only |
| `test/archive19_flash_response_test.dart` | test | indexed-only |
| `test/archive20_scene_policy_test.dart` | test | indexed-only |
| `test/archive42_reality_active_probe_regression_test.dart` | test | indexed-only |
| `test/build109_low_modulation_hfr_recovery_test.dart` | test | indexed-only |
| `test/build109_ml_fullframe_recovery_test.dart` | test | indexed-only |
| `test/build111_photo_monitor_regression_test.dart` | test | indexed-only |
| `test/build112_photo_optical_corroboration_test.dart` | test | indexed-only |
| `test/build112_social_fingerprint_failclosed_test.dart` | test | indexed-only |
| `test/build113_audio_fingerprint_test.dart` | test | indexed-only |
| `test/build113_copy_localization_contract_test.dart` | test | indexed-only |
| `test/build115_reflection_semantic_resolution_test.dart` | test | indexed-only |
| `test/build116_bmw_display_hfr_mixedscene_test.dart` | test | indexed-only |
| `test/build117_scene_context_architecture_test.dart` | test | indexed-only |
| `test/build118_photo_preview_highres_contract_test.dart` | test | indexed-only |
| `test/build119_photo_preview_rotation_contract_test.dart` | test | indexed-only |
| `test/build120_passive_scene_context_activation_test.dart` | test | indexed-only |
| `test/build121_unified_photo_scene_context_test.dart` | test | indexed-only |
| `test/build122_corpus_wide_recovery_test.dart` | test | indexed-only |
| `test/build123_context_free_display_policy_test.dart` | test | indexed-only |
| `test/build124_multi_evidence_display_policy_test.dart` | test | indexed-only |
| `test/build125_fov_comparability_guard_test.dart` | test | indexed-only |
| `test/build125_zoom_coherent_hfr_test.dart` | test | indexed-only |
| `test/build126_video_fov_persistence_test.dart` | test | indexed-only |
| `test/build127_archive90_video_lattice_regression_test.dart` | test | indexed-only |
| `test/build127_ml_hard_negative_training_contract_test.dart` | test | indexed-only |
| `test/build127_physical_texture_lattice_guard_test.dart` | test | indexed-only |
| `test/build127_v3_photo_residual_28case_gate_test.dart` | test | indexed-only |
| `test/build127_v3_photo_residual_policy_test.dart` | test | indexed-only |
| `test/build128_derivative_integrity_spatial_v2_test.dart` | test | indexed-only |
| `test/build128_original_hard_binding_fail_closed_test.dart` | test | indexed-only |
| `test/build128_photo_video_preview_fov_parity_test.dart` | test | indexed-only |
| `test/build133_live_reference_and_recovery_contract_test.dart` | test | indexed-only |
| `test/build133_release_hardening_contract_test.dart` | test | indexed-only |
| `test/build136_field_regression_contract_test.dart` | test | indexed-only |
| `test/build137_text_scene_ux_contract_test.dart` | test | indexed-only |
| `test/build139_r2_primary_reference_contract_test.dart` | test | indexed-only |
| `test/build142_r2_manual_compare_contract_test.dart` | test | indexed-only |
| `test/build143_authorized_subtitle_derivation_contract_test.dart` | test | indexed-only |
| `test/build144_prelaunch_hardening_test.dart` | test | indexed-only |
| `test/build145_social_verification_recovery_test.dart` | test | indexed-only |
| `test/build146_text_verification_entry_test.dart` | test | indexed-only |
| `test/build147_gps_photo_integrity_test.dart` | test | indexed-only |
| `test/build148_photo_microtamper_test.dart` | test | indexed-only |
| `test/build149_authorized_derivative_scene_result_test.dart` | test | indexed-only |
| `test/build149_product_communication_contract_test.dart` | test | indexed-only |
| `test/build65_display_recall_regression_test.dart` | test | indexed-only |
| `test/build66_planar_multiframe_regression_test.dart` | test | indexed-only |
| `test/build67_reality_regression_test.dart` | test | indexed-only |
| `test/build69_capture_fusion_integration_test.dart` | test | indexed-only |
| `test/build71_video_semantic_persistence_regression_test.dart` | test | indexed-only |
| `test/build72_verification_scene_copy_contract_test.dart` | test | indexed-only |
| `test/build72_video_reality_and_container_regression_test.dart` | test | indexed-only |
| `test/build73_video_screen_persistence_v2_regression_test.dart` | test | indexed-only |
| `test/build74_fusion_regression_test.dart` | test | indexed-only |
| `test/build96_login_quickverify_regression_contract_test.dart` | test | indexed-only |
| `test/c8ff_regression_contract_test.dart` | test | indexed-only |
| `test/camera_focus_recovery_after_native_probe_test.dart` | test | indexed-only |
| `test/camera_physical_scene_contract_test.dart` | test | indexed-only |
| `test/camera_ready_video_evidence_contract_test.dart` | test | indexed-only |
| `test/capture_location_contract_test.dart` | test | indexed-only |
| `test/commercial_api_transport_contract_test.dart` | test | indexed-only |
| `test/commercial_billing_fresh_server_status_test.dart` | test | indexed-only |
| `test/commercial_billing_server_verification_contract_test.dart` | test | indexed-only |
| `test/commercial_registration_timeout_contract_test.dart` | test | indexed-only |
| `test/commercial_ux_kyc_identity_contract_test.dart` | test | indexed-only |
| `test/creator_entitlement_revalidation_contract_test.dart` | test | indexed-only |
| `test/creator_weekly_subscription_contract_test.dart` | test | indexed-only |
| `test/current_device_monitor_recall_regression_test.dart` | test | indexed-only |
| `test/device_revocation_ui_contract_test.dart` | test | indexed-only |
| `test/display_risk_policy_v4_test.dart` | test | indexed-only |
| `test/display_signature_matrix_test.dart` | test | indexed-only |
| `test/dual_display_reality_evidence_v1_test.dart` | test | indexed-only |
| `test/fast_uncertified_media_precheck_contract_test.dart` | test | indexed-only |
| `test/final_localization_hardening_test.dart` | test | indexed-only |
| `test/final_video_ui_paywall_contract_test.dart` | test | indexed-only |
| `test/foreign_storekit_stale_transaction_contract_test.dart` | test | indexed-only |
| `test/free_photo_reference_verification_contract_test.dart` | test | indexed-only |
| `test/frequency_probe_session_safety_contract_test.dart` | test | indexed-only |
| `test/geometry_not_absolute_proof_test.dart` | test | indexed-only |
| `test/hcv_active_display_classifier_test.dart` | test | indexed-only |
| `test/hcv_active_display_fusion_test.dart` | test | indexed-only |
| `test/hcv_capture_provenance_test.dart` | test | indexed-only |
| `test/hcv_capture_provenance_verifier_test.dart` | test | indexed-only |
| `test/hcv_capture_timestamp_test.dart` | test | indexed-only |
| `test/hcv_display_risk_conflict_regression_test.dart` | test | indexed-only |
| `test/hcv_display_risk_fusion_test.dart` | test | indexed-only |
| `test/hcv_engine_capture_provenance_contract_test.dart` | test | indexed-only |
| `test/hcv_id_format_test.dart` | test | indexed-only |
| `test/hcv_id_lookup_contract_test.dart` | test | indexed-only |
| `test/hcv_media_id_ocr_test.dart` | test | indexed-only |
| `test/hcv_planar_motion_model_test.dart` | test | indexed-only |
| `test/hcv_projective_motion_model_test.dart` | test | indexed-only |
| `test/hcv_provenance_chain_test.dart` | test | indexed-only |
| `test/hcv_registry_provenance_gate_contract_test.dart` | test | indexed-only |
| `test/hcv_scene_decision_fusion_test.dart` | test | indexed-only |
| `test/hcv_scene_geometry_classifier_test.dart` | test | indexed-only |
| `test/hcv_software_attestation_contract_test.dart` | test | indexed-only |
| `test/hcv_software_attestation_test.dart` | test | indexed-only |
| `test/hcv_software_attestation_verifier_test.dart` | test | indexed-only |
| `test/hcv_text_integrity_test.dart` | test | indexed-only |
| `test/hcv_trust_analyzer_standard_test.dart` | test | indexed-only |
| `test/hcvpack_integrity_release_gate_test.dart` | test | indexed-only |
| `test/hfr_coherent_display_periodicity_gate_test.dart` | test | indexed-only |
| `test/hfr_coherent_display_periodicity_integration_contract_test.dart` | test | indexed-only |
| `test/hfr_v31_advanced_probe_contract_test.dart` | test | indexed-only |
| `test/hfr_v32_harmonic_reality_physics_test.dart` | test | indexed-only |
| `test/hfr_v3_fullframe_mixed_scene_test.dart` | test | indexed-only |
| `test/ios_document_open_contract_test.dart` | test | indexed-only |
| `test/ios_photo_picker_lifecycle_contract_test.dart` | test | indexed-only |
| `test/ios_photo_picker_limited_access_fallback_contract_test.dart` | test | indexed-only |
| `test/ios_share_handoff_contract_test.dart` | test | indexed-only |
| `test/ios_video_watermark_archive42_contract_test.dart` | test | indexed-only |
| `test/kyc_recovery_contract_test.dart` | test | indexed-only |
| `test/live_probe_geometry_fields_test.dart` | test | indexed-only |
| `test/media_specific_verification_picker_contract_test.dart` | test | indexed-only |
| `test/messenger_mlkit_image_preflight_contract_test.dart` | test | indexed-only |
| `test/mixed_scene_monitor_regression_test.dart` | test | indexed-only |
| `test/ml_calibration_corpus_v1_test.dart` | test | indexed-only |
| `test/monitor_certificate_regression_test.dart` | test | indexed-only |
| `test/monitor_corroboration_policy_test.dart` | test | indexed-only |
| `test/native_storefront_price_contract_test.dart` | test | indexed-only |
| `test/native_temporal_frequency_focus_handoff_contract_test.dart` | test | indexed-only |
| `test/native_temporal_frequency_v2_contract_test.dart` | test | indexed-only |
| `test/native_temporal_frequency_v2_crash_hotfix_contract_test.dart` | test | indexed-only |
| `test/native_temporal_frequency_v2_hfr_range_contract_test.dart` | test | indexed-only |
| `test/no_capture_submode_claims_test.dart` | test | indexed-only |
| `test/no_strong_geometry_only_test.dart` | test | indexed-only |
| `test/official_reference_v3_contract_test.dart` | test | indexed-only |
| `test/paywall_native_storefront_contract_test.dart` | test | indexed-only |
| `test/phase_c_48_case_promotion_matrix_test.dart` | test | indexed-only |
| `test/phase_c_ml_geometry_persistence_regression_test.dart` | test | indexed-only |
| `test/photo_detail_compare_v4_test.dart` | test | source-read-complete |
| `test/photo_display_risk_policy_test.dart` | test | indexed-only |
| `test/photo_framing_embedded_context_guard_test.dart` | test | indexed-only |
| `test/photo_hfr_partial_conflict_guard_test.dart` | test | indexed-only |
| `test/photo_ml_first_threshold_080_regression_test.dart` | test | indexed-only |
| `test/photo_ocr_registry_recovery_contract_test.dart` | test | indexed-only |
| `test/photo_pre_capture_only_contract_test.dart` | test | indexed-only |
| `test/photo_quick_negative_latency_contract_test.dart` | test | indexed-only |
| `test/photo_semantic_capture_isolation_test.dart` | test | source-read-complete |
| `test/photo_semantic_framing_contract_test.dart` | test | indexed-only |
| `test/photo_semantic_framing_tflite_asset_test.dart` | test | source-read-complete |
| `test/photo_semantic_opencv_preprocessing_parity_test.dart` | test | source-read-complete |
| `test/photo_temporal_fast_contract_test.dart` | test | indexed-only |
| `test/photo_temporal_four_frame_sampling_contract_test.dart` | test | indexed-only |
| `test/photo_temporal_v2_c8ff_regression_test.dart` | test | indexed-only |
| `test/photo_video_equivalent_method_test.dart` | test | indexed-only |
| `test/photo_visual_framing_diagnostic_test.dart` | test | indexed-only |
| `test/physical_probe_user_instruction_test.dart` | test | indexed-only |
| `test/physical_scene_claims_photo_video_test.dart` | test | indexed-only |
| `test/physical_scene_decision_schema_test.dart` | test | indexed-only |
| `test/physical_scene_evidence_schema_test.dart` | test | indexed-only |
| `test/planarity_safety_test.dart` | test | indexed-only |
| `test/prelaunch_initial_scene_ui_paywall_contract_test.dart` | test | indexed-only |
| `test/prelaunch_legal_localization_contract_test.dart` | test | indexed-only |
| `test/prelaunch_product_refinement_contract_test.dart` | test | indexed-only |
| `test/prelaunch_rc2_regression_20260825_test.dart` | test | indexed-only |
| `test/prelaunch_ui_camera_refinement_contract_test.dart` | test | indexed-only |
| `test/prelaunch_usability_subtitle_account_contract_test.dart` | test | indexed-only |
| `test/prelaunch_verification_registry_regression_20260824_test.dart` | test | indexed-only |
| `test/prelaunch_visual_caption_refinement_contract_test.dart` | test | indexed-only |
| `test/probe_duration_contract_test.dart` | test | indexed-only |
| `test/profile_language_sync_contract_test.dart` | test | indexed-only |
| `test/public_home_unpaid_restore_contract_test.dart` | test | indexed-only |
| `test/quick_hcv_media_gate_contract_test.dart` | test | indexed-only |
| `test/rc2_installed_runtime_regression_contract_test.dart` | test | indexed-only |
| `test/rc2_photo_integrity_contract_test.dart` | test | indexed-only |
| `test/rc2_real_world_decision_regression_test.dart` | test | indexed-only |
| `test/rc2_verification_scene_priority_contract_test.dart` | test | indexed-only |
| `test/reality_override_threshold_test.dart` | test | indexed-only |
| `test/reality_temporal_false_positive_regression_test.dart` | test | indexed-only |
| `test/reference_visual_fingerprint_v3_test.dart` | test | indexed-only |
| `test/reflective_planar_ml_guard_regression_test.dart` | test | indexed-only |
| `test/registry_display_risk_claims_test.dart` | test | indexed-only |
| `test/registry_first_capture_race_contract_test.dart` | test | indexed-only |
| `test/registry_local_republish_contract_test.dart` | test | indexed-only |
| `test/registry_subscription_expiry_retry_contract_test.dart` | test | indexed-only |
| `test/registry_transient_retry_regression_test.dart` | test | indexed-only |
| `test/registry_verify_hcv_id16_contract_test.dart` | test | indexed-only |
| `test/save_original_reference_first_test.dart` | test | indexed-only |
| `test/scene_class_values_test.dart` | test | indexed-only |
| `test/scene_decision_values_test.dart` | test | indexed-only |
| `test/scene_geometry_thresholds_test.dart` | test | indexed-only |
| `test/server_creator_id_sync_contract_test.dart` | test | indexed-only |
| `test/share_extension_localization_and_reference_copy_test.dart` | test | indexed-only |
| `test/shared_media_cold_start_contract_test.dart` | test | indexed-only |
| `test/storefront_price_fail_closed_contract_test.dart` | test | indexed-only |
| `test/storefront_price_stability_contract_test.dart` | test | indexed-only |
| `test/storefront_session_freshness_contract_test.dart` | test | indexed-only |
| `test/storekit_cancel_retry_terminal_contract_test.dart` | test | indexed-only |
| `test/storekit_localized_price_contract_test.dart` | test | indexed-only |
| `test/storekit_transaction_lifecycle_contract_test.dart` | test | indexed-only |
| `test/storekit_user_safe_error_copy_test.dart` | test | indexed-only |
| `test/subtitle_tail_coverage_contract_test.dart` | test | indexed-only |
| `test/temporal_frequency_probe_contract_test.dart` | test | indexed-only |
| `test/testflight_ml_release_contract_test.dart` | test | indexed-only |
| `test/text_keyboard_registry_photo_arm_contract_test.dart` | test | indexed-only |
| `test/text_social_workflow_contract_test.dart` | test | indexed-only |
| `test/v3_hard_negative_172a_gate_test.dart` | test | indexed-only |
| `test/verification_clarity_localization_ml_contract_test.dart` | test | indexed-only |
| `test/verification_color_semantics_test.dart` | test | indexed-only |
| `test/verification_visual_consistency_contract_test.dart` | test | indexed-only |
| `test/verified_originals_reference_test.dart` | test | indexed-only |
| `test/verified_originals_v2_contract_test.dart` | test | indexed-only |
| `test/video_geometry_ml_conflict_guard_test.dart` | test | indexed-only |
| `test/video_initial_scene_policy_test.dart` | test | indexed-only |
| `test/video_ml_adaptive_sampling_contract_test.dart` | test | indexed-only |
| `test/video_native_capture_writer_stability_contract_test.dart` | test | indexed-only |
| `test/video_photo_spatial_evidence_test.dart` | test | indexed-only |
| `test/video_photo_spatial_fusion_test.dart` | test | indexed-only |
| `test/video_transcription_full_coverage_contract_test.dart` | test | indexed-only |
| `test/weak_semantic_no_physical_resolution_test.dart` | test | indexed-only |
| `test/weekly_duplicate_storekit_preflight_contract_test.dart` | test | indexed-only |
| `test/weekly_entitlement_settle_regression_test.dart` | test | indexed-only |
| `test/zoom_restore_contract_test.dart` | test | indexed-only |
| `tool/README_materialization_20260826.md` | build-or-operations | source-read-complete |
| `tool/apply_account_success_feedback.py` | build-or-operations | indexed-only |
| `tool/apply_camera_localization_finalizer_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_certificate_contract_test_fix.py` | build-or-operations | indexed-only |
| `tool/apply_certificate_regression_behavior_fix.py` | build-or-operations | indexed-only |
| `tool/apply_certificate_regression_compile_fix.py` | build-or-operations | indexed-only |
| `tool/apply_certificate_regression_fix.py` | build-or-operations | indexed-only |
| `tool/apply_commercial_profile_shell.py` | build-or-operations | indexed-only |
| `tool/apply_commercial_registry_auth.py` | build-or-operations | indexed-only |
| `tool/apply_creator_weekly_subscription_20260826.py` | build-or-operations | indexed-only |
| `tool/apply_e2e_video_livesignals_polish_20260819.py` | build-or-operations | indexed-only |
| `tool/apply_fast_uncertified_media_precheck_20260823.py` | build-or-operations | indexed-only |
| `tool/apply_file_import_and_ocr_fix.py` | build-or-operations | indexed-only |
| `tool/apply_ios_share_handoff_fix.py` | build-or-operations | indexed-only |
| `tool/apply_media_specific_verification_picker_fix_20260822.py` | build-or-operations | indexed-only |
| `tool/apply_mixed_scene_monitor_fix.py` | build-or-operations | indexed-only |
| `tool/apply_ml_ios_runtime_finalizer_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_planar_parallax_compile_safety.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_account_help_refinement_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_camera_files_subtitle_ui_fix_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_camera_generated_escape_fix_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_landing_localization_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_landing_visual_compile_fix.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_landing_visual_match.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_legal_localization_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_legal_localization_compile_guard_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_legal_localization_visual_anchor_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_proceed_anchor_normalization.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_product_refinement_20260817.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_product_refinement_contract_fix.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_speech_recognition_robustness_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_ui_camera_refinement.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_user_language_help_refinement_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_ux_kyc_identity_fix.py` | build-or-operations | indexed-only |
| `tool/apply_prelaunch_visual_caption_refinement_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_public_home_unpaid_restore_fix_20260822.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_decision_architecture_fix_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_decision_architecture_fix_legacy_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_definitive_build_finalizer_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_definitive_build_finalizer_legacy_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_ios_original_photo_picker_finalizer_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_native_storefront_price_finalizer_20260826.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_photo_integrity_finalizer_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_photo_integrity_wrapper_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_photo_package_camera_finalizer_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_photo_package_import_finalizer_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_photo_parallax_and_media_verify_finalizer_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_policy_test_alignment_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_runtime_regressions_finalizer_20260826.py` | build-or-operations | indexed-only |
| `tool/apply_rc2_verification_scene_priority_finalizer_20260826.py` | build-or-operations | indexed-only |
| `tool/apply_registry_full_diagnostics_20260825.py` | build-or-operations | indexed-only |
| `tool/apply_registry_read_compatibility_20260824.py` | build-or-operations | indexed-only |
| `tool/apply_safe_capture_location_fix.py` | build-or-operations | indexed-only |
| `tool/apply_server_verified_billing_gate.py` | build-or-operations | indexed-only |
| `tool/apply_storekit_localized_price_ui_fix_20260826.py` | build-or-operations | indexed-only |
| `tool/apply_storekit_transaction_lifecycle_fix_20260821.py` | build-or-operations | indexed-only |
| `tool/apply_text_keyboard_registry_photo_arm_fix.py` | build-or-operations | indexed-only |
| `tool/apply_text_social_verification.py` | build-or-operations | indexed-only |
| `tool/apply_verification_clarity_localization_ml_fix_20260824.py` | build-or-operations | indexed-only |
| `tool/apply_verification_compile_contract_finalizer_20260824.py` | build-or-operations | indexed-only |
| `tool/apply_verification_language_finalizer_20260824.py` | build-or-operations | indexed-only |
| `tool/apply_verification_registry_finalizer_20260824.py` | build-or-operations | indexed-only |
| `tool/apply_verification_result_copy_finalizer_20260824.py` | build-or-operations | indexed-only |
| `tool/apply_verification_severity_colors_20260824.py` | build-or-operations | indexed-only |
| `tool/build_testflight_ipa_rc2_20260825.sh` | build-or-operations | source-read-complete |
| `tool/convert_v3_dualbranch_litert.py` | build-or-operations | indexed-only |
| `tool/diagnose_tflite_models_20260825.py` | build-or-operations | indexed-only |
| `tool/finalize_testflight_release_source_20260825.py` | build-or-operations | indexed-only |
| `tool/normalize_camera_localization_anchors_20260825.py` | build-or-operations | indexed-only |
| `tool/normalize_capture_ready_dialog_for_localization_20260825.py` | build-or-operations | indexed-only |
| `tool/normalize_rc2_finalizer_idempotence_20260826.py` | build-or-operations | indexed-only |
| `tool/normalize_registry_helper_20260825.py` | build-or-operations | indexed-only |
| `tool/normalize_registry_initial_status_20260825.py` | build-or-operations | indexed-only |
| `tool/pin_tflite_ios_runtime_20260826.sh` | build-or-operations | source-read-complete |
| `tool/prepare_prelaunch_visual_caption_refinement_20260818.py` | build-or-operations | indexed-only |
| `tool/run_ios_share_handoff_fix.py` | build-or-operations | indexed-only |
| `tool/run_prelaunch_visual_caption_refinement_20260818.py` | build-or-operations | indexed-only |
| `tool/validate_display_fusion.dart` | build-or-operations | indexed-only |
| `tool/verify_materialized_source_commit_20260826.py` | build-or-operations | indexed-only |
| `tool/verify_postpatch_release_20260825.py` | build-or-operations | indexed-only |
| `web/favicon.png` | source/configuration; see dependency edges | indexed-only |
| `web/icons/Icon-192.png` | source/configuration; see dependency edges | indexed-only |
| `web/icons/Icon-512.png` | source/configuration; see dependency edges | indexed-only |
| `web/icons/Icon-maskable-192.png` | source/configuration; see dependency edges | indexed-only |
| `web/icons/Icon-maskable-512.png` | source/configuration; see dependency edges | indexed-only |
| `web/index.html` | source/configuration; see dependency edges | indexed-only |
| `web/manifest.json` | source/configuration; see dependency edges | indexed-only |
| `windows/.gitignore` | source/configuration; see dependency edges | indexed-only |
| `windows/CMakeLists.txt` | source/configuration; see dependency edges | indexed-only |
| `windows/flutter/CMakeLists.txt` | source/configuration; see dependency edges | indexed-only |
| `windows/flutter/generated_plugin_registrant.cc` | source/configuration; see dependency edges | indexed-only |
| `windows/flutter/generated_plugin_registrant.h` | source/configuration; see dependency edges | indexed-only |
| `windows/flutter/generated_plugins.cmake` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/CMakeLists.txt` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/Runner.rc` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/flutter_window.cpp` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/flutter_window.h` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/main.cpp` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/resource.h` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/resources/app_icon.ico` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/runner.exe.manifest` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/utils.cpp` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/utils.h` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/win32_window.cpp` | source/configuration; see dependency edges | indexed-only |
| `windows/runner/win32_window.h` | source/configuration; see dependency edges | indexed-only |

## backend

File: 173. Stati: indexed-only: 139, source-read-complete: 32, source-read-partial: 2.

| File | Ruolo/categoria | Lettura |
| --- | --- | --- |
| `.github/COMMERCIAL_VALIDATION_TRIGGER` | build-or-operations | indexed-only |
| `.github/workflows/audit-one-link-launch.yml` | build-or-operations | indexed-only |
| `.github/workflows/check.yml` | build-or-operations | indexed-only |
| `.github/workflows/closed-chain-reference-v2-validation.yml` | build-or-operations | indexed-only |
| `.github/workflows/deploy-verified-originals-render.yml` | build-or-operations | indexed-only |
| `.github/workflows/r2-audit-security-contract.yml` | build-or-operations | indexed-only |
| `.github/workflows/r2-primary-provider-acceptance.yml` | build-or-operations | indexed-only |
| `.github/workflows/r2-reference-acceptance.yml` | build-or-operations | indexed-only |
| `.github/workflows/render-load-test.yml` | build-or-operations | indexed-only |
| `.github/workflows/sigillum-connector-boundary.yml` | build-or-operations | indexed-only |
| `.github/workflows/telegram-reference-acceptance.yml` | build-or-operations | indexed-only |
| `.github/workflows/validate-production.yml` | build-or-operations | indexed-only |
| `.github/workflows/verified-originals-production.yml` | build-or-operations | indexed-only |
| `.github/workflows/verify-live-render-deployment.yml` | build-or-operations | indexed-only |
| `.gitignore` | source/configuration; see dependency edges | indexed-only |
| `.node-version` | source/configuration; see dependency edges | indexed-only |
| `CLOSED_CHAIN_REFERENCE_V2_CHECKPOINT.md` | documentation | indexed-only |
| `DELEGATED_REFERENCE_AUDIT.md` | documentation | indexed-only |
| `PRIMARY_REFERENCE_LIFECYCLE_20261002.md` | documentation | indexed-only |
| `PRODUCTION_ACTIVATION.md` | documentation | indexed-only |
| `PRODUCTION_ARCHITECTURE.md` | documentation | indexed-only |
| `R2_REFERENCE_ACCEPTANCE.md` | documentation | indexed-only |
| `README.md` | documentation | indexed-only |
| `REFERENCE_PROVIDER_DECISION_20261001.md` | documentation | source-read-complete |
| `TELEGRAM_REFERENCE_ACCEPTANCE.md` | documentation | indexed-only |
| `YOUTUBE_OAUTH_VERIFICATION_DEMO.md` | documentation | indexed-only |
| `app_store_account_binding_test.js` | test | indexed-only |
| `app_store_billing.js` | source/configuration; see dependency edges | source-read-complete |
| `app_store_ocsp_fallback_test.js` | test | indexed-only |
| `app_store_weekly_product_test.js` | test | indexed-only |
| `apple_associated_domains_test.js` | test | indexed-only |
| `apple_live_reconcile_runtime_test.js` | test | indexed-only |
| `apple_recent_verification_reconcile_runtime_test.js` | test | indexed-only |
| `audit_one_link_start_test.js` | test | indexed-only |
| `audit_reference_route_contract_test.js` | test | indexed-only |
| `audit_reference_scope.js` | source/configuration; see dependency edges | indexed-only |
| `audit_reference_scope_test.js` | test | indexed-only |
| `auth_api.js` | source/configuration; see dependency edges | indexed-only |
| `auth_proxy.js` | source/configuration; see dependency edges | indexed-only |
| `auth_smoke_test.js` | test | indexed-only |
| `billing_status_freshness_runtime_test.js` | test | indexed-only |
| `certificate_account_binding.js` | source/configuration; see dependency edges | source-read-complete |
| `certificate_account_binding_runtime_test.js` | test | indexed-only |
| `certificate_account_binding_test.js` | test | indexed-only |
| `consumer_theme_account_reuse_test.js` | test | indexed-only |
| `creator_identity_isolation_test.js` | test | indexed-only |
| `delegated_reference_audit.js` | private reference/audit lifecycle | indexed-only |
| `delegated_reference_audit_test.js` | test | indexed-only |
| `delegated_reference_audit_ui.js` | private reference/audit lifecycle | indexed-only |
| `device_enrollment_approval_runtime_test.js` | test | indexed-only |
| `device_revocation_runtime_test.js` | test | indexed-only |
| `docs/sigillum/ARCHITECTURE.md` | documentation | indexed-only |
| `docs/sigillum/DEPLOYMENT_STATE.md` | documentation | source-read-complete |
| `docs/sigillum/FILE_INVENTORY.md` | documentation | indexed-only |
| `docs/sigillum/HANDOFF.md` | documentation | source-read-complete |
| `docs/sigillum/OPEN_ISSUES.md` | documentation | source-read-complete |
| `docs/sigillum/TEST_MATRIX.md` | documentation | indexed-only |
| `docs/sigillum/VERIFICATION_PIPELINE.md` | documentation | indexed-only |
| `evidence/delegated-audit-cloud-browser.jpg` | private reference/audit lifecycle | indexed-only |
| `flutter` | source/configuration; see dependency edges | indexed-only |
| `hcv_signature_canonical.js` | source/configuration; see dependency edges | source-read-complete |
| `hcv_signature_canonical_test.js` | test | indexed-only |
| `kyc_proxy.js` | source/configuration; see dependency edges | indexed-only |
| `kyc_session_safety_test.js` | test | indexed-only |
| `legacy_public_claims_test.js` | test | indexed-only |
| `legal_documents.js` | source/configuration; see dependency edges | indexed-only |
| `legal_documents_test.js` | test | indexed-only |
| `load_test.js` | test | indexed-only |
| `migrations/20261012_sigillum_connector_oauth.sql` | source/configuration; see dependency edges | indexed-only |
| `migrations/20261012_sigillum_connector_principal.sql` | source/configuration; see dependency edges | indexed-only |
| `migrations/20261012_sigillum_mcp_credentials.sql` | source/configuration; see dependency edges | indexed-only |
| `package-lock.json` | source/configuration; see dependency edges | indexed-only |
| `package.json` | source/configuration; see dependency edges | source-read-complete |
| `photo_copy_verification_contract_test.js` | test | indexed-only |
| `photo_detail_compare.js` | source/configuration; see dependency edges | source-read-complete |
| `photo_detail_compare_test.js` | test | source-read-complete |
| `prelaunch_cleanup_test_state.js` | source/configuration; see dependency edges | indexed-only |
| `prelaunch_email_test.js` | test | indexed-only |
| `prelaunch_kyc_status_test.js` | test | indexed-only |
| `prelaunch_kyc_test.js` | test | indexed-only |
| `prelaunch_login_test.js` | test | indexed-only |
| `prelaunch_seed_subscription.js` | source/configuration; see dependency edges | indexed-only |
| `primary_reference_lifecycle.js` | private reference/audit lifecycle | source-read-complete |
| `primary_reference_lifecycle_pg_test.js` | test | indexed-only |
| `primary_reference_manifest.js` | private reference/audit lifecycle | source-read-complete |
| `primary_reference_manifest_test.js` | test | indexed-only |
| `primary_reference_provider.js` | private reference/audit lifecycle | source-read-complete |
| `primary_reference_provider_test.js` | test | indexed-only |
| `primary_reference_read_auth.js` | private reference/audit lifecycle | source-read-complete |
| `primary_reference_read_auth_pg_test.js` | test | indexed-only |
| `production_config.js` | source/configuration; see dependency edges | source-read-complete |
| `production_config_test.js` | test | indexed-only |
| `production_server.js` | source/configuration; see dependency edges | source-read-partial; 1–90,397–421,590–820,879–901,1169–1219,1378–1552 |
| `production_smoke_test.js` | test | indexed-only |
| `profile_language_sync_runtime_test.js` | test | indexed-only |
| `r2_reference_acceptance_test.js` | test | indexed-only |
| `reference_visual_fingerprint_v3_real_media_test.js` | test | indexed-only |
| `reference_visual_fingerprint_v3_test.js` | test | indexed-only |
| `registry_provenance_v2.js` | source/configuration; see dependency edges | source-read-complete |
| `registry_provenance_v2_runtime_test.js` | test | indexed-only |
| `registry_provenance_v2_test.js` | test | indexed-only |
| `render.production.yaml` | source/configuration; see dependency edges | source-read-complete |
| `server.js` | source/configuration; see dependency edges | indexed-only |
| `sigillum_connector_audit_request.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_connector_audit_request_test.js` | test | indexed-only |
| `sigillum_connector_bridge.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_connector_bridge_test.js` | test | indexed-only |
| `sigillum_connector_grant_adapter.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_connector_grant_adapter_test.js` | test | indexed-only |
| `sigillum_connector_oauth.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_connector_oauth_test.js` | test | indexed-only |
| `sigillum_connector_oauth_ui.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_connector_production_test.js` | test | indexed-only |
| `sigillum_connector_r2_capture.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_connector_r2_capture_test.js` | test | indexed-only |
| `sigillum_connector_remote.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_connector_remote_test.js` | test | indexed-only |
| `sigillum_connector_runtime.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_connector_runtime_test.js` | test | indexed-only |
| `sigillum_mcp_auth.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_mcp_auth_test.js` | test | indexed-only |
| `sigillum_mcp_credentials.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_mcp_credentials_test.js` | test | indexed-only |
| `sigillum_mcp_dispatcher.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_mcp_dispatcher_test.js` | test | indexed-only |
| `sigillum_mcp_http.js` | connector/OAuth/MCP | indexed-only |
| `sigillum_mcp_http_test.js` | test | indexed-only |
| `sigillum_mcp_service.js` | connector/OAuth/MCP | source-read-complete |
| `sigillum_mcp_service_test.js` | test | indexed-only |
| `sigillum_owner_web_auth.js` | connector/OAuth/MCP | source-read-complete |
| `subtitle_derivation_contract_test.js` | test | indexed-only |
| `telegram_reference_acceptance_test.js` | test | indexed-only |
| `tool/apply_account_email_reuse.py` | build-or-operations | indexed-only |
| `tool/apply_app_store_billing.py` | build-or-operations | indexed-only |
| `tool/apply_apple_associated_domains.py` | build-or-operations | indexed-only |
| `tool/apply_apple_live_reconcile.py` | build-or-operations | indexed-only |
| `tool/apply_apple_recent_verification_reconcile.py` | build-or-operations | indexed-only |
| `tool/apply_billing_status_freshness.py` | build-or-operations | indexed-only |
| `tool/apply_certificate_account_binding.py` | build-or-operations | indexed-only |
| `tool/apply_consumer_legal_theme.py` | build-or-operations | indexed-only |
| `tool/apply_device_enrollment_approval.py` | build-or-operations | indexed-only |
| `tool/apply_device_enrollment_postreview_hardening.py` | build-or-operations | indexed-only |
| `tool/apply_device_revocation.py` | build-or-operations | indexed-only |
| `tool/apply_hcv_signature_canonical_fix.py` | build-or-operations | indexed-only |
| `tool/apply_kyc_session_safety.py` | build-or-operations | indexed-only |
| `tool/apply_legal_localization_20260818.py` | build-or-operations | indexed-only |
| `tool/apply_postgres_startup_retry.py` | build-or-operations | indexed-only |
| `tool/apply_production_live_guard.py` | build-or-operations | indexed-only |
| `tool/apply_production_runtime_safety.py` | build-or-operations | indexed-only |
| `tool/apply_profile_language_sync.py` | build-or-operations | indexed-only |
| `tool/apply_registry_provenance_v2.py` | build-or-operations | indexed-only |
| `tool/apply_sigillum_connector_runtime.py` | build-or-operations | source-read-complete |
| `tool/apply_verified_originals_production.py` | build-or-operations | source-read-complete |
| `tool/audit_fixture_store.js` | build-or-operations | indexed-only |
| `tool/audit_test_database.js` | build-or-operations | indexed-only |
| `tool/connector_tls_fixture.js` | build-or-operations | indexed-only |
| `tool/delegated_audit_browser_fixture.js` | build-or-operations | indexed-only |
| `tool/delegated_audit_fixture_images.json` | build-or-operations | indexed-only |
| `tool/delegated_audit_fixture_smoke.js` | build-or-operations | indexed-only |
| `tool/ensure_device_enrollment_schema.js` | build-or-operations | indexed-only |
| `tool/r2_primary_provider_acceptance.js` | build-or-operations | indexed-only |
| `tool/r2_primary_reference_provider_acceptance.js` | build-or-operations | indexed-only |
| `tool/r2_reference_acceptance.js` | build-or-operations | indexed-only |
| `tool/r2_reference_acceptance_sdk.js` | build-or-operations | indexed-only |
| `tool/telegram_reference_acceptance.js` | build-or-operations | indexed-only |
| `tool/youtube_oauth_demo_windows.ps1` | build-or-operations | indexed-only |
| `tool/youtube_oauth_provision.js` | build-or-operations | indexed-only |
| `tool/youtube_scope_demo.js` | build-or-operations | indexed-only |
| `verified_originals_production.js` | private reference/audit lifecycle | source-read-partial; 1–85,1377–1518,1915–2197,2759–2882,4870–4989 |
| `verified_originals_production_contract_test.js` | test | indexed-only |
| `verified_originals_production_test.js` | test | indexed-only |
| `verified_originals_r2_production_test.js` | test | indexed-only |
| `youtube_oauth_tools_test.js` | test | indexed-only |

