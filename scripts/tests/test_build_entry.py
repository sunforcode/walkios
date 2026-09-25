#!/usr/bin/env python3
"""Exercise the Walk build entrypoint without running XcodeGen or Xcode.

依据 specs/README.md R-DEBUG：受支持入口在调用工具前校验模式、configuration 与 action；
开发入口拒绝 Release 与 archive，Release/archive 只使用生产依赖图。
"""

from __future__ import annotations

import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build as entry


class BuildEntryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.output = Path(self.temporary_directory.name).resolve() / "out"

    def invoke(self, *arguments: str) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return entry.main([*arguments, "--output", str(self.output)])

    def test_invalid_requests_fail_before_any_mutation_or_subprocess(self) -> None:
        invalid_requests = [
            [],
            ["--mode", "debug", "--action", "archive"],
            ["--mode", "debug", "--action", "build", "--configuration", "Release"],
            ["--mode", "release", "--action", "build", "--configuration", "Debug"],
            ["--mode", "release", "--action", "test", "--destination", "platform=iOS Simulator,name=X"],
            ["--mode", "debug", "--action", "test"],
            ["--mode", "debug", "--action", "test", "--destination", " "],
            ["--mode", "release", "--action", "archive", "--destination", "generic/platform=iOS Simulator"],
            ["--mode", "release", "--action", "clean"],
            ["--mode", "staging", "--action", "build"],
            ["--mode", "release", "--action", "build", "CODE_SIGNING_ALLOWED=YES"],
            ["--mode", "debug", "--action", "test", "--destination", "x", "--scheme", "WalkRelease"],
        ]
        for arguments in invalid_requests:
            with self.subTest(arguments=arguments):
                with (
                    mock.patch.object(entry.subprocess, "run") as run,
                    mock.patch.object(entry.Path, "mkdir") as mkdir,
                    mock.patch.object(entry.Path, "open") as open_file,
                    contextlib.redirect_stderr(io.StringIO()),
                ):
                    with self.assertRaises(SystemExit) as raised:
                        self.invoke(*arguments)
                    self.assertEqual(raised.exception.code, 2)
                    run.assert_not_called()
                    mkdir.assert_not_called()
                    open_file.assert_not_called()

    def test_release_uses_production_spec_and_never_the_dev_project(self) -> None:
        plan = entry.plan(["--mode", "release", "--action", "archive", "--output", str(self.output)])
        self.assertEqual(plan.spec.name, "project-release.yml")
        self.assertEqual(plan.scheme, "WalkRelease")
        self.assertEqual(plan.configuration, "Release")
        self.assertEqual(plan.destination, "generic/platform=iOS")
        self.assertEqual(plan.project.name, "WalkRelease.xcodeproj")
        self.assertNotEqual(plan.project.resolve(), (entry.REPO_ROOT / "Walk.xcodeproj").resolve())
        self.assertTrue(plan.run_isolation_check)

    def test_debug_uses_committed_dev_project(self) -> None:
        plan = entry.plan([
            "--mode", "debug", "--action", "test",
            "--destination", "platform=iOS Simulator,name=iPhone 17 Pro",
            "--output", str(self.output),
        ])
        self.assertEqual(plan.spec.name, "project.yml")
        self.assertEqual(plan.project.resolve(), (entry.REPO_ROOT / "Walk.xcodeproj").resolve())
        self.assertEqual(plan.configuration, "Debug")
        self.assertEqual(plan.scheme, "Walk")

    def test_debug_scheme_allow_list(self) -> None:
        for scheme in ("Walk", "WalkBaseline", "WalkComponents", "WalkDebugTools"):
            with self.subTest(scheme=scheme):
                plan = entry.plan([
                    "--mode", "debug", "--action", "test", "--scheme", scheme,
                    "--destination", "platform=iOS Simulator,name=X", "--output", str(self.output),
                ])
                self.assertEqual(plan.scheme, scheme)

    def test_release_build_defaults_to_simulator_and_checks_isolation(self) -> None:
        plan = entry.plan(["--mode", "release", "--action", "build", "--output", str(self.output)])
        self.assertEqual(plan.destination, "generic/platform=iOS Simulator")
        self.assertTrue(plan.run_isolation_check)


if __name__ == "__main__":
    unittest.main()
