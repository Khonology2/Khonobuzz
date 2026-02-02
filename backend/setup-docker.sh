#!/bin/bash

# Docker Setup Script for Khonology Backend
# This script helps set up Docker environment for the backend

set -e

echo "🐳 Khonology Backend Docker Setup"
echo "=================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create credentials directory if it doesn't exist
if [ ! -d "credentials" ]; then
    echo "📁 Creating credentials directory..."
    mkdir -p credentials
    echo "✅ Credentials directory created"
else
    echo "✅ Credentials directory already exists"
fi

# Check for Firebase credentials files
echo ""
echo "🔍 Checking for Firebase credentials files..."

credential_files=(
    "pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json"
    "khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json"
)

missing_files=()
for file in "${credential_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    else
        echo "✅ Found: $file"
        # Copy to credentials directory if not already there
        if [ ! -f "credentials/$file" ]; then
            cp "$file" "credentials/"
            echo "📋 Copied to credentials/: $file"
        fi
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo ""
    echo "❌ Missing Firebase credential files:"
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
    echo ""
    echo "Please place the missing JSON credential files in the backend directory and run this script again."
    exit 1
fi

# Check for .env file
echo ""
echo "🔍 Checking for environment configuration..."
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found. Creating example .env file..."
    cat > .env << EOF
# Required Environment Variables
JWT_SECRET_KEY=your-super-secret-jwt-key-here
ENCRYPTION_KEY=your-super-secret-encryption-key-here
DATABASE_URL=postgresql://user:password@localhost:5432/database_name

# Optional Environment Variables
DEBUG=false
HOST=0.0.0.0
PORT=5000
BACKEND_URL=https://your-backend-url.com

# Firebase Credentials Paths
PDH_FIREBASE_CREDENTIALS_PATH=/app/credentials/pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json
FIREBASE_CREDENTIALS_PATH=/app/credentials/khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json
EOF
    echo "✅ Example .env file created. Please update it with your actual values."
else
    echo "✅ .env file found"
fi

# Ask user which setup they want
echo ""
echo "🚀 Choose your setup option:"
echo "1) Development (without local database)"
echo "2) Development (with local PostgreSQL)"
echo "3) Production"
echo "4) Just build Docker image"
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo "🔧 Starting development environment..."
        docker-compose up --build
        ;;
    2)
        echo "🔧 Starting development environment with local PostgreSQL..."
        docker-compose --profile local-db up --build
        ;;
    3)
        echo "🏭 Starting production environment..."
        if [ ! -f "docker-compose.prod.yml" ]; then
            echo "❌ docker-compose.prod.yml not found!"
            exit 1
        fi
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d
        ;;
    4)
        echo "🏗️  Building Docker image..."
        docker build -t khonology-backend .
        echo "✅ Docker image built successfully!"
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "✨ Setup complete!"
echo "📖 API Documentation: http://localhost:5000/docs"
echo "🏥 Health Check: http://localhost:5000/health"
