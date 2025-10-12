from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
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

# Initialize Firebase Admin SDK
cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
initialize_app(cred)
db = firestore.client()

app = FastAPI()

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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

        user_data = {
            'email': email,
            'password': password,
            'name': full_name,
            'role': role,
            'status': 'Pending', # Default new users to 'Pending'
            'created_at': datetime.utcnow(), # Consider using timezone-aware datetimes
            'updated_at': datetime.utcnow()
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
            'updated_at': datetime.utcnow()
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

        # Check if user status is 'Active'
        if user_data['status'] != 'Active':
            raise HTTPException(status_code=403, detail="User not active. Please contact administrator.")

        # Successful login, return user data
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "message": "Login successful",
                "user": {
                    "id": users[0].id,
                    "email": user_data['email'],
                    "name": user_data.get('name', ''),
                    "role": user_data.get('role', 'user')
                }
            }
        )

    except HTTPException as e:
        print(f"[DEBUG] Login failed due to HTTPException: {e}")
        return JSONResponse(status_code=e.status_code, content={"error": e.detail})
    except Exception as e:
        print(f"[ERROR] During FastAPI login: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
