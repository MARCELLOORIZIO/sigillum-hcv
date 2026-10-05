# SIGILLUM App Store readiness

## Build to submit

- Workflow: `SIGILLUM iOS User`
- Canonical branch: `release/testflight-final-20260827`
- Edition flag: `SIGILLUM_EDITION=user`
- Lab-only screens must stay out of the user build.
- Current deployment target: **iPhone only, iOS 16.0 or later**.
- Technical device floor from iOS 16 compatibility: **iPhone 8, iPhone 8 Plus and iPhone X or later**. Full SIGILLUM capture/ML validation on the oldest devices remains a release test requirement.

## Product promise

**You create. SIGILLUM protects the origin.**

SIGILLUM creates a verifiable origin before distribution. Photos and videos originate in the SIGILLUM Camera. Text is written and certified inside the app. SIGILLUM links content to an HCV-ID, Creator, device and signed certificate. Before a photo or video is released outside the app, SIGILLUM registers the protected original reference so later copies can be checked against what existed before distribution.

### What the user does

- Photo/video: open SIGILLUM → capture/record → save or share.
- Text: write in SIGILLUM → certify → copy or share.
- Verify media: share/select the received file → view the result.
- Verify text: copy the published text → paste it into SIGILLUM → verify.
- Optional human comparison: open the protected reference and compare image/audio with the received copy.

### What SIGILLUM does automatically

- HCV-ID and cryptographic hashes.
- Signed HCV certificate.
- Creator/device binding and KYC state where completed.
- Capture timestamp and optional GPS.
- Photo/video scene and screen-recapture checks.
- Secure local original/HCVPACK storage.
- Registry registration.
- Protected server reference before external release of photos/videos.
- Media-specific copy comparison, including visual/audio checks for modern video.
- Authorized derivation tracking, such as SIGILLUM captioned video.
- Text fingerprint verification for published text.

## Required wording

Use strong commercial language for the product benefit, but keep these distinctions:
- A byte-identical hash match may be called an identical/original match.
- A recompressed copy that passes comparison is a **copy compatible with the SIGILLUM reference**, not automatically byte-identical.
- Scene analysis reports physical-scene/display evidence; it does not certify the substantive truth of what happened.
- A Registry record alone is not a media-integrity verdict.
- KYC links a verified identity to the Creator account; it does not certify the truth of the Creator’s statements.

## Store description — English

**You create. SIGILLUM protects the origin.**

Capture photos and videos with the SIGILLUM Camera or certify text before you publish it. SIGILLUM creates the HCV-ID and signed certificate, links the content to the Creator and device, and keeps its origin verifiable over time. Before a photo or video leaves SIGILLUM, a protected original reference is registered so later copies can be checked automatically or compared by a person.

Create. Certify. Share. Verify.

## Descrizione Store — Italiano

**Tu crei. SIGILLUM protegge l’origine.**

Scatta foto e registra video con la Camera SIGILLUM oppure certifica un testo prima di pubblicarlo. SIGILLUM crea HCV-ID e certificato firmato, collega il contenuto al Creator e al dispositivo e rende verificabile l’origine nel tempo. Prima che una foto o un video esca da SIGILLUM viene registrato il riferimento originale protetto, così le copie successive possono essere controllate automaticamente o confrontate da una persona.

Crea. Certifica. Condividi. Verifica.

## Descripción Store — Español

**Tú creas. SIGILLUM protege el origen.**

Captura fotos y vídeos con la Cámara SIGILLUM o certifica un texto antes de publicarlo. SIGILLUM crea el HCV-ID y el certificado firmado, vincula el contenido con el Creator y el dispositivo y mantiene verificable su origen. Antes de que una foto o un vídeo salga de SIGILLUM se registra la referencia original protegida para poder comprobar después las copias de forma automática o mediante comparación humana.

Crea. Certifica. Comparte. Verifica.

## Описание Store — Русский

**Вы создаёте. SIGILLUM защищает источник.**

Снимайте фото и видео Камерой SIGILLUM или сертифицируйте текст до публикации. SIGILLUM создаёт HCV-ID и подписанный сертификат, связывает контент с Creator и устройством и сохраняет проверяемость происхождения. До выхода фото или видео из SIGILLUM регистрируется защищённый оригинальный эталон, чтобы последующие копии можно было проверить автоматически или сравнить вручную.

Создайте. Сертифицируйте. Поделитесь. Проверьте.

## TestFlight smoke test

1. Install on a real iPhone.
2. Certify one photo, one video and one text.
3. Confirm photo/video capture comes from the SIGILLUM Camera.
4. Save/share a photo or video and confirm the protected server reference exists before release.
5. Verify exact originals.
6. Verify ordinary social recompression.
7. Verify a deliberately modified photo/video.
8. Verify text exact / formatting-only / modified.
9. Verify an authorized captioned-video derivation.
10. Open the protected reference and perform a human visual/audio comparison.
11. Check IT/EN/ES/RU copy.
12. Validate at least one iOS 16-era device before claiming full support for the oldest technically installable iPhones.
