#!/usr/bin/env python3
"""Inspect existing DebugSwift isolation artifacts; never build or modify them.

Requires macOS plutil and Xcode's nm, otool, and lipo. Debug requires positive
SDK/adapter compilation, linkage, symbols, and SDK resources. Release requires
their absence in the project, compilation tasks, link maps, and packaged app.
Supply the complete build transcript when a build used incremental compilation.
This verifies artifacts, not UI test success or runtime behavior.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys


MODULES = ("DebugSwift", "WalkDebugTools")
MACHO_MAGICS = {
    b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
    b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca",
}
COMPILE_TASK = re.compile(
    r"^(SwiftCompile|SwiftEmitModule|CompileSwift|CompileSwiftSources|CompileC)\b"
    r".*\(in target '([^']+)' from project '([^']+)'\)\s*$"
)
LINK_TASK = re.compile(r"^Ld (.+?) normal(?: (\S+))? \(in target '([^']+)' from project '([^']+)'\)\s*$")


def command(*arguments):
    result = subprocess.run(arguments, capture_output=True, text=True, timeout=120)
    if result.returncode:
        raise RuntimeError(f"{arguments[0]} exited {result.returncode}: {result.stderr.strip()[:600]}")
    return result.stdout


def file_evidence(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    stat = path.stat()
    return {"path": str(path), "bytes": stat.st_size, "sha256": digest.hexdigest()}


def module_hits(lines):
    # Exact case matters: path fragments such as "debugswift" in build output
    # directories are not SDK linkage evidence.
    result = {}
    for module in MODULES:
        hits = [line.strip()[:350] for line in lines if module in line]
        result[module] = {"count": len(hits), "examples": hits[:2]}
    return result


def module_identity(value):
    # Package/dependency identities, not arbitrary source paths or comments.
    name = str(value).rstrip("/").split("/")[-1].removesuffix(".git")
    return next((module for module in MODULES if name.lower() == module.lower()), None)


def inspect(args):
    report = {
        "mode": args.mode,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "passed": False,
        "checks": [],
    }
    checks = report["checks"]

    def check(name, passed, **evidence):
        checks.append({"check": name, "passed": bool(passed), **evidence})

    project = args.project.resolve()
    if project.suffix == ".xcodeproj":
        project /= "project.pbxproj"
    app = args.app.resolve()
    derived = args.derived_data.resolve()
    log_path = args.build_log.resolve()
    required = [(project, "file"), (app, "directory"), (app / "Info.plist", "file"),
                (derived / "Build", "directory"), (log_path, "file")]
    missing = [str(path) for path, kind in required
               if not (path.is_file() if kind == "file" else path.is_dir())]
    check("required_inputs", not missing, missing=missing)
    if missing:
        return report

    with (app / "Info.plist").open("rb") as stream:
        executable = plistlib.load(stream).get("CFBundleExecutable")
    if not executable or Path(executable).name != executable:
        check("app_executable", False, error="Info.plist has no valid CFBundleExecutable")
        return report
    main_binary = app / executable
    check("app_executable", main_binary.is_file(), path=str(main_binary))
    if not main_binary.is_file():
        return report

    objects = json.loads(command("plutil", "-convert", "json", "-o", "-", str(project)))["objects"]
    main_targets = [obj for obj in objects.values()
                    if obj.get("isa") == "PBXNativeTarget"
                    and obj.get("productType") == "com.apple.product-type.application"
                    and objects.get(obj.get("productReference"), {}).get("path") == app.name]
    check("project_main_target", len(main_targets) == 1,
          targets=[obj.get("name") for obj in main_targets])
    if len(main_targets) != 1:
        return report
    target = main_targets[0]
    target_name = target["name"]
    identities = []
    for obj in objects.values():
        if obj.get("isa") not in {
            "XCLocalSwiftPackageReference", "XCRemoteSwiftPackageReference",
            "XCSwiftPackageProductDependency", "PBXNativeTarget", "PBXTargetDependency",
        }:
            continue
        for field in ("relativePath", "repositoryURL", "productName", "name"):
            module = module_identity(obj.get(field, ""))
            if module:
                identities.append({"kind": obj["isa"], "field": field,
                                   "value": obj[field], "module": module})
    products = [objects[ref].get("productName") for ref in target.get("packageProductDependencies", [])]
    linked_products = []
    for phase_ref in target.get("buildPhases", []):
        phase = objects[phase_ref]
        if phase["isa"] == "PBXFrameworksBuildPhase":
            for file_ref in phase.get("files", []):
                product = objects.get(objects[file_ref].get("productRef"), {})
                if product.get("productName"):
                    linked_products.append(product["productName"])
    expected_debug = args.mode == "debug"
    project_ok = (
        "WalkDebugTools" in products and "WalkDebugTools" in linked_products
        and any(item["module"] == "WalkDebugTools" and item["kind"] in {
            "XCLocalSwiftPackageReference", "XCRemoteSwiftPackageReference"
        } for item in identities)
    ) if expected_debug else not identities
    check("project_dependencies", project_ok, project=file_evidence(project),
          references=identities, app_package_products=products, app_linked_products=linked_products)

    log_lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    compile_records = {module: [] for module in MODULES}
    main_compiles = []
    links = []
    for number, line in enumerate(log_lines, 1):
        task = COMPILE_TASK.match(line)
        if task:
            record = {"line": number, "task": task[1], "target": task[2], "project": task[3]}
            if task[2] in compile_records:
                compile_records[task[2]].append(record)
            if task[2] == target_name:
                main_compiles.append(record)
        link = LINK_TASK.match(line)
        if link and link[3] == target_name:
            output = Path(link[1].replace("\\ ", " "))
            if output.is_relative_to(derived):
                links.append({"line": number, "output": str(output), "arch": link[2]})
    check("build_log_app_tasks", bool(main_compiles) and bool(links),
          log=file_evidence(log_path), app_compile_count=len(main_compiles), app_link_tasks=links,
          outcomes=[line for line in log_lines if re.fullmatch(r"\*\* .+ (SUCCEEDED|FAILED) \*\*", line)])
    compile_ok = all(compile_records.values()) if expected_debug else not any(compile_records.values())
    check("sdk_compile_tasks", compile_ok,
          modules={module: {"count": len(records), "examples": records[:2]}
                   for module, records in compile_records.items()})

    binaries = []
    for path in sorted(app.rglob("*")):
        if path.is_file():
            with path.open("rb") as stream:
                if stream.read(4) in MACHO_MAGICS:
                    binaries.append(path)
    check("app_macho_inventory", main_binary in binaries,
          binaries=[str(path.relative_to(app)) for path in binaries])
    if main_binary not in binaries:
        return report
    architectures = command("xcrun", "lipo", "-archs", str(main_binary)).split()
    check("app_architectures", bool(architectures), architectures=architectures)

    maps = []
    for path in sorted((derived / "Build").rglob("*LinkMap*.txt")):
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        output = next((line.removeprefix("# Path: ") for line in lines if line.startswith("# Path: ")), "")
        if Path(output).name not in {executable, executable + ".debug.dylib"}:
            continue
        arch = next((line.removeprefix("# Arch: ") for line in lines if line.startswith("# Arch: ")), "")
        logged_output = output in {item["output"] for item in links}
        valid = (logged_output and "# Object files:" in lines and "# Symbols:" in lines
                 and any(re.match(r"^\[\s*\d+\]", line) for line in lines))
        maps.append({**file_evidence(path), "linked_output": output, "arch": arch,
                     "logged_output": logged_output, "valid": valid, "modules": module_hits(lines)})
    missing_arches = sorted(set(architectures) - {item["arch"] for item in maps if item["valid"]})
    check("main_app_link_maps", bool(maps) and all(item["valid"] for item in maps) and not missing_arches,
          missing_architectures=missing_arches, maps=maps)
    # Require each shipped architecture to carry the SDK and adapter in Debug.
    # A UI-test-runner map can never satisfy this check.
    if expected_debug:
        linked_ok = bool(architectures) and all(
            any(item["arch"] == arch and item["valid"] and item["modules"][module]["count"]
                for item in maps) for arch in architectures for module in MODULES
        )
    else:
        linked_ok = bool(maps) and not any(item["modules"][module]["count"] for item in maps for module in MODULES)
    check("sdk_link_map_contents", linked_ok)

    symbol_records = []
    dependency_records = []
    symbol_totals = {module: 0 for module in MODULES}
    dependency_totals = {module: 0 for module in MODULES}
    for binary in binaries:
        symbols = command("xcrun", "nm", "-arch", "all", "-j", str(binary)).splitlines()
        # nm can print architecture/file headings; these are not symbols.
        symbols = [line for line in symbols if line and not line.endswith(":")]
        symbol_matches = module_hits(symbols)
        dependencies = [line.strip().split(" (compatibility version", 1)[0]
                        for line in command("xcrun", "otool", "-L", str(binary)).splitlines()
                        if line.startswith("\t")]
        dependencies = sorted(set(dependencies))
        dependency_matches = module_hits(dependencies)
        for module in MODULES:
            symbol_totals[module] += symbol_matches[module]["count"]
            dependency_totals[module] += dependency_matches[module]["count"]
        symbol_records.append({**file_evidence(binary), "symbol_count": len(symbols), "modules": symbol_matches})
        dependency_records.append({"binary": str(binary.relative_to(app)), "libraries": dependencies,
                                   "modules": dependency_matches})
    symbols_ok = all(symbol_totals.values()) if expected_debug else not any(symbol_totals.values())
    check("sdk_symbols", symbols_ok, totals=symbol_totals, binaries=symbol_records)
    # SwiftPM may link these libraries statically. No dynamic SDK entry is a
    # legitimate Debug result, provided positive link-map and nm checks pass.
    check("sdk_dynamic_dependencies", expected_debug or not any(dependency_totals.values()),
          totals=dependency_totals, binaries=dependency_records)

    bundles = []
    for bundle in sorted(app.rglob("*.bundle")):
        if bundle.is_dir() and any(module in bundle.name for module in MODULES):
            resource_count = sum(1 for path in bundle.rglob("*")
                                 if path.is_file() and path.name not in {"Info.plist", ".DS_Store"})
            bundles.append({"path": str(bundle.relative_to(app)), "resource_files": resource_count})
    resources_ok = any("DebugSwift" in item["path"] and item["resource_files"] > 0 for item in bundles) if expected_debug else not bundles
    check("sdk_resource_bundles", resources_ok, bundles=bundles)
    report["passed"] = all(item["passed"] for item in checks)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("debug", "release"), required=True)
    parser.add_argument("--project", type=Path, required=True, help="Generated .xcodeproj or project.pbxproj")
    parser.add_argument("--derived-data", type=Path, required=True)
    parser.add_argument("--app", type=Path, required=True, help="Built main .app, including archived Apps")
    parser.add_argument("--build-log", type=Path, required=True)
    parser.add_argument("--output", type=Path, help="Optional JSON report; input artifacts remain read-only")
    args = parser.parse_args()
    try:
        report = inspect(args)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError, plistlib.InvalidFileException) as error:
        report = {"mode": args.mode, "passed": False, "error": str(error)}
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        try:
            output = args.output.resolve()
            artifact_roots = [args.project.resolve(), args.app.resolve(), args.derived_data.resolve(), args.build_log.resolve()]
            if any(output == path or output.is_relative_to(path) for path in artifact_roots):
                raise ValueError("--output must be outside inspected input artifacts")
            args.output.write_text(encoded, encoding="utf-8")
        except (OSError, ValueError) as error:
            report["passed"] = False
            report["output_error"] = str(error)
            encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    sys.stdout.write(encoded)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
