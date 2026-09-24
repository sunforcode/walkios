#!/usr/bin/env python3
"""Restricted build entrypoint for the W0 DebugSwift isolation fixture.

This validates supported invocations before creating files or launching tools.
It cannot prevent someone from bypassing it and invoking xcodebuild directly.
Build output is separated by mode; logs and result bundles live under Runs/.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
FIXTURE_ROOT = REPO_ROOT / "scripts" / "fixtures" / "debugswift-isolation"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--mode", required=True, choices=("debug", "release"))
    parser.add_argument("--action", required=True, choices=("build", "test", "archive"))
    parser.add_argument("--configuration", help="Must match the mode: Debug or Release.")
    parser.add_argument("--output", type=Path, default=REPO_ROOT / "build" / "debugswift-w0")
    parser.add_argument("--destination", help="Required for test; archive only accepts generic/platform=iOS.")
    arguments = parser.parse_args(argv)

    # Keep all validation ahead of mkdir, file writes, and subprocess execution.
    configuration = arguments.mode.capitalize()
    if arguments.configuration is not None and arguments.configuration != configuration:
        parser.error(f"{arguments.mode} mode only permits --configuration {configuration}")
    if arguments.mode == "debug" and arguments.action == "archive":
        parser.error("debug mode cannot archive; use --mode release")
    destination = arguments.destination.strip() if arguments.destination is not None else None
    if arguments.action == "test" and not destination:
        parser.error("test requires a nonempty --destination")
    if arguments.action == "archive":
        if destination is not None and destination != "generic/platform=iOS":
            parser.error("release archive requires generic/platform=iOS")
        destination = "generic/platform=iOS"
    else:
        destination = destination or "generic/platform=iOS Simulator"

    spec = FIXTURE_ROOT / f"{arguments.mode}.yml"
    if not spec.is_file():
        parser.error(f"fixture spec is missing: {spec}")
    resolved_source = FIXTURE_ROOT / "Package.resolved"
    if arguments.mode == "debug" and not resolved_source.is_file():
        parser.error(f"the checked-in Debug dependency lock is missing: {resolved_source}")

    output = arguments.output.expanduser().resolve()
    project_directory = output / configuration
    scheme = f"WalkIsolation{configuration}"
    project = project_directory / f"{scheme}.xcodeproj"
    derived_data = project_directory / "DerivedData"
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    run_directory = output / "Runs" / f"{arguments.mode}-{arguments.action}-{run_id}"

    def run_step(name: str, command: list[str]) -> int:
        log_path = run_directory / f"{name}.log"
        print(f"{name}: {log_path}", flush=True)
        with log_path.open("w", encoding="utf-8") as log:
            log.write(f"$ {shlex.join(command)}\n\n")
            log.flush()
            result = subprocess.run(
                command,
                cwd=REPO_ROOT,
                stdout=log,
                stderr=subprocess.STDOUT,
                check=False,
            )
        if result.returncode:
            print(f"{name} failed ({result.returncode}); see {log_path}", file=sys.stderr)
        return result.returncode

    try:
        project_directory.mkdir(parents=True, exist_ok=True)
        run_directory.mkdir(parents=True, exist_ok=False)
        status = run_step("generate", [
            "xcodegen", "generate", "--spec", str(spec),
            "--project-root", str(FIXTURE_ROOT), "--project", str(project_directory),
        ])
        if status:
            return status

        common = [
            "-project", str(project), "-scheme", scheme,
            "-configuration", configuration, "-derivedDataPath", str(derived_data),
        ]
        package_arguments: list[str] = []
        if arguments.mode == "debug":
            resolved_target = project / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"
            resolved_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(resolved_source, resolved_target)
            package_arguments = [
                "-clonedSourcePackagesDirPath", str(output / "SourcePackages"),
                "-onlyUsePackageVersionsFromResolvedFile", "-skipPackageUpdates",
            ]
            status = run_step("resolve", [
                "xcodebuild", "-resolvePackageDependencies", *common, *package_arguments,
            ])
            if status:
                return status

        command = [
            "xcodebuild", arguments.action, *common,
            "-destination", destination, "-disableAutomaticPackageResolution",
            *package_arguments,
        ]
        if arguments.action == "test":
            command.extend([
                "-parallel-testing-enabled", "NO",
                "-resultBundlePath", str(run_directory / "Tests.xcresult"),
                "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-",
            ])
        else:
            command.append("CODE_SIGNING_ALLOWED=NO")
        if arguments.action == "archive":
            command.extend(["-archivePath", str(run_directory / f"{scheme}.xcarchive")])
        return run_step(arguments.action, command)
    except OSError as error:
        print(f"probe entrypoint failed: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print(f"probe interrupted; logs: {run_directory}", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
