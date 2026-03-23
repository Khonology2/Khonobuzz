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
from datetime import datetime
from pydantic import BaseModel
from fastapi.responses import JSONResponse
from fastapi import status
from fastapi import HTTPException
from typing import Optional, Dict, Any
from pathlib import Path
import jwt
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
    json_env_var = f"{env_var_name}_JSON"
    json_str = os.environ.get(json_env_var)
    if json_str:
        if not json_str.strip():
            error_log(f"{json_env_var} is set but EMPTY (only whitespace). Please set a valid JSON value.")
            json_str = None
        else:
            debug_log(f"Checking for {json_env_var}: SET (length: {len(json_str)} chars)")
    else:
        debug_log(f"Checking for {json_env_var}: NOT SET")
        possible_vars = [
            json_env_var.upper(),
            json_env_var.lower(),
            json_env_var.replace('_JSON', ''),
            f"{env_var_name}_CREDENTIALS",
            f"{env_var_name}_CREDENTIALS_JSON",
        ]
        for possible_var in possible_vars:
            if possible_var != json_env_var and possible_var in os.environ:
                debug_log(f"Found similar variable '{possible_var}' but looking for '{json_env_var}'")
    if json_str:
        try:
            json_str = json_str.strip()
            # Remove surrounding quotes if present
            if (json_str.startswith('"') and json_str.endswith('"')) or \
               (json_str.startswith("'") and json_str.endswith("'")):
                json_str = json_str[1:-1]
            
            # Check for common formatting issues
            if json_str.startswith('"') and not json_str.startswith('{"'):
                error_msg = (
                    f"Invalid format in {json_env_var}. The value appears to have extra quotes.\n"
                    f"Current format starts with: {json_str[:50]}...\n"
                    f"Expected format: {{\"type\":\"service_account\",...}}\n"
                    f"Solution: Remove surrounding quotes from the environment variable in Render."
                )
                raise ValueError(error_msg)
            
            # Additional check for malformed JSON that starts with quotes but not proper JSON
            if json_str.startswith('"') and '\n' in json_str:
                error_msg = (
                    f"Invalid format in {json_env_var}. The JSON appears to be quoted with newlines.\n"
                    f"This usually happens when copying multi-line JSON into Render's environment variable field.\n"
                    f"Solution: Use base64 encoding or ensure the JSON is on a single line without extra quotes.\n"
                    f"First 100 chars: {json_str[:100]}..."
                )
                raise ValueError(error_msg)
            
            # Check if it looks like base64 (starts with base64 characters)
            import re
            if re.match(r'^[A-Za-z0-9+/]+={0,2}$', json_str.strip()) and len(json_str.strip()) > 50:
                debug_log(f"{json_env_var} appears to be base64 encoded, attempting decode...")
                try:
                    json_str = base64.b64decode(json_str).decode('utf-8')
                    debug_log(f"Successfully base64 decoded {json_env_var}")
                except Exception as decode_error:
                    debug_log(f"Base64 decode failed for {json_env_var}: {decode_error}")
                    # Continue with original string
            
            debug_log(f"{json_env_var} value length: {len(json_str)} characters")
            debug_log(f"{json_env_var} starts with: {json_str[:50]}...")
            debug_log(f"{json_env_var} ends with: ...{json_str[-50:]}")
            try:
                cred_dict = json.loads(json_str)
                required_fields = ['type', 'project_id', 'private_key', 'client_email']
                missing_fields = [field for field in required_fields if field not in cred_dict]
                if missing_fields:
                    raise ValueError(f"Missing required Firebase credential fields: {missing_fields}")
                debug_log(f"Successfully loaded credentials from {json_env_var} (direct JSON)")
                return credentials.Certificate(cred_dict)
            except json.JSONDecodeError as e:
                error_log(f"JSON decode error for {json_env_var}: {str(e)}")
                error_log(f"Error at position {e.pos if hasattr(e, 'pos') else 'unknown'}")
                debug_log(f"Direct JSON parse failed for {json_env_var}, trying base64 decode...")
                try:
                    json_str = base64.b64decode(json_str).decode('utf-8')
                    cred_dict = json.loads(json_str)
                    debug_log(f"Successfully loaded credentials from {json_env_var} (base64 decoded)")
                    return credentials.Certificate(cred_dict)
                except Exception as decode_error:
                    error_log(f"Base64 decode failed for {json_env_var}: {decode_error}")
                    error_msg = (
                        f"Invalid JSON format in {json_env_var}.\n"
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
                error_log(f"Unexpected error parsing {json_env_var}: {type(e).__name__}: {str(e)}")
                raise
        except (ValueError, json.JSONDecodeError) as e:
            error_log(f"Failed to parse credentials from {json_env_var}: {e}")
            raise
        except Exception as e:
            error_log(f"Failed to load credentials from {json_env_var}: {e}")
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
    pdh_cred = load_firebase_credentials('PDH_FIREBASE_CREDENTIALS', 'pdh-fe6eb-firebase-adminsdk-fbsvc-6fbc402974.json')
    pdh_app = initialize_app(pdh_cred, name='pdhApp')
    pdh_db = firestore.client(app=pdh_app)
    info_log("PDH Firebase credentials loaded successfully")
except Exception as e:
    error_log(f"Failed to initialize PDH Firebase (continuing without it): {e}")
    info_log("Backend will continue without PDH Firebase functionality")

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
try:
    main_cred = load_firebase_credentials('FIREBASE_CREDENTIALS', 'khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-d20003b368.json')
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
        db.collection('users').limit(1).get()
        info_log(
            f"Startup warm-up Firestore users took {time.time() - start:.3f} seconds",
        )
    except Exception as e:
        error_log(f"Startup warm-up failed: {e}")
cors_origins_env = os.environ.get('CORS_ORIGINS', '*')
PRODUCTION_BACKEND_URLS = [
    'https://khonobuzz-central-hub.onrender.com',
]
PRODUCTION_FRONTEND_URLS = [
    'https://khono-buzz-central-hub-web.onrender.com',
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
# Allow localhost with any port (prod and dev) so Flutter web dev works.
# Also allow any Render subdomain so frontends deployed at custom URLs work.
RENDER_ORIGIN_REGEX = r"https://[a-z0-9-]+\.onrender\.com"
cors_origin_regex = "|".join([LOCALHOST_ORIGIN_REGEX, RENDER_ORIGIN_REGEX])
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
    info_log(f"→ {request.method} {request.url.path} from {request.client.host if request.client else 'unknown'}")
    if DEBUG_MODE and request.query_params:
        debug_log(f"  Query params: {dict(request.query_params)}")
    response = await call_next(request)
    process_time = (datetime.utcnow() - start_time).total_seconds()
    info_log(f"← {request.method} {request.url.path} - {response.status_code} ({process_time:.3f}s)")
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
    if origin and (
        origin.startswith("http://localhost") or origin.startswith("http://127.0.0.1")
    ):
        return {
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Credentials": "true",
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
                "Returning 404 because version.json was not found",
                {
                    "path": str(path),
                },
            )
            # endregion
            resp = JSONResponse(status_code=404, content={"error": "version.json not found"})
            resp.headers.update(_cors_headers_for_request(request))
            return resp
        raw = path.read_text(encoding="utf-8")
        data = json.loads(raw)
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
                    )
                    onboarding_data['token'] = encrypted_token
                    onboarding_data['token_updated_at'] = datetime.utcnow()
                    print(f"[DEBUG] Token generated during PDH sync for user_id: {uid} with roles: {roles}")
                except Exception as token_error:
                    print(f"[ERROR] Failed to generate token during PDH sync: {token_error}")
        if pdh_db:
            pdh_db.collection('users').document(uid).set(user_data, merge=True)
            pdh_db.collection('onboarding').document(uid).set(onboarding_data, merge=True)
        else:
            print("[WARNING] PDH Firebase not initialized, skipping sync")
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
        if pdh_db and user_fields:
            pdh_db.collection('users').document(uid).set(user_fields, merge=True)
            user_email = user_fields.get('email', '')
        if pdh_db and onboarding_fields:
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
                    )
                    onboarding_fields['token'] = encrypted_token
                    onboarding_fields['token_updated_at'] = datetime.utcnow()
                    print(f"[DEBUG] Token regenerated during PDH update for user_id: {uid} with roles: {roles}")
                except Exception as token_error:
                    print(f"[ERROR] Failed to regenerate token during PDH update: {token_error}")
            if pdh_db:
                pdh_db.collection('onboarding').document(uid).set(onboarding_fields, merge=True)
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "PDH update successful"})
    except Exception as e:
        print(f"[ERROR] During PDH update: {e}")
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

        onboarding_query = (
            db.collection('onboarding')
            .where('user_id', '==', user_id)
            .limit(1)
            .stream()
        )
        onboarding_info = {}
        for onboarding_doc in onboarding_query:
            onboarding_info = onboarding_doc.to_dict() or {}
            break

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

        # Extract update fields
        first_name = data.get('firstName') or data.get('name') or ''
        last_name = data.get('surname') or data.get('lastName') or ''
        preferred_name = data.get('preferredName') or ''
        department = data.get('department') or ''
        designation = data.get('designation') or ''
        phone_number = data.get('phoneNumber') or ''
        managed_by = data.get('managedBy') or data.get('manager') or ''
        profile_image_url = data.get('profileImageUrl') or ''
        profile_image_public_id = data.get('profileImagePublicId') or ''
        full_name = (f"{first_name} {last_name}".strip() or preferred_name or '').strip()

        # 2. Update 'users' collection
        user_update = {
            'department': department,
            'designation': designation,
            'manager': managed_by,
            'updated_at': datetime.utcnow(),
        }
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

        onboarding_update = {
            'firstName': first_name,
            'lastName': last_name,
            'surname': last_name if last_name else data.get('surname', ''),
            'preferredName': preferred_name,
            'fullName': full_name,
            'department': department,
            'designation': designation,
            'phoneNumber': phone_number,
            'managedBy': managed_by,
            'profileImageUrl': profile_image_url,
            'profileImagePublicId': profile_image_public_id,
            'updated_at': datetime.utcnow(),
            'email': normalized_email,
        }

        if onboarding_doc_ref:
            onboarding_doc_ref.update(onboarding_update)
        else:
            # Create onboarding doc if it doesn't exist
            db.collection('onboarding').add({
                **onboarding_update,
                'user_id': user_id,
                'created_at': datetime.utcnow(),
            })

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"message": "Profile updated successfully"}
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
        }
        if encrypted_token:
            onboarding_data['token'] = encrypted_token
            onboarding_data['token_updated_at'] = datetime.utcnow()
        print(f"[DEBUG] Onboarding data being sent to Firestore (onboarding collection - FastAPI): {onboarding_data}")
        db.collection('onboarding').add(onboarding_data)
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
    try:
        users_query = db.collection('users').stream()
        users_with_sort_keys = []
        for user_doc in users_query:
            user_info = user_doc.to_dict() or {}
            onboarding_query = db.collection('onboarding').where('user_id', '==', user_doc.id).limit(1).stream()
            onboarding_info = {}
            for onboarding_doc in onboarding_query:
                onboarding_info = onboarding_doc.to_dict() or {}
                break
            first_name = onboarding_info.get('firstName') or onboarding_info.get('name') or ''
            last_name = onboarding_info.get('lastName') or onboarding_info.get('surname') or ''
            created_at_val = user_info.get('created_at')
            created_at_dt = created_at_val if isinstance(created_at_val, datetime) else None
            updated_at_val = user_info.get('updated_at')
            updated_at_dt = updated_at_val if isinstance(updated_at_val, datetime) else None
            last_sign_in_val = user_info.get('lastSignInAt')
            last_sign_in_dt = last_sign_in_val if isinstance(last_sign_in_val, datetime) else None
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
            }
            sort_key = updated_at_dt or created_at_dt
            users_with_sort_keys.append((sort_key, user_payload))
        users_with_sort_keys.sort(key=lambda item: item[0] or datetime.min, reverse=True)
        users_data = [payload for _, payload in users_with_sort_keys]
        return JSONResponse(status_code=status.HTTP_200_OK, content={'users': users_data})
    except Exception as e:
        print(f"[ERROR] During users fetch: {e}")
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
        onboarding_update_payload = {}
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
            onboarding_query = (
                db.collection('onboarding')
                .where('user_id', '==', user_id)
                .limit(1)
                .stream()
            )
            onboarding_doc = None
            for doc in onboarding_query:
                onboarding_doc = doc
                break
            if onboarding_doc is not None and onboarding_update_payload:
                onboarding_doc.reference.update(onboarding_update_payload)
                if should_regenerate_token:
                    try:
                        print(f"[DEBUG] Regenerating token for user_id: {user_id} due to moduleAccessRole update")
                        user_email = current_user_data.get('email', '')
                        onboarding_data = onboarding_doc.to_dict() or {}
                        if not user_email:
                            user_email = onboarding_data.get('email', '')
                        new_module_access_role = user_update.moduleAccessRole or ''
                        roles = parse_module_access_role_to_roles(new_module_access_role)
                        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or current_user_data.get('firstName') or ''
                        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or current_user_data.get('lastName') or ''
                        full_name = f"{first_name} {last_name}".strip()
                        if not full_name:
                            full_name = current_user_data.get('name', '') or onboarding_data.get('name', '')
                        encrypted_token = generate_and_encrypt_token(
                            user_id=user_id,
                            email=user_email,
                            full_name=full_name,
                            roles=roles,
                        )
                        update_data = {
                            'token': encrypted_token,
                            'token_updated_at': datetime.utcnow(),
                            'fullName': full_name,
                        }
                        if user_email and not onboarding_data.get('email'):
                            update_data['email'] = user_email
                        onboarding_doc.reference.update(update_data)
                        print(f"[DEBUG] Token regenerated and updated in main onboarding collection for user_id: {user_id}")
                        # Sync new token to PDH
                        if pdh_db:
                            try:
                                pdh_onboarding_ref = pdh_db.collection('onboarding').document(user_id)
                                pdh_onboarding_ref.set({
                                    'email': user_email,
                                    'token': encrypted_token,
                                    'fullName': full_name,
                                    'token_updated_at': datetime.utcnow(),
                                    'updated_at': datetime.utcnow(),
                                }, merge=True)
                                print(f"[DEBUG] New token synced to PDH onboarding collection for user_id: {user_id}")
                            except Exception as pdh_sync_error:
                                print(f"[ERROR] Failed to sync new token to PDH: {pdh_sync_error}")
                        else:
                            print("[WARNING] PDH Firebase not initialized, skipping token sync")
                    except Exception as token_error:
                        print(f"[ERROR] Failed to regenerate token: {token_error}")
        updated_doc = user_ref.get()
        updated_data = updated_doc.to_dict() or {}
        onboarding_info = {}
        onboarding_query2 = db.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
        for ondoc in onboarding_query2:
            onboarding_info = ondoc.to_dict() or {}
            break
        first_name = onboarding_info.get('firstName') or onboarding_info.get('name') or ''
        last_name = onboarding_info.get('lastName') or onboarding_info.get('surname') or ''
        created_at_val = updated_data.get('created_at')
        created_at_dt = created_at_val if isinstance(created_at_val, datetime) else None
        updated_at_val = updated_data.get('updated_at')
        updated_at_dt = updated_at_val if isinstance(updated_at_val, datetime) else None
        created_at_str = created_at_dt.isoformat() + 'Z' if created_at_dt else None
        updated_at_str = updated_at_dt.isoformat() + 'Z' if updated_at_dt else None
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
        }
        return JSONResponse(status_code=status.HTTP_200_OK, content={'message': 'User updated successfully', 'user': user_payload})
    except Exception as e:
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
        if pdh_db:
            try:
                pdh_user_ref = pdh_db.collection('users').document(user_id)
                pdh_user_doc = pdh_user_ref.get()
                if pdh_user_doc.exists:
                    pdh_user_ref.delete()
                    print(f"[DEBUG] Deleted user {user_id} from PDH users collection")
            except Exception as pdh_error:
                print(f"[WARNING] Failed to delete from PDH users collection: {pdh_error}")
        if pdh_db:
            try:
                pdh_onboarding_ref = pdh_db.collection('onboarding').document(user_id)
                pdh_onboarding_doc = pdh_onboarding_ref.get()
                if pdh_onboarding_doc.exists:
                    pdh_onboarding_ref.delete()
                    print(f"[DEBUG] Deleted user {user_id} from PDH onboarding collection")
                pdh_onboarding_query = (
                    pdh_db.collection('onboarding')
                    .where('user_id', '==', user_id)
                    .limit(1)
                    .stream()
                )
                for pdh_onboarding_doc in pdh_onboarding_query:
                    pdh_onboarding_doc.reference.delete()
                    print(f"[DEBUG] Deleted user {user_id} from PDH onboarding collection (by query)")
                    break
            except Exception as pdh_error:
                print(f"[WARNING] Failed to delete from PDH onboarding collection: {pdh_error}")

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"message": f"User {user_id} deleted successfully"}
        )
    except Exception as e:
        print(f"[ERROR] During user deletion: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.get("/api/departments")
async def list_departments():
    """Return all department names from Firestore collection."""
    try:
        docs = db.collection("departments").stream()
        names = []
        for doc in docs:
            data = doc.to_dict() or {}
            n = (data.get("name") or "").strip()
            if n and n not in names:
                names.append(n)
        names.sort(key=str.lower)
        return JSONResponse(status_code=200, content={"departments": names})
    except Exception as e:
        print(f"[ERROR] list_departments: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/departments")
async def create_department(body: NameBody):
    """Add a new department; store in Firestore collection. Returns updated list."""
    try:
        name = (body.name or "").strip()
        if not name:
            raise HTTPException(status_code=400, detail="name is required")
        coll = db.collection("departments")
        existing = coll.where("name", "==", name).limit(1).stream()
        if next(existing, None) is not None:
            pass
        else:
            coll.add({"name": name})
        docs = coll.stream()
        names = []
        for doc in docs:
            data = doc.to_dict() or {}
            n = (data.get("name") or "").strip()
            if n and n not in names:
                names.append(n)
        names.sort(key=str.lower)
        return JSONResponse(status_code=201, content={"departments": names})
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] create_department: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.get("/api/designations")
async def list_designations():
    """Return all designation names from Firestore collection."""
    try:
        docs = db.collection("designations").stream()
        names = []
        for doc in docs:
            data = doc.to_dict() or {}
            n = (data.get("name") or "").strip()
            if n and n not in names:
                names.append(n)
        names.sort(key=str.lower)
        return JSONResponse(status_code=200, content={"designations": names})
    except Exception as e:
        print(f"[ERROR] list_designations: {e}")
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
            coll.add({"name": name})
        docs = coll.stream()
        names = []
        for doc in docs:
            data = doc.to_dict() or {}
            n = (data.get("name") or "").strip()
            if n and n not in names:
                names.append(n)
        names.sort(key=str.lower)
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
                users = query.get()
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
                else:
                    # Case-insensitive fallback: user may be stored with mixed case
                    for doc in users_ref.stream():
                        doc_data = doc.to_dict() or {}
                        doc_email = (doc_data.get('email') or '').strip()
                        if doc_email.lower() == normalized_email:
                            user_data = doc_data
                            user_id = doc.id
                            stored_email = doc_email
                            USER_CACHE[cache_key] = {
                                "user_data": user_data,
                                "user_id": user_id,
                                "stored_email": stored_email,
                                "expires_at": now + LOGIN_CACHE_TTL_SECONDS,
                            }
                            debug_log(f"Login cache populated (case-insensitive) for {normalized_email}")
                            break
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
        module_access_role = ""
        onboarding_lookup_start = time.time()
        try:
            onboarding_query = db.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
            for onboarding_doc in onboarding_query:
                onboarding_data = onboarding_doc.to_dict() or {}
                module_access_role = onboarding_data.get('moduleAccessRole', '') or user_data.get('moduleAccessRole', '')
                break
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
            )
        except Exception:
            pass
        token_gen_end = time.time()
        if not is_special_session:
            try:
                db.collection('users').document(user_id).update({
                    'lastSignInAt': last_sign_in_at,
                })
                user_data['lastSignInAt'] = last_sign_in_at
            except Exception as sign_in_error:
                error_log(f"Failed to update lastSignInAt for {normalized_email}: {sign_in_error}")
        if encrypted_token:
            if onboarding_data:
                try:
                    onboarding_doc_ref = db.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
                    doc_found = False
                    for doc in onboarding_doc_ref:
                        update_data = {
                            'token': encrypted_token,
                            'token_updated_at': datetime.utcnow(),
                            'fullName': full_name,
                            'email': user_data['email'],
                        }
                        if not is_special_session:
                            update_data['updated_at'] = datetime.utcnow()
                        doc.reference.update(update_data)
                        doc_found = True
                        break
                    if not doc_found:
                        onboarding_data['token'] = encrypted_token
                        onboarding_data['token_updated_at'] = datetime.utcnow()
                        onboarding_data['email'] = user_data['email']
                        onboarding_data['fullName'] = full_name
                        if not is_special_session:
                            onboarding_data['created_at'] = datetime.utcnow()
                            onboarding_data['updated_at'] = datetime.utcnow()
                        db.collection('onboarding').add(onboarding_data)
                except Exception:
                    pass
            else:
                try:
                    onboarding_data = {
                        'user_id': user_id,
                        'email': user_data['email'],
                        'token': encrypted_token,
                        'fullName': full_name,
                        'token_updated_at': datetime.utcnow(),
                    }
                    if not is_special_session:
                        onboarding_data['created_at'] = datetime.utcnow()
                        onboarding_data['updated_at'] = datetime.utcnow()
                    db.collection('onboarding').add(onboarding_data)
                except Exception:
                    pass
            if pdh_db:
                try:
                    pdh_onboarding_ref = pdh_db.collection('onboarding').document(user_id)
                    pdh_data = {
                        'email': user_data['email'],
                        'token': encrypted_token,
                        'fullName': full_name,
                        'token_updated_at': datetime.utcnow(),
                    }
                    if not is_special_session:
                        pdh_data['updated_at'] = datetime.utcnow()
                    pdh_onboarding_ref.set(pdh_data, merge=True)
                except Exception:
                    pass
        module_access_raw = user_data.get('moduleAccess') or onboarding_data.get('moduleAccess', '')
        final_module_access = derive_module_access_from_role(module_access_raw, module_access_role)
        response_name = full_name or user_data.get('name', '')
        response_profile_url = safe_onboarding_for_response.get('profileImageUrl', '')
        response_profile_public_id = safe_onboarding_for_response.get('profileImagePublicId', '')
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
        onboarding_query = db.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
        onboarding_data = {}
        module_access_role = ""
        onboarding_doc_ref = None
        for onboarding_doc in onboarding_query:
            onboarding_data = onboarding_doc.to_dict() or {}
            onboarding_doc_ref = onboarding_doc.reference
            module_access_role = onboarding_data.get('moduleAccessRole', '') or user_data.get('moduleAccessRole', '')
            break
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
            encrypted_token = generate_and_encrypt_token(
                user_id=user_id,
                email=user_data['email'],
                full_name=full_name,
                roles=roles,
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
                    }
                    db.collection('onboarding').add(onboarding_data)
                    print(f"[DEBUG] Created onboarding document with token for user_id: {user_id}")
                if pdh_db:
                    try:
                        pdh_onboarding_ref = pdh_db.collection('onboarding').document(user_id)
                        pdh_onboarding_ref.set({
                            'email': user_data['email'],
                            'token': encrypted_token,
                            'fullName': full_name,
                            'token_updated_at': datetime.utcnow(),
                            'updated_at': datetime.utcnow(),
                        }, merge=True)
                        print(f"[DEBUG] Token synced to PDH onboarding collection for user_id: {user_id}")
                    except Exception as pdh_sync_error:
                        print(f"[ERROR] Failed to sync token to PDH: {pdh_sync_error}")
        except Exception as token_error:
            print(f"[ERROR] Failed to generate token: {token_error}")
            return JSONResponse(status_code=500, content={"error": "Failed to generate token"})
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "token": encrypted_token,
                "email": user_data['email'],
                "moduleAccessRole": module_access_role,
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
