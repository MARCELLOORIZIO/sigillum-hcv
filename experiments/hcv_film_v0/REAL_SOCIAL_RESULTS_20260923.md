# HCV Film v0.1 — real social round-trip results — 2026-09-23

## Scope

Real-world survivability test of the 12-marker robust carrier after Messenger and Instagram processing.

This remains a **carrier survivability** experiment only. It is not yet a tamper/authenticity test.

## Source sample

- photo: 1920×1080 PNG
- video: 1920×1080 H.264, 30 fps, 3.0 s, 90 frames
- carrier profile: robust
- marker radius: 0.80% of shorter side
- alpha: 0.75
- payload: 8 bits encoded as Hamming(12,8)
- same 12-bit code repeated in every video frame for this social round-trip phase

## Messenger

Returned photo:
- 1920×1080 JPEG
- raw carrier errors: **0 / 12**
- payload errors after ECC: **0 / 8**
- full recovery: **YES**

Returned video:
- 1920×1080 H.264
- 30 fps
- 90 frames
- duration 3.000 s
- file size 3,029,400 bytes
- bitrate ~8.08 Mb/s
- raw carrier errors: **0 / 1080** (12 bits × 90 frames)
- frames with carrier errors: **0 / 90**
- payload errors after ECC: **0**
- full recovery: **YES**

## Instagram

Returned photo:
- 1024×576 JPEG
- raw carrier errors: **0 / 12**
- payload errors after ECC: **0 / 8**
- full recovery: **YES**

Returned video:
- 640×360 H.264
- 30 fps
- 90 frames
- duration 3.000 s
- file size 45,596 bytes
- bitrate ~121.6 kb/s

Observed platform behavior:
- frame 1: completely black, mean RGB intensity 0
- frame 2: completely black, mean RGB intensity 0
- frames 3–90: normal social-transcoded content

Carrier decoding:
- frames 1–2: unavailable because Instagram replaced them with all-black frames; all 12 physical markers are absent
- frames 3–90: **0 raw marker errors**
- decoded content-bearing frames: **88 / 88 perfect**
- residual payload errors on frames 3–90: **0**

Interpretation:
Instagram did not merely damage the first two carriers. It replaced the first two frames with black frames. The HCV Film carrier survived every actual content-bearing Instagram frame despite a downscale to 640×360 and bitrate reduction to ~121.6 kb/s.

A production protocol therefore needs temporal synchronization / start-padding tolerance rather than stronger markers for this observed case.

## Current measured conclusion

The robust 12-marker HCV Film carrier has now achieved:
- synthetic compression matrix: complete post-ECC payload recovery in 19/19 cases
- Messenger photo: complete recovery
- Messenger video: complete recovery in 90/90 frames
- Instagram photo: complete recovery
- Instagram video: complete recovery in every content-bearing frame, 88/88; two leading frames were replaced by platform-generated black frames

## Not proven yet

- tamper detection
- cryptographic binding of carrier state to image/video content
- resistance to marker extraction/transplantation
- crop/rotation/perspective recovery
- WhatsApp/X round trips
- adversarial text/object/UFO insertion
- color/brightness edits
- frame insertion/deletion beyond observed leading black padding
