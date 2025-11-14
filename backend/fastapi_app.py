from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.gzip import GZipMiddleware
from brotli_asgi import BrotliMiddleware  # pyright: ignore[reportMissingImports]  # pyright: ignore[reportMissingImports]
from firebase_admin import credentials, firestore, initialize_app
from dotenv import load_dotenv
import os
from datetime import datetime
from pydantic import BaseModel
from fastapi.responses import JSONResponse
from fastapi import status # Import status for HTTP status codes
from fastapi import HTTPException # Import HTTPException for authentication errors
from typing import Optional

load_dotenv()

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
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=False,  # Must be False when using "*" origin
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)
app.add_middleware(BrotliMiddleware)
app.add_middleware(GZipMiddleware, minimum_size=500)

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

        if user_fields:
            pdh_db.collection('users').document(uid).set(user_fields, merge=True)
        if onboarding_fields:
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

        if user_fields:
            skills_heatmap_db.collection('users').document(uid).set(user_fields, merge=True)
        if onboarding_fields:
            skills_heatmap_db.collection('onboarding').document(uid).set(onboarding_fields, merge=True)
            
        return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "Skills Heatmap update successful"})
    except Exception as e:
        print(f"[ERROR] During Skills Heatmap update: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.get("/")
async def home():
    return {"message": "Khonology Backend API (FastAPI)", "status": "running"}

@app.post("/api/auth/register")
async def register_user(user: UserRegister):
    try:
        print(f"[DEBUG] Raw incoming JSON data (FastAPI): {user.model_dump()}")

        email = user.email
        password = user.password
        full_name = user.name
        first_name = user.firstName
        last_name = user.lastName
        role = user.role
        department = user.department
        designation = user.designation

        print(f"[DEBUG] Extracted email (FastAPI): {email}")
        print(f"[DEBUG] Extracted password (FastAPI): {password}")
        print(f"[DEBUG] Extracted full_name (from Pydantic): {full_name}")
        print(f"[DEBUG] Parsed first_name (from Pydantic): {first_name}")
        print(f"[DEBUG] Parsed last_name (from Pydantic): {last_name}")
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

        onboarding_data = {
            'user_id': user_id,
            'email': email,
            'name': first_name,
            'surname': last_name,
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
        print(f"[DEBUG] Onboarding data being sent to Firestore (onboarding collection - FastAPI): {onboarding_data}")
        
        db.collection('onboarding').add(onboarding_data) # Synchronous call

        return JSONResponse(
            status_code=status.HTTP_201_CREATED,
            content={
                "message": "User created successfully",
                "user": {
                    "id": user_id,
                    "email": email,
                    "name": full_name,
                    "role": role
                }
            }
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
        print(f"[DEBUG] Login attempt for email: {user_login.email}")

        users_ref = db.collection('users')
        query = users_ref.where('email', '==', user_login.email).limit(1)
        users = query.get()

        if not users:
            print(f"[DEBUG] User not found: {user_login.email}")
            return JSONResponse(status_code=404, content={"error": "User not found"})

        user_data = users[0].to_dict()
        # Authenticate user (e.g., check password) - REMOVED PASSWORD CHECK
        # if user_data['password'] != user_login.password:
        #     raise HTTPException(status_code=401, detail="Invalid credentials")

        user_status = user_data.get('status', 'Pending')

        if user_status != 'Active':
            print(
                "[DEBUG] Login proceeding for non-active user.",
                f"Email: {user_login.email}, Status: {user_status}",
            )

        # Successful login, return user data
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "message": "Login successful",
                "user": {
                    "id": users[0].id,
                    "email": user_data['email'],
                    "name": user_data.get('name', ''),
                    "role": user_data.get('role', 'user'),
                    "status": user_status,
                }
            }
        )

    except HTTPException as e:
        print(f"[DEBUG] Login failed due to HTTPException: {e}")
        return JSONResponse(status_code=e.status_code, content={"error": e.detail})
    except Exception as e:
        print(f"[ERROR] During FastAPI login: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
