#!/usr/bin/env python3
"""
HCV Film v0.2 — content-dependent authentication experiment.

Purpose
-------
Test whether the same 12 physical carrier markers can be made dependent on
canonicalized image/video content so that:
  * aggressive lossy recompression keeps verification valid;
  * semantic edits make verification fail.

This is a research prototype, NOT production cryptography.

Design
------
PHOTO:
  - 32x18 spatial grid over YCbCr block means.
  - marker neighborhoods are excluded from canonicalization.
  - only signing-time features sufficiently far from quantization boundaries
    ("guard-band features") are committed.
  - SHA-256 over canonical bins + HCV-ID produces a 12-bit carrier tag.
  - the 12 bits are embedded directly into the 12 robust markers.

VIDEO:
  - same spatial canonicalization per frame.
  - a SHA-256 temporal chain includes previous full chain digest, frame index,
    HCV-ID and current canonical bins.
  - first 8 bits of each full digest are encoded with Hamming(12,8) into the
    12 markers of that frame.
  - a content edit therefore perturbs the current and downstream chain.

The 12-bit PHOTO tag and 8-bit/frame VIDEO payload are intentionally too small
for production security. This experiment asks feasibility only.
"""

from __future__ import annotations
import hashlib
import json
import math
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out_v02"

W, H = 1920, 1080
FPS = 30
FRAMES = 60
HCV_ID = "HCV-FILM-V02-CONTENT-BINDING"

POSITIONS = [
    (0.09, 0.12), (0.23, 0.08), (0.39, 0.14), (0.56, 0.09),
    (0.74, 0.13), (0.90, 0.22), (0.14, 0.46), (0.33, 0.53),
    (0.53, 0.44), (0.72, 0.52), (0.87, 0.73), (0.48, 0.84),
]
RADIUS_FRAC = 0.008
ALPHA = 0.75
BIT_COLORS = {
    0: np.array([26.0, 58.0, 208.0], dtype=np.float32),
    1: np.array([229.0, 211.0, 47.0], dtype=np.float32),
}

GRID_X = 32
GRID_Y = 18
QUANT_STEP = 16.0
GUARD_MARGIN = 3.0
MASK_RADIUS_FRAC = 0.014
CANON_W = 640
CANON_H = 360
_MASK_CACHE: dict[tuple[int, int], np.ndarray] = {}


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True)


def require_binary(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(f"Required binary not found: {name}")


def background(phase: int = 0) -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W]
    r = 60 + 100 * xx / (W - 1) + 20 * np.sin((yy + phase * 4) / 90)
    g = 90 + 90 * yy / (H - 1) + 18 * np.cos((xx + phase * 5) / 120)
    b = 155 + 50 * np.sin((xx + yy + phase * 7) / 145)
    arr = np.clip(np.stack([r, g, b], axis=2), 0, 255).astype(np.uint8)
    im = Image.fromarray(arr, "RGB")
    d = ImageDraw.Draw(im)
    d.rectangle((100, 690, 780, 1040), fill=(48, 118, 68))
    d.ellipse((1090 + (phase % 20), 170, 1590 + (phase % 20), 650), fill=(198, 126, 76))
    d.polygon([(800, 980), (980, 520), (1160, 980)], fill=(88, 69, 144))
    d.rectangle((1240, 760, 1760, 980), fill=(70, 90, 115))
    return im


def marker_mask(h: int, w: int) -> np.ndarray:
    key = (h, w)
    cached = _MASK_CACHE.get(key)
    if cached is not None:
        return cached
    yy, xx = np.mgrid[0:h, 0:w]
    mask = np.ones((h, w), dtype=bool)
    radius = min(h, w) * MASK_RADIUS_FRAC
    for fx, fy in POSITIONS:
        cx, cy = fx * (w - 1), fy * (h - 1)
        mask &= ((xx - cx) ** 2 + (yy - cy) ** 2) > radius ** 2
    _MASK_CACHE[key] = mask
    return mask


