from fastapi import FastAPI, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.gzip import GZipMiddleware
from brotli_asgi import BrotliMiddleware
from firebase_admin import credentials, firestore, initialize_app
from dotenv import load_dotenv
import os
import logging
import json
import base64
import time
import re
import asyncio
from datetime import datetime
from pydantic import BaseModel
from fastapi.responses import JSONResponse
from fastapi import status
from fastapi import HTTPException
from typing import Optional, Dict, Any, Callable
from pathlib import Path
import jwt
from redis import Redis
try:
    from .token_utils import (
        generate_and_encrypt_token,
        parse_module_access_role_to_roles,
        parse_module_access_role_to_arw_roles,
        verify_token,
    )
except ImportError:
    from token_utils import (
        generate_and_encrypt_token,
        parse_module_access_role_to_roles,
        parse_module_access_role_to_arw_roles,
        verify_token,
    )
try:
    from .cloudinary_service import cloudinary_service
except ImportError:
    from cloudinary_service import cloudinary_service
try:
    from .sso_pg_sync import sync_sso_user_login
except ImportError:
    from sso_pg_sync import sync_sso_user_login
load_dotenv()
DEBUG_MODE = os.environ.get('DEBUG', 'True').lower() == 'true'
LOG_LEVEL = logging.DEBUG if DEBUG_MODE else logging.INFO
logging.basicConfig(
    level=LOG_LEVEL,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)
def debug_log(message: str):
    """Log debug messages only if DEBUG mode is enabled"""
    if DEBUG_MODE:
        logger.debug(message)
        print(f"[DEBUG] {message}")
def error_log(message: str):
    "Log error messages (always shown)"
    logger.error(message)
    print(f"[ERROR] {message}")
def info_log(message: str):
    logger.info(message)
    print(f"[INFO] {message}")


def append_agent_debug_log(hypothesis_id: str, location: str, message: str, data: Dict[str, Any]):
    try:
        payload = {
            "sessionId": "7ef484",
            "runId": "pre-fix",
            "hypothesisId": hypothesis_id,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": int(time.time() * 1000),
        }
        log_path = Path(__file__).resolve().parent.parent / "debug-7ef484.log"
        with log_path.open("a", encoding="utf-8") as debug_file:
            debug_file.write(json.dumps(payload, ensure_ascii=True) + "\n")
    except Exception:
        pass


LOGIN_CACHE_TTL_SECONDS = int(os.environ.get('LOGIN_CACHE_TTL_SECONDS', '600'))
USER_CACHE: Dict[str, Dict[str, Any]] = {}
LOGIN_QUERY_TIMEOUT_SECONDS = float(os.environ.get('LOGIN_QUERY_TIMEOUT_SECONDS', '8'))
ONBOARDING_QUERY_TIMEOUT_SECONDS = float(os.environ.get('ONBOARDING_QUERY_TIMEOUT_SECONDS', '6'))

# Cache for /api/version to avoid re-reading version.json on every request.
# This is useful when the Flutter app (or multiple dev hot-reloads) call the endpoint repeatedly.
VERSION_JSON_CACHE_TTL_SECONDS = int(os.environ.get('VERSION_JSON_CACHE_TTL_SECONDS', '60'))
_VERSION_JSON_CACHE: Dict[str, Any] = {
    "expires_at": 0.0,
    "mtime": None,
    "data": None,
}

# Hot endpoint caches (in-memory) to reduce Firestore pressure.
USERS_CACHE_TTL_SECONDS = int(os.environ.get('USERS_CACHE_TTL_SECONDS', '45'))
ADMIN_NOTIFICATIONS_CACHE_TTL_SECONDS = int(
    os.environ.get('ADMIN_NOTIFICATIONS_CACHE_TTL_SECONDS', '30')
)
HOT_ENDPOINT_CACHE: Dict[str, Dict[str, Any]] = {}
CACHE_KEY_PREFIX = (os.environ.get('CACHE_KEY_PREFIX', 'khonobuzz') or 'khonobuzz').strip()
REDIS_URL = (os.environ.get('REDIS_URL', '') or '').strip()
REDIS_CONNECT_TIMEOUT_SECONDS = float(os.environ.get('REDIS_CONNECT_TIMEOUT_SECONDS', '0.6'))
REDIS_SOCKET_TIMEOUT_SECONDS = float(os.environ.get('REDIS_SOCKET_TIMEOUT_SECONDS', '0.6'))
REDIS_FAILURE_THRESHOLD = int(os.environ.get('REDIS_FAILURE_THRESHOLD', '3'))
REDIS_FAILURE_COOLDOWN_SECONDS = int(os.environ.get('REDIS_FAILURE_COOLDOWN_SECONDS', '60'))
_REDIS_CLIENT: Optional[Redis] = None
_REDIS_AVAILABLE = False
_REDIS_STATE: Dict[str, Any] = {
    "consecutive_failures": 0,
    "disabled_until": 0.0,
}

# Firestore circuit breaker for quota-protection.
FIRESTORE_BREAKER_FAILURE_THRESHOLD = int(
    os.environ.get('FIRESTORE_BREAKER_FAILURE_THRESHOLD', '3')
)
FIRESTORE_BREAKER_OPEN_SECONDS = int(
    os.environ.get('FIRESTORE_BREAKER_OPEN_SECONDS', '120')
)
FIRESTORE_BREAKER_STATE: Dict[str, Any] = {
    "consecutive_failures": 0,
    "open_until": 0.0,
}


def _is_quota_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return "quota exceeded" in msg or msg.strip().startswith("429")


def _cache_get(cache_key: str) -> Optional[Any]:
    redis_value = _redis_get_json(cache_key, fresh_only=True)
    if redis_value is not None:
        return redis_value
    entry = HOT_ENDPOINT_CACHE.get(cache_key)
    if not entry:
        return None
    if entry.get("expires_at", 0) <= time.time():
        return None
    return entry.get("data")


def _cache_get_any(cache_key: str) -> Optional[Any]:
    redis_value = _redis_get_json(cache_key, fresh_only=False)
    if redis_value is not None:
        return redis_value
    entry = HOT_ENDPOINT_CACHE.get(cache_key)
    if not entry:
        return None
    return entry.get("data")


def _cache_set(cache_key: str, data: Any, ttl_seconds: int) -> None:
    _redis_set_json(cache_key, data, ttl_seconds)
    HOT_ENDPOINT_CACHE[cache_key] = {
        "data": data,
        "expires_at": time.time() + max(1, ttl_seconds),
        "updated_at": time.time(),
    }


def _cache_delete(cache_key: str) -> None:
    HOT_ENDPOINT_CACHE.pop(cache_key, None)
    if not _REDIS_AVAILABLE:
        return
    redis_client = _get_redis_client()
    if redis_client is None:
        return
    try:
        redis_client.delete(_redis_full_key(cache_key))
    except Exception as exc:
        _redis_record_failure(exc)
        debug_log(f"Redis cache delete failed for {cache_key}: {exc}")


def _cache_delete_prefix(prefix: str) -> None:
    for key in list(HOT_ENDPOINT_CACHE.keys()):
        if key.startswith(prefix):
            HOT_ENDPOINT_CACHE.pop(key, None)
    _redis_delete_prefix(prefix)


def _redis_full_key(cache_key: str) -> str:
    return f"{CACHE_KEY_PREFIX}:cache:{cache_key}"


def _redis_is_temporarily_disabled() -> bool:
    return time.time() < float(_REDIS_STATE.get("disabled_until", 0.0))


def _redis_record_success() -> None:
    _REDIS_STATE["consecutive_failures"] = 0
    _REDIS_STATE["disabled_until"] = 0.0


def _redis_record_failure(exc: Exception) -> None:
    global _REDIS_CLIENT, _REDIS_AVAILABLE
    _REDIS_CLIENT = None
    _REDIS_AVAILABLE = False
    failures = int(_REDIS_STATE.get("consecutive_failures", 0)) + 1
    _REDIS_STATE["consecutive_failures"] = failures
    if failures >= REDIS_FAILURE_THRESHOLD:
        _REDIS_STATE["disabled_until"] = time.time() + REDIS_FAILURE_COOLDOWN_SECONDS
        debug_log(
            f"Redis temporarily disabled for {REDIS_FAILURE_COOLDOWN_SECONDS}s "
            f"after {failures} failures: {exc}"
        )


def _get_redis_client() -> Optional[Redis]:
    global _REDIS_CLIENT, _REDIS_AVAILABLE
    if not REDIS_URL:
        return None
    if _redis_is_temporarily_disabled():
        return None
    if _REDIS_CLIENT is not None:
        return _REDIS_CLIENT
    try:
        _REDIS_CLIENT = Redis.from_url(
            REDIS_URL,
            decode_responses=True,
            socket_connect_timeout=REDIS_CONNECT_TIMEOUT_SECONDS,
            socket_timeout=REDIS_SOCKET_TIMEOUT_SECONDS,
        )
        _REDIS_CLIENT.ping()
        _REDIS_AVAILABLE = True
        _redis_record_success()
        info_log("Redis cache connected")
    except Exception as exc:
        _redis_record_failure(exc)
        error_log(f"Redis unavailable, using in-memory cache only: {exc}")
    return _REDIS_CLIENT


def _redis_get_json(cache_key: str, fresh_only: bool) -> Optional[Any]:
    redis_client = _get_redis_client()
    if redis_client is None:
        return None
    try:
        payload_raw = redis_client.get(_redis_full_key(cache_key))
        if not payload_raw:
            return None
        payload = json.loads(payload_raw)
        if fresh_only and float(payload.get("expires_at", 0.0)) <= time.time():
            return None
        return payload.get("data")
    except Exception as exc:
        _redis_record_failure(exc)
        debug_log(f"Redis cache get failed for {cache_key}: {exc}")
        return None


def _redis_set_json(cache_key: str, data: Any, ttl_seconds: int) -> None:
    redis_client = _get_redis_client()
    if redis_client is None:
        return
    try:
        payload = {
            "data": data,
            "expires_at": time.time() + max(1, ttl_seconds),
            "updated_at": time.time(),
        }
        # Keep stale payload around longer so stale fallback still works.
        redis_client.setex(
            _redis_full_key(cache_key),
            max(30, ttl_seconds * 4),
            json.dumps(payload, ensure_ascii=True),
        )
    except Exception as exc:
        _redis_record_failure(exc)
        debug_log(f"Redis cache set failed for {cache_key}: {exc}")


def _redis_delete_prefix(prefix: str) -> None:
    if not _REDIS_AVAILABLE:
        return
    redis_client = _get_redis_client()
    if redis_client is None:
        return
    pattern = f"{_redis_full_key(prefix)}*"
    try:
        for key in redis_client.scan_iter(match=pattern):
            redis_client.delete(key)
    except Exception as exc:
        _redis_record_failure(exc)
        debug_log(f"Redis cache prefix delete failed for {prefix}: {exc}")


def _firestore_breaker_is_open() -> bool:
    return time.time() < float(FIRESTORE_BREAKER_STATE.get("open_until", 0.0))


def _firestore_breaker_record_success() -> None:
    FIRESTORE_BREAKER_STATE["consecutive_failures"] = 0
    FIRESTORE_BREAKER_STATE["open_until"] = 0.0


def _firestore_breaker_record_failure(exc: Exception) -> None:
    if not _is_quota_error(exc):
        return
    failures = int(FIRESTORE_BREAKER_STATE.get("consecutive_failures", 0)) + 1
    FIRESTORE_BREAKER_STATE["consecutive_failures"] = failures
    if failures >= FIRESTORE_BREAKER_FAILURE_THRESHOLD:
        FIRESTORE_BREAKER_STATE["open_until"] = time.time() + FIRESTORE_BREAKER_OPEN_SECONDS

def derive_module_access_from_role(module_access: Optional[str], module_access_role: Optional[str]) -> Optional[str]:
    if module_access and module_access.strip():
        return module_access
    if not module_access_role or not module_access_role.strip():
        return None
    parts = module_access_role.split(',')
    module_names = []
    for part in parts:
        trimmed = part.strip()
        if trimmed.startswith('PDH'):
            if 'Personal Development Hub' not in module_names:
                module_names.append('Personal Development Hub')
    return ','.join(module_names) if module_names else None


def normalize_theme_preference(theme_value: Optional[str]) -> str:
    raw = (theme_value or "").strip().lower()
    return "light" if raw == "light" else "dark"


def resolve_theme_preference(user_data: Dict[str, Any], onboarding_data: Dict[str, Any]) -> str:
    # Prefer explicit onboarding preference, then user profile preference.
    return normalize_theme_preference(
        onboarding_data.get("themePreference") or user_data.get("themePreference")
    )


def _coerce_datetime(value: Any) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    try:
        candidate = value.to_datetime()  # Firestore DatetimeWithNanoseconds
        if isinstance(candidate, datetime):
            return candidate
    except Exception:
        pass
    try:
        candidate = value.toDate()  # JS-style timestamp in mixed payloads
        if isinstance(candidate, datetime):
            return candidate
    except Exception:
        pass
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        normalized = raw.replace('Z', '+00:00') if raw.endswith('Z') else raw
        try:
            return datetime.fromisoformat(normalized)
        except Exception:
            return None
    if isinstance(value, (int, float)):
        try:
            ts = float(value)
            # Accept both seconds and milliseconds epochs.
            if ts > 1e12:
                ts = ts / 1000.0
            return datetime.utcfromtimestamp(ts)
        except Exception:
            return None
    return None


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return default


