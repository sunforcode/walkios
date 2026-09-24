#!/usr/bin/env python3
"""Exercise the W0 entrypoint without running XcodeGen or Xcode."""

from __future__ import annotations

import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_debugswift_probe as probe


class DebugSwiftProbeEntryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.output = Path(self.temporary_directory.name).resolve() / "probe-output"

    def invoke(self, *arguments: str) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return probe.main([*arguments, "--output", str(self.output)])

    def test_invalid_requests_fail_before_any_mutation_or_subprocess(self) -> None:
        invalid_requests = [
            [],
            ["--mode", "debug", "--action", "build", "--configuration", "Release"],
            ["--mode", "release", "--action", "build", "--configuration", "Debug"],
            ["--mode", "debug", "--action", "archive"],
            ["--mode", "debug", "--action", "test"],
            ["--mode", "release", "--action", "test", "--destination", " "],
            ["--mode", "release", "--action", "archive", "--destination", "generic/platform=iOS Simulator"],
            ["--mode", "real", "--action", "build"],
            ["--mode", "release", "--action", "clean"],
            ["--mode", "release", "--action", "build", "--", "-alltargets"],
            ["--mode", "release", "--action", "build", "CODE_SIGNING_ALLOWED=YES"],
            ["--mode", "debug", "--action", "build", "--config", "Debug"],
        ]
        for arguments in invalid_requests:
            with self.subTest(arguments=arguments):
                with (
                    mock.patch.object(probe.subprocess, "run") as run,
                    mock.patch.object(probe.Path, "mkdir") as mkdir,
                    mock.patch.object(probe.shutil, "copyfile") as copyfile,
                    mock.patch.object(probe.Path, "open") as open_file,
                    contextlib.redirect_stderr(io.StringIO()),
                ):
                    with self.assertRaises(SystemExit) as raised:
                        self.invoke(*arguments)
                    self.assertEqual(raised.exception.code, 2)
                    run.assert_not_called()
                    mkdir.assert_not_called()
                    copyfile.assert_not_called()
                    open_file.assert_not_called()
                self.assertFalse(self.output.exists())

    def test_release_build_never_prepares_debug_project_or_sdk_cache(self) -> None:
        with (
            mock.patch.object(probe.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run,
            mock.patch.object(probe.shutil, "copyfile") as copyfile,
        ):
            self.assertEqual(self.invoke("--mode", "release", "--action", "build"), 0)

        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(len(commands), 2)
        self.assertEqual(commands[0][0:2], ["xcodegen", "generate"])
        self.assertIn(str(probe.FIXTURE_ROOT / "release.yml"), commands[0])
        self.assertIn(str(self.output / "Release"), commands[0])
        self.assertEqual(commands[1][0:2], ["xcodebuild", "build"])
        self.assertIn(str(self.output / "Release" / "WalkIsolationRelease.xcodeproj"), commands[1])
        self.assertIn(str(self.output / "Release" / "DerivedData"), commands[1])
        self.assertIn("CODE_SIGNING_ALLOWED=NO", commands[1])
        self.assertEqual(commands[1][commands[1].index("-configuration") + 1], "Release")
        for command in commands:
            self.assertNotIn("-resolvePackageDependencies", command)
            self.assertNotIn("-clonedSourcePackagesDirPath", command)
            self.assertFalse(any("SourcePackages" in argument or "WalkIsolationDebug" in argument for argument in command))
        copyfile.assert_not_called()
        self.assertFalse((self.output / "Debug").exists())
        self.assertFalse((self.output / "SourcePackages").exists())

    def test_debug_test_copies_lock_before_resolving_and_uses_adhoc_signing(self) -> None:
        destination = "platform=iOS Simulator,id=SIMULATOR-ID"
        copied_lock = self.output / "Debug" / "WalkIsolationDebug.xcodeproj" / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"

        def run_without_building(command: list[str], **kwargs: object) -> subprocess.CompletedProcess:
            if "-resolvePackageDependencies" in command:
                self.assertEqual(copied_lock.read_bytes(), (probe.FIXTURE_ROOT / "Package.resolved").read_bytes())
            return subprocess.CompletedProcess(command, 0)

        with mock.patch.object(probe.subprocess, "run", side_effect=run_without_building) as run:
            self.assertEqual(self.invoke("--mode", "debug", "--action", "test", "--destination", destination), 0)

        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(len(commands), 3)
        self.assertIn(str(probe.FIXTURE_ROOT / "debug.yml"), commands[0])
        self.assertIn("-resolvePackageDependencies", commands[1])
        for command in commands[1:]:
            self.assertIn("-onlyUsePackageVersionsFromResolvedFile", command)
            self.assertIn(str(self.output / "SourcePackages"), command)
        test_command = commands[2]
        self.assertEqual(test_command[0:2], ["xcodebuild", "test"])
        self.assertIn(destination, test_command)
        self.assertIn("CODE_SIGNING_ALLOWED=YES", test_command)
        self.assertIn("CODE_SIGN_IDENTITY=-", test_command)
        self.assertIn("-disableAutomaticPackageResolution", test_command)

    def test_release_archive_is_unsigned_and_always_uses_generic_ios(self) -> None:
        with mock.patch.object(probe.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(self.invoke("--mode", "release", "--action", "archive"), 0)
        commands = [call.args[0] for call in run.call_args_list]
        archive_command = commands[-1]
        self.assertEqual(archive_command[0:2], ["xcodebuild", "archive"])
        self.assertEqual(archive_command[archive_command.index("-destination") + 1], "generic/platform=iOS")
        self.assertIn("CODE_SIGNING_ALLOWED=NO", archive_command)
        self.assertIn("-archivePath", archive_command)
        self.assertFalse(any("SourcePackages" in argument or "WalkIsolationDebug" in argument for command in commands for argument in command))

    def test_debug_build_is_unsigned_even_with_explicit_matching_configuration(self) -> None:
        with mock.patch.object(probe.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(self.invoke("--mode", "debug", "--action", "build", "--configuration", "Debug"), 0)
        command = run.call_args.args[0]
        self.assertEqual(command[0:2], ["xcodebuild", "build"])
        self.assertIn("CODE_SIGNING_ALLOWED=NO", command)
        self.assertEqual(command[command.index("-configuration") + 1], "Debug")

    def test_release_test_uses_adhoc_signing_without_preparing_sdk(self) -> None:
        destination = "platform=iOS Simulator,id=SIMULATOR-ID"
        with (
            mock.patch.object(probe.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run,
            mock.patch.object(probe.shutil, "copyfile") as copyfile,
        ):
            self.assertEqual(self.invoke("--mode", "release", "--action", "test", "--destination", destination), 0)
        self.assertEqual(run.call_count, 2)
        command = run.call_args.args[0]
        self.assertEqual(command[0:2], ["xcodebuild", "test"])
        self.assertIn("CODE_SIGNING_ALLOWED=YES", command)
        self.assertIn("CODE_SIGN_IDENTITY=-", command)
        self.assertNotIn("-clonedSourcePackagesDirPath", command)
        copyfile.assert_not_called()
        self.assertFalse((self.output / "Debug").exists())
        self.assertFalse((self.output / "SourcePackages").exists())

    def test_resolve_failure_stops_before_debug_build(self) -> None:
        with (
            mock.patch.object(probe.subprocess, "run", side_effect=[
                subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 9),
            ]) as run,
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(self.invoke("--mode", "debug", "--action", "build"), 9)
        self.assertEqual(run.call_count, 2)
        self.assertIn("-resolvePackageDependencies", run.call_args.args[0])

    def test_generation_failure_stops_before_lock_copy_or_xcodebuild(self) -> None:
        with (
            mock.patch.object(probe.subprocess, "run", return_value=subprocess.CompletedProcess([], 7)) as run,
            mock.patch.object(probe.shutil, "copyfile") as copyfile,
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(self.invoke("--mode", "debug", "--action", "build"), 7)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][0], "xcodegen")
        copyfile.assert_not_called()

    def test_missing_debug_lock_fails_before_any_mutation_or_subprocess(self) -> None:
        with (
            mock.patch.object(probe.Path, "is_file", side_effect=lambda path: path.name != "Package.resolved", autospec=True),
            mock.patch.object(probe.subprocess, "run") as run,
            mock.patch.object(probe.Path, "mkdir") as mkdir,
            contextlib.redirect_stderr(io.StringIO()),
        ):
            with self.assertRaises(SystemExit) as raised:
                self.invoke("--mode", "debug", "--action", "build")
        self.assertEqual(raised.exception.code, 2)
        run.assert_not_called()
        mkdir.assert_not_called()
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
