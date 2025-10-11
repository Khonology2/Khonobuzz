from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import credentials, firestore, initialize_app
from dotenv import load_dotenv
import os
from datetime import datetime
from pydantic import BaseModel
from fastapi.responses import JSONResponse
from fastapi import status # Import status for HTTP status codes

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
    # Removed password: str

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
            'firstName': first_name,
            'lastName': last_name,
            'department': department,
            'designation': designation,
            'created_at': datetime.utcnow(), # Consider using timezone-aware datetimes
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

        user = users[0].to_dict()
        # Removed password validation: if user['password'] != user_login.password:
        # Removed print statement for invalid credentials
        # Removed JSONResponse for invalid credentials

        print(f"[DEBUG] Login successful for email: {user_login.email}")
        return {
            "message": "Login successful",
            "user": {
                "id": users[0].id,
                "email": user['email'],
                "name": user.get('name', ''),
                "role": user.get('role', 'user')
            }
        }

    except Exception as e:
        print(f"[ERROR] During FastAPI login: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
