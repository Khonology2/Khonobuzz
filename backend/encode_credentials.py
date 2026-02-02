#!/usr/bin/env python3
"""
Helper script to encode Firebase credentials for Render deployment.
This solves the issue with JSON formatting in environment variables.
"""

import base64
import json
import sys
import os

def encode_credentials(json_file_path):
    """Read JSON file and return base64 encoded string"""
    try:
        with open(json_file_path, 'r') as f:
            json_data = f.read()
        
        # Validate it's proper JSON
        json.loads(json_data)
        
        # Encode to base64
        encoded = base64.b64encode(json_data.encode('utf-8')).decode('utf-8')
        
        print(f"Original JSON length: {len(json_data)} characters")
        print(f"Base64 encoded length: {len(encoded)} characters")
        print("\n" + "="*60)
        print("COPY THIS VALUE for PDH_FIREBASE_CREDENTIALS_JSON in Render:")
        print("="*60)
        print(encoded)
        print("="*60)
        
        return encoded
        
    except FileNotFoundError:
        print(f"Error: File {json_file_path} not found")
        return None
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {json_file_path}: {e}")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None

def main():
    if len(sys.argv) != 2:
        print("Usage: python encode_credentials.py <path-to-firebase-json>")
        print("\nExample:")
        print("  python encode_credentials.py pdh-fe6eb-firebase-adminsdk-fbsvc-6fbc402974.json")
        sys.exit(1)
    
    json_file = sys.argv[1]
    encode_credentials(json_file)

if __name__ == "__main__":
    main()
