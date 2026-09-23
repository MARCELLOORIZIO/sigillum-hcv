# HCV Film v0 — compression survivability experiment

This experiment tests one question only:

> Can a 12-marker SIGILLUM carrier remain fully decodable after aggressive photo/video recompression?

It does **not** yet claim tamper detection, authenticity, social-platform equivalence, or security against marker copying.

## Carrier

Each sample carries 12 relative-position markers. Every marker encodes one bit using a blended luminance/chroma state plus a small high-contrast core. Three visibility/size profiles are tested:

- `subtle`: radius 0.40% of the shorter image side, alpha 0.35
- `balanced`: radius 0.60%, alpha 0.55
- `robust`: radius 0.80%, alpha 0.75

The video payload changes in every frame. HCV Film v0.1 now maps an 8-bit deterministic payload through Hamming(12,8): 8 data bits + 4 parity bits are carried by the same 12 markers. This corrects a single damaged marker in a frame without increasing marker count, size, or visibility.

## Compression matrix

Photo:
- JPEG quality 95, 80, 60, 40, 25, 10
- resize 75% + JPEG 60
- resize 50% + JPEG 40
- resize 25% + JPEG 25
- JPEG quality 40 repeated three times

Video:
- H.264 CRF 18, 23, 28, 35, 40, 45
- 1080p -> 720p CRF 35
- 1080p -> 480p CRF 40
- H.264 CRF 35 repeated three times

## Strict success criterion

`full_recovery=true` only when **all 12 bits** are decoded correctly.

For video, the criterion is stricter: all 12 bits must be correct in **every expected frame**. Missing frames count as failures.

## Deliberate limitations of v0

- known geometry: no crop/rotation/perspective recovery yet
- no real Instagram/WhatsApp/Messenger round trip yet
- no ECC yet
- no cryptographic content binding yet
- no attack/tamper tests yet
- no claim that a copied constellation cannot be transplanted

Those belong to later experiments only if this carrier first survives compression.


## v0.1 rationale

The first measured run found the robust profile perfect in 18/19 stress cases. Its only failure was 1080p -> 480p at H.264 CRF 40: 6 raw bit errors over 720 carrier bits, distributed as exactly one raw bit error in each of 6 different frames. Hamming(12,8) was introduced specifically to test whether that sparse failure mode can be corrected without increasing marker density or visibility.
