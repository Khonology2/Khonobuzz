@echo off
REM Docker Setup Script for Khonology Backend (Windows)
REM This script helps set up Docker environment for the backend

echo 🐳 Khonology Backend Docker Setup
echo ==================================

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker is not installed. Please install Docker Desktop first.
    pause
    exit /b 1
)

REM Check if Docker Compose is installed
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker Compose is not installed. Please install Docker Compose first.
    pause
    exit /b 1
)

REM Create credentials directory if it doesn't exist
if not exist "credentials" (
    echo 📁 Creating credentials directory...
    mkdir credentials
    echo ✅ Credentials directory created
) else (
    echo ✅ Credentials directory already exists
)

REM Check for Firebase credentials files
echo.
echo 🔍 Checking for Firebase credentials files...

set missing_files=0

if not exist "pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json" (
    echo ❌ Missing: pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json
    set /a missing_files+=1
) else (
    echo ✅ Found: pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json
    if not exist "credentials\pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json" (
        copy "pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json" "credentials\"
        echo 📋 Copied to credentials\: pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json
    )
)

if not exist "khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json" (
    echo ❌ Missing: khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json
    set /a missing_files+=1
) else (
    echo ✅ Found: khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json
    if not exist "credentials\khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json" (
        copy "khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json" "credentials\"
        echo 📋 Copied to credentials\: khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json
    )
)

if %missing_files% gtr 0 (
    echo.
    echo ❌ Some Firebase credential files are missing. Please place them in the backend directory and run this script again.
    pause
    exit /b 1
)

REM Check for .env file
echo.
echo 🔍 Checking for environment configuration...
if not exist ".env" (
    echo ⚠️  .env file not found. Creating example .env file...
    (
        echo # Required Environment Variables
        echo JWT_SECRET_KEY=your-super-secret-jwt-key-here
        echo ENCRYPTION_KEY=your-super-secret-encryption-key-here
        echo DATABASE_URL=postgresql://user:password@localhost:5432/database_name
        echo.
        echo # Optional Environment Variables
        echo DEBUG=false
        echo HOST=0.0.0.0
        echo PORT=5000
        echo BACKEND_URL=https://your-backend-url.com
        echo.
        echo # Firebase Credentials Paths
        echo PDH_FIREBASE_CREDENTIALS_PATH=/app/credentials/pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json
        echo FIREBASE_CREDENTIALS_PATH=/app/credentials/khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json
    ) > .env
    echo ✅ Example .env file created. Please update it with your actual values.
) else (
    echo ✅ .env file found
)

REM Ask user which setup they want
echo.
echo 🚀 Choose your setup option:
echo 1^) Development ^(without local database^)
echo 2^) Development ^(with local PostgreSQL^)
echo 3^) Production
echo 4^) Just build Docker image
set /p choice=Enter your choice ^(1-4^): 

if "%choice%"=="1" (
    echo 🔧 Starting development environment...
    docker-compose up --build
) else if "%choice%"=="2" (
    echo 🔧 Starting development environment with local PostgreSQL...
    docker-compose --profile local-db up --build
) else if "%choice%"=="3" (
    echo 🏭 Starting production environment...
    if not exist "docker-compose.prod.yml" (
        echo ❌ docker-compose.prod.yml not found!
        pause
        exit /b 1
    )
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d
) else if "%choice%"=="4" (
    echo 🏗️  Building Docker image...
    docker build -t khonology-backend .
    echo ✅ Docker image built successfully!
) else (
    echo ❌ Invalid choice. Please run the script again.
    pause
    exit /b 1
)

echo.
echo ✨ Setup complete!
echo 📖 API Documentation: http://localhost:5000/docs
echo 🏥 Health Check: http://localhost:5000/health
pause