def _get_best_onboarding_record(user_id: str):
    """Pick deterministic onboarding record for a user.
    Prefers canonical document id == user_id; otherwise best legacy record by recency.
    """
    canonical_ref = db.collection('onboarding').document(user_id)
    canonical_doc = canonical_ref.get(timeout=ONBOARDING_QUERY_TIMEOUT_SECONDS)
    if canonical_doc.exists:
        return canonical_ref, (canonical_doc.to_dict() or {})

    docs = list(
        db.collection('onboarding')
        .where('user_id', '==', user_id)
        .limit(5)
        .stream(timeout=ONBOARDING_QUERY_TIMEOUT_SECONDS)
    )
    if not docs:
        return canonical_ref, {}

    def _score(doc):
        data = doc.to_dict() or {}
        return (
            _coerce_datetime(data.get('updated_at'))
            or _coerce_datetime(data.get('lastSignInAt'))
            or _coerce_datetime(data.get('created_at'))
            or datetime.min
        )

    best_doc = max(docs, key=_score)
    return best_doc.reference, (best_doc.to_dict() or {})
def load_firebase_credentials(env_var_name: str, default_path: str):
    """
    Load Firebase credentials from environment variable (JSON string or base64 encoded JSON) or file path.
    Priority:
    1. Environment variable with JSON string (PDH_FIREBASE_CREDENTIALS_JSON, etc.)
    2. Environment variable with base64 encoded JSON
    3. Environment variable with file path (PDH_FIREBASE_CREDENTIALS_PATH, etc.)
    4. Default file path
    Args:
        env_var_name: Name of the environment variable (e.g., 'PDH_FIREBASE_CREDENTIALS')
        default_path: Default file path if no env var is set
    Returns:
        credentials.Certificate object
    """
    def _normalize_credential_dict(cred_dict: dict) -> dict:
        """Normalize service account fields commonly mangled in env vars."""
        normalized = dict(cred_dict)
        private_key = normalized.get('private_key')
        if isinstance(private_key, str) and private_key:
            pk = private_key.strip()
            # Remove accidental wrapping quotes from env editors.
            if (pk.startswith('"') and pk.endswith('"')) or (
                pk.startswith("'") and pk.endswith("'")
            ):
                pk = pk[1:-1]
            # Convert escaped newlines to real newlines.
            pk = pk.replace('\\r\\n', '\n').replace('\\n', '\n')
            # Ensure header/footer start on their own lines.
            pk = pk.replace(
                "-----BEGIN PRIVATE KEY----- ",
                "-----BEGIN PRIVATE KEY-----\n",
            ).replace(
                " -----END PRIVATE KEY-----",
                "\n-----END PRIVATE KEY-----",
            )
            normalized['private_key'] = pk
        return normalized

    json_env_var = f"{env_var_name}_JSON"
    literal_json_env_var = env_var_name
    json_str = None
    json_source_var = None
    for candidate_var in (json_env_var, literal_json_env_var):
        candidate_value = os.environ.get(candidate_var)
        if candidate_value is None:
            continue
        if not candidate_value.strip():
            error_log(f"{candidate_var} is set but EMPTY (only whitespace). Please set a valid JSON value.")
            continue
        json_str = candidate_value
        json_source_var = candidate_var
        debug_log(f"Checking for {candidate_var}: SET (length: {len(candidate_value)} chars)")
        break

    if not json_str:
        debug_log(f"Checking for {json_env_var}: NOT SET")
        debug_log(f"Checking for {literal_json_env_var}: NOT SET")
        possible_vars = [
            json_env_var.upper(),
            json_env_var.lower(),
            json_env_var.replace('_JSON', ''),
            f"{env_var_name}_CREDENTIALS",
            f"{env_var_name}_CREDENTIALS_JSON",
        ]
        for possible_var in possible_vars:
            if possible_var not in (json_env_var, literal_json_env_var) and possible_var in os.environ:
                debug_log(
                    f"Found similar variable '{possible_var}' but looking for "
                    f"'{json_env_var}' or '{literal_json_env_var}'"
                )

    if json_str and json_source_var:
        try:
            json_str = json_str.strip()
            # Remove surrounding quotes if present
            if (json_str.startswith('"') and json_str.endswith('"')) or \
               (json_str.startswith("'") and json_str.endswith("'")):
                json_str = json_str[1:-1]
            
            # Check for common formatting issues
            if json_str.startswith('"') and not json_str.startswith('{"'):
                error_msg = (
                    f"Invalid format in {json_source_var}. The value appears to have extra quotes.\n"
                    f"Current format starts with: {json_str[:50]}...\n"
                    f"Expected format: {{\"type\":\"service_account\",...}}\n"
                    f"Solution: Remove surrounding quotes from the environment variable in Render."
                )
                raise ValueError(error_msg)
            
            # Additional check for malformed JSON that starts with quotes but not proper JSON
            if json_str.startswith('"') and '\n' in json_str:
                error_msg = (
                    f"Invalid format in {json_source_var}. The JSON appears to be quoted with newlines.\n"
                    f"This usually happens when copying multi-line JSON into Render's environment variable field.\n"
                    f"Solution: Ensure the JSON is valid and without extra quotes.\n"
                    f"First 100 chars: {json_str[:100]}..."
                )
                raise ValueError(error_msg)
            
            # Check if it looks like base64 (starts with base64 characters)
            import re
            if re.match(r'^[A-Za-z0-9+/]+={0,2}$', json_str.strip()) and len(json_str.strip()) > 50:
                debug_log(f"{json_source_var} appears to be base64 encoded, attempting decode...")
                try:
                    json_str = base64.b64decode(json_str).decode('utf-8')
                    debug_log(f"Successfully base64 decoded {json_source_var}")
                except Exception as decode_error:
                    debug_log(f"Base64 decode failed for {json_source_var}: {decode_error}")
                    # Continue with original string
            
            debug_log(f"{json_source_var} value length: {len(json_str)} characters")
            debug_log(f"{json_source_var} starts with: {json_str[:50]}...")
            debug_log(f"{json_source_var} ends with: ...{json_str[-50:]}")
            try:
                cred_dict = json.loads(json_str)
                required_fields = ['type', 'project_id', 'private_key', 'client_email']
                missing_fields = [field for field in required_fields if field not in cred_dict]
                if missing_fields:
                    raise ValueError(f"Missing required Firebase credential fields: {missing_fields}")
                cred_dict = _normalize_credential_dict(cred_dict)
                info_log(
                    f"Using {json_source_var} as credential source for {env_var_name}"
                )
                debug_log(f"Successfully loaded credentials from {json_source_var} (direct JSON)")
                return credentials.Certificate(cred_dict)
            except json.JSONDecodeError as e:
                error_log(f"JSON decode error for {json_source_var}: {str(e)}")
                error_log(f"Error at position {e.pos if hasattr(e, 'pos') else 'unknown'}")
                debug_log(f"Direct JSON parse failed for {json_source_var}, trying base64 decode...")
                try:
                    json_str = base64.b64decode(json_str).decode('utf-8')
                    cred_dict = json.loads(json_str)
                    cred_dict = _normalize_credential_dict(cred_dict)
                    info_log(
                        f"Using {json_source_var} as credential source for {env_var_name}"
                    )
                    debug_log(f"Successfully loaded credentials from {json_source_var} (base64 decoded)")
                    return credentials.Certificate(cred_dict)
                except Exception as decode_error:
                    error_log(f"Base64 decode failed for {json_source_var}: {decode_error}")
                    error_msg = (
                        f"Invalid JSON format in {json_source_var}.\n"
                        f"JSON Parse Error: {str(e)}\n"
                        f"Make sure you copied the ENTIRE JSON content from your Firebase service account file.\n"
                        f"The value should start with '{{\"type\":\"service_account\"' and end with '}}'.\n"
                        f"Current value length: {len(json_str)} characters.\n"
                        f"Check that the value in Render is complete and not truncated."
                    )
                    raise ValueError(error_msg)
            except ValueError:
                raise
            except Exception as e:
                error_log(f"Unexpected error parsing {json_source_var}: {type(e).__name__}: {str(e)}")
                raise
        except (ValueError, json.JSONDecodeError) as e:
            error_log(f"Failed to parse credentials from {json_source_var}: {e}")
            raise
        except Exception as e:
            error_log(f"Failed to load credentials from {json_source_var}: {e}")
    path_env_var = f"{env_var_name}_PATH"
    file_path = os.environ.get(path_env_var)
    debug_log(f"Checking for {path_env_var}: {'SET' if file_path else 'NOT SET'}")
    if file_path:
        debug_log(f"Checking if file exists: {file_path}")
        script_dir = Path(__file__).parent.absolute()
        env_file_path = script_dir / file_path if not os.path.isabs(file_path) else Path(file_path)
        if os.path.exists(file_path):
            debug_log(f"Successfully loaded credentials from file: {file_path}")
            return credentials.Certificate(file_path)
        elif env_file_path.exists():
            debug_log(f"Successfully loaded credentials from file (script dir): {env_file_path}")
            return credentials.Certificate(str(env_file_path))
        else:
            error_log(f"File path specified in {path_env_var} does not exist: {file_path} (also tried: {env_file_path})")
    script_dir = Path(__file__).parent.absolute()
    default_file_path = script_dir / default_path
    debug_log(f"Checking default file path: {default_path}")
    if os.path.exists(default_path):
        debug_log(f"Successfully loaded credentials from default file (relative path): {default_path}")
        return credentials.Certificate(default_path)
    elif default_file_path.exists():
        debug_log(f"Successfully loaded credentials from default file (script dir): {default_file_path}")
        return credentials.Certificate(str(default_file_path))
    related_vars = [var for var in os.environ.keys() if 'FIREBASE' in var.upper() or 'CREDENTIAL' in var.upper()]
    error_msg = (
        f"Firebase credentials not found for {env_var_name}.\n"
        f"Please set one of the following environment variables on Render:\n"
        f"  1. {json_env_var} - JSON string (recommended for Render)\n"
        f"  2. {path_env_var} - File path to credentials JSON file\n"
        f"Or ensure the default file exists: {default_path}\n"
        f"\n"
        f"To set {json_env_var} on Render:\n"
        f"1. Go to your Render service dashboard\n"
        f"2. Navigate to Environment tab\n"
        f"3. Add new environment variable: {json_env_var}\n"
        f"4. Paste the entire JSON content from your Firebase service account file\n"
        f"5. Save and redeploy\n"
        f"\n"
        f"DEBUG INFO:\n"
        f"  Looking for: {json_env_var}\n"
        f"  Found related environment variables: {', '.join(related_vars) if related_vars else 'NONE'}\n"
        f"  Total environment variables: {len(os.environ)}"
    )
    error_log(error_msg)
    raise FileNotFoundError(error_msg)
# Initialize PDH Firebase (optional)
pdh_db = None
try:
    pdh_cred = load_firebase_credentials('PDH_FIREBASE_CREDENTIALS', 'pdh-v2-firebase-adminsdk-fbsvc-24b03c7996.json')
    pdh_app = initialize_app(pdh_cred, name='pdhApp')
    candidate_pdh_db = firestore.client(app=pdh_app)
    # Validate PDH credentials once up front; if invalid, disable PDH sync paths.
    candidate_pdh_db.collection('_health').limit(1).get()
    pdh_db = candidate_pdh_db
    info_log("PDH Firebase credentials loaded successfully")
except Exception as e:
    error_log(f"Failed to initialize PDH Firebase (continuing without it): {e}")
    info_log("Backend will continue without PDH Firebase functionality")


def _run_with_pdh_db(action_label: str, operation: Callable[[Any], None]) -> bool:
    """Run a PDH operation and disable PDH after first auth failure."""
    global pdh_db
    if pdh_db is None:
        return False
    try:
        operation(pdh_db)
        return True
    except Exception as e:
        msg = str(e).lower()
        auth_failure = (
            e.__class__.__name__ == "RefreshError"
            or "invalid_grant" in msg
            or "invalid jwt signature" in msg
        )
        if auth_failure:
            error_log(
                f"PDH auth failed during {action_label}; disabling PDH sync for this process: {e}"
            )
            pdh_db = None
        else:
            error_log(f"PDH operation failed during {action_label}: {e}")
        return False

from fastapi import Body
class UserRegister(BaseModel):
    email: str
    password: str
    name: str
    firstName: str
    lastName: str
    role: str = "user"
    department: str = ""
    designation: str = ""
    entity: Optional[str] = None
class UserLogin(BaseModel):
    email: str


class AccessPermissions(BaseModel):
    create: bool = False
    read: bool = False
    update: bool = False
    delete: bool = False
class PageAccess(BaseModel):
    user_management: AccessPermissions = AccessPermissions()
    dashboard: AccessPermissions = AccessPermissions()
    resource_allocation: AccessPermissions = AccessPermissions()
    project_data: AccessPermissions = AccessPermissions()
    reports_analytics: AccessPermissions = AccessPermissions()
    audit_logging: AccessPermissions = AccessPermissions()
    time_keeping: AccessPermissions = AccessPermissions()
class Role(BaseModel):
    roleName: str
    description: Optional[str] = None
    pageAccess: PageAccess = PageAccess()
