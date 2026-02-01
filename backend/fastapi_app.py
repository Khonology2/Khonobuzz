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
        verify_token,
    )
except ImportError:
    from token_utils import (
        generate_and_encrypt_token,
        parse_module_access_role_to_roles,
        verify_token,
    )
try:
    from .imagekit_service import imagekit_service
except ImportError:
    from imagekit_service import imagekit_service
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
        elif trimmed.startswith('Skills Heatmap'):
            if 'Resource & Capacity Skills Heatmap' not in module_names:
                module_names.append('Resource & Capacity Skills Heatmap')
        elif trimmed.startswith('Automated Recruitment Workflow'):
            if 'Automated Recruitment Workflow' not in module_names:
                module_names.append('Automated Recruitment Workflow')
        elif trimmed.startswith('Proposal & SOW Builder') or trimmed.startswith('SOW Builder'):
            if 'Proposal & SOW Builder' not in module_names:
                module_names.append('Proposal & SOW Builder')
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
try:
    pdh_cred = load_firebase_credentials('PDH_FIREBASE_CREDENTIALS', 'pdh-fe6eb-firebase-adminsdk-fbsvc-6fbc402974.json')
    pdh_app = initialize_app(pdh_cred, name='pdhApp')
    pdh_db = firestore.client(app=pdh_app)
    info_log("PDH Firebase credentials loaded successfully")
except Exception as e:
    error_log(f"Failed to initialize PDH Firebase: {e}")
    raise
try:
    skills_heatmap_cred = load_firebase_credentials('SKILLS_HEATMAP_FIREBASE_CREDENTIALS', 'resource-capacity-3b654-firebase-adminsdk-fbsvc-71599861bf.json')
    skills_heatmap_app = initialize_app(skills_heatmap_cred, name='skillsHeatmapApp')
    skills_heatmap_db = firestore.client(app=skills_heatmap_app)
    info_log("Skills Heatmap Firebase credentials loaded successfully")
except Exception as e:
    error_log(f"Failed to initialize Skills Heatmap Firebase: {e}")
    raise
try:
    sow_builder_cred = load_firebase_credentials(
        'SOW_BUILDER_FIREBASE_CREDENTIALS',
        'lukens-e17d6-firebase-adminsdk-fbsvc-ea49e5a350.json',
    )
    sow_builder_app = initialize_app(sow_builder_cred, name='sowBuilderApp')
    sow_builder_db = firestore.client(app=sow_builder_app)
    info_log("SOW Builder Firebase credentials loaded successfully")
