#!/usr/bin/env python3
"""
Utility to regenerate DATA/DATA_INDEX.csv, checksums.sha256 and manifest.json for a module.
- Recomputes row/col counts and hashes for CSVs listed in DATA_INDEX.
- Rewrites checksums.sha256 (excluding manifest.json and the checksum file itself).
- Rewrites manifest.json with updated file metadata.
"""
import argparse
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

DATA_INDEX_COLUMNS = [
    "workbook_group",
    "workbook_file",
    "sheet_name",
    "csv_relpath",
    "rows",
    "cols",
    "sha256",
    "generated_utc",
    "size_bytes",
    "bytes",
    "modified_utc",
    "sha256_of_csv",
    "csv_rows",
    "csv_cols",
    "notes",
]


def sha256_hex(path: Path) -> Tuple[str, int, bytes]:
    data = path.read_bytes()
    return hashlib.sha256(data).hexdigest(), len(data), data


def csv_dimensions(csv_bytes: bytes) -> Tuple[int, int]:
    text = csv_bytes.decode("utf-8")
    reader = csv.reader(text.splitlines())
    try:
        header = next(reader)
    except StopIteration:
        return 0, 0

    data_rows = 0
    max_cols = len(header)
    for row in reader:
        data_rows += 1
        max_cols = max(max_cols, len(row))
    return data_rows, max_cols


def format_num(num: int) -> str:
    # Preserve the historical ".0" style used in DATA_INDEX for row/col counts.
    return f"{float(num):.1f}"


def refresh_data_index(module_dir: Path, now_utc: str) -> None:
    idx_path = module_dir / "DATA/DATA_INDEX.csv"
    if not idx_path.exists():
        return

    rows: List[Dict[str, str]] = []
    with idx_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != DATA_INDEX_COLUMNS:
            raise SystemExit(
                f"Unexpected DATA_INDEX columns: {reader.fieldnames}. Expected {DATA_INDEX_COLUMNS}"
            )
        for row in reader:
            csv_path = module_dir / row["csv_relpath"]
            if not csv_path.exists():
                raise SystemExit(f"Missing CSV referenced in DATA_INDEX: {csv_path}")
            sha, size, csv_bytes = sha256_hex(csv_path)
            r_count, c_count = csv_dimensions(csv_bytes)
            row.update(
                {
                    "rows": format_num(r_count),
                    "cols": format_num(c_count),
                    "csv_rows": format_num(r_count),
                    "csv_cols": format_num(c_count),
                    "sha256": sha,
                    "sha256_of_csv": sha,
                    "bytes": str(size),
                    "size_bytes": str(size),
                    "generated_utc": now_utc,
                    "modified_utc": now_utc,
                }
            )
            rows.append(row)

    with idx_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=DATA_INDEX_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def collect_files(module_dir: Path) -> Sequence[Path]:
    files: List[Path] = []
    for path in sorted(module_dir.rglob("*")):
        if path.is_file():
            files.append(path)
    return files


def write_checksums(module_dir: Path, files: Sequence[Path]) -> None:
    checksums_path = module_dir / "checksums.sha256"
    lines = ["# sha256  relpath"]
    for path in files:
        rel = path.relative_to(module_dir)
        if rel.as_posix() in {"manifest.json", "checksums.sha256"}:
            continue
        sha, _, _ = sha256_hex(path)
        lines.append(f"{sha}  {rel.as_posix()}")
    checksums_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_manifest(module_dir: Path, files: Sequence[Path], version_aj: str, now_utc: str) -> None:
    manifest_path = module_dir / "manifest.json"
    module_name = module_dir.name
    entries = []
    for path in files:
        rel = path.relative_to(module_dir)
        if rel.as_posix() == "manifest.json":
            continue
        sha, size, _ = sha256_hex(path)
        entries.append({"relpath": rel.as_posix(), "bytes": size, "sha256": sha})

    manifest = {
        "module": module_name,
        "version_aj": version_aj,
        "manifest_version": 1,
        "generated_utc": now_utc,
        "files": entries,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Refresh manifest/checksums/DATA_INDEX for a module.")
    parser.add_argument("module_dir", type=Path, help="Module folder (e.g., RM_QA)")
    parser.add_argument("--version-aj", required=True, dest="version_aj", help="AJ ID to stamp in manifest")
    args = parser.parse_args()

    module_dir: Path = args.module_dir.resolve()
    if not module_dir.is_dir():
        raise SystemExit(f"Module dir not found: {module_dir}")

    now_utc = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    refresh_data_index(module_dir, now_utc)
    files = collect_files(module_dir)
    write_checksums(module_dir, files)
    write_manifest(module_dir, files, args.version_aj, now_utc)


if __name__ == "__main__":
    main()
