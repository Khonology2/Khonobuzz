from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.gzip import GZipMiddleware
from brotli_asgi import BrotliMiddleware  # pyright: ignore[reportMissingImports]  # pyright: ignore[reportMissingImports]
from firebase_admin import credentials, firestore, initialize_app
from dotenv import load_dotenv
import os
import logging
from datetime import datetime
from pydantic import BaseModel
from fastapi.responses import JSONResponse
from fastapi import status # Import status for HTTP status codes
from fastapi import HTTPException # Import HTTPException for authentication errors
from typing import Optional
from token_utils import generate_and_encrypt_token, verify_token, parse_module_access_role_to_roles

load_dotenv()

# Configure logging
DEBUG_MODE = os.environ.get('DEBUG', 'True').lower() == 'true'
LOG_LEVEL = logging.DEBUG if DEBUG_MODE else logging.INFO

logging.basicConfig(
    level=LOG_LEVEL,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Helper function for debug logging
def debug_log(message: str):
    """Log debug messages only if DEBUG mode is enabled"""
    if DEBUG_MODE:
        logger.debug(message)
        print(f"[DEBUG] {message}")

def error_log(message: str):
    """Log error messages (always shown)"""
    logger.error(message)
    print(f"[ERROR] {message}")

def info_log(message: str):
    """Log info messages (always shown)"""
    logger.info(message)
    print(f"[INFO] {message}")

# Configuration
FIREBASE_CREDENTIALS_PATH = os.environ.get('FIREBASE_CREDENTIALS_PATH') or 'khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-d20003b368.json'
PDH_FIREBASE_CREDENTIALS_PATH = os.environ.get('PDH_FIREBASE_CREDENTIALS_PATH') or 'pdh-fe6eb-firebase-adminsdk-fbsvc-6fbc402974.json'
SKILLS_HEATMAP_FIREBASE_CREDENTIALS_PATH = os.environ.get('SKILLS_HEATMAP_FIREBASE_CREDENTIALS_PATH') or 'resource-capacity-3b654-firebase-adminsdk-fbsvc-71599861bf.json'

# PDH Firestore App Initialization
pdh_cred = credentials.Certificate(PDH_FIREBASE_CREDENTIALS_PATH)
pdh_app = initialize_app(pdh_cred, name='pdhApp')
pdh_db = firestore.client(app=pdh_app)

# Skills Heatmap Firestore App Initialization
skills_heatmap_cred = credentials.Certificate(SKILLS_HEATMAP_FIREBASE_CREDENTIALS_PATH)
skills_heatmap_app = initialize_app(skills_heatmap_cred, name='skillsHeatmapApp')
skills_heatmap_db = firestore.client(app=skills_heatmap_app)

from fastapi import Body

# Pydantic models for request body validation
class UserRegister(BaseModel):
    email: str
    password: str
    name: str # The combined name (first + last) from Flutter
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
    moduleAccess: Optional[str] = None
    moduleRole: Optional[str] = None
    moduleAccessRole: Optional[str] = None  # Combined field: "PDH - Employee", "PDH - Manager", "SOW Builder - Manager"
    adminApproved: Optional[str] = None

# Initialize Firebase Admin SDK
cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
initialize_app(cred)
db = firestore.client()

app = FastAPI(
    title="Khonology Backend API",
    description="Backend API for Khonology project management application",
    version="1.0.0",
)

# Enable CORS for Flutter app
# Note: When allow_credentials=True, you cannot use allow_origins=["*"]
# For development: use ["*"] with allow_credentials=False to allow all origins
# For production: specify exact origins in a list with allow_credentials=True
cors_origins_env = os.environ.get('CORS_ORIGINS', '*')

# Default production frontend URLs
PRODUCTION_FRONTEND_URLS = [
    'https://khonobuzz-web.netlify.app',  # Netlify deployment
    'https://khonobuzz-web-app.onrender.com',  # Render deployment
]

# Check if running in production
# Render sets RENDER=true, or check for production-like hostnames
is_production = (
    os.environ.get('RENDER') is not None 
    or os.environ.get('ENVIRONMENT') == 'production'
    or os.environ.get('NODE_ENV') == 'production'
    or 'onrender.com' in os.environ.get('RENDER_EXTERNAL_URL', '')
)

if cors_origins_env == '*':
    if is_production:
        # In production, use specific origins instead of wildcard
        cors_origins = PRODUCTION_FRONTEND_URLS + ['http://localhost:5000', 'http://localhost:3000']
        cors_allow_credentials = True
    else:
        # In development, allow all origins
        cors_origins = ["*"]
        cors_allow_credentials = False
else:
    # Split comma-separated origins and ensure production URLs are included
    cors_origins = [origin.strip() for origin in cors_origins_env.split(',')]
    # Add production frontend URLs if not already present
    for prod_url in PRODUCTION_FRONTEND_URLS:
        if prod_url not in cors_origins:
            cors_origins.append(prod_url)
    cors_allow_credentials = os.environ.get('CORS_ALLOW_CREDENTIALS', 'True' if is_production else 'False').lower() == 'true'

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=cors_allow_credentials,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)
app.add_middleware(BrotliMiddleware)
app.add_middleware(GZipMiddleware, minimum_size=500)

