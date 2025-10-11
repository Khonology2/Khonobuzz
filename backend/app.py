from flask import Flask, request, jsonify
from flask_cors import CORS
from firebase_admin import credentials, firestore, initialize_app
from config import Config
import os
from datetime import datetime
import uuid

# Initialize Flask app with config
app = Flask(__name__)
app.config.from_object(Config)
CORS(app)  # Enable CORS for Flutter app

# Initialize Firebase Admin SDK using config
cred = credentials.Certificate(app.config['FIREBASE_CREDENTIALS_PATH'])
firebase_app = initialize_app(cred)
db = firestore.client()

# Routes
@app.route('/')
def home():
    return jsonify({"message": "Khonology Backend API", "status": "running"})

# Authentication routes
@app.route('/api/auth/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return jsonify({"error": "Email and password required"}), 400
        
        # Check user in Firebase
        users_ref = db.collection('users')
        query = users_ref.where('email', '==', email).limit(1)
        users = query.get()
        
        if not users:
            return jsonify({"error": "User not found"}), 404
        
        user = users[0].to_dict()
        if user['password'] != password:  # In production, use proper password hashing
            return jsonify({"error": "Invalid credentials"}), 401
        
        return jsonify({
            "message": "Login successful",
            "user": {
                "id": users[0].id,
                "email": user['email'],
                "role": user.get('role', 'user'),
                "name": user.get('name', '')
            }
        }), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/auth/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        print(f"[DEBUG] Raw incoming JSON data: {data}") # Added debug print for raw data

        email = data.get('email')
        password = data.get('password')
        full_name = data.get('name', '') # Get the full name from the incoming data
        
        # Split full_name into first_name and last_name
        name_parts = full_name.split(' ', 1) # Split only on the first space
        first_name = name_parts[0] if len(name_parts) > 0 else ''
        last_name = name_parts[1] if len(name_parts) > 1 else ''
        
        role = data.get('role', 'user')
        department = data.get('department', '') # Get department
        designation = data.get('designation', '') # Get designation
        
        # The combined_name for validation is now simply the full_name received
        combined_name = full_name.strip()

        print(f"[DEBUG] Extracted email: {email}") # Added debug print
        print(f"[DEBUG] Extracted password: {password}") # Added debug print
        print(f"[DEBUG] Extracted full_name (from JSON): {full_name}") # Added debug print
        print(f"[DEBUG] Parsed first_name: {first_name}") # Added debug print
        print(f"[DEBUG] Parsed last_name: {last_name}") # Added debug print
        print(f"[DEBUG] Combined name (for validation): {combined_name}") # Added debug print

        if not email or not password or not combined_name:
            return jsonify({"error": "Email, password, and name required"}), 400
        
        # Check if user already exists
        users_ref = db.collection('users')
        query = users_ref.where('email', '==', email).limit(1)
        existing_users = query.get()
        
        if existing_users:
            return jsonify({"error": "User already exists"}), 409
        
        # Create new user in 'users' collection
        user_data = {
            'email': email,
            'password': password,  # In production, hash this password
            'name': combined_name, # Use combined_name (which is full_name) for users collection
            'role': role,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        print(f"[DEBUG] User data being sent to Firestore (users collection): {user_data}")

        doc_ref = users_ref.add(user_data)
        user_id = doc_ref[1].id
        print(f"[DEBUG] Firestore doc_ref for users: {doc_ref}, User ID: {user_id}")

        # Create entry in 'onboarding' collection
        onboarding_data = {
            'user_id': user_id,
            'email': email,
            'firstName': first_name,
            'lastName': last_name,
            'department': department,
            'designation': designation,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        print(f"[DEBUG] Onboarding data being sent to Firestore (onboarding collection): {onboarding_data}")
        
        db.collection('onboarding').add(onboarding_data)

        return jsonify({
            "message": "User created successfully",
            "user": {
                "id": user_id,
                "email": email,
                "name": combined_name,
                "role": role
            }
        }), 201
        
    except Exception as e:
        print(f"[ERROR] During registration: {e}") # Enhanced error logging
        return jsonify({"error": str(e)}), 500

# Project Management routes
@app.route('/api/projects', methods=['GET'])
def get_projects():
    try:
        projects_ref = db.collection('projects')
        projects = projects_ref.get()
        
        project_list = []
        for project in projects:
            project_data = project.to_dict()
            project_data['id'] = project.id
            project_list.append(project_data)
        
        return jsonify({"projects": project_list}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/projects', methods=['POST'])
def create_project():
    try:
        data = request.get_json()
        
        project_data = {
            'name': data.get('name'),
            'description': data.get('description', ''),
            'status': data.get('status', 'active'),
            'start_date': data.get('start_date'),
            'end_date': data.get('end_date'),
            'assigned_users': data.get('assigned_users', []),
            'created_by': data.get('created_by'),
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        doc_ref = db.collection('projects').add(project_data)
        project_id = doc_ref[1].id
        
        return jsonify({
            "message": "Project created successfully",
            "project_id": project_id
        }), 201
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/projects/<project_id>', methods=['PUT'])
def update_project(project_id):
    try:
        data = request.get_json()
        data['updated_at'] = datetime.utcnow()
        
        db.collection('projects').document(project_id).update(data)
        
        return jsonify({"message": "Project updated successfully"}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/projects/<project_id>', methods=['DELETE'])
def delete_project(project_id):
    try:
        db.collection('projects').document(project_id).delete()
        
        return jsonify({"message": "Project deleted successfully"}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Time Tracking routes
@app.route('/api/time-tracking', methods=['POST'])
def log_time():
    try:
        data = request.get_json()
        
        time_entry = {
            'user_id': data.get('user_id'),
            'project_id': data.get('project_id'),
            'task': data.get('task', ''),
            'hours': data.get('hours'),
            'date': data.get('date'),
            'description': data.get('description', ''),
            'created_at': datetime.utcnow()
        }
        
        doc_ref = db.collection('time_entries').add(time_entry)
        
        return jsonify({
            "message": "Time logged successfully",
            "entry_id": doc_ref[1].id
        }), 201
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/time-tracking/<user_id>', methods=['GET'])
def get_user_time_entries(user_id):
    try:
        time_entries_ref = db.collection('time_entries')
        query = time_entries_ref.where('user_id', '==', user_id)
        entries = query.get()
        
        entry_list = []
        for entry in entries:
            entry_data = entry.to_dict()
            entry_data['id'] = entry.id
            entry_list.append(entry_data)
        
        return jsonify({"time_entries": entry_list}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Resource Allocation routes
@app.route('/api/resource-allocation', methods=['POST'])
def allocate_resource():
    try:
        data = request.get_json()
        
        allocation = {
            'user_id': data.get('user_id'),
            'project_id': data.get('project_id'),
            'role': data.get('role', 'member'),
            'allocation_percentage': data.get('allocation_percentage', 100),
            'start_date': data.get('start_date'),
            'end_date': data.get('end_date'),
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        doc_ref = db.collection('resource_allocations').add(allocation)
        
        return jsonify({
            "message": "Resource allocated successfully",
            "allocation_id": doc_ref[1].id
        }), 201
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/resource-allocation/<project_id>', methods=['GET'])
def get_project_allocations(project_id):
    try:
        allocations_ref = db.collection('resource_allocations')
        query = allocations_ref.where('project_id', '==', project_id)
        allocations = query.get()
        
        allocation_list = []
        for allocation in allocations:
            allocation_data = allocation.to_dict()
            allocation_data['id'] = allocation.id
            allocation_list.append(allocation_data)
        
        return jsonify({"allocations": allocation_list}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Analytics routes
@app.route('/api/analytics/dashboard', methods=['GET'])
def get_dashboard_analytics():
    try:
        # Get project statistics
        projects_ref = db.collection('projects')
        projects = projects_ref.get()
        
        total_projects = len(projects)
        active_projects = len([p for p in projects if p.to_dict().get('status') == 'active'])
        
        # Get time tracking statistics
        time_entries_ref = db.collection('time_entries')
        time_entries = time_entries_ref.get()
        
        total_hours = sum([entry.to_dict().get('hours', 0) for entry in time_entries])
        
        # Get user statistics
        users_ref = db.collection('users')
        users = users_ref.get()
        total_users = len(users)
        
        analytics = {
            'total_projects': total_projects,
            'active_projects': active_projects,
            'total_hours_logged': total_hours,
            'total_users': total_users,
            'completion_rate': round((total_projects - active_projects) / total_projects * 100, 2) if total_projects > 0 else 0
        }
        
        return jsonify({"analytics": analytics}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# User Management routes
@app.route('/api/users', methods=['GET'])
def get_users():
    try:
        users_ref = db.collection('users')
        users = users_ref.get()
        
        user_list = []
        for user in users:
            user_data = user.to_dict()
            user_data['id'] = user.id
            # Remove password from response
            user_data.pop('password', None)
            user_list.append(user_data)
        
        return jsonify({"users": user_list}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/users/<user_id>', methods=['PUT'])
def update_user(user_id):
    try:
        data = request.get_json()
        data['updated_at'] = datetime.utcnow()
        
        # Don't allow password updates through this endpoint
        data.pop('password', None)
        
        db.collection('users').document(user_id).update(data)
        
        return jsonify({"message": "User updated successfully"}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(
        debug=app.config['DEBUG'],
        host='0.0.0.0',
        port=app.config['PORT']
    )
