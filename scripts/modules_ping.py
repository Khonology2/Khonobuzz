#!/usr/bin/env python3
"""
Warm up Render-hosted module backends by sending periodic HTTP GET requests.

Use when developing or from a small always-on process so PDH and Skills Heatmap
backends stay awake (reduces cold-start delay when users open those widgets).

Default targets (override with MODULE_PING_URLS env):
  - Skills Heatmap: https://resource-capacity-backend.onrender.com
  - Personal Development Hub: https://personal-development-backend.onrender.com

Examples:
  python scripts/modules_ping.py --once
  python scripts/modules_ping.py --interval 240
  python scripts/modules_ping.py --interval 300 --timeout 15
"""

from __future__ import annotations

import argparse
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Iterable, List, Optional, Tuple

DEFAULT_URLS: Tuple[str, ...] = (
    "https://resource-capacity-backend.onrender.com",
    "https://personal-development-backend.onrender.com",
)

# Paths tried per base URL (first 2xx wins for that base)
PATH_CANDIDATES: Tuple[str, ...] = ("/", "/health", "/api/health", "/api")


def _urls_from_env() -> List[str]:
    raw = os.environ.get("MODULE_PING_URLS", "").strip()
    if not raw:
        return list(DEFAULT_URLS)
    return [u.strip() for u in raw.split(",") if u.strip()]


def ping_url(full_url: str, timeout: float) -> Tuple[str, Optional[int], str]:
    """GET full_url; return (url, status_or_none, short_message)."""
    req = urllib.request.Request(
        full_url,
        method="GET",
        headers={"User-Agent": "KhonoBuzz-modules-ping/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            code = resp.getcode()
            return (full_url, code, "ok")
    except urllib.error.HTTPError as e:
        return (full_url, e.code, str(e.reason)[:80])
    except urllib.error.URLError as e:
        return (full_url, None, str(e.reason)[:80])
    except Exception as e:
        return (full_url, None, str(e)[:80])


def warm_base(base: str, timeout: float) -> Tuple[str, Optional[int], str]:
    """Try base + path candidates until one succeeds (2xx)."""
    base = base.rstrip("/")
    last: Tuple[str, int | None, str] = (base, None, "no attempt")
    for path in PATH_CANDIDATES:
        full = f"{base}{path}" if path.startswith("/") else f"{base}/{path}"
        url, code, msg = ping_url(full, timeout=timeout)
        last = (url, code, msg)
        if code is not None and 200 <= code < 300:
            return last
        if code is not None and code not in (404, 405):
            # Some backends return 401 on / but still wake up; treat as warmed
            if code < 500:
                return last
    return last


def run_once(urls: Iterable[str], timeout: float) -> int:
    failures = 0
    for base in urls:
        url, code, msg = warm_base(base, timeout=timeout)
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        if code is not None and 200 <= code < 300:
            print(f"[{ts}] OK {code} {url}")
        elif code is not None:
            print(f"[{ts}] WARN {code} {url} ({msg})")
            failures += 1
        else:
            print(f"[{ts}] FAIL {url} ({msg})")
            failures += 1
    return 0 if failures == 0 else 1


def run_loop(urls: List[str], interval: float, timeout: float) -> None:
    print(
        f"Pinging {len(urls)} URL(s) every {interval}s (Ctrl+C to stop).",
        file=sys.stderr,
    )
    while True:
        run_once(urls, timeout=timeout)
        time.sleep(interval)


def main() -> int:
    parser = argparse.ArgumentParser(description="Warm module backends on Render.")
    parser.add_argument(
        "--once",
        action="store_true",
        help="Ping once and exit (default if --interval not set)",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=0,
        metavar="SEC",
        help="Seconds between ping rounds (0 = run once and exit)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=12.0,
        help="HTTP timeout per request in seconds (default: 12)",
    )
    args = parser.parse_args()
    urls = _urls_from_env()
    if not urls:
        print("No URLs configured.", file=sys.stderr)
        return 2

    if args.interval > 0:
        run_loop(urls, interval=args.interval, timeout=args.timeout)
        return 0
    return run_once(urls, timeout=args.timeout)


if __name__ == "__main__":
    raise SystemExit(main())