class UserUpdate(BaseModel):
    role: Optional[str] = None
    status: Optional[str] = None
    entity: Optional[str] = None
    department: Optional[str] = None
    designation: Optional[str] = None
    manager: Optional[str] = None
    moduleAccess: Optional[str] = None
    moduleRole: Optional[str] = None
    moduleAccessRole: Optional[str] = None
    adminApproved: Optional[str] = None
    regenerateToken: Optional[bool] = None


class NameBody(BaseModel):
    name: str


class AdminNotificationCreate(BaseModel):
    actorEmail: str
    title: str
    message: str
    area: str = "general"
    details: Dict[str, Any] = {}
    targetRoles: Optional[list[str]] = None
    requiresAck: bool = False
    effectiveDateIso: str = ""


class AdminNotificationClear(BaseModel):
    role: str
    userEmail: str


class AdminNotificationDismiss(BaseModel):
    role: str
    userEmail: str
    alertId: str


class AdminNotificationAcknowledge(BaseModel):
    userEmail: str
    alertId: str
try:
    main_cred = load_firebase_credentials('FIREBASE_CREDENTIALS', 'khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json')
    initialize_app(main_cred)
    db = firestore.client()
    info_log("Main Firebase credentials loaded successfully")
except Exception as e:
    error_log(f"Failed to initialize main Firebase: {e}")
    raise
app = FastAPI(
    title="Khonology Backend API",
    description="Backend API for Khonology project management application",
    version="1.0.0",
)
@app.on_event("startup")
async def startup_warmup():
    start = time.time()
    try:
        _get_redis_client()
        if _firestore_breaker_is_open():
            info_log("Startup warm-up skipped: Firestore circuit breaker is open")
            return
        # Keep startup non-blocking: Firestore can be slow on cold starts.
        await asyncio.wait_for(
            asyncio.to_thread(lambda: db.collection('users').limit(1).get()),
            timeout=6.0,
        )
        _firestore_breaker_record_success()
        info_log(
            f"Startup warm-up Firestore users took {time.time() - start:.3f} seconds",
        )
    except asyncio.TimeoutError:
        error_log(
            "Startup warm-up timed out after 6s; continuing startup without blocking",
        )
    except Exception as e:
        _firestore_breaker_record_failure(e)
        error_log(f"Startup warm-up failed: {e}")
cors_origins_env = os.environ.get('CORS_ORIGINS', '*')
PRIMARY_FRONTEND_URL = os.environ.get(
    'FRONTEND_URL',
    'https://khono-buzz-central-hub-web.onrender.com',
).rstrip('/')
PRODUCTION_BACKEND_URLS = [
    'https://khonobuzz-central-hub.onrender.com',
]
PRODUCTION_FRONTEND_URLS = [
    PRIMARY_FRONTEND_URL,
    'https://khonobuzz-web-app-llfi.onrender.com',
    'https://khonology-buzz-build.onrender.com',
]
is_production = (
    os.environ.get('RENDER') is not None
    or os.environ.get('ENVIRONMENT') == 'production'
    or os.environ.get('NODE_ENV') == 'production'
    or 'onrender.com' in os.environ.get('RENDER_EXTERNAL_URL', '')
)
LOCALHOST_ORIGINS = [
    'http://localhost:5000',
    'http://localhost:3000',
    'http://127.0.0.1:5000',
    'http://127.0.0.1:3000',
    'http://localhost',
    'http://127.0.0.1',
    'http://10.0.2.2:5000',
]
LOCALHOST_ORIGIN_REGEX = r"http://localhost(:\d+)?|http://127\.0\.0\.1(:\d+)?"
if cors_origins_env == '*':
    if is_production:
        cors_origins = PRODUCTION_FRONTEND_URLS + LOCALHOST_ORIGINS
        cors_allow_credentials = True
        info_log(f"Production mode: CORS configured for {len(cors_origins)} origins")
    else:
        cors_origins = PRODUCTION_FRONTEND_URLS + LOCALHOST_ORIGINS
        cors_allow_credentials = True
        info_log(f"Development mode: CORS configured for {len(cors_origins)} origins")
else:
    cors_origins = [origin.strip() for origin in cors_origins_env.split(',')]
    for prod_url in PRODUCTION_FRONTEND_URLS:
        if prod_url not in cors_origins:
            cors_origins.append(prod_url)
    if not is_production:
        for localhost_origin in LOCALHOST_ORIGINS:
            if localhost_origin not in cors_origins:
                cors_origins.append(localhost_origin)
    cors_allow_credentials = os.environ.get(
        'CORS_ALLOW_CREDENTIALS',
        'True' if is_production else 'False',
    ).lower() == 'true'
    info_log(
        f"CORS configured with {len(cors_origins)} origins from CORS_ORIGINS env var",
    )
# In production, pin CORS to explicit origins only.
# In development, still allow localhost origins with arbitrary ports.
cors_origin_regex = None if is_production else LOCALHOST_ORIGIN_REGEX
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_origin_regex=cors_origin_regex,
    allow_credentials=cors_allow_credentials,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)
app.add_middleware(BrotliMiddleware)
app.add_middleware(GZipMiddleware, minimum_size=500)
@app.middleware("http")
async def log_requests(request, call_next):
    """Log all incoming requests"""
    start_time = datetime.utcnow()
    should_log = request.url.path != "/api/version"
    if should_log:
        info_log(
            f"→ {request.method} {request.url.path} from {request.client.host if request.client else 'unknown'}"
        )
    if DEBUG_MODE and should_log and request.query_params:
        debug_log(f"  Query params: {dict(request.query_params)}")
    response = await call_next(request)
    process_time = (datetime.utcnow() - start_time).total_seconds()
    if should_log:
        info_log(
            f"← {request.method} {request.url.path} - {response.status_code} ({process_time:.3f}s)"
        )
    return response


@app.middleware("http")
async def enforce_cors_headers(request, call_next):
    """Ensure CORS headers are present for every cross-origin response."""
    response = await call_next(request)
    response.headers.update(_cors_headers_for_request(request))
    return response
@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "ok",
        "message": "Khonology Backend API is running",
        "environment": "production" if is_production else "development",
        "cors_origins_count": len(cors_origins) if cors_origins != ["*"] else "all",
    }
@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }


def _cors_headers_for_request(request: Request) -> dict:
    """Return CORS headers so browser allows the response (avoids net::ERR_FAILED 200)."""
    origin = request.headers.get("origin") or ""
    if not origin:
        return {}

    allow_origin = False
    if origin in cors_origins:
        allow_origin = True
    elif cors_origin_regex:
        try:
            allow_origin = re.match(cors_origin_regex, origin) is not None
        except re.error:
            allow_origin = False

    if allow_origin:
        return {
            "Access-Control-Allow-Origin": (
                PRIMARY_FRONTEND_URL if is_production else origin
            ),
            "Access-Control-Allow-Credentials": "true",
            "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Vary": "Origin",
        }
    return {}

@app.get("/api/version")
async def get_version(request: Request):
    """
    Returns version.json content so the app can display the latest version without rebuild.
    Reads from VERSION_JSON_PATH env, or repo root version.json when running from backend/.
    """
    try:
        path_str = os.environ.get("VERSION_JSON_PATH")
        if path_str:
            path = Path(path_str)
        else:
            # Default: version.json in repo root (parent of backend/)
            path = (Path(__file__).resolve().parent.parent / "version.json")
        # region agent log
        append_agent_debug_log(
            "H3",
            "backend/fastapi_app.py:445",
            "Resolved version.json path for /api/version",
            {
                "cwd": str(Path.cwd()),
                "path": str(path),
                "exists": path.exists(),
                "versionJsonPathEnvSet": bool(path_str),
                "origin": request.headers.get("origin", ""),
            },
        )
        # endregion
        if not path.exists():
            # region agent log
            append_agent_debug_log(
                "H3",
                "backend/fastapi_app.py:458",
                "version.json missing; returning safe fallback payload",
                {
                    "path": str(path),
                },
            )
            # endregion
            fallback_payload = {
                "version": "2026.03.AB1",
                "last_feature_commit": "",
                "feature_date": "",
                "commit_count_since_feature": 1,
            }
            response = JSONResponse(content=fallback_payload)
            response.headers["X-Version-Cache"] = "FALLBACK"
            response.headers.update(_cors_headers_for_request(request))
            return response

        now = time.time()
        mtime = path.stat().st_mtime
        # Serve cached version.json if still valid.
        if (
            _VERSION_JSON_CACHE.get("data") is not None
            and _VERSION_JSON_CACHE.get("mtime") == mtime
            and now < float(_VERSION_JSON_CACHE.get("expires_at", 0.0))
        ):
            response = JSONResponse(content=_VERSION_JSON_CACHE["data"])
            response.headers["X-Version-Cache"] = "HIT"
            response.headers.update(_cors_headers_for_request(request))
            return response

        raw = path.read_text(encoding="utf-8")
        data = json.loads(raw)

        # Update cache after successful parse.
        _VERSION_JSON_CACHE["data"] = data
        _VERSION_JSON_CACHE["mtime"] = mtime
        _VERSION_JSON_CACHE["expires_at"] = now + VERSION_JSON_CACHE_TTL_SECONDS
        # region agent log
        append_agent_debug_log(
            "H5",
            "backend/fastapi_app.py:470",
            "Loaded version.json for /api/version",
            {
                "path": str(path),
                "version": data.get("version"),
                "featureDate": data.get("feature_date"),
            },
        )
        # endregion
        response = JSONResponse(content=data)
        response.headers["X-Version-Cache"] = "MISS"
        response.headers.update(_cors_headers_for_request(request))
        return response
    except Exception as e:
        error_log(f"Failed to serve version: {e}")
        resp = JSONResponse(status_code=500, content={"error": "Failed to load version"})
        resp.headers.update(_cors_headers_for_request(request))
        return resp


class TokenValidationRequest(BaseModel):
    token: str


def _validate_token_internal(token: str):
    try:
        payload = verify_token(token)
        user_id = payload.get('user_id') or payload.get('uid', '')
        user_data = None
        if user_id:
            try:
                user_doc = db.collection('users').document(user_id).get()
                if user_doc.exists:
                    user_data = user_doc.to_dict()
            except Exception as e:
                print(f"[WARNING] Failed to fetch user data during token validation: {e}")
        return {
            "valid": True,
            "payload": payload,
            "user": user_data,
        }, 200
    except jwt.ExpiredSignatureError:
        return {
            "valid": False,
            "error": "Token has expired",
        }, 401
    except jwt.InvalidTokenError as e:
        return {
            "valid": False,
            "error": f"Invalid token: {str(e)}",
        }, 400
    except Exception as e:
        return {
            "valid": False,
            "error": f"Token validation failed: {str(e)}",
        }, 500


@app.post("/validate-token")
async def validate_token(request: TokenValidationRequest):
    start_time = time.time()
    try:
        result, status_code = _validate_token_internal(request.token)
        return JSONResponse(status_code=status_code, content=result)
    except Exception as e:
        error_log(f"Error during token validation (POST): {e}")
        return JSONResponse(
            status_code=500,
            content={"valid": False, "error": "Token validation failed"},
        )
    finally:
        elapsed_time = time.time() - start_time
        info_log(f"Token validation (POST) took {elapsed_time:.3f} seconds")


@app.get("/validate-token")
async def validate_token_get(token: str = Query(..., description="Token to validate")):
    start_time = time.time()
    try:
        result, status_code = _validate_token_internal(token)
        return JSONResponse(status_code=status_code, content=result)
    except Exception as e:
        error_log(f"Error during token validation (GET): {e}")
        return JSONResponse(
            status_code=500,
            content={"valid": False, "error": "Token validation failed"},
        )
    finally:
        elapsed_time = time.time() - start_time
        info_log(f"Token validation (GET) took {elapsed_time:.3f} seconds")