def canonical_features(im: Image.Image) -> np.ndarray:
    # Normalize every source (4K/1080p/social downscale) to one inexpensive
    # canonical raster before extracting the 32x18 content grid.
    work = im.resize((CANON_W, CANON_H), Image.Resampling.LANCZOS)
    arr = np.asarray(work.convert("YCbCr"), dtype=np.float32)
    h, w, _ = arr.shape
    mask = marker_mask(h, w)
    values: list[float] = []
    for gy in range(GRID_Y):
        y0 = round(gy * h / GRID_Y)
        y1 = round((gy + 1) * h / GRID_Y)
        for gx in range(GRID_X):
            x0 = round(gx * w / GRID_X)
            x1 = round((gx + 1) * w / GRID_X)
            local_mask = mask[y0:y1, x0:x1]
            block = arr[y0:y1, x0:x1]
            vals = block[local_mask]
            if len(vals) == 0:
                values.extend([128.0, 128.0, 128.0])
            else:
                values.extend(vals.mean(axis=0).tolist())
    return np.asarray(values, dtype=np.float32)


def select_guard_indices(features: np.ndarray) -> np.ndarray:
    remainder = np.mod(features, QUANT_STEP)
    distance = np.minimum(remainder, QUANT_STEP - remainder)
    return np.where(distance >= GUARD_MARGIN)[0]


def quantized_bytes(features: np.ndarray, indices: np.ndarray) -> bytes:
    bins = np.floor(features[indices] / QUANT_STEP).astype(np.int16)
    return bins.tobytes()


def digest_bits(digest: bytes, n: int) -> list[int]:
    bits: list[int] = []
    for byte in digest:
        for shift in range(7, -1, -1):
            bits.append((byte >> shift) & 1)
            if len(bits) == n:
                return bits
    raise AssertionError("digest too short")


def photo_digest(im: Image.Image, indices: np.ndarray) -> bytes:
    payload = HCV_ID.encode() + b"|PHOTO|" + quantized_bytes(canonical_features(im), indices)
    return hashlib.sha256(payload).digest()


def hamming12_encode(data: list[int]) -> list[int]:
    if len(data) != 8:
        raise ValueError("Hamming(12,8) requires 8 bits")
    code = [0] * 13
    positions = [3, 5, 6, 7, 9, 10, 11, 12]
    for pos, bit in zip(positions, data):
        code[pos] = bit
    for parity_pos in (1, 2, 4, 8):
        parity = 0
        for pos in range(1, 13):
            if pos & parity_pos and pos != parity_pos:
                parity ^= code[pos]
        code[parity_pos] = parity
    return code[1:]


def hamming12_decode(bits: list[int]) -> tuple[list[int], int]:
    code = [0] + [int(x) & 1 for x in bits]
    syndrome = 0
    for parity_pos in (1, 2, 4, 8):
        parity = 0
        for pos in range(1, 13):
            if pos & parity_pos:
                parity ^= code[pos]
        if parity:
            syndrome |= parity_pos
    if 1 <= syndrome <= 12:
        code[syndrome] ^= 1
    positions = [3, 5, 6, 7, 9, 10, 11, 12]
    return [code[pos] for pos in positions], syndrome


def blend_disk(arr: np.ndarray, cx: int, cy: int, radius: int, target: np.ndarray, alpha: float) -> None:
    h, w, _ = arr.shape
    x0, x1 = max(0, cx - radius), min(w, cx + radius + 1)
    y0, y1 = max(0, cy - radius), min(h, cy + radius + 1)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    mask = ((xx - cx) ** 2 + (yy - cy) ** 2) <= radius ** 2
    patch = arr[y0:y1, x0:x1]
    patch[mask] = patch[mask] * (1.0 - alpha) + target * alpha


def embed_bits(im: Image.Image, bits: list[int]) -> Image.Image:
    arr = np.asarray(im.convert("RGB"), dtype=np.float32).copy()
    h, w, _ = arr.shape
    radius = max(3, int(round(min(w, h) * RADIUS_FRAC)))
    for (fx, fy), bit in zip(POSITIONS, bits):
        cx = int(round(fx * (w - 1)))
        cy = int(round(fy * (h - 1)))
        blend_disk(arr, cx, cy, int(radius * 1.45), np.array([128., 128., 128.]), ALPHA * 0.22)
        blend_disk(arr, cx, cy, radius, BIT_COLORS[bit], ALPHA)
        core = max(1, int(round(radius * 0.28)))
        core_target = np.array([18., 18., 18.]) if bit == 0 else np.array([238., 238., 238.])
        blend_disk(arr, cx, cy, core, core_target, min(0.95, ALPHA + 0.15))
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def sample_mean(arr: np.ndarray, cx: int, cy: int, radius: int) -> np.ndarray:
    h, w, _ = arr.shape
    x0, x1 = max(0, cx - radius), min(w, cx + radius + 1)
    y0, y1 = max(0, cy - radius), min(h, cy + radius + 1)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    mask = ((xx - cx) ** 2 + (yy - cy) ** 2) <= radius ** 2
    vals = arr[y0:y1, x0:x1][mask]
    return vals.mean(axis=0)


