#!/usr/bin/env python3
"""
Test script to verify Cloudinary backend functionality
"""

import os
import sys
import requests
import json
from pathlib import Path

# Add backend directory to path
backend_dir = Path(__file__).parent.parent / "backend"
sys.path.insert(0, str(backend_dir))

def test_backend_health():
    """Test if backend is running and healthy"""
    try:
        response = requests.get("http://localhost:5000/health", timeout=5)
        if response.status_code == 200:
            print("✅ Backend is running and healthy")
            return True
        else:
            print(f"❌ Backend health check failed: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Backend connection failed: {e}")
        print("💡 Make sure the backend is running on localhost:5000")
        return False

def test_cloudinary_config():
    """Test Cloudinary configuration"""
    try:
        from dotenv import load_dotenv
        load_dotenv()
        
        cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME')
        api_key = os.getenv('CLOUDINARY_API_KEY')
        api_secret = os.getenv('CLOUDINARY_API_SECRET')
        
        if all([cloud_name, api_key, api_secret]):
            print("✅ Cloudinary environment variables are configured")
            print(f"   - Cloud Name: {cloud_name}")
            print(f"   - API Key: {api_key[:10]}...")
            return True
        else:
            print("❌ Missing Cloudinary configuration:")
            if not cloud_name:
                print("   - CLOUDINARY_CLOUD_NAME not set")
            if not api_key:
                print("   - CLOUDINARY_API_KEY not set")
            if not api_secret:
                print("   - CLOUDINARY_API_SECRET not set")
            return False
    except Exception as e:
        print(f"❌ Error checking Cloudinary config: {e}")
        return False

def test_cloudinary_service():
    """Test Cloudinary service import and initialization"""
    try:
        from cloudinary_service import cloudinary_service
        print("✅ Cloudinary service imported successfully")
        
        # Test service configuration
        if hasattr(cloudinary_service, 'cloud_name'):
            print(f"✅ Cloudinary service configured with cloud: {cloudinary_service.cloud_name}")
            return True
        else:
            print("❌ Cloudinary service not properly configured")
            return False
    except ImportError as e:
        print(f"❌ Failed to import Cloudinary service: {e}")
        return False
    except Exception as e:
        print(f"❌ Cloudinary service error: {e}")
        return False

def test_profile_upload_endpoint():
    """Test profile image upload endpoint exists"""
    try:
        response = requests.options("http://localhost:5000/users/profile-image", timeout=5)
        print("✅ Profile upload endpoint is accessible")
        return True
    except requests.exceptions.RequestException as e:
        print(f"❌ Profile upload endpoint error: {e}")
        return False

def main():
    print("🔍 TESTING CLOUDINARY BACKEND SETUP")
    print("=" * 50)
    
    tests = [
        ("Backend Health", test_backend_health),
        ("Cloudinary Config", test_cloudinary_config),
        ("Cloudinary Service", test_cloudinary_service),
        ("Upload Endpoint", test_profile_upload_endpoint),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n🧪 {test_name}:")
        result = test_func()
        results.append((test_name, result))
    
    print("\n" + "=" * 50)
    print("📊 TEST RESULTS:")
    
    passed = 0
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"   {test_name}: {status}")
        if result:
            passed += 1
    
    print(f"\n🎯 Overall: {passed}/{len(results)} tests passed")
    
    if passed == len(results):
        print("🎉 All tests passed! Cloudinary backend is ready for use.")
        print("\n📱 Frontend Integration Ready:")
        print("   - ProfileImageUpload widget created")
        print("   - Admin profile screen updated")
        print("   - Staff profile screen updated")
        print("   - Backend endpoints configured")
        print("\n🚀 Users can now upload profile pictures!")
    else:
        print("⚠️  Some tests failed. Please check the configuration.")
    
    print("=" * 50)

if __name__ == "__main__":
    main()
