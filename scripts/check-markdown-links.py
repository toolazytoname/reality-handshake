#!/usr/bin/env python3
"""Check relative Markdown file links and balanced Mermaid fences."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


def markdown_files(root: Path) -> list[Path]:
    return sorted(path for path in root.rglob("*.md") if ".git" not in path.parts)


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    errors: list[str] = []

    for markdown in markdown_files(root):
        text = markdown.read_text(encoding="utf-8")
        fence_lines = [
            line_number
            for line_number, line in enumerate(text.splitlines(), start=1)
            if line.lstrip().startswith("```")
        ]
        if len(fence_lines) % 2:
            errors.append(
                f"{markdown.relative_to(root)}:{fence_lines[-1]}: unbalanced code fence"
            )

        for match in LINK_RE.finditer(text):
            raw_target = match.group(1).strip()
            if raw_target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target = raw_target.split("#", 1)[0].strip("<>")
            if not target:
                continue
            resolved = (markdown.parent / unquote(target)).resolve()
            try:
                resolved.relative_to(root)
            except ValueError:
                errors.append(
                    f"{markdown.relative_to(root)}: link escapes repository: {raw_target}"
                )
                continue
            if not resolved.exists():
                errors.append(
                    f"{markdown.relative_to(root)}: missing link target: {raw_target}"
                )

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    print(f"Markdown links passed: {len(markdown_files(root))} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
