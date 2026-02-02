#!/usr/bin/env python3
"""
Script to format Firebase credential JSON files for Render environment variables.
This script:
1. Reads Firebase credential JSON files
2. Converts them to single-line strings suitable for Render
3. Generates the environment variable format ready to copy-paste
Usage:
    python format_credentials_for_render.py
"""
import json
import os
def format_json_for_render(json_file_path, env_var_name):
    """
    Read a JSON file and format it as a single-line string for Render.
    Args:
        json_file_path: Path to the JSON file
        env_var_name: Name of the environment variable
    Returns:
        Formatted string ready for Render
    """
    if not os.path.exists(json_file_path):
        print(f"⚠️  File not found: {json_file_path}")
        return None
    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            json_content = f.read()
            json_data = json.loads(json_content)
        single_line = json.dumps(json_data, separators=(',', ':'))
        return f"{env_var_name}={single_line}"
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in {json_file_path}: {e}")
        return None
    except Exception as e:
        print(f"❌ Error processing {json_file_path}: {e}")
        return None
def main():
    print("=" * 80)
    print("Firebase Credentials Formatter for Render")
    print("=" * 80)
    print()
    credentials = [
        {
            'file': 'pdh-fe6eb-firebase-adminsdk-fbsvc-2700680531.json',
            'env_var': 'PDH_FIREBASE_CREDENTIALS_JSON',
            'description': 'PDH Firebase Credentials'
        },
        {
            'file': 'khonology-buzz-build-web-app-firebase-adminsdk-fbsvc-539b11f7f3.json',
            'env_var': 'FIREBASE_CREDENTIALS_JSON',
            'description': 'Main Firebase Credentials'
        }
    ]
    print("Processing Firebase credential files...")
    print()
    formatted_output = []
    for cred in credentials:
        print(f"Processing: {cred['description']}")
        print(f"  File: {cred['file']}")
        print(f"  Env Var: {cred['env_var']}")
        result = format_json_for_render(cred['file'], cred['env_var'])
        if result:
            formatted_output.append(result)
            print(f"  ✓ Successfully formatted")
        else:
            print(f"  ✗ Failed to format")
        print()
    if formatted_output:
        print("=" * 80)
        print("FORMATTED OUTPUT FOR RENDER")
        print("=" * 80)
        print()
        print("Copy and paste these into Render Dashboard > Environment:")
        print()
        for output in formatted_output:
            print(output)
            print()
        print("=" * 80)
        print("INSTRUCTIONS:")
        print("=" * 80)
        print("1. Go to Render Dashboard > Your Service > Environment")
        print("2. Click 'Add Environment Variable'")
        print("3. For each line above:")
        print("   - Variable Name: The part before the '=' (e.g., PDH_FIREBASE_CREDENTIALS_JSON)")
        print("   - Value: The part after the '=' (the entire JSON string)")
        print("4. Click 'Save Changes'")
        print("5. Render will automatically redeploy")
        print()
        print("NOTE: Render handles multi-line JSON automatically, so you can also")
        print("      copy the original JSON file content directly if preferred.")
        print("=" * 80)
    else:
        print("=" * 80)
        print("❌ No credentials were successfully formatted.")
        print("=" * 80)
        print()
        print("Make sure your Firebase credential JSON files are in the backend/ directory:")
        for cred in credentials:
            print(f"  - {cred['file']}")
if __name__ == '__main__':
    main()
