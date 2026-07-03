# SIGILLUM App Store readiness

## Build to submit

- Workflow: `SIGILLUM iOS User`
- Branch: `sigillum-iphone`
- Edition flag: `SIGILLUM_EDITION=user`
- Lab-only screens must stay out of the user build.

## User-facing scope

- Certify photo or video.
- Certify text.
- Verify media, text, HCVPACK and HCV-ID.
- Show identity, integrity, scene-risk and derivation separately.
- Explain the SIGILLUM control chain in simple language.

## App Review positioning

SIGILLUM provides technical evidence of provenance and integrity. It does not claim to prove the absolute truth of a scene and does not replace a legal expert report.

Use this language consistently in the App Store description, screenshots, privacy policy and in-app information page.

## Required before App Store submission

- Public privacy policy URL: `https://hcv-registry-server.onrender.com/privacy`
- Public terms URL: `https://hcv-registry-server.onrender.com/terms`
- Public support URL: `https://hcv-registry-server.onrender.com/support`
- Data deletion URL: `https://hcv-registry-server.onrender.com/delete-data`
- App Store screenshots for iPhone.
- App Store description in Italian and English at minimum.
- TestFlight build validated on a real iPhone.
- Registry server online, health endpoint working and legal pages reachable.
- KYC endpoint configured with provider key before claiming legal identity verification.
- Camera, microphone, photos and file access permission texts reviewed.

## TestFlight smoke test

1. Install the user IPA.
2. Certify one photo.
3. Certify one video.
4. Certify one text.
5. Verify the original files.
6. Verify a social-compressed or renamed file.
7. Verify an HCVPACK.
8. Open the information/privacy page in each available language.
9. Confirm Lab functions are not visible in the user app.

## Store description draft

SIGILLUM creates verifiable technical proof for photos, videos and text. Each certified content receives an HCV-ID, a signed certificate, a cryptographic fingerprint and an online Registry record. Verification separates provenance, integrity, scene risk and derivation, so users can understand what is technically confirmed and what requires caution.
