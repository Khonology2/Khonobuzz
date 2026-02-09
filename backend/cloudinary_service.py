"""
Cloudinary Service for Profile Picture Uploads
Replaces ImageKit with Cloudinary for better integration
"""

import os
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
import cloudinary
import cloudinary.uploader
from dotenv import load_dotenv

load_dotenv()

class CloudinaryService:
    """Service for handling Cloudinary operations"""
    
    def __init__(self):
        """Initialize Cloudinary with environment variables"""
        self.cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME')
        self.api_key = os.getenv('CLOUDINARY_API_KEY')
        self.api_secret = os.getenv('CLOUDINARY_API_SECRET')
        
        if not all([self.cloud_name, self.api_key, self.api_secret]):
            raise ValueError("Missing Cloudinary configuration in environment variables")
        
        # Configure Cloudinary
        cloudinary.config(
            cloud_name=self.cloud_name,
            api_key=self.api_key,
            api_secret=self.api_secret
        )
    
    async def upload_profile_image(self, file, user_id: str) -> Dict[str, Any]:
        """
        Upload profile image to Cloudinary
        
        Args:
            file: The image file to upload
            user_id: User ID for folder organization
            
        Returns:
            Dict containing upload result with success status, URL, and metadata
        """
        try:
            print(f"[CLOUDINARY] Starting upload for user: {user_id}")
            print(f"[CLOUDINARY] File details: {file.filename if hasattr(file, 'filename') else 'Unknown'}")
            print(f"[CLOUDINARY] File type: {type(file)}")
            
            # Sanitize user ID for folder names (remove special characters)
            import re
            sanitized_user_id = re.sub(r'[^a-zA-Z0-9_\-\.]', '_', user_id)
            print(f"[CLOUDINARY] Sanitized user ID: {sanitized_user_id}")
            
            # Generate unique filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            unique_id = str(uuid.uuid4())[:8]
            filename = f"profile_{sanitized_user_id}_{timestamp}_{unique_id}"
            
            print(f"[CLOUDINARY] Generated filename: {filename}")
            print(f"[CLOUDINARY] Upload folder: profile_pictures/{sanitized_user_id}")
            
            # Read file content for cloudinary
            file_content = None
            if hasattr(file, 'read'):
                try:
                    # For FastAPI UploadFile, use await
                    file_content = await file.read()
                    print(f"[CLOUDINARY] File content size: {len(file_content)} bytes")
                    print(f"[CLOUDINARY] File content type: {type(file_content)}")
                    print(f"[CLOUDINARY] File content is bytes: {isinstance(file_content, bytes)}")
                except Exception as e:
                    print(f"[CLOUDINARY] Error reading file: {e}")
                    # Fallback to sync read
                    try:
                        file_content = file.read()
                        print(f"[CLOUDINARY] File content size (sync): {len(file_content)} bytes")
                        print(f"[CLOUDINARY] File content type (sync): {type(file_content)}")
                    except Exception as e2:
                        print(f"[CLOUDINARY] Error reading file (sync): {e2}")
                        file_content = file
            else:
                print(f"[CLOUDINARY] File object: {file}")
                file_content = file
            
            # Upload to Cloudinary with user-specific folder
            upload_result = cloudinary.uploader.upload(
                file_content,
                public_id=filename,
                folder=f"profile_pictures/{sanitized_user_id}",
                overwrite=True,
                resource_type="image",
                format="jpg",
                quality="auto:good",
                fetch_format="auto",
                crop="limit",
                width=400,
                height=400
            )
            
            print(f"[CLOUDINARY] Upload result: {upload_result}")
            
            # Construct the response
            result = {
                "success": True,
                "url": upload_result.get("secure_url"),
                "public_id": upload_result.get("public_id"),
                "format": upload_result.get("format"),
                "size": upload_result.get("bytes"),
                "width": upload_result.get("width"),
                "height": upload_result.get("height"),
                "created_at": upload_result.get("created_at"),
                "resource_type": upload_result.get("resource_type"),
                "folder": upload_result.get("folder"),
                "user_id": user_id
            }
            
            print(f"[CLOUDINARY] Profile image uploaded successfully for user: {user_id}")
            print(f"[CLOUDINARY] Image URL: {result['url']}")
            
            return result
            
        except Exception as e:
            print(f"[CLOUDINARY] Error uploading profile image for user {user_id}: {str(e)}")
            import traceback
            print(f"[CLOUDINARY] Traceback: {traceback.format_exc()}")
            return {
                "success": False,
                "error": str(e),
                "message": "Failed to upload profile image to Cloudinary"
            }
    
    def delete_profile_image(self, public_id: str) -> Dict[str, Any]:
        """
        Delete profile image from Cloudinary
        
        Args:
            public_id: The public ID of the image to delete
            
        Returns:
            Dict containing deletion result
        """
        try:
            result = cloudinary.uploader.destroy(public_id)
            
            success = result.get("result") == "ok"
            
            if success:
                print(f"[CLOUDINARY] Profile image deleted successfully: {public_id}")
            else:
                print(f"[CLOUDINARY] Failed to delete profile image: {public_id}")
            
            return {
                "success": success,
                "result": result.get("result"),
                "public_id": public_id
            }
            
        except Exception as e:
            print(f"[CLOUDINARY] Error deleting profile image {public_id}: {str(e)}")
            return {
                "success": False,
                "error": str(e),
                "message": "Failed to delete profile image from Cloudinary"
            }
    
    def get_profile_image_url(self, public_id: str, transformations: Optional[Dict] = None) -> str:
        """
        Get optimized URL for profile image
        
        Args:
            public_id: The public ID of the image
            transformations: Optional Cloudinary transformations
            
        Returns:
            Optimized image URL
        """
        try:
            # Default transformations for profile pictures
            default_transformations = {
                "crop": "fill",
                "gravity": "face",
                "width": 200,
                "height": 200,
                "quality": "auto",
                "fetch_format": "auto"
            }
            
            # Merge with provided transformations
            final_transformations = {**default_transformations, **(transformations or {})}
            
            # Generate URL
            url = cloudinary.CloudinaryImage(public_id).build_url(**final_transformations)
            
            return url
            
        except Exception as e:
            print(f"[CLOUDINARY] Error generating URL for {public_id}: {str(e)}")
            # Return fallback URL
            return f"https://res.cloudinary.com/{self.cloud_name}/image/upload/{public_id}"

# Create global instance
cloudinary_service = CloudinaryService()
