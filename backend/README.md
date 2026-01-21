# Khonology Backend API

FastAPI-based REST API for the Khonology project management application.

## Setup Instructions

### Option 1: Docker Setup (Recommended)

#### Prerequisites
- Docker and Docker Compose installed
- Firebase credentials files

#### Quick Start
1. **Create credentials directory:**
```bash
mkdir -p credentials
```

2. **Copy Firebase credentials to credentials directory:**
```bash
# Copy all JSON credential files to the credentials/ directory
cp *.json credentials/
```

3. **Run with Docker Compose:**
```bash
# For development (without local database)
docker-compose up --build

# For development with local PostgreSQL
docker-compose --profile local-db up --build

# For production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build
```

4. **Access the API:**
- API: `http://localhost:5000`
- Documentation: `http://localhost:5000/docs`

#### Environment Variables
Create a `.env` file or set environment variables:
```bash
# Required
JWT_SECRET_KEY=your-secret-key
ENCRYPTION_KEY=your-encryption-key
DATABASE_URL=your-database-url

# Optional
DEBUG=false
HOST=0.0.0.0
PORT=5000
BACKEND_URL=https://your-backend-url.com
```

### Option 2: Local Development

#### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

#### 2. Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Go to Project Settings > Service Accounts
4. Generate a new private key
5. Download the JSON file and rename it to `khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-d20003b368.json`
6. Place it in the backend folder

#### 3. Environment Variables
Copy `.env` file and update the values:
```bash
cp .env.example .env
```

#### 4. Run the Application
```bash
python app.py
```

The API will be available at:
- **Local Development**: `http://localhost:5000`
- **Production**: `https://khonobuzz-backend-i24f.onrender.com`

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
