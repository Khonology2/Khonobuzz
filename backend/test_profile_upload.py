#!/usr/bin/env python3
"""
Test script to verify the profile image upload fix
"""

import asyncio
import httpx
import io
from pathlib import Path

async def test_profile_upload():
    """Test the profile image upload endpoint"""
    
    # Create a simple test image
    test_image_content = b"fake_image_content_for_testing"
    files = {
        'file': ('test_avatar.png', io.BytesIO(test_image_content), 'image/png')
    }
    
    params = {
        'user_id': 'test_user@example.com'
    }
    
    url = "http://localhost:8000/users/profile-image"
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, files=files, params=params)
            
            print(f"Status Code: {response.status_code}")
            print(f"Response: {response.text}")
            
            if response.status_code == 200:
                print("✅ Profile image upload test PASSED!")
                return True
            else:
                print("❌ Profile image upload test FAILED!")
                return False
                
    except Exception as e:
        print(f"❌ Test failed with error: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Testing profile image upload fix...")
    result = asyncio.run(test_profile_upload())
    print(f"Test result: {'PASSED' if result else 'FAILED'}")
