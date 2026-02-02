import os
from dotenv import load_dotenv
from imagekitio import ImageKit
import logging

# Load environment variables
load_dotenv()

logger = logging.getLogger(__name__)

class ImageKitService:
    def __init__(self):
        try:
            # Initialize ImageKit with environment variables
            self.imagekit = ImageKit(
                private_key=os.getenv('IMAGEKIT_PRIVATE_KEY'),
                public_key=os.getenv('IMAGEKIT_PUBLIC_KEY'),
                url_endpoint=os.getenv('IMAGEKIT_URL_ENDPOINT')
            )
            logger.info("ImageKit service initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize ImageKit: {e}")
            # Try alternative initialization
            try:
                self.imagekit = ImageKit(
                    private_key=os.getenv('IMAGEKIT_PRIVATE_KEY'),
                    public_key=os.getenv('IMAGEKIT_PUBLIC_KEY'),
                    url_endpoint=os.getenv('IMAGEKIT_URL_ENDPOINT')
                )
                logger.info("ImageKit service initialized successfully (alternative method)")
            except Exception as e2:
                logger.error(f"Failed to initialize ImageKit with alternative method: {e2}")
                self.imagekit = None
    
    def upload_profile_image(self, file, user_id):
        """
        Upload a profile image to ImageKit with proper validation and folder structure
        
        Args:
            file: File object (from multipart/form-data)
            user_id: User ID for folder organization
            
        Returns:
            dict: {
                'success': bool,
                'url': str (if successful),
                'file_id': str (if successful),
                'error': str (if failed)
            }
        """
        try:
            if not self.imagekit:
                return {
                    'success': False,
                    'error': 'ImageKit service not initialized'
                }
            
            # Validate file
            if not file:
                return {
                    'success': False,
                    'error': 'No file provided'
                }
            
            # Check file size (5MB limit)
            file.seek(0, 2)  # Seek to end
            file_size = file.tell()
            file.seek(0)  # Reset to beginning
            
            if file_size > 5 * 1024 * 1024:  # 5MB
                return {
                    'success': False,
                    'error': 'File size exceeds 5MB limit'
                }
            
            # Read file content
            file_content = file.read()
            
            # Validate file type (basic check for image signatures)
            image_signatures = {
                b'\xFF\xD8\xFF': 'image/jpeg',  # JPEG
                b'\x89PNG\r\n\x1a\n': 'image/png',  # PNG
                b'GIF87a': 'image/gif',  # GIF
                b'GIF89a': 'image/gif',  # GIF
                b'RIFF': 'image/webp',  # WebP (RIFF...WEBP)
            }
            
            content_type = None
            for signature, mime_type in image_signatures.items():
                if file_content.startswith(signature):
                    content_type = mime_type
                    break
            
            if not content_type:
                return {
                    'success': False,
                    'error': 'Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed'
                }
            
            # Create folder path
            folder_path = f"profile_pictures/{user_id}"
            
            # Generate safe filename
            import hashlib
            file_hash = hashlib.md5(file_content).hexdigest()[:8]
            file_extension = content_type.split('/')[-1]
            safe_filename = f"profile_{file_hash}.{file_extension}"
            
            # Upload to ImageKit
            upload_response = self.imagekit.upload_file(
                file=file_content,
                file_name=safe_filename,
                options={
                    "folder": folder_path,
                    "use_unique_file_name": False,
                    "response_fields": ["url", "file_id"]
                }
            )
            
            # Check upload response
            if upload_response and hasattr(upload_response, 'url') and upload_response.url:
                return {
                    'success': True,
                    'url': upload_response.url,
                    'file_id': upload_response.file_id if hasattr(upload_response, 'file_id') else ''
                }
            else:
                return {
                    'success': False,
                    'error': 'Upload failed - invalid response from ImageKit'
                }
                
        except Exception as e:
            logger.error(f"Profile image upload error: {str(e)}")
            return {
                'success': False,
                'error': f'Upload failed: {str(e)}'
            }
    
    def upload_image(self, image_file, folder='profile_pictures'):
        """
        Upload an image to ImageKit
        
        Args:
            image_file: File object or file path
            folder: ImageKit folder name (default: 'profile_pictures')
            
        Returns:
            dict: Upload response containing url and file_id
        """
        try:
            if not self.imagekit:
                return {
                    'success': False,
                    'error': 'ImageKit not initialized',
                    'message': 'Failed to upload image'
                }
            
            # Upload to ImageKit
            upload_info = self.imagekit.upload_file(
                file=image_file,
                file_name=f"profile_{hash(image_file) if hasattr(image_file, '__hash__') else str(hash(str(image_file)))}.jpg",
                options={}
            )
            
            # Check if upload was successful
            if upload_info and hasattr(upload_info, 'url') and upload_info.url:
                return {
                    'success': True,
                    'secure_url': upload_info.url,
                    'file_id': upload_info.file_id if hasattr(upload_info, 'file_id') else '',
                    'message': 'Image uploaded successfully'
                }
            else:
                return {
                    'success': False,
                    'error': 'Invalid response from ImageKit',
                    'message': 'Failed to upload image'
                }
                
        except Exception as e:
            logger.error(f"ImageKit upload error: {e}")
            return {
                'success': False,
                'error': str(e),
                'message': 'Failed to upload image'
            }
    
    def get_optimized_url(self, image_url, width=None, height=None, quality=80):
        """
        Get optimized image URL with transformations
        
        Args:
            image_url: Original image URL
            width: Optional width
            height: Optional height
            quality: Image quality (1-100)
            
        Returns:
            str: Optimized image URL
        """
        try:
            if not self.imagekit:
                return image_url
            
            # Create transformation parameters
            transformations = []
            if width:
                transformations.append(f"w-{width}")
            if height:
                transformations.append(f"h-{height}")
            transformations.append(f"q-{quality}")
            
            if transformations:
                transformation_string = ",".join(transformations)
                # Add transformations to URL
                if "?" in image_url:
                    return f"{image_url}&tr={transformation_string}"
                else:
                    return f"{image_url}?tr={transformation_string}"
            
            return image_url
            
        except Exception as e:
            logger.error(f"Error creating optimized URL: {e}")
            return image_url
    
    def delete_image(self, file_id):
        """
        Delete an image from ImageKit
        
        Args:
            file_id: ImageKit file ID
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            if not self.imagekit:
                return False
            
            delete_response = self.imagekit.delete_file(file_id)
            return delete_response and hasattr(delete_response, 'response') and delete_response.response == 204
            
        except Exception as e:
            logger.error(f"Error deleting image: {e}")
            return False

# Create global instance
imagekit_service = ImageKitService()
