#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


SCRIPT = Path(__file__).resolve().parents[1] / "compare_ui_baseline.py"
CANVAS = (390, 844)


class CompareUIBaselineCLITests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.master_dir = self.root / "master"
        self.candidate_dir = self.root / "candidate"
        self.report_dir = self.root / "report"

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def run_compare(self, *extra_arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--master-dir",
                str(self.master_dir),
                "--ios-dir",
                str(self.candidate_dir),
                "--report-dir",
                str(self.report_dir),
                *extra_arguments,
            ],
            check=False,
            capture_output=True,
            text=True,
        )

    @staticmethod
    def write_image(path: Path, color: tuple[int, int, int] = (0, 0, 0), size=CANVAS) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGB", size, color).save(path)

    def write_matching_pair(self, name: str = "scenario.png") -> None:
        self.write_image(self.master_dir / name)
        self.write_image(self.candidate_dir / name)

    def test_missing_master_directory_fails(self) -> None:
        self.write_image(self.candidate_dir / "scenario.png")

        result = self.run_compare()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Master directory does not exist", result.stderr)

    def test_missing_candidate_directory_fails(self) -> None:
        self.write_image(self.master_dir / "scenario.png")

        result = self.run_compare()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Candidate directory does not exist", result.stderr)

    def test_candidate_file_without_master_fails(self) -> None:
        self.write_image(self.master_dir / "approved.png")
        self.write_image(self.candidate_dir / "candidate-only.png")

        result = self.run_compare()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("candidate-only.png", result.stderr)

    def test_master_extra_file_fails(self) -> None:
        self.write_matching_pair()
        self.write_image(self.master_dir / "master-only.png")

        result = self.run_compare()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("master-only.png", result.stderr)

    def test_wrong_canvas_fails(self) -> None:
        self.write_image(self.master_dir / "scenario.png")
        self.write_image(self.candidate_dir / "scenario.png", size=(389, 844))

        result = self.run_compare()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected 390x844", result.stderr)

    def test_invalid_mask_fails(self) -> None:
        self.write_matching_pair()

        result = self.run_compare("--mask", "100:20")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid mask", result.stderr)

    def test_above_threshold_fails(self) -> None:
        self.write_matching_pair()
        candidate_path = self.candidate_dir / "scenario.png"
        with Image.open(candidate_path) as image:
            changed = image.copy()
        changed.putpixel((0, 0), (255, 255, 255))
        changed.save(candidate_path)

        result = self.run_compare("--max-diff-ratio", "0")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exceeds threshold", result.stderr)
        self.assertTrue((self.report_dir / "report.json").is_file())
        self.assertTrue((self.report_dir / "report.md").is_file())
        self.assertTrue((self.report_dir / "scenario-diff.png").is_file())

    def test_at_or_below_threshold_passes(self) -> None:
        self.write_matching_pair()
        candidate_path = self.candidate_dir / "scenario.png"
        with Image.open(candidate_path) as image:
            changed = image.copy()
        changed.putpixel((0, 0), (255, 255, 255))
        changed.save(candidate_path)
        exact_ratio = 1 / (CANVAS[0] * CANVAS[1])

        result = self.run_compare("--max-diff-ratio", repr(exact_ratio))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS", result.stdout)

    def test_master_bytes_remain_unchanged(self) -> None:
        self.write_matching_pair()
        master_path = self.master_dir / "scenario.png"
        before = master_path.read_bytes()

        result = self.run_compare("--max-diff-ratio", "0")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(master_path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