# Request logging middleware
@app.middleware("http")
async def log_requests(request, call_next):
    """Log all incoming requests"""
    start_time = datetime.utcnow()
    
    # Log request
    info_log(f"→ {request.method} {request.url.path} from {request.client.host if request.client else 'unknown'}")
    if DEBUG_MODE and request.query_params:
        debug_log(f"  Query params: {dict(request.query_params)}")
    
    # Process request
    response = await call_next(request)
    
    # Log response
    process_time = (datetime.utcnow() - start_time).total_seconds()
    info_log(f"← {request.method} {request.url.path} - {response.status_code} ({process_time:.3f}s)")
    
    return response

@app.post("/api/pdh/sync-user")
async def pdh_sync_user(data: dict):
    try:
        uid = data['uid']
        user_data = data['userData']
        onboarding_data = data['onboardingData']
        
        # Convert ISO strings back to datetime objects
        for key in ['created_at', 'updated_at']:
            if key in user_data and isinstance(user_data[key], str):
                user_data[key] = datetime.fromisoformat(user_data[key].replace('Z', '+00:00'))
        
        for key in ['created_at', 'updated_at', 'first_valid', 'last_valid']:
            if key in onboarding_data and isinstance(onboarding_data[key], str):
                onboarding_data[key] = datetime.fromisoformat(onboarding_data[key].replace('Z', '+00:00'))
        
        # Generate token if moduleAccessRole is present or if token is already in onboarding_data
        module_access_role = onboarding_data.get('moduleAccessRole', '') or user_data.get('moduleAccessRole', '')
        user_email = user_data.get('email', '') or onboarding_data.get('email', '')
        
        # Ensure email is always populated in onboarding_data (required for PDH)
        if user_email and not onboarding_data.get('email'):
            onboarding_data['email'] = user_email
        
        # Parse moduleAccessRole into roles array
        roles = parse_module_access_role_to_roles(module_access_role)
        
        # Get user's full name
        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or user_data.get('firstName') or ''
        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or user_data.get('lastName') or ''
        full_name = f"{first_name} {last_name}".strip()
        
        # Fallback to 'name' field if full_name is empty
        if not full_name:
            full_name = user_data.get('name', '')
        
        # Add fullName field to onboarding_data for PDH
        onboarding_data['fullName'] = full_name
        
        # Use existing token from onboarding_data if present, otherwise generate new one
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
        
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "PDH sync successful"})
    except Exception as e:
        print(f"[ERROR] During PDH sync: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.patch("/api/pdh/update-user/{uid}")
async def pdh_update_user(uid: str, data: dict):
    try:
        user_fields = data.get('userFields')
        onboarding_fields = data.get('onboardingFields')

        # Check if moduleAccessRole is being updated - regenerate token if so
        should_regenerate_token = False
        new_module_access_role = ''
        user_email = ''
        user_fields_dict = user_fields or {}
        onboarding_fields_dict = onboarding_fields or {}
        
        if onboarding_fields and 'moduleAccessRole' in onboarding_fields:
            should_regenerate_token = True
            new_module_access_role = onboarding_fields.get('moduleAccessRole', '')
        elif user_fields and 'moduleAccessRole' in user_fields:
            should_regenerate_token = True
            new_module_access_role = user_fields.get('moduleAccessRole', '')
        
        if user_fields:
            pdh_db.collection('users').document(uid).set(user_fields, merge=True)
            user_email = user_fields.get('email', '')
        
        if onboarding_fields:
            # Get email if not already found
            if not user_email:
                user_email = onboarding_fields.get('email', '')
            
            # Ensure email is always populated in onboarding_fields (required for PDH)
            if user_email and not onboarding_fields.get('email'):
                onboarding_fields['email'] = user_email
            
            # Parse moduleAccessRole into roles array
            roles = parse_module_access_role_to_roles(new_module_access_role)
            
            # Get user's full name
            first_name = onboarding_fields.get('firstName') or onboarding_fields.get('name') or user_fields_dict.get('firstName') or ''
            last_name = onboarding_fields.get('lastName') or onboarding_fields.get('surname') or user_fields_dict.get('lastName') or ''
            full_name = f"{first_name} {last_name}".strip()
            
            # Fallback to 'name' field if full_name is empty
            if not full_name:
                full_name = user_fields_dict.get('name', '')
            
            # Add fullName field to onboarding_fields for PDH
            onboarding_fields['fullName'] = full_name
            
            # Regenerate token if moduleAccessRole changed
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
        
        # Convert ISO strings back to datetime objects
        for key in ['created_at', 'updated_at']:
            if key in user_data and isinstance(user_data[key], str):
                user_data[key] = datetime.fromisoformat(user_data[key].replace('Z', '+00:00'))
        
        for key in ['created_at', 'updated_at', 'first_valid', 'last_valid']:
            if key in onboarding_data and isinstance(onboarding_data[key], str):
                onboarding_data[key] = datetime.fromisoformat(onboarding_data[key].replace('Z', '+00:00'))
        
        # Generate token if moduleAccessRole is present or if token is already in onboarding_data
        module_access_role = onboarding_data.get('moduleAccessRole', '') or user_data.get('moduleAccessRole', '')
        user_email = user_data.get('email', '') or onboarding_data.get('email', '')
        
        # Ensure email is always populated in onboarding_data (required for PDH)
        if user_email and not onboarding_data.get('email'):
            onboarding_data['email'] = user_email
        
        # Parse moduleAccessRole into roles array
        roles = parse_module_access_role_to_roles(module_access_role)
        
        # Get user's full name
        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or user_data.get('firstName') or ''
        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or user_data.get('lastName') or ''
        full_name = f"{first_name} {last_name}".strip()
        
        # Fallback to 'name' field if full_name is empty
        if not full_name:
            full_name = user_data.get('name', '')
        
        # Add fullName field to onboarding_data for Skills Heatmap
        onboarding_data['fullName'] = full_name
        
        # Use existing token from onboarding_data if present, otherwise generate new one
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
        
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "Skills Heatmap sync successful"})
    except Exception as e:
        print(f"[ERROR] During Skills Heatmap sync: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.patch("/api/skills-heatmap/update-user/{uid}")
async def skills_heatmap_update_user(uid: str, data: dict):
    try:
        user_fields = data.get('userFields')
        onboarding_fields = data.get('onboardingFields')

        # Check if moduleAccessRole is being updated - regenerate token if so
        should_regenerate_token = False
        new_module_access_role = ''
        user_email = ''
        user_fields_dict = user_fields or {}
        onboarding_fields_dict = onboarding_fields or {}
        
        if onboarding_fields and 'moduleAccessRole' in onboarding_fields:
            should_regenerate_token = True
            new_module_access_role = onboarding_fields.get('moduleAccessRole', '')
        elif user_fields and 'moduleAccessRole' in user_fields:
            should_regenerate_token = True
            new_module_access_role = user_fields.get('moduleAccessRole', '')
        
        if user_fields:
            skills_heatmap_db.collection('users').document(uid).set(user_fields, merge=True)
            user_email = user_fields.get('email', '')
        
        if onboarding_fields:
            # Get email if not already found
            if not user_email:
                user_email = onboarding_fields.get('email', '')
            
            # Ensure email is always populated in onboarding_fields (required for PDH)
            if user_email and not onboarding_fields.get('email'):
                onboarding_fields['email'] = user_email
            
            # Parse moduleAccessRole into roles array
            roles = parse_module_access_role_to_roles(new_module_access_role)
            
            # Get user's full name
            first_name = onboarding_fields.get('firstName') or onboarding_fields.get('name') or user_fields_dict.get('firstName') or ''
            last_name = onboarding_fields.get('lastName') or onboarding_fields.get('surname') or user_fields_dict.get('lastName') or ''
            full_name = f"{first_name} {last_name}".strip()
            
            # Fallback to 'name' field if full_name is empty
            if not full_name:
                full_name = user_fields_dict.get('name', '')
            
            # Add fullName field to onboarding_fields for Skills Heatmap
            onboarding_fields['fullName'] = full_name
            
            # Regenerate token if moduleAccessRole changed
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
            
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "Skills Heatmap update successful"})
    except Exception as e:
        print(f"[ERROR] During Skills Heatmap update: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.get("/")
async def home():
    info_log("Health check endpoint accessed")
    return {"message": "Khonology Backend API (FastAPI)", "status": "running"}

@app.post("/api/auth/register")
async def register_user(user: UserRegister):
    try:
        print(f"[DEBUG] Raw incoming JSON data (FastAPI): {user.model_dump()}")

        email = user.email
        password = user.password
        first_name = user.firstName.strip() if user.firstName else ''
        last_name = user.lastName.strip() if user.lastName else ''
        # Construct full_name from firstName and lastName (combining them)
        full_name = f"{first_name} {last_name}".strip()
        # Fallback to user.name if full_name is empty (for backward compatibility)
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

        if not email or not password or not full_name:
            # FastAPI handles validation automatically based on Pydantic model, but an explicit check for empty strings might still be useful if fields are optional in model but required in logic
            return JSONResponse(status_code=400, content={"error": "Email, password, and name required"})

        users_ref = db.collection('users')
        query = users_ref.where('email', '==', email).limit(1)
        existing_users = query.get() # Synchronous call

        if existing_users:
            return JSONResponse(status_code=409, content={"error": "User already exists"})

        # Ensure entity is always present, defaulting to empty string
        entity_value = user.entity if user.entity is not None else ''
        print(f"[DEBUG] Entity value for new user: '{entity_value}' (type: {type(entity_value)})")
        
        user_data = {
            'email': email,
            'password': password,
            'name': full_name,
            'role': role,
            'status': 'Pending', # Default new users to 'Pending'
            'created_at': datetime.utcnow(), # Consider using timezone-aware datetimes
            'updated_at': datetime.utcnow(),
            'entity': entity_value,  # Always include entity field
            'department': department,
            'designation': designation,
            'moduleAccess': '',  # Initialize moduleAccess field
            'moduleRole': '',  # Initialize moduleRole field
            'moduleAccessRole': '',  # Initialize moduleAccessRole combined field
        }
        print(f"[DEBUG] User data being sent to Firestore (users collection - FastAPI): {user_data}")

        doc_ref = users_ref.add(user_data)
        user_id = doc_ref[1].id
        print(f"[DEBUG] Firestore doc_ref for users (FastAPI): {doc_ref}, User ID: {user_id}")

        # Get module role (will be empty for new users, but included for consistency)
        module_role = ''
        
        # Parse moduleAccessRole into roles array (empty for new users)
        roles = parse_module_access_role_to_roles(module_role)
        
        # Generate and encrypt token
        encrypted_token = None
        try:
            encrypted_token = generate_and_encrypt_token(
                user_id=user_id,
                email=email,
                full_name=full_name,
                roles=roles,
            )
            print(f"[DEBUG] Token generated for new user: {user_id} with roles: {roles}")
        except Exception as token_error:
            print(f"[ERROR] Failed to generate token during registration: {token_error}")
            # Continue with registration even if token generation fails

        onboarding_data = {
            'user_id': user_id,
            'email': email,
            'name': first_name,
            'surname': last_name,
            'fullName': full_name.strip(),  # Add fullName field combining first_name and last_name
            'department': department,
            'designation': designation,
            'first_valid': datetime(2025, 9, 25, 0, 0, 0), # Specific date from user
            'inserted_by': email,
            'last_valid': datetime(2039, 12, 31, 0, 0, 0), # Specific date from user
            'onboarding_id': user_id, # Using user_id as onboarding_id
            'status_id': "",
            'updated_by': email,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow(),
            'entity': entity_value,  # Always include entity field, same as users collection
            'moduleAccess': '',  # Initialize moduleAccess field
            'moduleRole': '',  # Initialize moduleRole field
            'moduleAccessRole': '',  # Initialize moduleAccessRole combined field
        }
        
        # Add token to onboarding data if generated successfully
        if encrypted_token:
            onboarding_data['token'] = encrypted_token
            onboarding_data['token_updated_at'] = datetime.utcnow()
        
        print(f"[DEBUG] Onboarding data being sent to Firestore (onboarding collection - FastAPI): {onboarding_data}")
        
        db.collection('onboarding').add(onboarding_data) # Synchronous call

        response_content = {
            "message": "User created successfully",
            "user": {
                "id": user_id,
                "email": email,
                "name": full_name,
                "role": role
            }
        }
        
        # Include token in response if generated
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

            # Fallbacks for timestamps
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
                # Prefer document update_time, then created_at_dt, then create_time
                if isinstance(doc_update, datetime):
                    updated_at_dt = doc_update
                elif created_at_dt is not None:
                    updated_at_dt = created_at_dt
                elif isinstance(doc_create, datetime):
                    updated_at_dt = doc_create

            created_at_str = created_at_dt.isoformat() + 'Z' if created_at_dt else None
            updated_at_str = updated_at_dt.isoformat() + 'Z' if updated_at_dt else None

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
                'moduleAccess': user_info.get('moduleAccess') or onboarding_info.get('moduleAccess', ''),
                'moduleRole': user_info.get('moduleRole') or onboarding_info.get('moduleRole', ''),
                'moduleAccessRole': user_info.get('moduleAccessRole') or onboarding_info.get('moduleAccessRole', ''),
                'createdAt': created_at_str,
                'updatedAt': updated_at_str,
            }
            # Sort primarily by updated_at, fallback to created_at
            sort_key = updated_at_dt or created_at_dt
            users_with_sort_keys.append((sort_key, user_payload))

        users_with_sort_keys.sort(key=lambda item: item[0] or datetime.min, reverse=True)
        users_data = [payload for _, payload in users_with_sort_keys]

        return JSONResponse(status_code=status.HTTP_200_OK, content={'users': users_data})
    except Exception as e:
        print(f"[ERROR] During users fetch: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.patch("/api/users/{user_id}")
async def update_user(user_id: str, user_update: UserUpdate = Body(...)):
    try:
        print(f"[DEBUG] update_user called for user_id={user_id} with body={user_update.model_dump()}")
        update_payload = {}
        if user_update.role is not None:
            update_payload['role'] = user_update.role
        if user_update.status is not None:
            update_payload['status'] = user_update.status
        if user_update.entity is not None:
            update_payload['entity'] = user_update.entity
        if user_update.moduleAccess is not None:
            update_payload['moduleAccess'] = user_update.moduleAccess
        if user_update.moduleRole is not None:
            update_payload['moduleRole'] = user_update.moduleRole
        if user_update.moduleAccessRole is not None:
            update_payload['moduleAccessRole'] = user_update.moduleAccessRole
        if user_update.adminApproved is not None:
            update_payload['admin'] = {'approved': user_update.adminApproved}

        if not update_payload:
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content={'error': 'No valid fields provided for update'},
            )

        update_payload['updated_at'] = datetime.utcnow()

        user_ref = db.collection('users').document(user_id)
        
        # Get current user data BEFORE updating (needed for token generation)
        current_user_doc = user_ref.get()
        current_user_data = current_user_doc.to_dict() or {}
        
        user_ref.update(update_payload)
        print(f"[DEBUG] Firestore users/{user_id} updated with: {update_payload}")

        # Always try to update the onboarding collection with any provided fields
        onboarding_update_payload = {'updated_at': datetime.utcnow()}
        if user_update.role is not None:
            onboarding_update_payload['role'] = user_update.role
        if user_update.status is not None:
            onboarding_update_payload['status'] = user_update.status
        if user_update.entity is not None:
            onboarding_update_payload['entity'] = user_update.entity
        if user_update.moduleAccess is not None:
            onboarding_update_payload['moduleAccess'] = user_update.moduleAccess
        if user_update.moduleRole is not None:
            onboarding_update_payload['moduleRole'] = user_update.moduleRole
        if user_update.moduleAccessRole is not None:
            onboarding_update_payload['moduleAccessRole'] = user_update.moduleAccessRole
        if user_update.adminApproved is not None:
            onboarding_update_payload['admin'] = {'approved': user_update.adminApproved}

        # Check if moduleAccessRole is being updated - if so, regenerate token
        should_regenerate_token = user_update.moduleAccessRole is not None
        
        if len(onboarding_update_payload) > 1:  # at least updated_at is there
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
            if onboarding_doc is not None:
                onboarding_doc.reference.update(onboarding_update_payload)
                print(f"[DEBUG] Firestore onboarding for user_id={user_id} updated with: {onboarding_update_payload}")
                
                # Regenerate token if moduleAccessRole changed
                if should_regenerate_token:
                    try:
                        # Get user email for token generation (use current_user_data instead of updated_data)
                        user_email = current_user_data.get('email', '')
                        onboarding_data = onboarding_doc.to_dict() or {}
                        if not user_email:
                            # Try to get from onboarding
                            user_email = onboarding_data.get('email', '')
                        
                        # Get the new module access role
                        new_module_access_role = user_update.moduleAccessRole or ''
                        
                        # Parse moduleAccessRole into roles array
                        roles = parse_module_access_role_to_roles(new_module_access_role)
                        
                        # Get user's full name (use current_user_data instead of updated_data)
                        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or current_user_data.get('firstName') or ''
                        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or current_user_data.get('lastName') or ''
                        full_name = f"{first_name} {last_name}".strip()
                        
                        # Fallback to 'name' field if full_name is empty
                        if not full_name:
                            full_name = current_user_data.get('name', '') or onboarding_data.get('name', '')
                        
                        # Generate new encrypted token
                        encrypted_token = generate_and_encrypt_token(
                            user_id=user_id,
                            email=user_email,
                            full_name=full_name,
                            roles=roles,
                        )
                        
                        # Update onboarding document with new token and ensure email is set
                        update_data = {
                            'token': encrypted_token,
                            'token_updated_at': datetime.utcnow(),
                            'fullName': full_name,  # Add fullName field
                        }
                        # Ensure email is always populated (required for PDH)
                        if user_email and not onboarding_data.get('email'):
                            update_data['email'] = user_email
                        
                        onboarding_doc.reference.update(update_data)
                        print(f"[DEBUG] Token regenerated and stored for user_id={user_id} with moduleAccessRole={new_module_access_role} and roles: {roles}")
                    except Exception as token_error:
                        print(f"[ERROR] Failed to regenerate token during user update: {token_error}")
                        # Continue with update even if token regeneration fails

        # Return the updated user document payload so clients can confirm changes immediately
        updated_doc = user_ref.get()
        updated_data = updated_doc.to_dict() or {}
        # Try to fetch onboarding info as well
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
            'moduleAccess': updated_data.get('moduleAccess') or onboarding_info.get('moduleAccess', ''),
            'moduleRole': updated_data.get('moduleRole') or onboarding_info.get('moduleRole', ''),
            'moduleAccessRole': updated_data.get('moduleAccessRole') or onboarding_info.get('moduleAccessRole', ''),
            'createdAt': created_at_str,
            'updatedAt': updated_at_str,
        }

        return JSONResponse(status_code=status.HTTP_200_OK, content={'message': 'User updated successfully', 'user': user_payload})
    except Exception as e:
        print(f"[ERROR] During user update: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/roles")
