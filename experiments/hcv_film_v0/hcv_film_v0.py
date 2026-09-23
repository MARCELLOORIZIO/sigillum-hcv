#!/usr/bin/env python3
"""
HCV Film v0 survivability experiment.

Goal: measure whether a 12-marker visible/semi-visible constellation remains
fully decodable after increasingly destructive JPEG/H.264 recompression.

This is deliberately NOT an authenticity/tamper detector yet. It isolates the
first engineering question: can the carrier survive compression?
"""

from __future__ import annotations

import csv
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out"
WIDTH = 1920
HEIGHT = 1080
FPS = 30
FRAMES = 60
SEED = "SIGILLUM-HCV-FILM-V0-20260923"

POSITIONS = [
    (0.09, 0.12), (0.23, 0.08), (0.39, 0.14), (0.56, 0.09),
    (0.74, 0.13), (0.90, 0.22), (0.14, 0.46), (0.33, 0.53),
    (0.53, 0.44), (0.72, 0.52), (0.87, 0.73), (0.48, 0.84),
]

# Radius is a fraction of the shorter side; alpha is carrier visibility.
PROFILES = {
    "subtle": {"radius_frac": 0.0040, "alpha": 0.35},
    "balanced": {"radius_frac": 0.0060, "alpha": 0.55},
    "robust": {"radius_frac": 0.0080, "alpha": 0.75},
}

# Symmetric-ish colors: the carrier uses both luminance and chroma.
BIT_COLORS = {
    0: np.array([26.0, 58.0, 208.0], dtype=np.float32),
    1: np.array([229.0, 211.0, 47.0], dtype=np.float32),
}


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True)