def decode_bits(im: Image.Image) -> list[int]:
    arr = np.asarray(im.convert("RGB"), dtype=np.float32)
    h, w, _ = arr.shape
    radius = max(2, int(round(min(w, h) * RADIUS_FRAC)))
    decoded = []
    for fx, fy in POSITIONS:
        cx = int(round(fx * (w - 1)))
        cy = int(round(fy * (h - 1)))
        center = sample_mean(arr, cx, cy, max(1, int(radius * 0.72)))
        outer = sample_mean(arr, cx, cy, max(2, int(radius * 2.25)))
        inner = sample_mean(arr, cx, cy, max(2, int(radius * 1.70)))
        bg = np.clip(2.4 * outer - 1.4 * inner, 0, 255)
        distances = []
        for bit in (0, 1):
            predicted = (1.0 - ALPHA) * bg + ALPHA * BIT_COLORS[bit]
            distances.append(float(np.linalg.norm(center - predicted)))
        decoded.append(0 if distances[0] <= distances[1] else 1)
    return decoded


def jpeg_variant(im: Image.Image, path: Path, quality: int, scale: float = 1.0) -> Image.Image:
    work = im
    if scale != 1.0:
        work = work.resize((round(im.width * scale), round(im.height * scale)), Image.Resampling.LANCZOS)
    work.save(path, "JPEG", quality=quality, subsampling=2)
    return Image.open(path).convert("RGB")


