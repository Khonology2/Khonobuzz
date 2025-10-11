# Khonology Backend API

Flask-based REST API for the Khonology project management application.

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
5. Download the JSON file and rename it to `firebase-service-account.json`
6. Place it in the backend folder

### 3. Environment Variables
Copy `.env` file and update the values:
```bash
cp .env.example .env
```

### 4. Run the Application
```bash
python run.py
```

The API will be available at `http://localhost:5000`

## API Endpoints

### Authentication
- `POST /api/auth/login` - User login
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