def require_binary(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(f"Required binary not found: {name}")


def code_bits(label: str) -> list[int]:
    digest = hashlib.sha256(f"{SEED}|{label}".encode()).digest()
    bits: list[int] = []
    for byte in digest:
        for shift in range(7, -1, -1):
            bits.append((byte >> shift) & 1)
            if len(bits) == 12:
                return bits
    raise AssertionError("unreachable")


def background_image(width: int = WIDTH, height: int = HEIGHT, phase: int = 0) -> Image.Image:
    yy, xx = np.mgrid[0:height, 0:width]
    r = (52 + 110 * xx / max(1, width - 1) + 24 * np.sin((yy + phase * 5) / 83.0))
    g = (80 + 95 * yy / max(1, height - 1) + 18 * np.cos((xx + phase * 7) / 117.0))
    b = (150 + 55 * np.sin((xx + yy + phase * 9) / 137.0))
    arr = np.stack([r, g, b], axis=2)
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    image = Image.fromarray(arr, "RGB")
    draw = ImageDraw.Draw(image)
    # Textures and edges make the carrier work over non-uniform content.
    draw.rectangle((120, 680, 760, 1010), fill=(42, 103, 61))
    draw.ellipse((1110 + phase % 30, 170, 1580 + phase % 30, 640), fill=(188, 121, 72))
    draw.polygon([(820, 950), (980, 520), (1140, 950)], fill=(82, 64, 134))
    return image


def blend_disk(arr: np.ndarray, cx: int, cy: int, radius: int, target: np.ndarray, alpha: float) -> None:
    h, w, _ = arr.shape
    x0, x1 = max(0, cx - radius), min(w, cx + radius + 1)
    y0, y1 = max(0, cy - radius), min(h, cy + radius + 1)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    mask = ((xx - cx) ** 2 + (yy - cy) ** 2) <= radius ** 2
    patch = arr[y0:y1, x0:x1]
    patch[mask] = patch[mask] * (1.0 - alpha) + target * alpha


def embed_constellation(image: Image.Image, bits: list[int], profile: dict) -> Image.Image:
    arr = np.asarray(image.convert("RGB"), dtype=np.float32).copy()
    h, w, _ = arr.shape
    radius = max(3, int(round(min(w, h) * profile["radius_frac"])))
    alpha = float(profile["alpha"])
    for idx, ((fx, fy), bit) in enumerate(zip(POSITIONS, bits)):
        cx, cy = int(round(fx * (w - 1))), int(round(fy * (h - 1)))
        # Thin neutral halo acts as a visual/pilot geometry cue.
        blend_disk(arr, cx, cy, int(radius * 1.45), np.array([128.0, 128.0, 128.0]), alpha * 0.22)
        blend_disk(arr, cx, cy, radius, BIT_COLORS[bit], alpha)
        # Tiny high-contrast center improves survivability without relying on a single pixel.
        core = max(1, int(round(radius * 0.28)))
        core_target = np.array([18.0, 18.0, 18.0]) if bit == 0 else np.array([238.0, 238.0, 238.0])
        blend_disk(arr, cx, cy, core, core_target, min(0.95, alpha + 0.15))
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def sample_mean(arr: np.ndarray, cx: int, cy: int, radius: int) -> np.ndarray:
    h, w, _ = arr.shape
    x0, x1 = max(0, cx - radius), min(w, cx + radius + 1)
    y0, y1 = max(0, cy - radius), min(h, cy + radius + 1)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    mask = ((xx - cx) ** 2 + (yy - cy) ** 2) <= radius ** 2
    vals = arr[y0:y1, x0:x1][mask]
    if len(vals) == 0:
        return np.zeros(3, dtype=np.float32)
    return vals.mean(axis=0)


def decode_constellation(image: Image.Image, profile: dict) -> list[int]:
    arr = np.asarray(image.convert("RGB"), dtype=np.float32)
    h, w, _ = arr.shape
    radius = max(2, int(round(min(w, h) * profile["radius_frac"])))
    alpha = float(profile["alpha"])
    decoded: list[int] = []
    for fx, fy in POSITIONS:
        cx, cy = int(round(fx * (w - 1))), int(round(fy * (h - 1)))
        center = sample_mean(arr, cx, cy, max(1, int(radius * 0.72)))
        # Estimate local unmarked background from an annulus outside the carrier.
        outer = sample_mean(arr, cx, cy, max(2, int(radius * 2.25)))
        inner = sample_mean(arr, cx, cy, max(2, int(radius * 1.70)))
        # Difference of disk means approximates the local ring/background.
        bg = np.clip(2.4 * outer - 1.4 * inner, 0, 255)
        distances = []
        for bit in (0, 1):
            predicted = (1.0 - alpha) * bg + alpha * BIT_COLORS[bit]
            distances.append(float(np.linalg.norm(center - predicted)))
        decoded.append(0 if distances[0] <= distances[1] else 1)
    return decoded


def bit_errors(expected: list[int], actual: list[int]) -> int:
    return sum(1 for a, b in zip(expected, actual) if a != b) + abs(len(expected) - len(actual))


def photo_variants(source: Path, target_dir: Path) -> list[tuple[str, Path]]:
    target_dir.mkdir(parents=True, exist_ok=True)
    im = Image.open(source).convert("RGB")
    variants: list[tuple[str, Path]] = []

    for q in (95, 80, 60, 40, 25, 10):
        path = target_dir / f"jpeg_q{q}.jpg"
        im.save(path, "JPEG", quality=q, subsampling=2, optimize=True)
        variants.append((f"jpeg_q{q}", path))

    for scale, q in ((0.75, 60), (0.50, 40), (0.25, 25)):
        resized = im.resize((round(im.width * scale), round(im.height * scale)), Image.Resampling.LANCZOS)
        path = target_dir / f"scale_{int(scale*100)}_q{q}.jpg"
        resized.save(path, "JPEG", quality=q, subsampling=2, optimize=True)
        variants.append((f"scale_{int(scale*100)}_q{q}", path))

    repeat = target_dir / "repeat_q40_3x.jpg"
    current = im
    for i in range(3):
        temp = target_dir / f"_tmp_repeat_{i}.jpg"
        current.save(temp, "JPEG", quality=40, subsampling=2)
        current = Image.open(temp).convert("RGB")
    current.save(repeat, "JPEG", quality=40, subsampling=2)
    variants.append(("repeat_q40_3x", repeat))
    return variants


def make_video_source(frame_dir: Path, out_path: Path, profile_name: str) -> None:
    frame_dir.mkdir(parents=True, exist_ok=True)
    profile = PROFILES[profile_name]
    for idx in range(FRAMES):
        base = background_image(phase=idx)
        marked = embed_constellation(base, code_bits(f"frame:{idx}"), profile)
        marked.save(frame_dir / f"frame_{idx:04d}.png")
    run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-framerate", str(FPS), "-i", str(frame_dir / "frame_%04d.png"),
        "-c:v", "libx264", "-crf", "0", "-preset", "ultrafast",
        "-pix_fmt", "yuv444p", str(out_path),
    ])


def video_variants(source: Path, target_dir: Path) -> list[tuple[str, Path]]:
    target_dir.mkdir(parents=True, exist_ok=True)
    variants: list[tuple[str, Path]] = []
    for crf in (18, 23, 28, 35, 40, 45):
        path = target_dir / f"h264_crf{crf}.mp4"
        run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(source), "-an", "-c:v", "libx264", "-preset", "veryfast",
            "-crf", str(crf), "-pix_fmt", "yuv420p", "-r", str(FPS), str(path),
        ])
        variants.append((f"h264_crf{crf}", path))

    for height, crf in ((720, 35), (480, 40)):
        path = target_dir / f"scale_{height}p_crf{crf}.mp4"
        run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(source), "-an", "-vf", f"scale=-2:{height}",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", str(crf),
            "-pix_fmt", "yuv420p", "-r", str(FPS), str(path),
        ])
        variants.append((f"scale_{height}p_crf{crf}", path))

    # Repeated lossy transcode simulates forwarding/re-upload chains.
    temp1 = target_dir / "_repeat1.mp4"
    temp2 = target_dir / "_repeat2.mp4"
    final = target_dir / "repeat_crf35_3x.mp4"
    prev = source
    for dst in (temp1, temp2, final):
        run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(prev), "-an", "-c:v", "libx264", "-preset", "veryfast",
            "-crf", "35", "-pix_fmt", "yuv420p", "-r", str(FPS), str(dst),
        ])
        prev = dst
    variants.append(("repeat_crf35_3x", final))
    return variants


