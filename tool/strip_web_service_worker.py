#!/usr/bin/env python3
"""Remove Flutter web service worker registration from build/web/flutter_bootstrap.js.

The service worker caches old main.dart.js/canvaskit; users then see code that is not
the latest deploy. CI calls this after `flutter build web` so production loads fresh assets.

Safe to run only on release output; local `flutter run` is unchanged.
"""
from __future__ import annotations

import pathlib
import sys


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    path = root / "build" / "web" / "flutter_bootstrap.js"
    if not path.is_file():
        print(f"Missing {path}", file=sys.stderr)
        return 1
    s = path.read_text(encoding="utf-8")
    needle = "_flutter.loader.load({"
    i = s.rfind(needle)
    if i == -1:
        print("Could not find _flutter.loader.load({ in flutter_bootstrap.js", file=sys.stderr)
        return 1
    # Brace-match the object passed to .load(
    start = s.find("{", i + len("_flutter.loader.load(") - 1)
    depth = 0
    j = start
    end = -1
    while j < len(s):
        c = s[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                k = j + 1
                if k < len(s) and s[k] == ")":
                    k += 1
                    if k < len(s) and s[k] == ";":
                        k += 1
                end = k
                break
        j += 1
    if end < 0:
        print("Could not match braces for loader.load", file=sys.stderr)
        return 1
    replacement = "_flutter.loader.load({});"
    new_s = s[:i] + replacement + s[end:]
    path.write_text(new_s, encoding="utf-8")
    print("Patched flutter_bootstrap.js: service worker registration removed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
