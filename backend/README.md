# Khonology Backend API

FastAPI-based REST API for the Khonology project management application.

## Setup Instructions

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Go to Project Settings > Service Accounts
4. Generate a new private key
5. Download the JSON file and rename it to `khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-d20003b368.json`
6. Place it in the backend folder

### 3. Environment Variables
Copy `.env` file and update the values:
```bash
cp .env.example .env
```

### 4. Run the Application
```bash
python app.py
```

The API will be available at:
- **Local Development**: `http://localhost:5000`
- **Production**: `https://khonobuzz-backend.onrender.com`

### 5. Testing the API
Once the server is running, you can test it by visiting:
- `http://localhost:5000/` - API status check
- `http://localhost:5000/docs` - Interactive API documentation (Swagger UI)
- `http://localhost:5000/redoc` - Alternative API documentation

### 6. Connecting Flutter App
Make sure the Flutter app's `lib/config/api_config.dart` has:
```dart
static const String baseUrl = 'http://localhost:5000';
```

For Android emulator, use:
```dart
static const String baseUrl = 'http://10.0.2.2:5000';
```

## API Endpoints

### Authentication
- `GET /` - Check API status
- `POST /api/auth/register` - User registration

### Projects
- `GET /api/projects` - Get all projects
- `POST /api/projects` - Create new project
- `PUT /api/projects/<id>` - Update project
- `DELETE /api/projects/<id>` - Delete project

### Time Tracking
- `POST /api/time-tracking` - Log time entry
- `GET /api/time-tracking/<user_id>` - Get user time entries

### Resource Allocation
- `POST /api/resource-allocation` - Allocate resource to project
- `GET /api/resource-allocation/<project_id>` - Get project allocations

### Analytics
- `GET /api/analytics/dashboard` - Get dashboard analytics

### User Management
- `GET /api/users` - Get all users
- `PUT /api/users/<id>` - Update user

## Firebase Collections

The API uses the following Firestore collections:
- `users` - User accounts and profiles
- `projects` - Project information
- `time_entries` - Time tracking data
- `resource_allocations` - Resource allocation data