async def create_role(role: Role):
    try:
        role_data = role.model_dump()

        # Add created_at and updated_at timestamps
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
            # Create a Role object from the dictionary
            role_obj = Role(**role_data)
            db.collection('roles').add({
                **role_obj.model_dump(),
                'created_at': datetime.utcnow(),
                'updated_at': datetime.utcnow(),
                'first_valid': datetime(2025, 9, 25, 2, 6, 42),  # Specific date from user
                'last_valid': datetime(2039, 12, 31, 2, 6, 29),   # Specific date from user
            })
        return JSONResponse(status_code=status.HTTP_201_CREATED, content={"message": "Initial roles created successfully"})
    except Exception as e:
        print(f"[ERROR] During initial role creation: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/api/auth/login")
async def login_user(user_login: UserLogin):
    try:
        # Normalize email (lowercase and strip whitespace)
        normalized_email = user_login.email.lower().strip()
        info_log(f"Login attempt for email: {normalized_email}")

        users_ref = db.collection('users')
        query = users_ref.where('email', '==', normalized_email).limit(1)
        
        try:
            users = query.get()
        except Exception as query_error:
            error_log(f"Firestore query error during login: {query_error}")
            return JSONResponse(
                status_code=500,
                content={"error": f"Database query failed: {str(query_error)}"}
            )

        # Check if query returned any results
        if not users or len(users) == 0:
            print(f"[DEBUG] User not found: {normalized_email}")
            return JSONResponse(status_code=404, content={"error": "User not found"})

        user_data = users[0].to_dict()
        user_id = users[0].id
        
        # Verify email matches (case-insensitive check)
        stored_email = user_data.get('email', '').lower().strip() if user_data.get('email') else ''
        if stored_email != normalized_email:
            print(f"[DEBUG] Email mismatch: stored={stored_email}, requested={normalized_email}")
            return JSONResponse(status_code=404, content={"error": "User not found"})
        # Authenticate user (e.g., check password) - REMOVED PASSWORD CHECK
        # if user_data['password'] != user_login.password:
        #     raise HTTPException(status_code=401, detail="Invalid credentials")

        user_status = user_data.get('status', 'Pending')

        # Reject login if user status is not 'Active'
        if user_status != 'Active':
            print(
                f"[DEBUG] Login rejected for non-active user. Email: {user_login.email}, Status: {user_status}",
            )
            return JSONResponse(
                status_code=status.HTTP_403_FORBIDDEN,
                content={
                    "error": f"Your account status is '{user_status}'. Please wait for admin approval to activate your account.",
                    "status": user_status
                }
            )

        # Get module role and user name from onboarding collection
        onboarding_data = {}
        module_access_role = ""
        
        try:
            onboarding_query = db.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
            for onboarding_doc in onboarding_query:
                onboarding_data = onboarding_doc.to_dict() or {}
                module_access_role = onboarding_data.get('moduleAccessRole', '') or user_data.get('moduleAccessRole', '')
                break
        except Exception as onboarding_query_error:
            error_log(f"Failed to query onboarding collection: {onboarding_query_error}")
            # Continue with login even if onboarding query fails
        
        # If not found in onboarding, try users collection
        if not module_access_role:
            module_access_role = user_data.get('moduleAccessRole', '')
        
        # Parse moduleAccessRole into roles array
        roles = parse_module_access_role_to_roles(module_access_role)
        
        # Get user's full name
        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or user_data.get('firstName') or ''
        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or user_data.get('lastName') or ''
        full_name = f"{first_name} {last_name}".strip()
        
        # Fallback to 'name' field if full_name is empty
        if not full_name:
            full_name = user_data.get('name', '')

        # Always generate a new token on each login for security and freshness
        encrypted_token = None
        try:
            encrypted_token = generate_and_encrypt_token(
                user_id=user_id,
                email=user_data['email'],
                full_name=full_name,
                roles=roles,
            )
            print(f"[DEBUG] Generated new token for user_id: {user_id} on login with roles: {roles}")
        except Exception as token_error:
            print(f"[ERROR] Failed to generate token during login: {token_error}")
            # Continue with login even if token generation fails
        
        # Store/update token in onboarding collection (khonobuzz) and sync to all collections
        if encrypted_token:
            # Update or create onboarding document in main collection
            if onboarding_data:
                # Update existing onboarding document
                try:
                    onboarding_doc_ref = db.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
                    doc_found = False
                    for doc in onboarding_doc_ref:
                        doc.reference.update({
                            'token': encrypted_token,
                            'token_updated_at': datetime.utcnow(),
                            'updated_at': datetime.utcnow(),
                            'fullName': full_name,  # Add fullName field
                            'email': user_data['email'],  # Ensure email is always present
                        })
                        print(f"[DEBUG] Token updated in main onboarding collection for user_id: {user_id}")
                        doc_found = True
                        break
                    
                    # If document not found in iteration, create it
                    if not doc_found:
                        onboarding_data['token'] = encrypted_token
                        onboarding_data['token_updated_at'] = datetime.utcnow()
                        onboarding_data['email'] = user_data['email']
                        onboarding_data['fullName'] = full_name
                        db.collection('onboarding').add(onboarding_data)
                        print(f"[DEBUG] Created onboarding document with token for user_id: {user_id}")
                except Exception as onboarding_update_error:
                    error_log(f"Failed to update onboarding document: {onboarding_update_error}")
                    # Continue with token sync even if update fails
            else:
                # Create onboarding document if it doesn't exist
                try:
                    onboarding_data = {
                        'user_id': user_id,
                        'email': user_data['email'],
                        'token': encrypted_token,
                        'fullName': full_name,  # Add fullName field
                        'token_updated_at': datetime.utcnow(),
                        'created_at': datetime.utcnow(),
                        'updated_at': datetime.utcnow(),
                    }
                    db.collection('onboarding').add(onboarding_data)
                    print(f"[DEBUG] Created onboarding document with token for user_id: {user_id}")
                except Exception as onboarding_create_error:
                    error_log(f"Failed to create onboarding document: {onboarding_create_error}")
                    # Continue with token sync even if creation fails
            
            # Always sync token and email to PDH onboarding collection
            try:
                pdh_onboarding_ref = pdh_db.collection('onboarding').document(user_id)
                pdh_onboarding_ref.set({
                    'email': user_data['email'],  # Ensure email is always populated
                    'token': encrypted_token,
                    'fullName': full_name,  # Add fullName field
                    'token_updated_at': datetime.utcnow(),
                    'updated_at': datetime.utcnow(),
                }, merge=True)
                print(f"[DEBUG] Token and email synced to PDH onboarding collection for user_id: {user_id}")
            except Exception as pdh_sync_error:
                print(f"[ERROR] Failed to sync token to PDH: {pdh_sync_error}")
            
            # Always sync token to Skills Heatmap onboarding collection
            try:
                skills_heatmap_onboarding_ref = skills_heatmap_db.collection('onboarding').document(user_id)
                skills_heatmap_onboarding_ref.set({
                    'token': encrypted_token,
                    'fullName': full_name,  # Add fullName field
                    'token_updated_at': datetime.utcnow(),
                    'updated_at': datetime.utcnow(),
                }, merge=True)
                print(f"[DEBUG] Token synced to Skills Heatmap onboarding collection for user_id: {user_id}")
            except Exception as skills_sync_error:
                print(f"[ERROR] Failed to sync token to Skills Heatmap: {skills_sync_error}")

        # Successful login, return user data with token
        response_content = {
            "message": "Login successful",
            "user": {
                "id": user_id,
                "email": user_data['email'],
                "name": user_data.get('name', ''),
                "role": user_data.get('role', 'user'),
                "status": user_status,
                "moduleAccessRole": module_access_role,
            }
        }
        
        # Include token in response (optional - you may want to remove this for security)
        # For now, we'll include it so the client can use it
        try:
            response_content["token"] = encrypted_token
        except:
            pass  # Token generation may have failed

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=response_content
        )

    except HTTPException as e:
        error_log(f"Login failed due to HTTPException: {e}")
        return JSONResponse(status_code=e.status_code, content={"error": e.detail})
    except Exception as e:
        import traceback
        error_log(f"During FastAPI login: {e}")
        error_log(f"Traceback: {traceback.format_exc()}")
        return JSONResponse(
            status_code=500,
            content={"error": f"Login failed: {str(e)}"}
        )


