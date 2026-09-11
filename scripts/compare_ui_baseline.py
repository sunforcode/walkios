#!/usr/bin/env python3
"""Compare candidate iOS screenshots with the approved iOS visual baseline."""

from __future__ import annotations

import argparse
import json
import math
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, UnidentifiedImageError


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MASTER_DIR = PROJECT_ROOT / "WalkBaselineGoldens/approved/iphone-17-ios-26.5"
DEFAULT_IOS_DIR = PROJECT_ROOT / "build/ui-baseline/candidate"
DEFAULT_REPORT_DIR = PROJECT_ROOT / "build/ui-baseline/report"

CANVAS = (390, 844)
CHANNEL_TOLERANCE = 12
DEFAULT_MAX_DIFF_RATIO = 0.001


class BaselineComparisonError(RuntimeError):
    pass


def png_files(directory: Path, label: str) -> dict[str, Path]:
    if not directory.is_dir():
        raise BaselineComparisonError(f"{label} directory does not exist: {directory}")
    files = {path.name: path for path in sorted(directory.glob("*.png")) if path.is_file()}
    if not files:
        raise BaselineComparisonError(f"{label} directory contains no PNG files: {directory}")
    return files


def parse_mask(value: str) -> list[tuple[int, int]]:
    if not value:
        return []

    bands: list[tuple[int, int]] = []
    try:
        for raw_band in value.split(","):
            parts = raw_band.strip().split(":")
            if len(parts) != 2:
                raise ValueError
            start, end = (int(part) for part in parts)
            if start < 0 or end > CANVAS[1] or start >= end:
                raise ValueError
            bands.append((start, end))
    except ValueError as error:
        raise BaselineComparisonError(
            f"Invalid mask {value!r}; expected comma-separated y ranges within "
            f"0:{CANVAS[1]}, for example '0:20,824:844'"
        ) from error
    return bands


def validate_threshold(value: float) -> float:
    if not math.isfinite(value) or not 0 <= value <= 1:
        raise BaselineComparisonError("--max-diff-ratio must be between 0 and 1")
    return value


def ensure_report_outside_master(report_dir: Path, master_dir: Path) -> None:
    resolved_report = report_dir.resolve()
    resolved_master = master_dir.resolve()
    if resolved_report == resolved_master or resolved_master in resolved_report.parents:
        raise BaselineComparisonError("Report directory must not be inside the approved master directory")


def load_rgb(path: Path) -> np.ndarray:
    try:
        with Image.open(path) as image:
            if image.size != CANVAS:
                raise BaselineComparisonError(
                    f"{path.name}: expected {CANVAS[0]}x{CANVAS[1]}, "
                    f"got {image.size[0]}x{image.size[1]}"
                )
            return np.asarray(image.convert("RGB"), dtype=np.int16)
    except (OSError, UnidentifiedImageError) as error:
        raise BaselineComparisonError(f"Unable to read PNG {path}: {error}") from error


def diff_mask(master: np.ndarray, candidate: np.ndarray) -> np.ndarray:
    delta = np.abs(master - candidate)
    return delta.max(axis=2) > CHANNEL_TOLERANCE


def apply_mask(mask: np.ndarray, bands: list[tuple[int, int]]) -> np.ndarray:
    scored = mask.copy()
    for start, end in bands:
        scored[start:end, :] = False
    return scored


def band_hotspots(mask: np.ndarray, band_height: int = 40, limit: int = 5) -> list[dict[str, object]]:
    height, _ = mask.shape
    bands: list[dict[str, object]] = []
    for start in range(0, height, band_height):
        end = min(start + band_height, height)
        ratio = float(mask[start:end].mean())
        if ratio > 0:
            bands.append({"y": start, "y_end": end, "diff_ratio": ratio})
    bands.sort(key=lambda band: float(band["diff_ratio"]), reverse=True)
    return bands[:limit]


