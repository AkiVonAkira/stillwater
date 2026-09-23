#!/usr/bin/env python3
"""Write stillwater.css from palette.json. Pass a feppz theme path to rebuild the VS Code adapter."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SKIP_KEYS = {"id", "label", "publisher"}


def remap_hex(text: str, hex_map: dict[str, str]) -> str:
    def repl(match: re.Match[str]) -> str:
        body = match.group(1)
        key = body[:6].lower()
        rest = body[6:]
        if key in hex_map:
            return "#" + hex_map[key] + rest
        return match.group(0)

    return re.sub(r"#([0-9A-Fa-f]{6,8})", repl, text)


def css_name(key: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "-", key).replace("_", "-").lower()


def write_css(palette: dict) -> None:
    lines = [":root {"]

    def walk(obj: object, prefix: str) -> None:
        if isinstance(obj, dict):
            for key, value in obj.items():
                if key in SKIP_KEYS:
                    continue
                name = css_name(str(key))
                next_prefix = f"{prefix}-{name}" if prefix else name
                walk(value, next_prefix)
            return
        if isinstance(obj, str) and obj.startswith("#"):
            lines.append(f"  --stillwater-{prefix}: {obj};")

    walk(palette, "")
    lines.append("}")
    lines.append("")
    out = ROOT / "stillwater.css"
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {out}")


def main() -> None:
    spec = json.loads((ROOT / "palette.json").read_text(encoding="utf-8"))
    write_css(spec["palette"])
    if len(sys.argv) < 2:
        print("vscode theme left as-is (pass a feppz theme path to rebuild it)")
        return
    src = Path(sys.argv[1])
    if not src.is_file():
        raise SystemExit(f"feppz source not found: {src}")
    themed = remap_hex(src.read_text(encoding="utf-8"), spec["hexMap"])
    if '"name": "Stillwater"' not in themed:
        themed = themed.replace('"type": "dark"', '"name": "Stillwater",\n\t"type": "dark"', 1)
    out = ROOT / "vscode" / "themes" / "stillwater-color-theme.json"
    out.write_text(themed, encoding="utf-8")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
