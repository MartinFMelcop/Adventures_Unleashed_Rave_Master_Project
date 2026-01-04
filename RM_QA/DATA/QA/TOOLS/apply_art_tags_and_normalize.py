#!/usr/bin/env python3
"""Auto-tag ART_IMAGE_ASSET_INDEX rows based on path and add normalized path column.

- Derives tags from directory prefixes.
- Adds/updates PathNormalized column (lowercase + spaces->"_" + dedup "_").
- Updates AtualizadoUTC when a row changes.

Usage: python RM_QA/DATA/QA/TOOLS/apply_art_tags_and_normalize.py \
           --index RM_CORE/DATA/CORE/ART_IMAGE_ASSET_INDEX.csv
"""
import argparse
import csv
import re
from datetime import datetime, timezone
from pathlib import PurePosixPath

TAG_RULES = [
    ("rpg_experimentaliaapp_legado/graphics/icons", ["ui_icon", "legacy_import"]),
    ("rpg_experimentaliaapp_legado/graphics/titles", ["title_screen", "legacy_import"]),
    ("rpg_experimentaliaapp_legado/graphics/windowskins", ["ui_skin", "legacy_import"]),
    ("overlord_lightnovels/light novels/illustrations", ["reference_illustration", "legacy_bundle"]),
]


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize_path(path: str) -> str:
    clean = path.replace("\\", "/").strip().lower()
    clean = re.sub(r"\s+", "_", clean)
    clean = re.sub(r"_+", "_", clean)
    return clean


def apply_rules(rel_path: str, existing_tags: list[str]) -> list[str]:
    norm = normalize_path(rel_path)
    normalized_rules = getattr(apply_rules, "_normalized_rules", None)
    if normalized_rules is None:
        normalized_rules = [
            (normalize_path(prefix), tags) for prefix, tags in TAG_RULES
        ]
        setattr(apply_rules, "_normalized_rules", normalized_rules)
    tags = set(t for t in existing_tags if t)
    for prefix, rule_tags in normalized_rules:
        if norm.startswith(prefix):
            tags.update(rule_tags)
    return sorted(tags)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--index", default="RM_CORE/DATA/CORE/ART_IMAGE_ASSET_INDEX.csv")
    args = ap.parse_args()

    with open(args.index, newline='', encoding='utf-8') as f:
        rows = list(csv.DictReader(f))

    fieldnames = list(rows[0].keys())
    if "PathNormalized" not in fieldnames:
        # Insert after RelativePath for readability
        try:
            idx = fieldnames.index("RelativePath") + 1
        except ValueError:
            idx = len(fieldnames)
        fieldnames.insert(idx, "PathNormalized")
        for r in rows:
            r["PathNormalized"] = ""

    now = utc_now()
    changed = 0
    for r in rows:
        rel_path = r.get("RelativePath", "")
        norm_path = normalize_path(rel_path)
        current_norm = r.get("PathNormalized", "")
        existing_tags = [t.strip() for t in r.get("Tags", "").split(";") if t.strip()]
        new_tags = apply_rules(rel_path, existing_tags)
        tags_str = ";".join(new_tags)

        row_changed = False
        if norm_path and norm_path != current_norm:
            row_changed = True
        elif not current_norm and norm_path:
            row_changed = True
        if r.get("PathNormalized", "") != norm_path:
            r["PathNormalized"] = norm_path
        if tags_str != r.get("Tags", ""):
            r["Tags"] = tags_str
            row_changed = True
        if row_changed:
            r["AtualizadoUTC"] = now
            changed += 1

    with open(args.index, "w", newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Updated {changed} rows; columns={len(fieldnames)}")


if __name__ == "__main__":
    main()