@app.get("/api/auth/token")
async def get_user_token(email: str = Query(..., description="User email address")):
    """
    Get the encrypted token for a user by email.
    This endpoint allows authenticated users to retrieve their token
    for appending to module links.
    """
    try:
        info_log(f"Token fetch request for email: {email}")
        
        # Find user by email
        users_ref = db.collection('users')
        query = users_ref.where('email', '==', email).limit(1)
        users = query.get()
        
        if not users:
            print(f"[DEBUG] User not found: {email}")
            return JSONResponse(status_code=404, content={"error": "User not found"})
        
        user_id = users[0].id
        user_data = users[0].to_dict()
        
        # Get token from onboarding collection
        onboarding_query = db.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
        encrypted_token = None
        module_access_role = ""
        onboarding_data = {}
        
        for onboarding_doc in onboarding_query:
            onboarding_data = onboarding_doc.to_dict() or {}
            encrypted_token = onboarding_data.get('token')
            module_access_role = onboarding_data.get('moduleAccessRole', '') or user_data.get('moduleAccessRole', '')
            break
        
        # Parse moduleAccessRole into roles array
        roles = parse_module_access_role_to_roles(module_access_role)
        
        # Get user's full name
        first_name = onboarding_data.get('firstName') or onboarding_data.get('name') or user_data.get('firstName') or ''
        last_name = onboarding_data.get('lastName') or onboarding_data.get('surname') or user_data.get('lastName') or ''
        full_name = f"{first_name} {last_name}".strip()
        
        # Fallback to 'name' field if full_name is empty
        if not full_name:
            full_name = user_data.get('name', '')
        
        # If no token found, generate a new one
        if not encrypted_token:
            print(f"[DEBUG] No token found, generating new token for user_id: {user_id}")
            try:
                encrypted_token = generate_and_encrypt_token(
                    user_id=user_id,
                    email=user_data['email'],
                    full_name=full_name,
                    roles=roles,
                )
                
                # Store the new token
                onboarding_query = db.collection('onboarding').where('user_id', '==', user_id).limit(1).stream()
                found_doc = False
                for doc in onboarding_query:
                    doc.reference.update({
                        'token': encrypted_token,
                        'token_updated_at': datetime.utcnow(),
                        'updated_at': datetime.utcnow(),
                        'fullName': full_name,  # Add fullName field
                    })
                    found_doc = True
                    break
                
                if not found_doc:
                    # Create onboarding document if it doesn't exist
                    onboarding_data = {
                        'user_id': user_id,
                        'email': user_data['email'],
                        'token': encrypted_token,
                        'fullName': full_name,  # Add fullName field
                        'token_updated_at': datetime.utcnow(),
                        'created_at': datetime.utcnow(),
                        'updated_at': datetime.utcnow(),
                    }
                    db.collection('onboarding').add(onboarding_data)
                    
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
        print(f"[ERROR] During token fetch: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})