def attack_photo(im: Image.Image, name: str) -> Image.Image:
    out = im.copy()
    d = ImageDraw.Draw(out)
    if name == "ufo_big":
        d.ellipse((900, 220, 1120, 350), fill=(88, 88, 96))
        d.ellipse((940, 255, 1080, 330), fill=(190, 195, 200))
    elif name == "ufo_small":
        d.ellipse((940, 245, 1020, 295), fill=(88, 88, 96))
        d.ellipse((955, 258, 1005, 288), fill=(190, 195, 200))
    elif name == "ufo_tiny":
        d.ellipse((960, 255, 1000, 280), fill=(88, 88, 96))
    elif name == "ufo_translucent":
        overlay = Image.new("RGBA", out.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.ellipse((900, 220, 1120, 350), fill=(88, 88, 96, 90))
        out = Image.alpha_composite(out.convert("RGBA"), overlay).convert("RGB")
    elif name == "text":
        d.rectangle((300, 160, 1180, 300), fill=(20, 20, 20))
        d.text((340, 190), "BREAKING NEWS UFO", fill=(245, 245, 245))
    elif name == "brightness_5":
        out = ImageEnhance.Brightness(out).enhance(1.05)
    elif name == "color_shift":
        arr = np.asarray(out).astype(np.float32)
        arr[:, :, 0] *= 1.12
        arr[:, :, 1] *= 0.92
        arr[:, :, 2] *= 1.05
        out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    elif name == "replace_zone":
        crop = out.crop((100, 690, 500, 940)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        out.paste(crop, (1250, 150, 1650, 400))
    else:
        raise ValueError(name)
    return out


def photo_verify(im: Image.Image, guard_indices: np.ndarray) -> dict:
    carrier = decode_bits(im)
    expected = digest_bits(photo_digest(im, guard_indices), 12)
    errors = sum(a != b for a, b in zip(carrier, expected))
    return {"verified": errors == 0, "tag_bit_mismatches": errors, "carrier": carrier, "expected": expected}


def build_photo_cases(photo_marked: Image.Image, guard_indices: np.ndarray) -> list[dict]:
    pdir = OUT / "photo"
    pdir.mkdir(parents=True, exist_ok=True)
    rows = []

    benign = {
        "jpeg_q10": jpeg_variant(photo_marked, pdir / "benign_jpeg_q10.jpg", 10),
        "scale25_q25": jpeg_variant(photo_marked, pdir / "benign_scale25_q25.jpg", 25, 0.25),
        "scale33_q20": jpeg_variant(photo_marked, pdir / "benign_scale33_q20.jpg", 20, 1/3),
    }
    for name, im in benign.items():
        result = photo_verify(im, guard_indices)
        rows.append({"kind": "benign", "case": name, **result})

    attacks = [
        "ufo_big", "ufo_small", "ufo_tiny", "ufo_translucent",
        "text", "brightness_5", "color_shift", "replace_zone",
    ]
    for name in attacks:
        attacked = attack_photo(photo_marked, name)
        direct = photo_verify(attacked, guard_indices)
        attacked_jpeg = jpeg_variant(attacked, pdir / f"attack_{name}_q40.jpg", 40)
        post = photo_verify(attacked_jpeg, guard_indices)
        rows.append({
            "kind": "attack", "case": name,
            "direct_verified": direct["verified"],
            "direct_mismatches": direct["tag_bit_mismatches"],
            "after_jpeg40_verified": post["verified"],
            "after_jpeg40_mismatches": post["tag_bit_mismatches"],
        })
    return rows


def video_chain_digest(im: Image.Image, indices: np.ndarray, frame_index: int, previous: bytes) -> bytes:
    payload = (
        previous + b"|" + HCV_ID.encode() + b"|VIDEO|" +
        frame_index.to_bytes(4, "big") + b"|" +
        quantized_bytes(canonical_features(im), indices)
    )
    return hashlib.sha256(payload).digest()


def build_video_frames(indices: np.ndarray) -> tuple[list[Image.Image], list[bytes]]:
    frames: list[Image.Image] = []
    digests: list[bytes] = []
    previous = bytes(32)
    for idx in range(FRAMES):
        base = background(idx)
        digest = video_chain_digest(base, indices, idx, previous)
        payload8 = digest_bits(digest, 8)
        marked = embed_bits(base, hamming12_encode(payload8))
        frames.append(marked)
        digests.append(digest)
        previous = digest
    return frames, digests


def save_video(frames: list[Image.Image], path: Path, crf: int = 10, scale_height: int | None = None) -> None:
    temp = OUT / "_frames"
    if temp.exists():
        shutil.rmtree(temp)
    temp.mkdir(parents=True)
    for idx, frame in enumerate(frames):
        frame.save(temp / f"f_{idx:04d}.png")
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-framerate", str(FPS), "-i", str(temp / "f_%04d.png"),
    ]
    if scale_height is not None:
        cmd += ["-vf", f"scale=-2:{scale_height}"]
    cmd += ["-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", str(crf), "-pix_fmt", "yuv420p", "-r", str(FPS), str(path)]
    run(cmd)
    shutil.rmtree(temp)


def extract_video(path: Path) -> list[Image.Image]:
    temp = OUT / "_decoded"
    if temp.exists():
        shutil.rmtree(temp)
    temp.mkdir(parents=True)
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(path), "-vsync", "0", str(temp / "f_%04d.png")])
    images = [Image.open(p).convert("RGB").copy() for p in sorted(temp.glob("f_*.png"))]
    shutil.rmtree(temp)
    return images


def verify_video(frames: list[Image.Image], indices: np.ndarray) -> dict:
    previous = bytes(32)
    mismatched_frames = []
    carrier_corrected_frames = 0
    usable = min(len(frames), FRAMES)
    for idx in range(usable):
        current = frames[idx]
        digest = video_chain_digest(current, indices, idx, previous)
        expected = digest_bits(digest, 8)
        decoded, syndrome = hamming12_decode(decode_bits(current))
        if syndrome:
            carrier_corrected_frames += 1
        if decoded != expected:
            mismatched_frames.append(idx)
        previous = digest
    if len(frames) != FRAMES:
        mismatched_frames.extend(range(usable, FRAMES))
    return {
        "verified": len(mismatched_frames) == 0,
        "mismatched_frame_count": len(mismatched_frames),
        "first_mismatches": mismatched_frames[:20],
        "carrier_corrected_frames": carrier_corrected_frames,
    }