@app.post("/api/pdh/sync-user")
async def pdh_sync_user(data: dict):
    try:
        uid = data['uid']
        user_data = data['userData']
        onboarding_data = data['onboardingData']
        for key in ['created_at', 'updated_at']:
            if key in user_data and isinstance(user_data[key], str):
                user_data[key] = datetime.fromisoformat(user_data[key].replace('Z', '+00:00'))
        for key in ['created_at', 'updated_at', 'first_valid', 'last_valid']:
            if key in onboarding_data and isinstance(onboarding_data[key], str):
                onboarding_data[key] = datetime.fromisoformat(onboarding_data[key].replace('Z', '+00:00'))
        module_access_role = onboarding_data.get('moduleAccessRole', '') or user_data.get('moduleAccessRole', '')
        user_email = user_data.get('email', '') or onboarding_data.get('email', '')
        if user_email and not onboarding_data.get('email'):
            onboarding_data['email'] = user_email
        roles = parse_module_access_role_to_roles(module_access_role)
        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or user_data.get('firstName') or ''
        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or user_data.get('lastName') or ''
        full_name = f"{first_name} {last_name}".strip()
        if not full_name:
            full_name = user_data.get('name', '')
        onboarding_data['fullName'] = full_name
        if 'token' not in onboarding_data or not onboarding_data.get('token'):
            if module_access_role and user_email:
                try:
                    encrypted_token = generate_and_encrypt_token(
                        user_id=uid,
                        email=user_email,
                        full_name=full_name,
                        roles=roles,
                        theme_preference=resolve_theme_preference(
                            user_data,
                            onboarding_data,
                        ),
                    )
                    onboarding_data['token'] = encrypted_token
                    onboarding_data['token_updated_at'] = datetime.utcnow()
                    print(f"[DEBUG] Token generated during PDH sync for user_id: {uid} with roles: {roles}")
                except Exception as token_error:
                    print(f"[ERROR] Failed to generate token during PDH sync: {token_error}")
        if not _run_with_pdh_db(
            "pdh_sync_user",
            lambda pdh: (
                pdh.collection('users').document(uid).set(user_data, merge=True),
                pdh.collection('onboarding').document(uid).set(onboarding_data, merge=True),
            ),
        ):
            print("[WARNING] PDH Firebase not initialized, skipping sync")
        sync_sso_user_login(uid, user_data, onboarding_data)
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "PDH sync successful"})
    except Exception as e:
        print(f"[ERROR] During PDH sync: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
@app.patch("/api/pdh/update-user/{uid}")
async def pdh_update_user(uid: str, data: dict):
    try:
        user_fields = data.get('userFields')
        onboarding_fields = data.get('onboardingFields')
        should_regenerate_token = False
        new_module_access_role = ''
        user_email = ''
        user_fields_dict = user_fields or {}
        if onboarding_fields and 'moduleAccessRole' in onboarding_fields:
            should_regenerate_token = True
            new_module_access_role = onboarding_fields.get('moduleAccessRole', '')
        elif user_fields and 'moduleAccessRole' in user_fields:
            should_regenerate_token = True
            new_module_access_role = user_fields.get('moduleAccessRole', '')
        if user_fields and _run_with_pdh_db(
            "pdh_update_user.users",
            lambda pdh: pdh.collection('users').document(uid).set(user_fields, merge=True),
        ):
            user_email = user_fields.get('email', '')
        if onboarding_fields:
            if not user_email:
                user_email = onboarding_fields.get('email', '')
            if user_email and not onboarding_fields.get('email'):
                onboarding_fields['email'] = user_email
            roles = parse_module_access_role_to_roles(new_module_access_role)
            first_name = onboarding_fields.get('firstName') or onboarding_fields.get('name') or user_fields_dict.get('firstName') or ''
            last_name = onboarding_fields.get('lastName') or onboarding_fields.get('surname') or user_fields_dict.get('lastName') or ''
            full_name = f"{first_name} {last_name}".strip()
            if not full_name:
                full_name = user_fields_dict.get('name', '')
            onboarding_fields['fullName'] = full_name
            if should_regenerate_token and user_email:
                try:
                    encrypted_token = generate_and_encrypt_token(
                        user_id=uid,
                        email=user_email,
                        full_name=full_name,
                        roles=roles,
                        theme_preference=resolve_theme_preference(
                            user_fields_dict,
                            onboarding_fields,
                        ),
                    )
                    onboarding_fields['token'] = encrypted_token
                    onboarding_fields['token_updated_at'] = datetime.utcnow()
                    print(f"[DEBUG] Token regenerated during PDH update for user_id: {uid} with roles: {roles}")
                except Exception as token_error:
                    print(f"[ERROR] Failed to regenerate token during PDH update: {token_error}")
            _run_with_pdh_db(
                "pdh_update_user.onboarding",
                lambda pdh: pdh.collection('onboarding').document(uid).set(onboarding_fields, merge=True),
            )
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "PDH update successful"})
    except Exception as e:
        print(f"[ERROR] During PDH update: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.patch("/api/onboarding/update-user/{uid}")
async def onboarding_update_user(uid: str, data: dict):
    try:
        onboarding_fields = data.get('onboardingFields') or {}
        if not isinstance(onboarding_fields, dict) or not onboarding_fields:
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content={"error": "onboardingFields is required"},
            )

        onboarding_query = (
            db.collection('onboarding').where('user_id', '==', uid).limit(1).stream()
        )
        onboarding_doc = None
        for doc in onboarding_query:
            onboarding_doc = doc
            break

        payload = dict(onboarding_fields)
        payload['user_id'] = uid
        payload['updated_at'] = datetime.utcnow()

        if onboarding_doc is not None:
            onboarding_doc.reference.set(payload, merge=True)
        else:
            payload['created_at'] = datetime.utcnow()
            db.collection('onboarding').add(payload)

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"message": "Onboarding update successful"},
        )
    except Exception as e:
        print(f"[ERROR] During onboarding update: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.get("/")
async def home():
    info_log("Health check endpoint accessed")
    return {"message": "Khonology Backend API (FastAPI)", "status": "running"}


@app.get("/api/users/by-email")
async def get_user_by_email(email: str = Query(..., description="User email address")):
    try:
        normalized_email = email.lower().strip()
        users_ref = db.collection('users')
        query = users_ref.where('email', '==', normalized_email).limit(1)
        users = query.get()
        if not users:
            print(f"[DEBUG] get_user_by_email: User not found: {normalized_email}")
            return JSONResponse(
                status_code=status.HTTP_404_NOT_FOUND,
                content={"error": "User not found"},
            )

        user_doc = users[0]
        user_info = user_doc.to_dict() or {}
        user_id = user_doc.id

        _, onboarding_info = _get_best_onboarding_record(user_id)

        # Only use onboarding for profile/name if it belongs to this user (avoid returning another user's data)
        onboarding_email = (onboarding_info.get('email') or '').strip().lower()
        safe_onboarding = onboarding_info if (not onboarding_email or onboarding_email == normalized_email) else {}

        # If profile image URL/ID clearly belong to another user (e.g. path contains other email), do not use onboarding for name/profile
        profile_url = (safe_onboarding.get('profileImageUrl') or '').strip()
        profile_id = (safe_onboarding.get('profileImagePublicId') or '').strip()
        encoded_email = normalized_email.replace('@', '%40')
        url_belongs = (not profile_url) or (normalized_email in profile_url.lower()) or (encoded_email in profile_url)
        id_belongs = (not profile_id) or (normalized_email in profile_id.lower()) or (encoded_email in profile_id)
        if not url_belongs or not id_belongs:
            safe_onboarding = {}  # use user_info only for name/profile so we never return another user's data

        module_access_raw = user_info.get('moduleAccess') or onboarding_info.get('moduleAccess', '')
        module_access_role_raw = user_info.get('moduleAccessRole') or onboarding_info.get('moduleAccessRole', '')

        entity_value = user_info.get('entity') or onboarding_info.get('entity') or ''
        response_user = {
            'email': user_info.get('email', normalized_email),
            'role': user_info.get('role', ''),
            'status': user_info.get('status', 'Pending'),
            'entity': entity_value,
            'moduleAccess': module_access_raw or '',
            'moduleAccessRole': module_access_role_raw or '',
            'firstName': safe_onboarding.get('firstName') or user_info.get('firstName') or user_info.get('name', '').split(' ')[0],
            'lastName': safe_onboarding.get('lastName') or safe_onboarding.get('surname') or user_info.get('lastName') or (user_info.get('name', '').split(' ')[1] if ' ' in user_info.get('name', '') else ''),
            'surname': safe_onboarding.get('surname') or safe_onboarding.get('lastName') or user_info.get('lastName') or '',
            'preferredName': safe_onboarding.get('preferredName') or user_info.get('preferredName') or '',
            'phoneNumber': safe_onboarding.get('phoneNumber') or user_info.get('phoneNumber') or '',
            'department': safe_onboarding.get('department') or user_info.get('department') or '',
            'designation': safe_onboarding.get('designation') or user_info.get('designation') or '',
            'managedBy': safe_onboarding.get('managedBy') or user_info.get('manager') or onboarding_info.get('manager') or '',
            'profileImageUrl': safe_onboarding.get('profileImageUrl') or '',
            'profileImagePublicId': safe_onboarding.get('profileImagePublicId') or '',
            'themePreference': (
                safe_onboarding.get('themePreference')
                or user_info.get('themePreference')
                or 'dark'
            ),
            'lastSignInAt': (
                (
                    _coerce_datetime(
                        user_info.get('lastSignInAt') or onboarding_info.get('lastSignInAt')
                    )
                ).isoformat() + 'Z'
            ) if _coerce_datetime(user_info.get('lastSignInAt') or onboarding_info.get('lastSignInAt')) else None,
            'loginCount': _safe_int(
                onboarding_info.get('loginCount', user_info.get('loginCount', 0)),
                0,
            ),
        }

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={'user': response_user},
        )
    except Exception as e:
        print(f"[ERROR] get_user_by_email failed for {email}: {e}")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": str(e)},
        )

@app.put("/api/admin/users/{email}/profile")
async def admin_update_user_profile(email: str, data: Dict[str, Any] = Body(...)):
    """
    Update a user's profile information in both 'users' and 'onboarding' collections.
    This endpoint is used by Admin and Staff profile screens.
    """
    try:
        normalized_email = email.lower().strip()
        
        # 1. Find the user in the 'users' collection
        users_ref = db.collection('users')
        query = users_ref.where('email', '==', normalized_email).limit(1).stream()
        user_id = None
        user_doc_ref = None
        
        for doc in query:
            user_id = doc.id
            user_doc_ref = users_ref.document(user_id)
            break
            
        if not user_id:
            return JSONResponse(
                status_code=status.HTTP_404_NOT_FOUND,
                content={"error": "User not found"}
            )

        # Extract update fields (partial updates supported)
        first_name = (data.get('firstName') if 'firstName' in data else data.get('name'))
        last_name = (
            data.get('surname')
            if 'surname' in data
            else (data.get('lastName') if 'lastName' in data else None)
        )
        preferred_name = data.get('preferredName') if 'preferredName' in data else None
        department = data.get('department') if 'department' in data else None
        designation = data.get('designation') if 'designation' in data else None
        phone_number = data.get('phoneNumber') if 'phoneNumber' in data else None
        managed_by = (
            data.get('managedBy')
            if 'managedBy' in data
            else (data.get('manager') if 'manager' in data else None)
        )
        profile_image_url = data.get('profileImageUrl') if 'profileImageUrl' in data else None
        profile_image_public_id = (
            data.get('profileImagePublicId') if 'profileImagePublicId' in data else None
        )
        theme_preference = (data.get('themePreference') or '').strip().lower()
        if theme_preference not in ('light', 'dark'):
            theme_preference = ''
        full_name = ''
        if first_name is not None or last_name is not None:
            full_name = f"{(first_name or '').strip()} {(last_name or '').strip()}".strip()
        elif preferred_name:
            full_name = str(preferred_name).strip()

        # 2. Update 'users' collection
        user_update = {'updated_at': datetime.utcnow()}
        if department is not None:
            user_update['department'] = department
        if designation is not None:
            user_update['designation'] = designation
        if managed_by is not None:
            user_update['manager'] = managed_by
        if theme_preference:
            user_update['themePreference'] = theme_preference
        if full_name:
            user_update['name'] = full_name
            
        if user_doc_ref:
            user_doc_ref.update(user_update)

        # 3. Update 'onboarding' collection
        onboarding_query = (
            db.collection('onboarding')
            .where('user_id', '==', user_id)
            .limit(1)
            .stream()
        )
        onboarding_doc_ref = None
        for ondoc in onboarding_query:
            onboarding_doc_ref = ondoc.reference
            break

        onboarding_update = {'updated_at': datetime.utcnow(), 'email': normalized_email}
        if first_name is not None:
            onboarding_update['firstName'] = first_name
        if last_name is not None:
            onboarding_update['lastName'] = last_name
            onboarding_update['surname'] = last_name
        if preferred_name is not None:
            onboarding_update['preferredName'] = preferred_name
        if full_name:
            onboarding_update['fullName'] = full_name
        if department is not None:
            onboarding_update['department'] = department
        if designation is not None:
            onboarding_update['designation'] = designation
        if phone_number is not None:
            onboarding_update['phoneNumber'] = phone_number
        if managed_by is not None:
            onboarding_update['managedBy'] = managed_by
        if profile_image_url is not None:
            onboarding_update['profileImageUrl'] = profile_image_url
        if profile_image_public_id is not None:
            onboarding_update['profileImagePublicId'] = profile_image_public_id
        if theme_preference:
            onboarding_update['themePreference'] = theme_preference

        if onboarding_doc_ref:
            onboarding_doc_ref.update(onboarding_update)
        else:
            # Create onboarding doc if it doesn't exist
            db.collection('onboarding').add({
                **onboarding_update,
                'user_id': user_id,
                'created_at': datetime.utcnow(),
            })

        regenerated_token = None
        if theme_preference:
            try:
                refreshed_user_doc = users_ref.document(user_id).get()
                refreshed_user = refreshed_user_doc.to_dict() or {}
                _, refreshed_onboarding = _get_best_onboarding_record(user_id)
                module_access_role = (
                    refreshed_user.get('moduleAccessRole')
                    or refreshed_onboarding.get('moduleAccessRole', '')
                )
                roles = parse_module_access_role_to_roles(module_access_role)
                resolved_first = (
                    refreshed_onboarding.get('firstName')
                    or refreshed_onboarding.get('name')
                    or refreshed_user.get('firstName')
                    or ''
                )
                resolved_last = (
                    refreshed_onboarding.get('lastName')
                    or refreshed_onboarding.get('surname')
                    or refreshed_user.get('lastName')
                    or ''
                )
                resolved_full_name = f"{resolved_first} {resolved_last}".strip()
                if not resolved_full_name:
                    resolved_full_name = refreshed_user.get('name', '')

                regenerated_token = generate_and_encrypt_token(
                    user_id=user_id,
                    email=normalized_email,
                    full_name=resolved_full_name,
                    roles=roles,
                    theme_preference=theme_preference,
                )

                token_update_payload = {
                    'token': regenerated_token,
                    'token_updated_at': datetime.utcnow(),
                    'fullName': resolved_full_name,
                    'email': normalized_email,
                    'themePreference': theme_preference,
                    'updated_at': datetime.utcnow(),
                }
                db.collection('onboarding').document(user_id).set(
                    {'user_id': user_id, **token_update_payload},
                    merge=True,
                )
                _run_with_pdh_db(
                    "admin_update_user_profile.token_sync",
                    lambda pdh: pdh.collection('onboarding').document(user_id).set(
                        {
                            'email': normalized_email,
                            'token': regenerated_token,
                            'fullName': resolved_full_name,
                            'token_updated_at': datetime.utcnow(),
                            'themePreference': theme_preference,
                            'updated_at': datetime.utcnow(),
                        },
                        merge=True,
                    ),
                )
            except Exception as token_error:
                print(f"[ERROR] admin_update_user_profile token refresh failed: {token_error}")

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "message": "Profile updated successfully",
                **({"token": regenerated_token} if regenerated_token else {}),
            }
        )
        
    except Exception as e:
        print(f"[ERROR] admin_update_user_profile: {e}")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": str(e)}
        )

