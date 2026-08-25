#!/usr/bin/env python3
"""Update README.md app table from bucket manifests."""

import json
import os
import re
from pathlib import Path


def main():
    # Get repo root (parent of scripts dir)
    repo_root = Path(__file__).parent.parent
    readme_path = repo_root / "README.md"
    bucket_dir = repo_root / "bucket"

    # Find manifests (excluding templates)
    manifests = sorted(
        [f for f in bucket_dir.glob("*.json") if not f.name.endswith(".template.json")]
    )

    # Build table rows
    rows = []
    for manifest in manifests:
        name = manifest.stem
        try:
            with open(manifest, "r", encoding="utf-8") as f:
                data = json.load(f)
            description = data.get("description", "-")
        except Exception:
            description = "-"
        rows.append(f"| {name} | {description} |")

    table = "| 应用 | 描述 |\n|------|------|\n" + "\n".join(rows) + "\n"

    # Read README
    content = readme_path.read_text(encoding="utf-8")

    # Replace content between markers
    pattern = r"(?<=<!-- APPS_TABLE_START -->).*?(?=<!-- APPS_TABLE_END -->)"
    new_content = re.sub(pattern, "\n" + table, content, flags=re.DOTALL)

    # Write README
    readme_path.write_text(new_content, encoding="utf-8")
    print(f"Updated README with {len(manifests)} apps")


if __name__ == "__main__":
    main()
