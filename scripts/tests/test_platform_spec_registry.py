"""Platform spec registry integrity tests.

Enforces the contract between the root repo master UI spec (../docs/ui) and
this repo's platform spec (specs/README.md):

1. Every master Page ID and Component ID appears exactly once in the registry.
2. Every registered carrier type name exists in its registered source file.
3. Every upstream authority link in specs/README.md resolves on disk.

Run: python3 scripts/tests/test_platform_spec_registry.py
"""

import re
import unittest
from pathlib import Path
from urllib.parse import unquote, urlsplit

REPO = Path(__file__).resolve().parents[2]
README = REPO / "specs" / "README.md"
MASTER_UI = REPO.parent / "docs" / "ui"

GAP_MARKERS = {"缺口"}


def master_object_ids():
    pages = sorted(
        d.name
        for d in (MASTER_UI / "pages").iterdir()
        if d.is_dir() and (d / "spec.md").is_file()
    )
    components = []
    for group in ("common", "business"):
        # business/ is tiered (atoms/ components/ composites/); scan recursively.
        # Component ID is the leaf directory name and stays globally unique.
        base = MASTER_UI / "components" / group
        components += sorted(
            d.name
            for d in base.rglob("*")
            if d.is_dir() and (d / "spec.md").is_file()
        )
    return pages, components


def registry_rows(text=None):
    """Yield (object_id, carrier, source_cell) from the two mapping sections.

    The business component table carries a leading 「层」 taxonomy column
    (L2a/L2b/L2c from the master tiers), so carrier and source are read as
    the last two cells of the row instead of fixed column positions.
    Other sections can contain architecture tables with ID-like values.
    """
    if text is None:
        text = README.read_text(encoding="utf-8")
    in_mapping_section = False
    for line in text.splitlines():
        heading = re.match(r"^(#{1,2})\s+(.+?)\s*#*\s*$", line)
        if heading:
            in_mapping_section = (
                heading.group(1) == "##"
                and heading.group(2) in {"Page 映射", "Component 映射"}
            )
            continue
        if not in_mapping_section or not line.lstrip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        object_id = cells[0].strip("`")
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*", object_id):
            continue
        yield object_id, cells[-2].strip("`"), cells[-1]


def local_link_paths(text, base):
    """Yield local link targets and filesystem paths, excluding URL fragments.

    This is a file existence check, not a Markdown heading/anchor validator.
    """
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc or not parsed.path:
            continue
        yield target, (base / unquote(parsed.path)).resolve()


class RegistryParserTests(unittest.TestCase):
    def test_only_page_and_component_mapping_sections_are_registry_rows(self):
        text = """
## App 架构基准
| `mock` | Mock 实现 | 页面开发 |
## Page 映射
| 总 UI Page ID | SwiftUI 承载 | 源码 |
|---|---|---|
| `PAGE-HOME` | `HomeView` | `Walk/HomeView.swift` |
## 其他说明
| `real` | 真实实现 | 网络优先 |
## Component 映射
### 通用组件
| 总 UI Component ID | SwiftUI 承载 | 源码 |
|---|---|---|
| `card` | `WalkCard` | `Packages/Card.swift` |
### 业务组件
| 总 UI Component ID | 层 | SwiftUI 承载 | 源码 |
|---|---|---|---|
| `daily-weather-summary-row` | L2b 业务独立 | `DailyWeatherSummaryRow` | `Walk/Weather.swift` |
## Token 映射
| `remoteOnly` | 真实实现 | 绕过缓存 |
"""
        self.assertEqual(list(registry_rows(text)), [
            ("PAGE-HOME", "HomeView", "`Walk/HomeView.swift`"),
            ("card", "WalkCard", "`Packages/Card.swift`"),
            ("daily-weather-summary-row", "DailyWeatherSummaryRow", "`Walk/Weather.swift`"),
        ])

    def test_unknown_and_duplicate_ids_remain_visible_to_integrity_checks(self):
        text = """
## Component 映射
| `unknown-component` | | 缺口 |
| `unknown-component` | | 缺口 |
"""
        self.assertEqual(list(registry_rows(text)), [
            ("unknown-component", "", "缺口"),
            ("unknown-component", "", "缺口"),
        ])

    def test_relative_link_fragments_are_not_part_of_filesystem_paths(self):
        target = "../docs/Design%20Tokens.md#颜色"
        self.assertEqual(
            list(local_link_paths(f"[Token]({target})", README.parent)),
            [(target, (README.parent / "../docs/Design Tokens.md").resolve())],
        )

    def test_external_and_same_document_links_are_not_filesystem_paths(self):
        text = "[网页](https://example.com/spec#section) [邮件](mailto:team@example.com) [本节](#登记规则)"
        self.assertEqual(list(local_link_paths(text, README.parent)), [])


class PlatformSpecRegistryTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(README.is_file(), "specs/README.md must exist")
        self.assertTrue(MASTER_UI.is_dir(), "root master UI spec must be checked out at ../docs")

    def test_every_master_object_is_registered_exactly_once(self):
        pages, components = master_object_ids()
        self.assertTrue(pages, "master pages must exist")
        self.assertTrue(components, "master components must exist")

        counts = {}
        for object_id, _, _ in registry_rows():
            counts[object_id] = counts.get(object_id, 0) + 1

        duplicates = sorted(object_id for object_id, n in counts.items() if n > 1)
        self.assertEqual(duplicates, [], "IDs registered more than once")

        missing = [object_id for object_id in pages + components if counts.get(object_id, 0) == 0]
        self.assertEqual(missing, [], "master objects missing from the registry")

        unknown = sorted(set(counts) - set(pages) - set(components))
        self.assertEqual(unknown, [], "registry entries that are not master objects")

    def test_mapped_carriers_exist_in_registered_sources(self):
        for object_id, carrier, source in registry_rows():
            if any(marker in source for marker in GAP_MARKERS):
                continue
            source_path = REPO / source.strip("`").split("#")[0]
            self.assertTrue(source_path.is_file(), f"{object_id}: source {source} does not exist")
            if carrier:
                type_name = carrier.split("(")[0].split(".")[0].strip()
                text = source_path.read_text(encoding="utf-8")
                self.assertRegex(
                    text, rf"\b(struct|class|enum) {re.escape(type_name)}\b",
                    f"{object_id}: carrier {type_name} not found in {source}",
                )

    def test_gap_rows_do_not_claim_sources(self):
        for object_id, carrier, source in registry_rows():
            if any(marker in source for marker in GAP_MARKERS):
                self.assertFalse(
                    (REPO / source.strip("`")).is_file() and "Walk/" in source,
                    f"{object_id}: gap row must not point at a source file",
                )

    def test_upstream_authority_links_resolve(self):
        text = README.read_text(encoding="utf-8")
        missing = []
        for target, resolved in local_link_paths(text, README.parent):
            if not resolved.exists():
                missing.append(target)
        self.assertEqual(missing, [], "unresolvable upstream authority links")


if __name__ == "__main__":
    unittest.main()