@app.post("/api/auth/register")
async def register_user(user: UserRegister):
    try:
        print(f"[DEBUG] Raw incoming JSON data (FastAPI): {user.model_dump()}")
        email = user.email
        password = user.password
        first_name = user.firstName.strip() if user.firstName else ''
        last_name = user.lastName.strip() if user.lastName else ''
        full_name = f"{first_name} {last_name}".strip()
        if not full_name:
            full_name = user.name.strip() if user.name else ''
        role = user.role
        department = user.department
        designation = user.designation
        print(f"[DEBUG] Extracted email (FastAPI): {email}")
        print(f"[DEBUG] Extracted password (FastAPI): {password}")
        print(f"[DEBUG] Parsed first_name (from Pydantic): {first_name}")
        print(f"[DEBUG] Parsed last_name (from Pydantic): {last_name}")
        print(f"[DEBUG] Constructed full_name (firstName + lastName): {full_name}")
        print(f"[DEBUG] Role (from Pydantic): {role}")
        print(f"[DEBUG] Department (from Pydantic): {department}")
        print(f"[DEBUG] Designation (from Pydantic): {designation}")
        email_stripped = email.strip() if email else ''
        if email_stripped and not email_stripped.lower().endswith('@khonology.com'):
            return JSONResponse(
                status_code=400,
                content={"error": "Only Khonology work emails (@khonology.com) are allowed"}
            )
        if not email or not password or not full_name:
            return JSONResponse(status_code=400, content={"error": "Email, password, and name required"})
        normalized_email = email.lower().strip()
        users_ref = db.collection('users')
        all_users = users_ref.stream()
        for user_doc in all_users:
            doc_data = user_doc.to_dict()
            doc_email = doc_data.get('email', '').strip() if doc_data.get('email') else ''
            if doc_email.lower() == normalized_email:
                return JSONResponse(status_code=409, content={"error": "User already exists"})
        entity_value = user.entity if user.entity is not None else ''
        print(f"[DEBUG] Entity value for new user: '{entity_value}' (type: {type(entity_value)})")
        user_data = {
            'email': normalized_email,
            'password': password,
            'name': full_name,
            'role': role,
            'status': 'Pending',
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow(),
            'entity': entity_value,
            'department': department,
            'designation': designation,
            'moduleAccess': '',
            'moduleRole': '',
            'moduleAccessRole': '',
            'themePreference': 'dark',
        }
        print(f"[DEBUG] User data being sent to Firestore (users collection - FastAPI): {user_data}")
        doc_ref = users_ref.add(user_data)
        user_id = doc_ref[1].id
        print(f"[DEBUG] Firestore doc_ref for users (FastAPI): {doc_ref}, User ID: {user_id}")
        module_role = ''
        roles = parse_module_access_role_to_roles(module_role)
        encrypted_token = None
        try:
            encrypted_token = generate_and_encrypt_token(
                user_id=user_id,
                email=normalized_email,
                full_name=full_name,
                roles=roles,
                theme_preference="dark",
            )
            print(f"[DEBUG] Token generated for new user: {user_id} with roles: {roles}")
        except Exception as token_error:
            print(f"[ERROR] Failed to generate token during registration: {token_error}")
        onboarding_data = {
            'user_id': user_id,
            'email': normalized_email,
            'name': first_name,
            'surname': last_name,
            'fullName': full_name.strip(),
            'department': department,
            'designation': designation,
            'first_valid': datetime(2025, 9, 25, 0, 0, 0),
            'inserted_by': normalized_email,
            'last_valid': datetime(2039, 12, 31, 0, 0, 0),
            'onboarding_id': user_id,
            'status_id': "",
            'updated_by': normalized_email,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow(),
            'entity': entity_value,
            'moduleAccess': '',
            'moduleRole': '',
            'moduleAccessRole': '',
            'themePreference': 'dark',
        }
        if encrypted_token:
            onboarding_data['token'] = encrypted_token
            onboarding_data['token_updated_at'] = datetime.utcnow()
        print(f"[DEBUG] Onboarding data being sent to Firestore (onboarding collection - FastAPI): {onboarding_data}")
        db.collection('onboarding').add(onboarding_data)
        sync_sso_user_login(user_id, user_data, onboarding_data)
        response_content = {
            "message": "User created successfully",
            "user": {
                "id": user_id,
                "email": normalized_email,
                "name": full_name,
                "role": role
            }
        }
        if encrypted_token:
            response_content["token"] = encrypted_token
        return JSONResponse(
            status_code=status.HTTP_201_CREATED,
            content=response_content
        )
    except Exception as e:
        print(f"[ERROR] During FastAPI registration: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
@app.get("/api/users")
async def list_users():
    cache_key = "users:list"
    fresh_cache = _cache_get(cache_key)
    if fresh_cache is not None:
        return JSONResponse(status_code=status.HTTP_200_OK, content={'users': fresh_cache})
    if _firestore_breaker_is_open():
        stale_cache = _cache_get_any(cache_key)
        if stale_cache is not None:
            return JSONResponse(status_code=status.HTTP_200_OK, content={'users': stale_cache})
        return JSONResponse(status_code=429, content={"error": "Firestore temporarily throttled"})
    try:
        users_query = db.collection('users').stream()
        users_with_sort_keys = []
        for user_doc in users_query:
            user_info = user_doc.to_dict() or {}
            _, onboarding_info = _get_best_onboarding_record(user_doc.id)
            first_name = onboarding_info.get('firstName') or onboarding_info.get('name') or ''
            last_name = onboarding_info.get('lastName') or onboarding_info.get('surname') or ''
            created_at_dt = _coerce_datetime(user_info.get('created_at'))
            updated_at_dt = _coerce_datetime(user_info.get('updated_at'))
            last_sign_in_dt = _coerce_datetime(
                user_info.get('lastSignInAt') or onboarding_info.get('lastSignInAt')
            )
            login_count_val = onboarding_info.get('loginCount')
            if login_count_val is None:
                login_count_val = user_info.get('loginCount')
            login_count = _safe_int(login_count_val, 0)
            try:
                doc_create = getattr(user_doc, 'create_time', None)
                doc_update = getattr(user_doc, 'update_time', None)
            except Exception:
                doc_create = None
                doc_update = None
            if created_at_dt is None:
                if isinstance(doc_create, datetime):
                    created_at_dt = doc_create
                elif isinstance(doc_update, datetime):
                    created_at_dt = doc_update
            if updated_at_dt is None:
                if isinstance(doc_update, datetime):
                    updated_at_dt = doc_update
                elif created_at_dt is not None:
                    updated_at_dt = created_at_dt
                elif isinstance(doc_create, datetime):
                    updated_at_dt = doc_create
            created_at_str = created_at_dt.isoformat() + 'Z' if created_at_dt else None
            updated_at_str = updated_at_dt.isoformat() + 'Z' if updated_at_dt else None
            last_sign_in_str = last_sign_in_dt.isoformat() + 'Z' if last_sign_in_dt else None
            module_access_raw = user_info.get('moduleAccess') or onboarding_info.get('moduleAccess', '')
            module_access_role_raw = user_info.get('moduleAccessRole') or onboarding_info.get('moduleAccessRole', '')
            final_module_access = derive_module_access_from_role(module_access_raw, module_access_role_raw)
            profile_image_url = onboarding_info.get('profileImageUrl') or user_info.get('profileImageUrl') or ''
            user_payload = {
                'id': user_doc.id,
                'email': user_info.get('email', ''),
                'role': user_info.get('role', 'Staff'),
                'status': user_info.get('status', 'Active'),
                'firstName': first_name,
                'lastName': last_name,
                'department': onboarding_info.get('department', ''),
                'designation': onboarding_info.get('designation', ''),
                'entity': user_info.get('entity') or onboarding_info.get('entity', ''),
                'manager': user_info.get('manager') or onboarding_info.get('manager', ''),
                'moduleAccess': final_module_access or '',
                'moduleRole': user_info.get('moduleRole') or onboarding_info.get('moduleRole', ''),
                'moduleAccessRole': module_access_role_raw or '',
                'profileImageUrl': profile_image_url,
                'createdAt': created_at_str,
                'updatedAt': updated_at_str,
                'lastSignInAt': last_sign_in_str,
                'loginCount': login_count,
            }
            sort_key = updated_at_dt or created_at_dt
            users_with_sort_keys.append((sort_key, user_payload))
        users_with_sort_keys.sort(key=lambda item: item[0] or datetime.min, reverse=True)
        users_data = [payload for _, payload in users_with_sort_keys]
        _firestore_breaker_record_success()
        _cache_set(cache_key, users_data, USERS_CACHE_TTL_SECONDS)
        return JSONResponse(status_code=status.HTTP_200_OK, content={'users': users_data})
    except Exception as e:
        _firestore_breaker_record_failure(e)
        msg = str(e)
        print(f"[ERROR] During users fetch: {msg}")
        if _is_quota_error(e):
            stale_cache = _cache_get_any(cache_key)
            if stale_cache is not None:
                return JSONResponse(status_code=status.HTTP_200_OK, content={'users': stale_cache})
            return JSONResponse(status_code=429, content={"error": "Quota exceeded"})
        return JSONResponse(status_code=500, content={"error": str(e)})
@app.patch("/api/users/{user_id}")
async def update_user(user_id: str, request: Request, user_update: UserUpdate = Body(...)):
    try:
        session_header = request.headers.get('X-Session-Type', '')
        is_special_session = session_header == 'special'
        update_payload = {}
        if user_update.role is not None:
            update_payload['role'] = user_update.role
        if user_update.status is not None:
            update_payload['status'] = user_update.status
        if user_update.entity is not None:
            update_payload['entity'] = user_update.entity
        if user_update.department is not None:
            update_payload['department'] = user_update.department
        if user_update.designation is not None:
            update_payload['designation'] = user_update.designation
        if user_update.manager is not None:
            update_payload['manager'] = user_update.manager
        if user_update.moduleAccess is not None:
            update_payload['moduleAccess'] = user_update.moduleAccess
        if user_update.moduleRole is not None:
            update_payload['moduleRole'] = user_update.moduleRole
        if user_update.moduleAccessRole is not None:
            update_payload['moduleAccessRole'] = user_update.moduleAccessRole
        if user_update.adminApproved is not None and not is_special_session:
            update_payload['admin'] = {'approved': user_update.adminApproved}
        if not update_payload:
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content={'error': 'No valid fields provided for update'},
            )
        if not is_special_session:
            update_payload['updated_at'] = datetime.utcnow()
        user_ref = db.collection('users').document(user_id)
        current_user_doc = user_ref.get()
        current_user_data = current_user_doc.to_dict() or {}
        user_ref.update(update_payload)
        onboarding_update_payload = {'user_id': user_id}
        if not is_special_session:
            onboarding_update_payload['updated_at'] = datetime.utcnow()
        if user_update.role is not None:
            onboarding_update_payload['role'] = user_update.role
        if user_update.status is not None:
            onboarding_update_payload['status'] = user_update.status
        if user_update.entity is not None:
            onboarding_update_payload['entity'] = user_update.entity
        if user_update.department is not None:
            onboarding_update_payload['department'] = user_update.department
        if user_update.designation is not None:
            onboarding_update_payload['designation'] = user_update.designation
        if user_update.manager is not None:
            onboarding_update_payload['manager'] = user_update.manager
        if user_update.moduleAccess is not None:
            onboarding_update_payload['moduleAccess'] = user_update.moduleAccess
        if user_update.moduleRole is not None:
            onboarding_update_payload['moduleRole'] = user_update.moduleRole
        if user_update.moduleAccessRole is not None:
            onboarding_update_payload['moduleAccessRole'] = user_update.moduleAccessRole
        if user_update.adminApproved is not None and not is_special_session:
            onboarding_update_payload['admin'] = {'approved': user_update.adminApproved}
        should_regenerate_token = user_update.moduleAccessRole is not None and (user_update.regenerateToken is True)
        if len(onboarding_update_payload) > 1:
            onboarding_ref, onboarding_data = _get_best_onboarding_record(user_id)
            onboarding_ref.set(onboarding_update_payload, merge=True)
            if should_regenerate_token:
                try:
                    print(f"[DEBUG] Regenerating token for user_id: {user_id} due to moduleAccessRole update")
                    refreshed_onboarding_doc = onboarding_ref.get()
                    refreshed_onboarding = refreshed_onboarding_doc.to_dict() or {}
                    user_email = current_user_data.get('email', '') or refreshed_onboarding.get('email', '')
                    new_module_access_role = user_update.moduleAccessRole or ''
                    roles = parse_module_access_role_to_roles(new_module_access_role)
                    first_name = (
                        refreshed_onboarding.get('firstName')
                        or refreshed_onboarding.get('name')
                        or current_user_data.get('firstName')
                        or ''
                    )
                    last_name = (
                        refreshed_onboarding.get('lastName')
                        or refreshed_onboarding.get('surname')
                        or current_user_data.get('lastName')
                        or ''
                    )
                    full_name = f"{first_name} {last_name}".strip()
                    if not full_name:
                        full_name = current_user_data.get('name', '') or refreshed_onboarding.get('name', '')
                    encrypted_token = generate_and_encrypt_token(
                        user_id=user_id,
                        email=user_email,
                        full_name=full_name,
                        roles=roles,
                        theme_preference=resolve_theme_preference(
                            current_user_data,
                            refreshed_onboarding,
                        ),
                    )
                    update_data = {
                        'user_id': user_id,
                        'token': encrypted_token,
                        'token_updated_at': datetime.utcnow(),
                        'fullName': full_name,
                        'updated_at': datetime.utcnow(),
                    }
                    if user_email:
                        update_data['email'] = user_email
                    onboarding_ref.set(update_data, merge=True)
                    print(f"[DEBUG] Token regenerated and updated in main onboarding collection for user_id: {user_id}")
                    # Sync new token to PDH
                    if _run_with_pdh_db(
                        "update_user.token_sync",
                        lambda pdh: pdh.collection('onboarding').document(user_id).set(
                            {
                                'email': user_email,
                                'token': encrypted_token,
                                'fullName': full_name,
                                'token_updated_at': datetime.utcnow(),
                                'updated_at': datetime.utcnow(),
                            },
                            merge=True,
                        ),
                    ):
                        print(f"[DEBUG] New token synced to PDH onboarding collection for user_id: {user_id}")
                    else:
                        print("[WARNING] PDH Firebase not initialized, skipping token sync")
                except Exception as token_error:
                    print(f"[ERROR] Failed to regenerate token: {token_error}")
        updated_doc = user_ref.get()
        updated_data = updated_doc.to_dict() or {}
        _, onboarding_info = _get_best_onboarding_record(user_id)
        first_name = onboarding_info.get('firstName') or onboarding_info.get('name') or ''
        last_name = onboarding_info.get('lastName') or onboarding_info.get('surname') or ''
        created_at_dt = _coerce_datetime(updated_data.get('created_at'))
        updated_at_dt = _coerce_datetime(updated_data.get('updated_at'))
        last_sign_in_dt = _coerce_datetime(
            updated_data.get('lastSignInAt') or onboarding_info.get('lastSignInAt')
        )
        login_count_val = onboarding_info.get('loginCount')
        if login_count_val is None:
            login_count_val = updated_data.get('loginCount')
        login_count = _safe_int(login_count_val, 0)
        created_at_str = created_at_dt.isoformat() + 'Z' if created_at_dt else None
        updated_at_str = updated_at_dt.isoformat() + 'Z' if updated_at_dt else None
        last_sign_in_str = last_sign_in_dt.isoformat() + 'Z' if last_sign_in_dt else None
        user_payload = {
            'id': user_id,
            'email': updated_data.get('email', ''),
            'role': updated_data.get('role', 'Staff'),
            'status': updated_data.get('status', 'Active'),
            'firstName': first_name,
            'lastName': last_name,
            'department': onboarding_info.get('department', ''),
            'designation': onboarding_info.get('designation', ''),
            'entity': updated_data.get('entity') or onboarding_info.get('entity', ''),
            'manager': updated_data.get('manager') or onboarding_info.get('manager', ''),
            'moduleAccess': updated_data.get('moduleAccess') or onboarding_info.get('moduleAccess', ''),
            'moduleRole': updated_data.get('moduleRole') or onboarding_info.get('moduleRole', ''),
            'moduleAccessRole': updated_data.get('moduleAccessRole') or onboarding_info.get('moduleAccessRole', ''),
            'createdAt': created_at_str,
            'updatedAt': updated_at_str,
            'lastSignInAt': last_sign_in_str,
            'loginCount': login_count,
        }
        _cache_delete("users:list")
        return JSONResponse(status_code=status.HTTP_200_OK, content={'message': 'User updated successfully', 'user': user_payload})
    except Exception as e:
        msg = str(e)
        if "quota exceeded" in msg.lower() or msg.strip().startswith("429"):
            return JSONResponse(status_code=429, content={"error": "Quota exceeded"})
        return JSONResponse(status_code=500, content={"error": str(e)})