def render_artifacts(
    master: np.ndarray,
    candidate: np.ndarray,
    scored_mask: np.ndarray,
    output_stem: Path,
) -> None:
    height, width = scored_mask.shape
    heat = np.zeros((height, width, 3), dtype=np.uint8)
    heat[..., 0] = np.where(scored_mask, 255, master[..., 0] // 3)
    heat[..., 1] = np.where(scored_mask, 40, master[..., 1] // 3)
    heat[..., 2] = np.where(scored_mask, 40, master[..., 2] // 3)
    Image.fromarray(heat).save(output_stem.with_name(f"{output_stem.name}-diff.png"))

    side_by_side = Image.new("RGB", (width * 2 + 12, height), (24, 24, 24))
    side_by_side.paste(Image.fromarray(master.astype(np.uint8)), (0, 0))
    side_by_side.paste(Image.fromarray(candidate.astype(np.uint8)), (width + 12, 0))
    side_by_side.save(output_stem.with_name(f"{output_stem.name}-side.png"))


def validate_matching_file_sets(
    master_files: dict[str, Path],
    candidate_files: dict[str, Path],
) -> list[str]:
    master_names = set(master_files)
    candidate_names = set(candidate_files)
    candidate_only = sorted(candidate_names - master_names)
    master_only = sorted(master_names - candidate_names)
    if candidate_only or master_only:
        messages = []
        if candidate_only:
            messages.append("Candidate files without approved master: " + ", ".join(candidate_only))
        if master_only:
            messages.append("Approved master files missing from candidate: " + ", ".join(master_only))
        raise BaselineComparisonError("; ".join(messages))
    return sorted(master_names)


def write_report(
    report_dir: Path,
    master_dir: Path,
    candidate_dir: Path,
    threshold: float,
    mask_bands: list[tuple[int, int]],
    entries: list[dict[str, object]],
) -> None:
    report_dir.mkdir(parents=True, exist_ok=True)
    failed = [entry for entry in entries if entry["status"] == "failed"]
    report = {
        "generatedAt": datetime.now().isoformat(timespec="seconds"),
        "masterDirectory": str(master_dir),
        "candidateDirectory": str(candidate_dir),
        "canvas": list(CANVAS),
        "channelTolerance": CHANNEL_TOLERANCE,
        "maxDiffRatio": threshold,
        "maskedBands": [list(band) for band in mask_bands],
        "result": "failed" if failed else "passed",
        "compared": len(entries),
        "failed": len(failed),
        "scenarios": entries,
    }
    (report_dir / "report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# Walk iOS 视觉基线比较报告",
        "",
        f"- 结果：{'FAIL' if failed else 'PASS'}",
        f"- 生成时间：{report['generatedAt']}",
        f"- 画布：{CANVAS[0]} × {CANVAS[1]}",
        f"- 通道容差：{CHANNEL_TOLERANCE}/255",
        f"- 最大差异比例：{threshold:.6%}",
        f"- 屏蔽带：{mask_bands if mask_bands else '无'}",
        f"- 已对比：{len(entries)}；失败：{len(failed)}",
        "",
        "| 场景 | 结果 | 差异像素占比 | 最热区域 (y) |",
        "|---|---|---:|---|",
    ]
    for entry in entries:
        hotspots = entry["hotspots"]
        hottest = hotspots[0]["y"] if hotspots else "—"
        lines.append(
            f"| {entry['scenario']} | {str(entry['status']).upper()} | "
            f"{float(entry['diff_ratio']):.6%} | {hottest} |"
        )
    (report_dir / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def compare(args: argparse.Namespace) -> int:
    threshold = validate_threshold(args.max_diff_ratio)
    mask_bands = parse_mask(args.mask)
    ensure_report_outside_master(args.report_dir, args.master_dir)

    master_files = png_files(args.master_dir, "Master")
    candidate_files = png_files(args.ios_dir, "Candidate")
    names = validate_matching_file_sets(master_files, candidate_files)

    args.report_dir.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, object]] = []
    for name in names:
        master = load_rgb(master_files[name])
        candidate = load_rgb(candidate_files[name])
        scored_mask = apply_mask(diff_mask(master, candidate), mask_bands)
        ratio = float(scored_mask.mean())
        status = "failed" if ratio > threshold else "passed"
        stem = args.report_dir / Path(name).stem
        render_artifacts(master, candidate, scored_mask, stem)
        entries.append(
            {
                "scenario": Path(name).stem,
                "status": status,
                "diff_ratio": ratio,
                "hotspots": band_hotspots(scored_mask),
                "master": str(master_files[name]),
                "candidate": str(candidate_files[name]),
                "artifacts": {
                    "diff": f"{stem.name}-diff.png",
                    "side_by_side": f"{stem.name}-side.png",
                },
            }
        )

    write_report(
        args.report_dir,
        args.master_dir,
        args.ios_dir,
        threshold,
        mask_bands,
        entries,
    )

    failures = [entry for entry in entries if entry["status"] == "failed"]
    print(f"Report: {args.report_dir / 'report.md'}")
    for entry in entries:
        print(f"  {entry['scenario']}: {float(entry['diff_ratio']):.6%} {str(entry['status']).upper()}")
    if failures:
        scenarios = ", ".join(str(entry["scenario"]) for entry in failures)
        raise BaselineComparisonError(
            f"{len(failures)} scenario(s) exceeds threshold {threshold:.6%}: {scenarios}"
        )
    print(f"PASS: {len(entries)} screenshot(s) are at or below {threshold:.6%}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master-dir", type=Path, default=DEFAULT_MASTER_DIR)
    parser.add_argument("--ios-dir", type=Path, default=DEFAULT_IOS_DIR)
    parser.add_argument("--report-dir", type=Path, default=DEFAULT_REPORT_DIR)
    parser.add_argument("--max-diff-ratio", type=float, default=DEFAULT_MAX_DIFF_RATIO)
    parser.add_argument(
        "--mask",
        default="",
        help="Optional comma-separated y ranges, for example '0:20,824:844'; no mask by default",
    )
    return parser


def main() -> int:
    try:
        return compare(build_parser().parse_args())
    except BaselineComparisonError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