def video_attack(frames: list[Image.Image], name: str) -> list[Image.Image]:
    out = [f.copy() for f in frames]
    if name == "ufo_big_10_frames":
        for i in range(20, 30):
            out[i] = attack_photo(out[i], "ufo_big")
    elif name == "ufo_small_5_frames":
        for i in range(35, 40):
            out[i] = attack_photo(out[i], "ufo_small")
    elif name == "ufo_tiny_single_frame":
        out[45] = attack_photo(out[45], "ufo_tiny")
    elif name == "text_10_frames":
        for i in range(10, 20):
            out[i] = attack_photo(out[i], "text")
    elif name == "replace_one_frame":
        out[30] = out[29].copy()
    elif name == "brightness_all":
        out = [ImageEnhance.Brightness(f).enhance(1.05) for f in out]
    elif name == "delete_one_frame":
        del out[25]
        out.append(out[-1].copy())
    else:
        raise ValueError(name)
    return out


def main() -> int:
    require_binary("ffmpeg")
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    # Guard-band positions are fixed from the unsigned source content.
    source_photo = background(0)
    source_features = canonical_features(source_photo)
    guard_indices = select_guard_indices(source_features)

    photo_tag = digest_bits(photo_digest(source_photo, guard_indices), 12)
    photo_marked = embed_bits(source_photo, photo_tag)
    photo_marked.save(OUT / "photo_signed.png")
    photo_rows = build_photo_cases(photo_marked, guard_indices)

    video_frames, _ = build_video_frames(guard_indices)
    video_dir = OUT / "video"
    video_dir.mkdir()
    source_video = video_dir / "source.mp4"
    save_video(video_frames, source_video, crf=10)

    video_rows = []
    # Benign transcodes
    for name, crf, height in [
        ("h264_crf45", 45, None),
        ("scale_720_crf35", 35, 720),
        ("scale_480_crf40", 40, 480),
    ]:
        path = video_dir / f"benign_{name}.mp4"
        save_video(video_frames, path, crf=crf, scale_height=height)
        result = verify_video(extract_video(path), guard_indices)
        video_rows.append({"kind": "benign", "case": name, **result})

    # Attacks, then a realistic re-encode so the verifier never sees pristine edits.
    for name in [
        "ufo_big_10_frames", "ufo_small_5_frames", "ufo_tiny_single_frame",
        "text_10_frames", "replace_one_frame", "brightness_all", "delete_one_frame",
    ]:
        attacked = video_attack(video_frames, name)
        path = video_dir / f"attack_{name}_crf35.mp4"
        save_video(attacked, path, crf=35)
        result = verify_video(extract_video(path), guard_indices)
        video_rows.append({"kind": "attack", "case": name, **result})

    summary = {
        "canonicalization": {
            "grid": [GRID_X, GRID_Y],
            "quant_step": QUANT_STEP,
            "guard_margin": GUARD_MARGIN,
            "selected_feature_count": int(len(guard_indices)),
            "total_feature_count": int(len(source_features)),
        },
        "photo": photo_rows,
        "video": video_rows,
    }

    benign_photo_ok = all(r["verified"] for r in photo_rows if r["kind"] == "benign")
    attacks_photo_rejected = all(
        (not r["direct_verified"]) and (not r["after_jpeg40_verified"])
        for r in photo_rows if r["kind"] == "attack"
    )
    benign_video_ok = all(r["verified"] for r in video_rows if r["kind"] == "benign")
    attacks_video_rejected = all(not r["verified"] for r in video_rows if r["kind"] == "attack")

    summary["gates"] = {
        "benign_photo_all_verified": benign_photo_ok,
        "photo_attacks_all_rejected_direct_and_after_jpeg": attacks_photo_rejected,
        "benign_video_all_verified": benign_video_ok,
        "video_attacks_all_rejected_after_h264": attacks_video_rejected,
        "all_gates_pass": benign_photo_ok and attacks_photo_rejected and benign_video_ok and attacks_video_rejected,
    }

    (OUT / "results_v02.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print("=== HCV FILM V0.2 RESULTS ===")
    print(json.dumps(summary, indent=2))

    # CI failure is intentional if the content-binding hypothesis does not hold.
    return 0 if summary["gates"]["all_gates_pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
