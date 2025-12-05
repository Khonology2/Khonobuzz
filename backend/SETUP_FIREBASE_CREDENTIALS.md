# Setting Up Firebase Credentials in .env

This guide explains how to move Firebase credentials from JSON files to environment variables in your `.env` file.

## Quick Setup

1. **Run the conversion script:**
   ```bash
   cd backend
   python convert_credentials_to_env.py
   ```

2. **Copy the output** and add it to your `.env` file.

3. **The backend will automatically use the credentials from `.env`** instead of JSON files.

## Manual Setup (Alternative)

If you prefer to do it manually:

1. **Convert each JSON file to base64:**
   ```python
   import json
   import base64
   
   # Read the JSON file
   with open('resource-capacity-3b654-firebase-adminsdk-fbsvc-71599861bf.json', 'r') as f:
       content = f.read()
   
   # Encode to base64
   base64_str = base64.b64encode(content.encode('utf-8')).decode('utf-8')
   print(f"SKILLS_HEATMAP_FIREBASE_CREDENTIALS_JSON={base64_str}")
   ```

2. **Add to your `.env` file:**
   ```env
   PDH_FIREBASE_CREDENTIALS_JSON=<base64-encoded-string>
   SKILLS_HEATMAP_FIREBASE_CREDENTIALS_JSON=<base64-encoded-string>
   FIREBASE_CREDENTIALS_JSON=<base64-encoded-string>
   ```

## How It Works

The backend supports **two methods** for loading Firebase credentials:

### Method 1: Base64 Encoded JSON (Recommended)
- Store the entire JSON content as a base64 encoded string in `.env`
- More secure - no JSON files needed in production
- Environment variable names: `*_FIREBASE_CREDENTIALS_JSON`

### Method 2: File Paths (Development)
- Keep JSON files and reference them via file paths
- Environment variable names: `*_FIREBASE_CREDENTIALS_PATH`

**Priority:** The backend checks for base64 JSON first, then file paths, then default file paths.

## Benefits

✅ **More Secure** - Credentials stored in environment variables instead of files  
✅ **Production Ready** - No need to manage JSON files in deployment  
✅ **Flexible** - Can still use file paths for local development  
✅ **Backward Compatible** - Existing setups with file paths still work  

## Verification

After setting up, start your backend server. You should see:
```
[INFO] PDH Firebase credentials loaded successfully
[INFO] Skills Heatmap Firebase credentials loaded successfully
[INFO] Main Firebase credentials loaded successfully
```

If you see errors, check:
1. The base64 strings are correctly formatted in `.env`
2. No extra spaces or line breaks in the environment variables
3. The JSON files are valid (if using file paths)

