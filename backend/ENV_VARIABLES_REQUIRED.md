# Environment Variables Required for Backend

This document lists all sensitive information and configuration values that should be placed in the `.env` file.

## 🔐 Critical Security Variables (REQUIRED)

### JWT & Token Configuration
- **JWT_SECRET_KEY** - Secret key for JWT token signing (32+ character random string)
- **ENCRYPTION_KEY** - Fernet encryption key for token encryption (generate using `Fernet.generate_key()`)
- **JWT_EXPIRATION_HOURS** - Token expiration time in hours (default: 24)

### Application Security
- **SECRET_KEY** - General application secret key (should be different from JWT_SECRET_KEY)

## 🔑 Firebase Credentials Paths

### Main Firebase Project
- **FIREBASE_CREDENTIALS_PATH** - Path to main Firebase service account JSON file
  - Default: `khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-d20003b368.json`

### PDH Firebase Project
- **PDH_FIREBASE_CREDENTIALS_PATH** - Path to PDH Firebase service account JSON file
  - Default: `pdh-fe6eb-firebase-adminsdk-fbsvc-6fbc402974.json`

### Skills Heatmap Firebase Project
- **SKILLS_HEATMAP_FIREBASE_CREDENTIALS_PATH** - Path to Skills Heatmap Firebase service account JSON file
  - Default: `resource-capacity-3b654-firebase-adminsdk-fbsvc-71599861bf.json`

## ⚙️ Server Configuration

### Server Settings
- **PORT** - Server port number (default: 5000)
- **HOST** - Server host address (default: 0.0.0.0 for development)

### Environment
- **DEBUG** - Debug mode (True/False, default: True)
  - **IMPORTANT**: Set to `False` in production!

## 🌐 CORS Configuration (Production)

### CORS Settings
- **CORS_ORIGINS** - Comma-separated list of allowed origins for CORS
  - Example: `https://khonobuzz-web.netlify.app,https://yourdomain.com`
  - For development: `*` (default, allows all origins)
  - **IMPORTANT**: The production frontend URL (`https://khonobuzz-web.netlify.app`) is automatically added to allowed origins
- **CORS_ALLOW_CREDENTIALS** - Whether to allow credentials in CORS (True/False)
  - Defaults to `True` in production, `False` in development

### Render Deployment Notes
When deploying to Render, the backend automatically detects production environment and:
- Uses specific CORS origins (including Netlify frontend) instead of wildcard
- Enables credentials for secure cookie/auth token handling
- The frontend URL `https://khonobuzz-web.netlify.app` is automatically included

## 📝 Complete .env Template

```env
# ============================================
# CRITICAL SECURITY VARIABLES (REQUIRED)
# ============================================
JWT_SECRET_KEY=your-jwt-secret-key-here
ENCRYPTION_KEY=your-encryption-key-here
SECRET_KEY=your-app-secret-key-here

# ============================================
# JWT CONFIGURATION
# ============================================
JWT_EXPIRATION_HOURS=24

# ============================================
# FIREBASE CREDENTIALS PATHS
# ============================================
FIREBASE_CREDENTIALS_PATH=khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-d20003b368.json
PDH_FIREBASE_CREDENTIALS_PATH=pdh-fe6eb-firebase-adminsdk-fbsvc-6fbc402974.json
SKILLS_HEATMAP_FIREBASE_CREDENTIALS_PATH=resource-capacity-3b654-firebase-adminsdk-fbsvc-71599861bf.json

# ============================================
# SERVER CONFIGURATION
# ============================================
PORT=5000
HOST=0.0.0.0

# ============================================
# ENVIRONMENT SETTINGS
# ============================================
DEBUG=False

# ============================================
# CORS CONFIGURATION (Production)
# ============================================
# CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
# CORS_ALLOW_CREDENTIALS=True
```

## 🚨 Security Notes

1. **Never commit `.env` file to version control** - It's already in `.gitignore`
2. **Use different keys for development and production**
3. **Rotate keys periodically in production**
4. **Set DEBUG=False in production**
5. **Restrict CORS origins in production**
6. **Keep Firebase credential JSON files secure** - They contain sensitive service account keys

## 🔧 Generating Credentials

Run the provided script to generate secure credentials:
```bash
cd backend
python generate_env_credentials.py
```

This will generate:
- JWT_SECRET_KEY
- ENCRYPTION_KEY

You'll still need to set:
- SECRET_KEY (can use same method as JWT_SECRET_KEY)
- Other configuration values as needed

