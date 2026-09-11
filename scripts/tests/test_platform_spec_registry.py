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


def registry_rows():
    """Yield (object_id, carrier, source_cell) for every registry table row.

    The business component table carries a leading 「层」 taxonomy column
    (L2a/L2b/L2c from the master tiers), so carrier and source are read as
    the last two cells of the row instead of fixed column positions.
    """
    text = README.read_text(encoding="utf-8")
    for line in text.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        object_id = cells[0].strip("`")
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*", object_id):
            continue
        yield object_id, cells[-2].strip("`"), cells[-1]


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
        for target in re.findall(r"\[[^\]]+\]\((?!https?://|#)([^)]+)\)", text):
            resolved = (README.parent / target).resolve()
            if not resolved.exists():
                missing.append(target)
        self.assertEqual(missing, [], "unresolvable upstream authority links")


if __name__ == "__main__":
    unittest.main()