@app.delete("/api/users/{user_id}")
async def delete_user(user_id: str):
    try:
        print(f"[DEBUG] delete_user called for user_id={user_id}")
        user_ref = db.collection('users').document(user_id)
        user_doc = user_ref.get()
        if not user_doc.exists:
            return JSONResponse(
                status_code=status.HTTP_404_NOT_FOUND,
                content={'error': f'User {user_id} not found in users collection'},
            )
        user_ref.delete()
        print(f"[DEBUG] Deleted user {user_id} from users collection")
        onboarding_query = (
            db.collection('onboarding')
            .where('user_id', '==', user_id)
            .limit(1)
            .stream()
        )
        for onboarding_doc in onboarding_query:
            onboarding_doc.reference.delete()
            print(f"[DEBUG] Deleted user {user_id} from onboarding collection")
            break
        onboarding_doc_ref = db.collection('onboarding').document(user_id)
        onboarding_doc = onboarding_doc_ref.get()
        if onboarding_doc.exists:
            onboarding_doc_ref.delete()
            print(f"[DEBUG] Deleted user {user_id} from onboarding collection (by document ID)")
        _run_with_pdh_db(
            "delete_user.pdh_cleanup",
            lambda pdh: (
                (lambda ref: (ref.delete() if ref.get().exists else None))(pdh.collection('users').document(user_id)),
                (lambda ref: (ref.delete() if ref.get().exists else None))(pdh.collection('onboarding').document(user_id)),
                next(
                    (
                        (doc.reference.delete(), doc)[1]
                        for doc in pdh.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
                    ),
                    None,
                ),
            ),
        )

        _cache_delete("users:list")
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"message": f"User {user_id} deleted successfully"}
        )
    except Exception as e:
        print(f"[ERROR] During user deletion: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.get("/api/departments")
async def list_departments():
    """Return all department names from both Firestore collections."""
    try:
        names = []
        for collection_name in ("departments", "department"):
            docs = list(db.collection(collection_name).stream())
            docs.sort(
                key=lambda doc: (
                    _coerce_datetime((doc.to_dict() or {}).get("created_at"))
                    or datetime.min
                ),
                reverse=True,
            )
            for doc in docs:
                data = doc.to_dict() or {}
                n = (data.get("name") or "").strip()
                if n and n not in names:
                    names.append(n)
        return JSONResponse(status_code=200, content={"departments": names})
    except Exception as e:
        print(f"[ERROR] list_departments: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/departments")
async def create_department(body: NameBody):
    """Add a new department to canonical collection. Returns merged updated list."""
    try:
        name = (body.name or "").strip()
        if not name:
            raise HTTPException(status_code=400, detail="name is required")
        coll = db.collection("departments")
        existing = coll.where("name", "==", name).limit(1).stream()
        if next(existing, None) is not None:
            pass
        else:
            coll.add({"name": name, "created_at": datetime.utcnow()})
        names = []
        for collection_name in ("departments", "department"):
            docs = list(db.collection(collection_name).stream())
            docs.sort(
                key=lambda doc: (
                    _coerce_datetime((doc.to_dict() or {}).get("created_at"))
                    or datetime.min
                ),
                reverse=True,
            )
            for doc in docs:
                data = doc.to_dict() or {}
                n = (data.get("name") or "").strip()
                if n and n not in names:
                    names.append(n)
        return JSONResponse(status_code=201, content={"departments": names})
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] create_department: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.get("/api/designations")
async def list_designations():
    """Return all designation names with newest created options first."""
    try:
        names = []
        for collection_name in ("designations", "designation"):
            docs = list(db.collection(collection_name).stream())
            docs.sort(
                key=lambda doc: (
                    _coerce_datetime((doc.to_dict() or {}).get("created_at"))
                    or datetime.min
                ),
                reverse=True,
            )
            for doc in docs:
                data = doc.to_dict() or {}
                n = (data.get("name") or "").strip()
                if n and n not in names:
                    names.append(n)
        return JSONResponse(status_code=200, content={"designations": names})
    except Exception as e:
        print(f"[ERROR] list_designations: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.get("/api/entities")
async def list_entities():
    """Return all entity names from entities collection plus assigned users."""
    try:
        names = []

        # Canonical entity options collection.
        for doc in db.collection("entities").stream():
            data = doc.to_dict() or {}
            n = (data.get("name") or "").strip()
            if n and n not in names:
                names.append(n)

        # Include already-assigned entity values so legacy data stays selectable.
        for doc in db.collection("users").stream():
            data = doc.to_dict() or {}
            n = (data.get("entity") or "").strip()
            if n and n not in names:
                names.append(n)

        names.sort(key=str.lower)
        return JSONResponse(status_code=200, content={"entities": names})
    except Exception as e:
        print(f"[ERROR] list_entities: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/entities")
async def create_entity(body: NameBody):
    """Add a new entity in canonical entities collection. Returns updated list."""
    try:
        name = (body.name or "").strip()
        if not name:
            raise HTTPException(status_code=400, detail="name is required")

        coll = db.collection("entities")
        existing = coll.where("name", "==", name).limit(1).stream()
        if next(existing, None) is None:
            coll.add({"name": name})

        names = []
        for doc in coll.stream():
            data = doc.to_dict() or {}
            n = (data.get("name") or "").strip()
            if n and n not in names:
                names.append(n)
        for doc in db.collection("users").stream():
            data = doc.to_dict() or {}
            n = (data.get("entity") or "").strip()
            if n and n not in names:
                names.append(n)

        names.sort(key=str.lower)
        return JSONResponse(status_code=201, content={"entities": names})
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] create_entity: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/admin/notifications")
async def create_admin_notification(payload: AdminNotificationCreate):
    try:
        actor_email = (payload.actorEmail or "").strip().lower()
        title = (payload.title or "").strip()
        message = (payload.message or "").strip()
        area = (payload.area or "general").strip()
        target_roles = payload.targetRoles or ["admin", "staff"]
        normalized_roles = sorted(
            {
                str(role).strip().lower()
                for role in target_roles
                if str(role).strip()
            }
        )
        if not actor_email or not title or not message:
            raise HTTPException(
                status_code=400,
                detail="actorEmail, title and message are required",
            )
        if not normalized_roles:
            normalized_roles = ["admin", "staff"]

        now = datetime.utcnow()
        details_payload = payload.details or {}
        if "targetCount" not in details_payload:
            details_payload["targetCount"] = len(normalized_roles)
        doc = {
            "actorEmail": actor_email,
            "actorRole": "admin",
            "title": title,
            "message": message,
            "area": area,
            "details": details_payload,
            "targetRoles": normalized_roles,
            "requiresAck": bool(getattr(payload, "requiresAck", False)),
            "effectiveDateIso": (getattr(payload, "effectiveDateIso", "") or "").strip(),
            "acknowledgedByEmails": [],
            "createdAt": firestore.SERVER_TIMESTAMP,
            "createdAtIso": now.isoformat() + "Z",
        }
        ref = db.collection("admin_notifications").document()
        ref.set(doc)
        _cache_delete_prefix("admin_notifications:")
        return JSONResponse(
            status_code=201,
            content={
                "message": "Notification created",
                "id": ref.id,
                "createdAtIso": doc["createdAtIso"],
            },
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] create_admin_notification: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.get("/api/admin/notifications")
async def list_admin_notifications(
    role: str = Query(...),
    userEmail: str = Query(""),
    limit: int = Query(30, ge=1, le=200),
):
    normalized_role = (role or "").strip().lower()
    normalized_email = (userEmail or "").strip().lower()
    cache_limit = min(limit, 60)
    cache_key = f"admin_notifications:{normalized_role}:{normalized_email}:{cache_limit}"
    fresh_cache = _cache_get(cache_key)
    if fresh_cache is not None:
        return JSONResponse(status_code=200, content={"alerts": fresh_cache[:limit]})
    if _firestore_breaker_is_open():
        stale_cache = _cache_get_any(cache_key)
        if stale_cache is not None:
            return JSONResponse(status_code=200, content={"alerts": stale_cache[:limit]})
        return JSONResponse(status_code=429, content={"error": "Firestore temporarily throttled"})
    try:
        if not normalized_role:
            raise HTTPException(status_code=400, detail="role is required")
        if normalized_role == "staff":
            limit = min(limit, 30)

        # Avoid composite-index requirement from array_contains + order_by by
        # querying role matches first, then sorting in memory.
        query = db.collection("admin_notifications").where(
            "targetRoles",
            "array_contains",
            normalized_role,
        )
        docs = list(query.stream())

        cleared_after = None
        dismissed_ids = set()
        if normalized_email:
            state_doc = db.collection("admin_notification_state").document(normalized_email).get()
            if state_doc.exists:
                state = state_doc.to_dict() or {}
                cleared_after = _coerce_datetime(state.get("clearedAtIso"))
                dismissed_ids = set(state.get("dismissedIds", []) or [])

        alerts = []
        for doc in docs:
            data = doc.to_dict() or {}
            created_at = _coerce_datetime(data.get("createdAt"))
            created_at_iso = data.get("createdAtIso")
            if not created_at_iso:
                created_at_iso = (
                    created_at.isoformat() + "Z" if created_at else datetime.utcnow().isoformat() + "Z"
                )
            alerts.append(
                {
                    "id": doc.id,
                    "actorEmail": data.get("actorEmail", ""),
                    "title": data.get("title", "Admin update"),
                    "message": data.get("message", ""),
                    "area": data.get("area", "general"),
                    "details": data.get("details", {}),
                    "targetRoles": data.get("targetRoles", []),
                    "requiresAck": bool(data.get("requiresAck", False)),
                    "effectiveDateIso": (data.get("effectiveDateIso", "") or "").strip(),
                    "acknowledgedByEmails": data.get("acknowledgedByEmails", []) or [],
                    "createdAtIso": created_at_iso,
                }
            )

        alerts.sort(
            key=lambda item: _coerce_datetime(item.get("createdAtIso")) or datetime.min,
            reverse=True,
        )
        if cleared_after is not None:
            alerts = [
                item
                for item in alerts
                if (_coerce_datetime(item.get("createdAtIso")) or datetime.min) > cleared_after
            ]
        alerts = [item for item in alerts if item.get("id") not in dismissed_ids]

        for item in alerts:
            acked_emails = [
                (e or "").strip().lower() for e in item.get("acknowledgedByEmails", [])
            ]
            item["acknowledged"] = normalized_email in acked_emails if normalized_email else False
            item["acknowledgedCount"] = len(acked_emails)
            item["targetCount"] = int(item.get("details", {}).get("targetCount", 0))
            item.pop("acknowledgedByEmails", None)
        _firestore_breaker_record_success()
        _cache_set(cache_key, alerts, ADMIN_NOTIFICATIONS_CACHE_TTL_SECONDS)
        alerts = alerts[:limit]

        return JSONResponse(status_code=200, content={"alerts": alerts})
    except HTTPException:
        raise
    except Exception as e:
        _firestore_breaker_record_failure(e)
        msg = str(e)
        print(f"[ERROR] list_admin_notifications: {msg}")
        if _is_quota_error(e):
            stale_cache = _cache_get_any(cache_key)
            if stale_cache is not None:
                return JSONResponse(status_code=200, content={"alerts": stale_cache[:limit]})
            return JSONResponse(status_code=429, content={"error": "Quota exceeded"})
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/admin/notifications/clear")
async def clear_admin_notifications(payload: AdminNotificationClear):
    try:
        normalized_role = (payload.role or "").strip().lower()
        normalized_email = (payload.userEmail or "").strip().lower()
        if not normalized_role or not normalized_email:
            raise HTTPException(
                status_code=400,
                detail="role and userEmail are required",
            )
        now_iso = datetime.utcnow().isoformat() + "Z"
        db.collection("admin_notification_state").document(normalized_email).set(
            {
                "role": normalized_role,
                "userEmail": normalized_email,
                "clearedAtIso": now_iso,
                "updatedAtIso": now_iso,
                "dismissedIds": [],
            },
            merge=True,
        )
        _cache_delete_prefix("admin_notifications:")
        return JSONResponse(status_code=200, content={"message": "Alerts cleared"})
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] clear_admin_notifications: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/admin/notifications/dismiss")
async def dismiss_admin_notification(payload: AdminNotificationDismiss):
    try:
        normalized_email = (payload.userEmail or "").strip().lower()
        alert_id = (payload.alertId or "").strip()
        if not normalized_email or not alert_id:
            raise HTTPException(status_code=400, detail="userEmail and alertId are required")
        db.collection("admin_notification_state").document(normalized_email).set(
            {
                "dismissedIds": firestore.ArrayUnion([alert_id]),
                "updatedAtIso": datetime.utcnow().isoformat() + "Z",
            },
            merge=True,
        )
        _cache_delete_prefix("admin_notifications:")
        return JSONResponse(status_code=200, content={"message": "Alert dismissed"})
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] dismiss_admin_notification: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/admin/notifications/ack")
async def acknowledge_admin_notification(payload: AdminNotificationAcknowledge):
    try:
        normalized_email = (payload.userEmail or "").strip().lower()
        alert_id = (payload.alertId or "").strip()
        if not normalized_email or not alert_id:
            raise HTTPException(status_code=400, detail="userEmail and alertId are required")
        ref = db.collection("admin_notifications").document(alert_id)
        ref.set(
            {
                "acknowledgedByEmails": firestore.ArrayUnion([normalized_email]),
                "updatedAtIso": datetime.utcnow().isoformat() + "Z",
            },
            merge=True,
        )
        _cache_delete_prefix("admin_notifications:")
        return JSONResponse(status_code=200, content={"message": "Alert acknowledged"})
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] acknowledge_admin_notification: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/designations")
async def create_designation(body: NameBody):
    """Add a new designation; store in Firestore collection. Returns updated list."""
    try:
        name = (body.name or "").strip()
        if not name:
            raise HTTPException(status_code=400, detail="name is required")
        coll = db.collection("designations")
        existing = coll.where("name", "==", name).limit(1).stream()
        if next(existing, None) is not None:
            pass
        else:
            coll.add({"name": name, "created_at": datetime.utcnow()})
        names = []
        for collection_name in ("designations", "designation"):
            docs = list(db.collection(collection_name).stream())
            docs.sort(
                key=lambda doc: (
                    _coerce_datetime((doc.to_dict() or {}).get("created_at"))
                    or datetime.min
                ),
                reverse=True,
            )
            for doc in docs:
                data = doc.to_dict() or {}
                n = (data.get("name") or "").strip()
                if n and n not in names:
                    names.append(n)
        return JSONResponse(status_code=201, content={"designations": names})
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] create_designation: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/roles")
async def create_role(role: Role):
    try:
        role_data = role.model_dump()
        role_data['created_at'] = datetime.utcnow()
        role_data['updated_at'] = datetime.utcnow()
        db.collection('roles').add(role_data)
        return JSONResponse(
            status_code=status.HTTP_201_CREATED,
            content={
                "message": "Role created successfully",
                "role": role_data,
            },
        )
    except Exception as e:
        print(f"[ERROR] During role creation: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
@app.post("/api/create_initial_roles")
async def create_initial_roles():
    roles_data = [
        {
            "roleName": "staff",
            "pageAccess": {
                "user_management": {"create": False, "read": False, "update": False, "delete": False},
                "dashboard": {"create": False, "read": True, "update": False, "delete": False},
                "resource_allocation": {"create": False, "read": False, "update": False, "delete": False},
                "project_data": {"create": False, "read": False, "update": False, "delete": False},
                "reports_analytics": {"create": False, "read": True, "update": False, "delete": False},
                "audit_logging": {"create": False, "read": False, "update": False, "delete": False},
                "time_keeping": {"create": False, "read": False, "update": False, "delete": False},
            },
        },
        {
            "roleName": "admin",
            "description": "Strategic administrator with full system access except for deletion.",
            "pageAccess": {
                "user_management": {"create": True, "read": True, "update": True, "delete": False},
                "dashboard": {"create": True, "read": True, "update": True, "delete": False},
                "resource_allocation": {"create": True, "read": True, "update": True, "delete": False},
                "project_data": {"create": True, "read": True, "update": True, "delete": False},
                "reports_analytics": {"create": True, "read": True, "update": True, "delete": False},
                "audit_logging": {"create": True, "read": True, "update": True, "delete": False},
                "time_keeping": {"create": True, "read": True, "update": True, "delete": False},
            },
        },
        {
            "roleName": "manager",
            "pageAccess": {
                "user_management": {"create": False, "read": False, "update": False, "delete": False},
                "dashboard": {"create": True, "read": True, "update": True, "delete": False},
                "resource_allocation": {"create": True, "read": True, "update": True, "delete": False},
                "project_data": {"create": True, "read": True, "update": True, "delete": False},
                "reports_analytics": {"create": False, "read": False, "update": False, "delete": False},
                "audit_logging": {"create": True, "read": True, "update": True, "delete": False},
                "time_keeping": {"create": False, "read": False, "update": False, "delete": False},
            },
        },
    ]
    try:
        for role_data in roles_data:
            role_obj = Role(**role_data)
            db.collection('roles').add({
                **role_obj.model_dump(),
                'created_at': datetime.utcnow(),
                'updated_at': datetime.utcnow(),
                'first_valid': datetime(2025, 9, 25, 2, 6, 42),
                'last_valid': datetime(2039, 12, 31, 2, 6, 29),
            })
        return JSONResponse(status_code=status.HTTP_201_CREATED, content={"message": "Initial roles created successfully"})
    except Exception as e:
        print(f"[ERROR] During initial role creation: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/auth/login")
async def login_user(user_login: UserLogin, request: Request):
    request_start = time.time()
    user_lookup_start = None
    user_lookup_end = None
    onboarding_lookup_start = None
    onboarding_lookup_end = None
    token_gen_start = None
    token_gen_end = None
    try:
        session_header = request.headers.get('X-Session-Type', '')
        is_special_session = session_header == 'special'
        if not user_login.email or not user_login.email.strip():
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content={"error": "Email is required"}
            )
        email_input = user_login.email.strip()
        if not email_input.lower().endswith('@khonology.com'):
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content={"error": "Only Khonology work emails (@khonology.com) are allowed"}
            )
        normalized_email = user_login.email.lower().strip()
        if not is_special_session:
            info_log(f"Login attempt for email: {normalized_email}")
        users_ref = db.collection('users')
        user_lookup_start = time.time()
        user_data = None
        user_id = None
        stored_email = None
        cache_key = f"user:{normalized_email}"
        cache_entry = USER_CACHE.get(cache_key)
        now = time.time()
        if cache_entry and cache_entry.get("expires_at", 0) > now:
            user_data = cache_entry.get("user_data")
            user_id = cache_entry.get("user_id")
            stored_email = cache_entry.get("stored_email")
            debug_log(f"Login cache hit for {normalized_email}")
        else:
            try:
                query = users_ref.where('email', '==', normalized_email).limit(1)
                users = await asyncio.wait_for(
                    asyncio.to_thread(query.get, timeout=LOGIN_QUERY_TIMEOUT_SECONDS),
                    timeout=LOGIN_QUERY_TIMEOUT_SECONDS + 1.0,
                )
                if users:
                    user_doc = users[0]
                    doc_data = user_doc.to_dict()
                    doc_email = doc_data.get('email', '').strip() if doc_data.get('email') else ''
                    user_data = doc_data
                    user_id = user_doc.id
                    stored_email = doc_email
                    USER_CACHE[cache_key] = {
                        "user_data": user_data,
                        "user_id": user_id,
                        "stored_email": stored_email,
                        "expires_at": now + LOGIN_CACHE_TTL_SECONDS,
                    }
                    debug_log(f"Login cache populated for {normalized_email}")
            except asyncio.TimeoutError:
                user_lookup_end = time.time()
                if not is_special_session:
                    error_log(
                        f"Firestore user lookup timed out for {normalized_email} "
                        f"after {LOGIN_QUERY_TIMEOUT_SECONDS:.1f}s"
                    )
                return JSONResponse(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    content={"error": "Login service temporarily unavailable. Please try again."}
                )
            except Exception as query_error:
                user_lookup_end = time.time()
                if not is_special_session:
                    error_log(f"Firestore query error during login: {query_error}")
                return JSONResponse(
                    status_code=500,
                    content={"error": f"Database query failed: {str(query_error)}"}
                )
        user_lookup_end = time.time()
        if not user_data or not user_id:
            print(f"[DEBUG] User not found: {normalized_email}")
            return JSONResponse(status_code=404, content={"error": "User not found"})
        # Ensure we never return another user's data: response must match requested email
        resolved_email = (user_data.get("email") or stored_email or "").strip().lower()
        if resolved_email != normalized_email:
            error_log(f"Login user mismatch: requested {normalized_email}, resolved {resolved_email}")
            if cache_key in USER_CACHE:
                del USER_CACHE[cache_key]
            return JSONResponse(
                status_code=500,
                content={"error": "Authentication error. Please try again."},
            )
        user_status = user_data.get('status', 'Pending')
        if not is_special_session and user_status != 'Active':
            return JSONResponse(
                status_code=status.HTTP_403_FORBIDDEN,
                content={
                    "error": f"Your account status is '{user_status}'. Please wait for admin approval to activate your account.",
                    "status": user_status
                }
            )
        onboarding_data = {}
        onboarding_ref = None
        module_access_role = ""
        onboarding_lookup_start = time.time()
        try:
            onboarding_ref, onboarding_data = await asyncio.wait_for(
                asyncio.to_thread(_get_best_onboarding_record, user_id),
                timeout=ONBOARDING_QUERY_TIMEOUT_SECONDS + 1.0,
            )
            module_access_role = (
                onboarding_data.get('moduleAccessRole', '')
                or user_data.get('moduleAccessRole', '')
            )
        except asyncio.TimeoutError:
            error_log(
                f"Onboarding lookup timed out for user {user_id} "
                f"after {ONBOARDING_QUERY_TIMEOUT_SECONDS:.1f}s"
            )
        except Exception as onboarding_query_error:
            error_log(f"Failed to query onboarding collection: {onboarding_query_error}")
        onboarding_lookup_end = time.time()
        # Only use onboarding for name/profile in response if it belongs to this user (avoid returning another user's data)
        onboarding_email = (onboarding_data.get('email') or '').strip().lower()
        safe_onboarding_for_response = onboarding_data if (not onboarding_email or onboarding_email == normalized_email) else {}
        if not module_access_role:
            module_access_role = user_data.get('moduleAccessRole', '')
        roles = parse_module_access_role_to_roles(module_access_role)
        if is_special_session:
            roles = ['admin']
        last_sign_in_at = datetime.utcnow()
        login_count = 0
        first_name = safe_onboarding_for_response.get('firstName') or safe_onboarding_for_response.get('name') or user_data.get('firstName') or ''
        last_name = safe_onboarding_for_response.get('lastName') or safe_onboarding_for_response.get('surname') or user_data.get('lastName') or ''
        full_name = f"{first_name} {last_name}".strip()
        if not full_name:
            full_name = user_data.get('name', '')
        encrypted_token = None
        token_gen_start = time.time()
        try:
            encrypted_token = generate_and_encrypt_token(
                user_id=user_id,
                email=user_data['email'],
                full_name=full_name,
                roles=roles,
                theme_preference=resolve_theme_preference(
                    user_data,
                    onboarding_data,
                ),
            )
        except Exception:
            pass
        token_gen_end = time.time()
        if not is_special_session:
            try:
                current_user_login_count = user_data.get('loginCount', 0)
                try:
                    current_user_login_count = int(current_user_login_count)
                except Exception:
                    current_user_login_count = 0
                db.collection('users').document(user_id).update({
                    'lastSignInAt': last_sign_in_at,
                    'loginCount': current_user_login_count + 1,
                    'updated_at': datetime.utcnow(),
                })
                user_data['lastSignInAt'] = last_sign_in_at
                user_data['loginCount'] = current_user_login_count + 1
            except Exception as sign_in_error:
                error_log(f"Failed to update login tracking for {normalized_email}: {sign_in_error}")
        if encrypted_token:
            try:
                if onboarding_ref is None:
                    onboarding_ref = db.collection('onboarding').document(user_id)
                update_data = {
                    'user_id': user_id,
                    'token': encrypted_token,
                    'token_updated_at': datetime.utcnow(),
                    'fullName': full_name,
                    'email': user_data['email'],
                    'themePreference': resolve_theme_preference(
                        user_data,
                        onboarding_data,
                    ),
                }
                if not is_special_session:
                    update_data['updated_at'] = datetime.utcnow()
                    if not onboarding_data:
                        update_data['created_at'] = datetime.utcnow()
                onboarding_ref.set(update_data, merge=True)
            except Exception:
                pass
            pdh_data = {
                'email': user_data['email'],
                'token': encrypted_token,
                'fullName': full_name,
                'token_updated_at': datetime.utcnow(),
                'themePreference': resolve_theme_preference(
                    user_data,
                    onboarding_data,
                ),
            }
            if not is_special_session:
                pdh_data['updated_at'] = datetime.utcnow()
            _run_with_pdh_db(
                "login_user.token_sync",
                lambda pdh: pdh.collection('onboarding').document(user_id).set(pdh_data, merge=True),
            )
        if not is_special_session:
            try:
                if onboarding_ref is None:
                    onboarding_ref, onboarding_info = await asyncio.wait_for(
                        asyncio.to_thread(_get_best_onboarding_record, user_id),
                        timeout=ONBOARDING_QUERY_TIMEOUT_SECONDS + 1.0,
                    )
                else:
                    onboarding_info = onboarding_data or {}
                existing_login_count = _safe_int(
                    onboarding_info.get('loginCount', user_data.get('loginCount', 0)),
                    0,
                )
                login_count = existing_login_count + 1
                tracking_payload = {
                    'user_id': user_id,
                    'email': user_data.get('email', ''),
                    'lastSignInAt': last_sign_in_at,
                    'loginCount': login_count,
                    'updated_at': datetime.utcnow(),
                }
                if onboarding_ref is not None:
                    onboarding_ref.set(tracking_payload, merge=True)
                else:
                    tracking_payload['created_at'] = datetime.utcnow()
                    db.collection('onboarding').document(user_id).set(
                        tracking_payload,
                        merge=True,
                    )
                _run_with_pdh_db(
                    "login_user.signin_tracking",
                    lambda pdh: pdh.collection('onboarding').document(user_id).set(
                        {
                            'email': user_data.get('email', ''),
                            'lastSignInAt': last_sign_in_at,
                            'loginCount': login_count,
                            'updated_at': datetime.utcnow(),
                        },
                        merge=True,
                    ),
                )
            except Exception as onboarding_signin_error:
                error_log(
                    f"Failed to update onboarding login tracking for {normalized_email}: {onboarding_signin_error}"
                )
        else:
            login_count = 0
        module_access_raw = user_data.get('moduleAccess') or onboarding_data.get('moduleAccess', '')
        final_module_access = derive_module_access_from_role(module_access_raw, module_access_role)
        response_name = full_name or user_data.get('name', '')
        response_profile_url = safe_onboarding_for_response.get('profileImageUrl', '')
        response_profile_public_id = safe_onboarding_for_response.get('profileImagePublicId', '')
        response_theme_preference = (
            safe_onboarding_for_response.get('themePreference')
            or user_data.get('themePreference')
            or 'dark'
        )
        response_content = {
            "message": "Login successful",
            "user": {
                "id": user_id,
                "email": user_data['email'],
                "name": response_name,
                "role": "Admin" if is_special_session else user_data.get('role', 'user'),
                "status": user_status,
                "moduleAccess": final_module_access or '',
                "moduleAccessRole": module_access_role,
                "profileImageUrl": response_profile_url,
                "profileImagePublicId": response_profile_public_id,
                "themePreference": response_theme_preference,
                "lastSignInAt": last_sign_in_at.isoformat() + 'Z',
                "loginCount": login_count,
            }
        }
        if encrypted_token:
            response_content["token"] = encrypted_token
        else:
            response_content["token_warning"] = "Token generation failed. Please fetch token via /api/auth/token endpoint."
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=response_content
        )
    except HTTPException as e:
        return JSONResponse(status_code=e.status_code, content={"error": e.detail})
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"Login failed: {str(e)}"}
        )
    finally:
        total_duration = time.time() - request_start
        if user_lookup_start is not None and user_lookup_end is not None:
            info_log(
                f"/api/auth/login user lookup took "
                f"{user_lookup_end - user_lookup_start:.3f} seconds",
            )
        if onboarding_lookup_start is not None and onboarding_lookup_end is not None:
            info_log(
                f"/api/auth/login onboarding lookup took "
                f"{onboarding_lookup_end - onboarding_lookup_start:.3f} seconds",
            )
        if token_gen_start is not None and token_gen_end is not None:
            info_log(
                f"/api/auth/login token generation took "
                f"{token_gen_end - token_gen_start:.3f} seconds",
            )
        info_log(f"/api/auth/login completed in {total_duration:.3f} seconds")