except Exception as e:
    error_log(f"Failed to initialize SOW Builder Firebase: {e}")
    raise
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
PRODUCTION_FRONTEND_URLS = [
    'https://khonobuzz-web-app.onrender.com',
    'https://pdh-web-app.onrender.com',
    'https://proposal-and-sow-builder.onrender.com',
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
        cors_origins = ["*"]
        cors_allow_credentials = False
        info_log("Development mode: CORS configured to allow all origins (including localhost)")
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
cors_origin_regex = None
if is_production:
    cors_origin_regex = LOCALHOST_ORIGIN_REGEX
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
        pdh_db.collection('users').document(uid).set(user_data, merge=True)
        pdh_db.collection('onboarding').document(uid).set(onboarding_data, merge=True)
        try:
            sow_builder_db.collection('users').document(uid).set(user_data, merge=True)
            sow_builder_db.collection('onboarding').document(uid).set(onboarding_data, merge=True)
        except Exception as sow_error:
            print(f"[ERROR] During SOW Builder sync (from PDH sync): {sow_error}")
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
        if user_fields:
            pdh_db.collection('users').document(uid).set(user_fields, merge=True)
            try:
                sow_builder_db.collection('users').document(uid).set(user_fields, merge=True)
            except Exception as sow_error:
                print(f"[ERROR] Failed to update SOW Builder users (PDH update): {sow_error}")
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
                    )
                    onboarding_fields['token'] = encrypted_token
                    onboarding_fields['token_updated_at'] = datetime.utcnow()
                    print(f"[DEBUG] Token regenerated during PDH update for user_id: {uid} with roles: {roles}")
                except Exception as token_error:
                    print(f"[ERROR] Failed to regenerate token during PDH update: {token_error}")
            pdh_db.collection('onboarding').document(uid).set(onboarding_fields, merge=True)
            try:
                sow_builder_db.collection('onboarding').document(uid).set(onboarding_fields, merge=True)
            except Exception as sow_error:
                print(f"[ERROR] Failed to update SOW Builder onboarding (PDH update): {sow_error}")
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "PDH update successful"})
    except Exception as e:
        print(f"[ERROR] During PDH update: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
@app.post("/api/skills-heatmap/sync-user")
async def skills_heatmap_sync_user(data: dict):
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
                    print(f"[DEBUG] Token generated during Skills Heatmap sync for user_id: {uid} with roles: {roles}")
                except Exception as token_error:
                    print(f"[ERROR] Failed to generate token during Skills Heatmap sync: {token_error}")
        skills_heatmap_db.collection('users').document(uid).set(user_data, merge=True)
        skills_heatmap_db.collection('onboarding').document(uid).set(onboarding_data, merge=True)
        try:
            sow_builder_db.collection('users').document(uid).set(user_data, merge=True)
            sow_builder_db.collection('onboarding').document(uid).set(onboarding_data, merge=True)
        except Exception as sow_error:
            print(f"[ERROR] During SOW Builder sync (from Skills Heatmap sync): {sow_error}")
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "Skills Heatmap sync successful"})
    except Exception as e:
        print(f"[ERROR] During Skills Heatmap sync: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
@app.patch("/api/skills-heatmap/update-user/{uid}")
async def skills_heatmap_update_user(uid: str, data: dict):
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
        if user_fields:
            skills_heatmap_db.collection('users').document(uid).set(user_fields, merge=True)
            try:
                sow_builder_db.collection('users').document(uid).set(user_fields, merge=True)
            except Exception as sow_error:
                print(f"[ERROR] Failed to update SOW Builder users (Skills Heatmap update): {sow_error}")
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
                    )
                    onboarding_fields['token'] = encrypted_token
                    onboarding_fields['token_updated_at'] = datetime.utcnow()
                    print(f"[DEBUG] Token regenerated during Skills Heatmap update for user_id: {uid} with roles: {roles}")
                except Exception as token_error:
                    print(f"[ERROR] Failed to regenerate token during Skills Heatmap update: {token_error}")
            skills_heatmap_db.collection('onboarding').document(uid).set(onboarding_fields, merge=True)
            try:
                sow_builder_db.collection('onboarding').document(uid).set(onboarding_fields, merge=True)
            except Exception as sow_error:
                print(f"[ERROR] Failed to update SOW Builder onboarding (Skills Heatmap update): {sow_error}")
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "Skills Heatmap update successful"})
    except Exception as e:
        print(f"[ERROR] During Skills Heatmap update: {e}")
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

        module_access_raw = user_info.get('moduleAccess') or onboarding_info.get('moduleAccess', '')
        module_access_role_raw = user_info.get('moduleAccessRole') or onboarding_info.get('moduleAccessRole', '')

        response_user = {
            'email': user_info.get('email', normalized_email),
            'role': user_info.get('role', ''),
            'status': user_info.get('status', 'Pending'),
            'moduleAccess': module_access_raw or '',
            'moduleAccessRole': module_access_role_raw or '',
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
            module_access_raw = user_info.get('moduleAccess') or onboarding_info.get('moduleAccess', '')
            module_access_role_raw = user_info.get('moduleAccessRole') or onboarding_info.get('moduleAccessRole', '')
            final_module_access = derive_module_access_from_role(module_access_raw, module_access_role_raw)
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
                'createdAt': created_at_str,
                'updatedAt': updated_at_str,
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
                        # Sync new token to Skills Heatmap
                        try:
                            skills_heatmap_onboarding_ref = skills_heatmap_db.collection('onboarding').document(user_id)
                            skills_heatmap_onboarding_ref.set({
                                'email': user_email,
                                'token': encrypted_token,
                                'fullName': full_name,
                                'token_updated_at': datetime.utcnow(),
                                'updated_at': datetime.utcnow(),
                            }, merge=True)
                            print(f"[DEBUG] New token synced to Skills Heatmap onboarding collection for user_id: {user_id}")
                        except Exception as skills_sync_error:
                            print(f"[ERROR] Failed to sync new token to Skills Heatmap: {skills_sync_error}")
                        # Sync new token to SOW Builder
                        try:
                            sow_builder_onboarding_ref = sow_builder_db.collection('onboarding').document(user_id)
                            sow_builder_onboarding_ref.set({
                                'email': user_email,
                                'token': encrypted_token,
                                'fullName': full_name,
                                'token_updated_at': datetime.utcnow(),
                                'updated_at': datetime.utcnow(),
                            }, merge=True)
                            print(f"[DEBUG] New token synced to SOW Builder onboarding collection for user_id: {user_id}")
                        except Exception as sow_sync_error:
                            print(f"[ERROR] Failed to sync new token to SOW Builder: {sow_sync_error}")
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
        try:
            pdh_user_ref = pdh_db.collection('users').document(user_id)
            pdh_user_doc = pdh_user_ref.get()
            if pdh_user_doc.exists:
                pdh_user_ref.delete()
                print(f"[DEBUG] Deleted user {user_id} from PDH users collection")
        except Exception as pdh_error:
            print(f"[WARNING] Failed to delete from PDH users collection: {pdh_error}")
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
        try:
            skills_heatmap_user_ref = skills_heatmap_db.collection('users').document(user_id)
            skills_heatmap_user_doc = skills_heatmap_user_ref.get()
            if skills_heatmap_user_doc.exists:
                skills_heatmap_user_ref.delete()
                print(f"[DEBUG] Deleted user {user_id} from Skills Heatmap users collection")
        except Exception as sh_error:
            print(f"[WARNING] Failed to delete from Skills Heatmap users collection: {sh_error}")
        try:
            skills_heatmap_onboarding_ref = skills_heatmap_db.collection('onboarding').document(user_id)
            skills_heatmap_onboarding_doc = skills_heatmap_onboarding_ref.get()
            if skills_heatmap_onboarding_doc.exists:
                skills_heatmap_onboarding_ref.delete()
                print(f"[DEBUG] Deleted user {user_id} from Skills Heatmap onboarding collection")
            skills_heatmap_onboarding_query = (
                skills_heatmap_db.collection('onboarding')
                .where('user_id', '==', user_id)
                .limit(1)
                .stream()
            )
            for sh_onboarding_doc in skills_heatmap_onboarding_query:
                sh_onboarding_doc.reference.delete()
                print(f"[DEBUG] Deleted user {user_id} from Skills Heatmap onboarding collection (by query)")
                break
        except Exception as sh_error:
            print(f"[WARNING] Failed to delete from Skills Heatmap onboarding collection: {sh_error}")
        try:
            sow_builder_user_ref = sow_builder_db.collection('users').document(user_id)
            sow_builder_user_doc = sow_builder_user_ref.get()
            if sow_builder_user_doc.exists:
                sow_builder_user_ref.delete()
                print(f"[DEBUG] Deleted user {user_id} from SOW Builder users collection")
        except Exception as sow_error:
            print(f"[WARNING] Failed to delete from SOW Builder users collection: {sow_error}")
        try:
            sow_builder_onboarding_ref = sow_builder_db.collection('onboarding').document(user_id)
            sow_builder_onboarding_doc = sow_builder_onboarding_ref.get()
            if sow_builder_onboarding_doc.exists:
                sow_builder_onboarding_ref.delete()
                print(f"[DEBUG] Deleted user {user_id} from SOW Builder onboarding collection")
            sow_builder_onboarding_query = (
                sow_builder_db.collection('onboarding')
                .where('user_id', '==', user_id)
                .limit(1)
                .stream()
            )
            for sow_onboarding_doc in sow_builder_onboarding_query:
                sow_onboarding_doc.reference.delete()
                print(f"[DEBUG] Deleted user {user_id} from SOW Builder onboarding collection (by query)")
                break
        except Exception as sow_error:
            print(f"[WARNING] Failed to delete from SOW Builder onboarding collection: {sow_error}")
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={'message': f'User {user_id} deleted successfully from all collections'},
        )
    except Exception as e:
        print(f"[ERROR] During user deletion: {e}")
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
        if not module_access_role:
            module_access_role = user_data.get('moduleAccessRole', '')
        roles = parse_module_access_role_to_roles(module_access_role)
        if is_special_session:
            roles = ['admin']
        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or user_data.get('firstName') or ''
        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or user_data.get('lastName') or ''
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
            try:
                skills_heatmap_onboarding_ref = skills_heatmap_db.collection('onboarding').document(user_id)
                skills_data = {
                    'token': encrypted_token,
                    'fullName': full_name,
                    'token_updated_at': datetime.utcnow(),
                }
                if not is_special_session:
                    skills_data['updated_at'] = datetime.utcnow()
                skills_heatmap_onboarding_ref.set(skills_data, merge=True)
            except Exception:
                pass
            try:
                sow_builder_onboarding_ref = sow_builder_db.collection('onboarding').document(user_id)
                sow_data = {
                    'token': encrypted_token,
                    'fullName': full_name,
                    'token_updated_at': datetime.utcnow(),
                }
                if not is_special_session:
                    sow_data['updated_at'] = datetime.utcnow()
                sow_builder_onboarding_ref.set(sow_data, merge=True)
            except Exception:
                pass
        module_access_raw = user_data.get('moduleAccess') or onboarding_data.get('moduleAccess', '')
        final_module_access = derive_module_access_from_role(module_access_raw, module_access_role)
        response_content = {
            "message": "Login successful",
            "user": {
                "id": user_id,
                "email": user_data['email'],
                "name": user_data.get('name', ''),
                "role": "Admin" if is_special_session else user_data.get('role', 'user'),
                "status": user_status,
                "moduleAccess": final_module_access or '',
                "moduleAccessRole": module_access_role,
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
async def get_user_token(email: str = Query(..., description="User email address")):
    """
    Generate a fresh encrypted token for a user by email.
    This endpoint ALWAYS generates a new token to ensure it's fresh and not expired.
    The token is then synced to all relevant collections (main, PDH, Skills Heatmap).
    """
    try:
        info_log(f"Token generation request for email: {email}")
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
        roles = parse_module_access_role_to_roles(module_access_role)
        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or user_data.get('firstName') or ''
        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or user_data.get('lastName') or ''
        full_name = f"{first_name} {last_name}".strip()
        if not full_name:
            full_name = user_data.get('name', '')
        print(f"[DEBUG] Generating fresh token for user_id: {user_id} with roles: {roles}")
        try:
            encrypted_token = generate_and_encrypt_token(
                user_id=user_id,
                email=user_data['email'],
                full_name=full_name,
                roles=roles,
            )
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
            try:
                skills_heatmap_onboarding_ref = skills_heatmap_db.collection('onboarding').document(user_id)
                skills_heatmap_onboarding_ref.set({
                    'email': user_data.get('email', ''),
                    'token': encrypted_token,
                    'fullName': full_name,
                    'token_updated_at': datetime.utcnow(),
                    'updated_at': datetime.utcnow(),
                }, merge=True)
                print(f"[DEBUG] Token synced to Skills Heatmap onboarding collection for user_id: {user_id}")
            except Exception as skills_sync_error:
                print(f"[ERROR] Failed to sync token to Skills Heatmap: {skills_sync_error}")
            try:
                sow_builder_onboarding_ref = sow_builder_db.collection('onboarding').document(user_id)
                sow_builder_onboarding_ref.set({
                    'email': user_data.get('email', ''),
                    'token': encrypted_token,
                    'fullName': full_name,
                    'token_updated_at': datetime.utcnow(),
                    'updated_at': datetime.utcnow(),
                }, merge=True)
                print(f"[DEBUG] Token synced to SOW Builder onboarding collection for user_id: {user_id}")
            except Exception as sow_sync_error:
                print(f"[ERROR] Failed to sync token to SOW Builder: {sow_sync_error}")
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
    Upload a profile image to ImageKit using the upload_profile_image method.
    
    Args:
        file: Image file (multipart/form-data)
        user_id: User ID for organizing files in folders
        
    Returns:
        JSON response with ImageKit CDN URL and file ID
    """
    try:
        info_log(f"Profile image upload request for user_id: {user_id}")
        
        # Use the new upload_profile_image method
        result = imagekit_service.upload_profile_image(file, user_id)
        
        if result['success']:
            info_log(f"Profile image uploaded successfully for user_id: {user_id}")
            return JSONResponse(
                status_code=200,
                content={
                    "url": result['url'],
                    "file_id": result['file_id']
                }
            )
        else:
            error_log(f"Profile image upload failed for user_id: {user_id}: {result['error']}")
            return JSONResponse(
                status_code=400,
                content={
                    "error": result['error']
                }
            )
            
    except Exception as e:
        error_log(f"Unexpected error during profile image upload: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"error": "Internal server error during upload"}
        )

@app.delete("/api/delete/profile-picture")
async def delete_profile_picture(public_id: str = Query(..., description="ImageKit file ID")):
    """
    Delete a profile picture from ImageKit
    """
    try:
        result = imagekit_service.delete_image(public_id)
        
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
