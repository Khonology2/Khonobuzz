#!/usr/bin/env python3
import argparse
import json
import sys
import time
from typing import Any, Dict, List, Optional, Tuple
from urllib import error, parse, request

# Default email to test when --email is not provided.
DEFAULT_EMAIL = "unathi.sibanda1@khonology.com"


def _now_ms() -> int:
    return int(time.time() * 1000)


def _safe_decode(body: bytes) -> str:
    try:
        return body.decode("utf-8", errors="replace")
    except Exception:
        return "<decode-error>"


def _truncate(text: str, max_len: int = 380) -> str:
    text = text.strip().replace("\r", " ").replace("\n", " ")
    if len(text) <= max_len:
        return text
    return text[: max_len - 3] + "..."


def http_call(
    method: str,
    url: str,
    headers: Optional[Dict[str, str]] = None,
    body_obj: Optional[Dict[str, Any]] = None,
    timeout: int = 20,
) -> Dict[str, Any]:
    headers = headers or {}
    data: Optional[bytes] = None
    if body_obj is not None:
        data = json.dumps(body_obj).encode("utf-8")
        headers.setdefault("Content-Type", "application/json")

    req = request.Request(url=url, data=data, headers=headers, method=method.upper())
    started = _now_ms()
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
            elapsed = _now_ms() - started
            return {
                "ok": True,
                "status": resp.status,
                "elapsed_ms": elapsed,
                "headers": dict(resp.getheaders()),
                "body": _safe_decode(body),
                "error": None,
            }
    except error.HTTPError as e:
        body = e.read() if hasattr(e, "read") else b""
        elapsed = _now_ms() - started
        return {
            "ok": False,
            "status": e.code,
            "elapsed_ms": elapsed,
            "headers": dict(e.headers.items()) if e.headers else {},
            "body": _safe_decode(body),
            "error": f"HTTPError {e.code}",
        }
    except Exception as e:
        elapsed = _now_ms() - started
        return {
            "ok": False,
            "status": None,
            "elapsed_ms": elapsed,
            "headers": {},
            "body": "",
            "error": str(e),
        }


def _print_result(label: str, result: Dict[str, Any], show_body: bool = True) -> None:
    status = result["status"] if result["status"] is not None else "NO_RESPONSE"
    elapsed = result["elapsed_ms"]
    err = result["error"]
    acao = result["headers"].get("Access-Control-Allow-Origin", "<missing>")
    print(f"- {label}: status={status} elapsed={elapsed}ms acao={acao}")
    if err:
        print(f"  error: {err}")
    if show_body:
        body_snippet = _truncate(result["body"])
        if body_snippet:
            print(f"  body: {body_snippet}")


def run_for_email(base_url: str, email: str, origin: str, timeout: int) -> Tuple[bool, List[str]]:
    print("\n" + "=" * 88)
    print(f"EMAIL: {email}")
    print("=" * 88)

    issues: List[str] = []
    parsed_base = base_url.rstrip("/")

    # Warmup/health routes observed in logs
    probes = [
        ("GET base /", f"{parsed_base}/"),
        ("GET /health", f"{parsed_base}/health"),
        ("GET /api", f"{parsed_base}/api"),
        ("GET /api/health", f"{parsed_base}/api/health"),
    ]
    for label, url in probes:
        res = http_call("GET", url, timeout=timeout)
        _print_result(label, res)

    # CORS preflight on login endpoint
    login_url = f"{parsed_base}/api/auth/login"
    preflight = http_call(
        "OPTIONS",
        login_url,
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
        timeout=timeout,
    )
    _print_result("OPTIONS /api/auth/login (CORS preflight)", preflight, show_body=False)
    if preflight["headers"].get("Access-Control-Allow-Origin") in (None, "", "<missing>"):
        issues.append("CORS header missing on login preflight")

    # Actual login call used by app
    login_res = http_call(
        "POST",
        login_url,
        headers={"Origin": origin},
        body_obj={"email": email},
        timeout=timeout,
    )
    _print_result("POST /api/auth/login", login_res)
    if login_res["status"] == 404:
        lower_body = (login_res.get("body") or "").lower()
        if "user not found" in lower_body:
            issues.append("POST /api/auth/login returned 404 user-not-found")
        else:
            issues.append("POST /api/auth/login returned 404 (route missing or backend mismatch)")
    elif login_res["status"] is None:
        issues.append("POST /api/auth/login no response (network/DNS/TLS issue)")

    # Fallback route used by app when login fails
    by_email = f"{parsed_base}/api/users/by-email?email={parse.quote(email)}"
    by_email_res = http_call("GET", by_email, headers={"Origin": origin}, timeout=timeout)
    _print_result("GET /api/users/by-email", by_email_res)
    if by_email_res["status"] == 404:
        lower_body = (by_email_res.get("body") or "").lower()
        if "user not found" in lower_body:
            issues.append("GET /api/users/by-email returned 404 user-not-found")
        else:
            issues.append("GET /api/users/by-email returned 404 (route missing or backend mismatch)")

    # Parse response semantics for quick diagnosis
    if login_res["status"] == 200:
        try:
            payload = json.loads(login_res["body"])
            user = payload.get("user") if isinstance(payload, dict) else None
            if not user:
                issues.append("Login 200 but missing user payload")
            else:
                print(
                    f"  parsed: login user email={user.get('email')} role={user.get('role')} status={user.get('status')}"
                )
        except Exception:
            issues.append("Login 200 but response was not valid JSON")

    if by_email_res["status"] == 200:
        try:
            payload = json.loads(by_email_res["body"])
            user = payload.get("user") if isinstance(payload, dict) else None
            if user:
                print(
                    f"  parsed: lookup user email={user.get('email')} role={user.get('role')} status={user.get('status')}"
                )
            else:
                issues.append("Lookup 200 but missing user payload")
        except Exception:
            issues.append("Lookup 200 but response was not valid JSON")

    passed = len(issues) == 0
    if passed:
        print("RESULT: PASS (no obvious endpoint/CORS issue detected)")
    else:
        print("RESULT: FAIL")
        for i, issue in enumerate(issues, 1):
            print(f"  {i}. {issue}")
    return passed, issues


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Diagnose deployed login endpoint health and CORS for specific users."
    )
    parser.add_argument(
        "--base-url",
        default="https://khonobuzz-central-hub.onrender.com",
        help="Backend base URL used by the app.",
    )
    parser.add_argument(
        "--origin",
        default="https://khono-buzz-central-hub-web.onrender.com",
        help="Frontend origin for CORS checks.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=20,
        help="HTTP timeout in seconds per request.",
    )
    parser.add_argument(
        "--email",
        action="append",
        required=False,
        help="Email to diagnose. Repeat --email for multiple users.",
    )
    args = parser.parse_args()
    emails = args.email or [DEFAULT_EMAIL]

    print("Login diagnostics starting...")
    print(f"base_url={args.base_url}")
    print(f"origin={args.origin}")
    print(f"emails={emails}")

    all_passed = True
    failures: Dict[str, List[str]] = {}
    for email in emails:
        passed, issues = run_for_email(args.base_url, email, args.origin, args.timeout)
        if not passed:
            all_passed = False
            failures[email] = issues

    print("\n" + "#" * 88)
    print("SUMMARY")
    print("#" * 88)
    if all_passed:
        print("All checks passed for all users.")
        return 0

    print("Some checks failed:")
    for email, issues in failures.items():
        print(f"- {email}")
        for issue in issues:
            print(f"  - {issue}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