def extract_video_frames(video: Path, frame_dir: Path) -> list[Path]:
    if frame_dir.exists():
        shutil.rmtree(frame_dir)
    frame_dir.mkdir(parents=True, exist_ok=True)
    run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(video), "-vsync", "0", str(frame_dir / "frame_%04d.png"),
    ])
    return sorted(frame_dir.glob("frame_*.png"))


def evaluate_photo(profile_name: str, marked_path: Path) -> list[dict]:
    profile = PROFILES[profile_name]
    expected = code_bits("photo")
    rows = []
    for variant, path in photo_variants(marked_path, OUT / profile_name / "photo_variants"):
        actual = decode_constellation(Image.open(path), profile)
        errors = bit_errors(expected, actual)
        rows.append({
            "profile": profile_name, "media": "photo", "variant": variant,
            "units": 1, "bits_tested": 12, "bit_errors": errors,
            "unit_errors": 1 if errors else 0,
            "full_recovery": errors == 0,
            "bit_error_rate": errors / 12.0,
        })
    return rows


def evaluate_video(profile_name: str, source: Path) -> list[dict]:
    profile = PROFILES[profile_name]
    rows = []
    for variant, path in video_variants(source, OUT / profile_name / "video_variants"):
        frames = extract_video_frames(path, OUT / profile_name / "decoded" / variant)
        tested = min(len(frames), FRAMES)
        bit_err = 0
        frame_err = 0
        for idx in range(tested):
            expected = code_bits(f"frame:{idx}")
            actual = decode_constellation(Image.open(frames[idx]), profile)
            errors = bit_errors(expected, actual)
            bit_err += errors
            frame_err += 1 if errors else 0
        # Missing frames are a hard failure for this v0 fixed-FPS experiment.
        missing = max(0, FRAMES - tested)
        bit_err += missing * 12
        frame_err += missing
        total_bits = FRAMES * 12
        rows.append({
            "profile": profile_name, "media": "video", "variant": variant,
            "units": FRAMES, "bits_tested": total_bits, "bit_errors": bit_err,
            "unit_errors": frame_err,
            "full_recovery": bit_err == 0 and tested == FRAMES,
            "bit_error_rate": bit_err / total_bits,
        })
    return rows


def main() -> int:
    require_binary("ffmpeg")
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    all_rows: list[dict] = []
    for profile_name, profile in PROFILES.items():
        pdir = OUT / profile_name
        pdir.mkdir(parents=True, exist_ok=True)

        photo_bits = code_bits("photo")
        marked_photo = embed_constellation(background_image(), photo_bits, profile)
        photo_path = pdir / "photo_marked.png"
        marked_photo.save(photo_path)
        all_rows.extend(evaluate_photo(profile_name, photo_path))

        source_video = pdir / "video_marked_lossless.mp4"
        make_video_source(pdir / "source_frames", source_video, profile_name)
        all_rows.extend(evaluate_video(profile_name, source_video))

    with (OUT / "results.json").open("w", encoding="utf-8") as f:
        json.dump(all_rows, f, indent=2)

    fields = [
        "profile", "media", "variant", "units", "bits_tested",
        "bit_errors", "unit_errors", "full_recovery", "bit_error_rate",
    ]
    with (OUT / "results.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(all_rows)

    summary = {}
    for profile_name in PROFILES:
        rows = [r for r in all_rows if r["profile"] == profile_name]
        summary[profile_name] = {
            "cases": len(rows),
            "full_recovery_cases": sum(1 for r in rows if r["full_recovery"]),
            "max_bit_error_rate": max((r["bit_error_rate"] for r in rows), default=0.0),
            "photo_full": all(r["full_recovery"] for r in rows if r["media"] == "photo"),
            "video_full": all(r["full_recovery"] for r in rows if r["media"] == "video"),
        }
    with (OUT / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    print("\n=== HCV FILM V0 DETAILED RESULTS ===")
    for row in all_rows:
        print(json.dumps(row, sort_keys=True))
    print("\n=== HCV FILM V0 SUMMARY ===")
    print(json.dumps(summary, indent=2))
    print(f"Artifacts: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
