#!/usr/bin/env python3
"""Walk 受支持的构建入口。

依据 specs/README.md R-DEBUG：
- 开发依赖图（project.yml → 仓内 Walk.xcodeproj）只有 Debug 配置，含 WalkDebugTools → DebugSwift；
  本入口拒绝对它执行 Release 或 archive。
- 生产依赖图（project-release.yml）只有 Release 配置，不声明调试依赖；每次在 build/ 下重新生成，
  构建后自动运行 scripts/check_debugswift_isolation.py 做产物隔离检查，检查失败即整体失败。

所有参数校验发生在创建目录、写文件或启动任何工具之前。本入口不接受任意 xcodebuild 参数透传。
它不能阻止有人绕过本入口直接调用 xcodebuild；发布产物以本入口的隔离检查报告为准。
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
DEV_SCHEMES = ("Walk", "WalkBaseline", "WalkComponents", "WalkDebugTools", "WalkDataModeE2E", "WalkKeyFlows")
RESOLVED_FILE = Path("project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
RELEASE_PROJECT = "WalkRelease.xcodeproj"


@dataclass(frozen=True)
class Plan:
    mode: str
    action: str
    spec: Path
    project: Path
    scheme: str
    configuration: str
    destination: str
    output: Path
    run_isolation_check: bool


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mode", required=True, choices=("debug", "release"))
    parser.add_argument("--action", required=True, choices=("build", "test", "archive"))
    parser.add_argument("--configuration", help="必须与模式一致：Debug 或 Release。")
    parser.add_argument("--scheme", help=f"仅 debug 模式可选：{', '.join(DEV_SCHEMES)}。")
    parser.add_argument("--destination", help="test 必填；archive 只接受 generic/platform=iOS。")
    parser.add_argument("--output", type=Path, default=REPO_ROOT / "build" / "walk-build")
    return parser


def plan(argv: list[str] | None = None) -> Plan:
    """解析并校验参数。只做纯计算，不触碰文件系统或子进程。"""
    parser = _parser()
    arguments = parser.parse_args(argv)

    configuration = arguments.mode.capitalize()
    if arguments.configuration is not None and arguments.configuration != configuration:
        parser.error(f"{arguments.mode} 模式只允许 --configuration {configuration}")
    if arguments.mode == "debug" and arguments.action == "archive":
        parser.error("开发依赖图不能 archive；出包请使用 --mode release")
    if arguments.mode == "release" and arguments.action == "test":
        parser.error("生产依赖图不包含测试 target；测试请使用 --mode debug")
    if arguments.mode == "release" and arguments.scheme is not None:
        parser.error("release 模式固定使用 WalkRelease scheme")
    if arguments.scheme is not None and arguments.scheme not in DEV_SCHEMES:
        parser.error(f"未知 scheme：{arguments.scheme}")

    destination = arguments.destination.strip() if arguments.destination is not None else None
    if arguments.action == "test" and not destination:
        parser.error("test 需要非空的 --destination")
    if arguments.action == "archive":
        if destination is not None and destination != "generic/platform=iOS":
            parser.error("archive 只接受 generic/platform=iOS")
        destination = "generic/platform=iOS"
    else:
        destination = destination or "generic/platform=iOS Simulator"

    output = arguments.output.expanduser().resolve()
    if arguments.mode == "release":
        spec = REPO_ROOT / "project-release.yml"
        # 生成在仓库根目录，使 Info.plist 等按项目目录解析的构建设置与开发图一致；
        # 该工程已被 .gitignore 排除，每次构建前重新生成。
        project = REPO_ROOT / RELEASE_PROJECT
        scheme = "WalkRelease"
    else:
        spec = REPO_ROOT / "project.yml"
        project = REPO_ROOT / "Walk.xcodeproj"
        scheme = arguments.scheme or "Walk"

    return Plan(
        mode=arguments.mode,
        action=arguments.action,
        spec=spec,
        project=project,
        scheme=scheme,
        configuration=configuration,
        destination=destination,
        output=output,
        run_isolation_check=arguments.mode == "release",
    )


def main(argv: list[str] | None = None) -> int:
    request = plan(argv)
    if not request.spec.is_file():
        print(f"工程定义缺失：{request.spec}", file=sys.stderr)
        return 2

    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    run_directory = request.output / "Runs" / f"{request.mode}-{request.action}-{run_id}"
    derived_data = request.output / request.configuration / "DerivedData"
    packages = request.output / "SourcePackages"

    def run_step(name: str, command: list[str]) -> int:
        log_path = run_directory / f"{name}.log"
        print(f"{name}: {log_path}", flush=True)
        with log_path.open("w", encoding="utf-8") as log:
            log.write(f"$ {shlex.join(command)}\n\n")
            log.flush()
            result = subprocess.run(command, cwd=REPO_ROOT, stdout=log, stderr=subprocess.STDOUT, check=False)
        if result.returncode:
            print(f"{name} 失败（{result.returncode}），见 {log_path}", file=sys.stderr)
        return result.returncode

    try:
        run_directory.mkdir(parents=True, exist_ok=False)
        if request.mode == "release":
            # 每次重新生成生产工程，并沿用开发图已锁定的 Alamofire / Lottie 版本；
            # 生产锁文件去掉 DebugSwift，防止被解析进生产依赖图。
            shutil.rmtree(request.project, ignore_errors=True)
            status = run_step("generate", ["xcodegen", "generate", "--spec", str(request.spec)])
            if status:
                return status
            _write_release_lock(request.project)
        else:
            status = run_step("generate", ["xcodegen", "generate", "--spec", str(request.spec)])
            if status:
                return status

        common = [
            "-project", str(request.project), "-scheme", request.scheme,
            "-configuration", request.configuration, "-derivedDataPath", str(derived_data),
            "-clonedSourcePackagesDirPath", str(packages),
        ]
        status = run_step("resolve", [
            "xcodebuild", "-resolvePackageDependencies", *common,
            "-onlyUsePackageVersionsFromResolvedFile",
        ])
        if status:
            return status

        command = [
            "xcodebuild", request.action, *common,
            "-destination", request.destination, "-disableAutomaticPackageResolution",
        ]
        if request.action == "test":
            command.extend([
                "-parallel-testing-enabled", "NO",
                "-resultBundlePath", str(run_directory / "Tests.xcresult"),
                "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-",
            ])
        else:
            command.append("CODE_SIGNING_ALLOWED=NO")
        archive_path = run_directory / f"{request.scheme}.xcarchive"
        if request.action == "archive":
            command.extend(["-archivePath", str(archive_path)])
        status = run_step(request.action, command)
        if status or not request.run_isolation_check:
            return status

        if request.action == "archive":
            app = archive_path / "Products" / "Applications" / "Walk.app"
        else:
            app = derived_data / "Build" / "Products" / "Release-iphonesimulator" / "Walk.app"
        return run_step("isolation-check", [
            sys.executable, str(REPO_ROOT / "scripts" / "check_debugswift_isolation.py"),
            "--mode", "release",
            "--project", str(request.project),
            "--derived-data", str(derived_data),
            "--app", str(app),
            "--build-log", str(run_directory / f"{request.action}.log"),
            "--output", str(run_directory / "isolation-report.json"),
        ])
    except OSError as error:
        print(f"构建入口失败：{error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print(f"已中断；日志：{run_directory}", file=sys.stderr)
        return 130


def _write_release_lock(project: Path) -> None:
    """从开发锁文件派生生产锁文件：保留共用依赖版本，去掉调试依赖。"""
    import json

    source = REPO_ROOT / "Walk.xcodeproj" / RESOLVED_FILE
    data = json.loads(source.read_text(encoding="utf-8"))
    data["pins"] = [pin for pin in data["pins"] if pin["identity"] != "debugswift"]
    data.pop("originHash", None)
    target = project / RESOLVED_FILE
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
