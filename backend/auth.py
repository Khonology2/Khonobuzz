"""JWT auth helpers and Sentry user context attachment."""
from typing import Any, Dict

try:
    from .token_utils import verify_token
except ImportError:
    from token_utils import verify_token


def get_current_user(token: str) -> Dict[str, Any]:
    """Verify JWT token and attach authenticated user to Sentry scope."""
    payload = verify_token(token)
    # Attach authenticated user to every Sentry event in this request.
    # Runs inside a try/except so Sentry never breaks authentication.
    try:
        import sentry_sdk as _sentry

        _sentry.set_user({
            "id": str(payload.get("sub") or payload.get("user_id") or payload.get("uid") or payload.get("id") or ""),
            "email": payload.get("email") or "",
            "role": payload.get("role") or "",
        })
    except Exception:
        pass
    return payload