@app.get("/api/auth/token")
async def get_user_token(
    email: str = Query(..., description="User email address"),
    module: Optional[str] = Query(None, description="Target app: 'recruitment' or 'arw' for ARW token with roles like ARW - Admin, ARW - Hiring Manager"),
    theme: Optional[str] = Query(None, description="Theme override: 'light' or 'dark'"),
):
    """
    Generate a fresh encrypted token for a user by email.
    When module=recruitment (or arw), the token payload roles are mapped to ARW format
    (e.g. ARW - Admin, ARW - Hiring Manager) for the Automated Recruitment Workflow app;
    the token is returned only and not saved to onboarding/PDH.
    Otherwise, a normal PDH token is generated and synced to onboarding/PDH.
    """
    try:
        info_log(f"Token generation request for email: {email}, module: {module}")
        users_ref = db.collection('users')
        query = users_ref.where('email', '==', email).limit(1)
        users = query.get()
        if not users:
            print(f"[DEBUG] User not found: {email}")
            return JSONResponse(status_code=404, content={"error": "User not found"})
        user_id = users[0].id
        user_data = users[0].to_dict()
        onboarding_ref, onboarding_data = _get_best_onboarding_record(user_id)
        module_access_role = ""
        onboarding_doc_ref = onboarding_ref
        module_access_role = onboarding_data.get('moduleAccessRole', '') or user_data.get('moduleAccessRole', '')
        is_arw = module and module.strip().lower() in ("recruitment", "arw")
        if is_arw:
            roles = parse_module_access_role_to_arw_roles(module_access_role)
            print(f"[DEBUG] Generating ARW token for user_id: {user_id} with roles: {roles}")
        else:
            roles = parse_module_access_role_to_roles(module_access_role)
            print(f"[DEBUG] Generating fresh token for user_id: {user_id} with roles: {roles}")
        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or user_data.get('firstName') or ''
        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or user_data.get('lastName') or ''
        full_name = f"{first_name} {last_name}".strip()
        if not full_name:
            full_name = user_data.get('name', '')
        try:
            requested_theme = normalize_theme_preference(theme) if theme else None
            token_theme = requested_theme or resolve_theme_preference(
                user_data,
                onboarding_data,
            )
            encrypted_token = generate_and_encrypt_token(
                user_id=user_id,
                email=user_data['email'],
                full_name=full_name,
                roles=roles,
                theme_preference=token_theme,
            )
            if not is_arw:
                if onboarding_doc_ref:
                    onboarding_doc_ref.update({
                        'token': encrypted_token,
                        'token_updated_at': datetime.utcnow(),
                        'updated_at': datetime.utcnow(),
                        'fullName': full_name,
                        'email': user_data['email'],
                    })
                    print(f"[DEBUG] Token updated in main onboarding collection for user_id: {user_id}")
                else:
                    onboarding_data = {
                        'user_id': user_id,
                        'email': user_data['email'],
                        'token': encrypted_token,
                        'fullName': full_name,
                        'token_updated_at': datetime.utcnow(),
                        'created_at': datetime.utcnow(),
                        'updated_at': datetime.utcnow(),
                        'moduleAccessRole': module_access_role,
                        'themePreference': token_theme,
                    }
                    db.collection('onboarding').add(onboarding_data)
                    print(f"[DEBUG] Created onboarding document with token for user_id: {user_id}")
                if _run_with_pdh_db(
                    "get_user_token.sync",
                    lambda pdh: pdh.collection('onboarding').document(user_id).set(
                        {
                            'email': user_data['email'],
                            'token': encrypted_token,
                            'fullName': full_name,
                            'token_updated_at': datetime.utcnow(),
                            'updated_at': datetime.utcnow(),
                            'themePreference': token_theme,
                        },
                        merge=True,
                    ),
                ):
                    print(f"[DEBUG] Token synced to PDH onboarding collection for user_id: {user_id}")
        except Exception as token_error:
            print(f"[ERROR] Failed to generate token: {token_error}")
            return JSONResponse(status_code=500, content={"error": "Failed to generate token"})
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "token": encrypted_token,
                "email": user_data['email'],
                "moduleAccessRole": module_access_role,
                "themePreference": token_theme,
            }
        )
    except Exception as e:
        print(f"[ERROR] During token generation: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

from fastapi import UploadFile, File
from typing import Union

@app.post("/users/profile-image")
async def upload_profile_image(file: UploadFile = File(...), user_id: str = Query(..., description="User ID for folder organization")):
    """
    Upload a profile image to Cloudinary using the upload_profile_image method.
    
    Args:
        file: Image file (multipart/form-data)
        user_id: User ID for organizing files in folders
        
    Returns:
        JSON response with Cloudinary CDN URL and public ID
    """
    try:
        info_log(f"Profile image upload request for user_id: {user_id}")
        
        # Use the new upload_profile_image method
        result = cloudinary_service.upload_profile_image(file, user_id)
        
        if result['success']:
            info_log(f"Profile image uploaded successfully for user_id: {user_id}")
            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "url": result['url'],
                    "public_id": result['public_id'],
                    "message": "Profile image uploaded successfully"
                }
            )
        else:
            error_log(f"Profile image upload failed for user_id: {user_id}: {result['error']}")
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "error": result['error'],
                    "message": "Failed to upload profile image"
                }
            )
    except Exception as e:
        error_log(f"Profile image upload exception for user_id: {user_id}: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": str(e),
                "message": "Internal server error during profile image upload"
            }
        )

@app.delete("/api/delete/profile-picture")
async def delete_profile_picture(public_id: str = Query(..., description="Cloudinary public ID")):
    """
    Delete a profile picture from Cloudinary
    """
    try:
        result = cloudinary_service.delete_image(public_id)
        
        if result:
            return JSONResponse(
                status_code=200,
                content={"success": True, "message": "Profile picture deleted successfully"}
            )
        else:
            return JSONResponse(
                status_code=500,
                content={"error": "Failed to delete profile picture", "message": "Deletion failed"}
            )
            
    except Exception as e:
        print(f"[ERROR] During profile picture deletion: {e}")
        return JSONResponse(
            status_code=500,
            content={"error": str(e), "message": "Failed to delete profile picture"}
        )
