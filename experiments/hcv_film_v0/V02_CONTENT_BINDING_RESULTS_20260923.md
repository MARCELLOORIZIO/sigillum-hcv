# HCV Film v0.2 — content-dependent attack battery — 2026-09-23

## Purpose

Test whether HCV Film can evolve from a compression-resistant carrier into a content-dependent authenticity seal.

This remains an experimental prototype. No production authenticity claim is made.

## Configuration that produced the best measured result

- physical carrier: 12 robust markers
- canonical raster: 640×360
- content grid: 32×18
- YCbCr block statistics
- quantization step: 20
- guard margin: 6
- PHOTO: 12-bit content-dependent digest tag
- VIDEO: 8 payload bits per frame protected with Hamming(12,8)
- VIDEO: full SHA-256 temporal chain
- VIDEO: signing-time guard indices selected independently per frame

## PHOTO result

### Benign transforms — all accepted
- JPEG quality 10: VERIFIED, 0 tag mismatches
- resize to 25% + JPEG 25: VERIFIED, 0 tag mismatches
- resize to 33% + JPEG 20: VERIFIED, 0 tag mismatches

Separate real social evidence from HCV Film v0.1 already established exact carrier survival on Messenger and Instagram.

### Attacks — all rejected, both pristine and after JPEG 40
- large UFO: rejected
- small UFO: rejected
- tiny UFO: rejected
- translucent UFO: rejected
- text overlay: rejected
- +5% brightness: rejected
- color shift: rejected
- region replacement: rejected

**PHOTO feasibility gate: PASS in this synthetic battery.**

## VIDEO result

### Benign transforms
- 720p H.264 CRF35: VERIFIED
- H.264 CRF45: false rejection beginning at frame 4
- 480p H.264 CRF40: false rejection beginning at frame 12

### Attacks
Rejected:
- large UFO over multiple frames
- text overlay
- frame replacement
- global brightness change
- frame deletion

Not rejected:
- small UFO over a few frames
- tiny UFO in a single frame

**VIDEO feasibility gate: FAIL for the current 12-marker/global-content architecture.**

## Engineering conclusion

The carrier itself is not the blocker: v0.1 already survived very aggressive synthetic compression and real Messenger/Instagram recompression.

The blocker is the VIDEO content representation. A 12-marker global tag forces an undesirable trade-off:
- coarse/robust canonicalization tolerates H.264 but can miss very small/local edits;
- sensitive canonicalization detects small edits but produces false rejections under aggressive H.264/downscale.

Therefore the next video experiment should not merely retune thresholds. It should change topology to a **denser local authentication film**:
- multiple local micro-markers/cells across the frame;
- each marker authenticates a local or cross-linked region;
- pseudorandom spatial placement and temporal motion;
- content-dependent marker state;
- cross-frame linking for insertion/deletion/replacement;
- ECC kept separate from authenticity.

This preserves the successful PHOTO profile while addressing the observed VIDEO failure mode.
