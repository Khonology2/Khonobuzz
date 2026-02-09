import os
import io
from dotenv import load_dotenv
import cloudinary
import cloudinary.uploader
import cloudinary.api
import logging
import hashlib

# Load environment variables
load_dotenv()

logger = logging.getLogger(__name__)

class CloudinaryService:
    def __init__(self):
        self.is_initialized = False
        try:
            # Initialize Cloudinary with environment variables
            cloudinary.config(
                cloud_name=os.getenv('CLOUDINARY_CLOUD_NAME'),
                api_key=os.getenv('CLOUDINARY_API_KEY'),
                api_secret=os.getenv('CLOUDINARY_API_SECRET')
            )
            self.is_initialized = True
            logger.info("Cloudinary service initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Cloudinary: {e}")
            self.is_initialized = False
    
    def upload_profile_image(self, file, user_id):
        """
        Upload a profile image to Cloudinary with proper validation and folder structure
        
        Args:
            file: UploadFile object (from FastAPI multipart/form-data)
            user_id: User ID for folder organization
            
        Returns:
            dict: {
                'success': bool,
                'url': str (if successful),
                'public_id': str (if successful),
                'error': str (if failed)
            }
        """
        try:
            if not self.is_initialized:
                return {
                    'success': False,
                    'error': 'Cloudinary service not initialized'
                }
            
            # Validate file
            if not file:
                return {
                    'success': False,
                    'error': 'No file provided'
                }
            
            # Get file content from UploadFile object
            file.file.seek(0)  # Reset file position
            file_content = file.file.read()
            
            # Reset file position again in case it's needed elsewhere
            file.file.seek(0)
            
            # Check file size (5MB limit)
            file_size = len(file_content)
            
            if file_size > 5 * 1024 * 1024:  # 5MB
                return {
                    'success': False,
                    'error': 'File size exceeds 5MB limit'
                }
            
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
            file_hash = hashlib.md5(file_content).hexdigest()[:8]
            file_extension = content_type.split('/')[-1]
            safe_filename = f"profile_{file_hash}.{file_extension}"
            
            # Upload to Cloudinary
            upload_response = cloudinary.uploader.upload(
                file_content,
                public_id=safe_filename,
                folder=folder_path,
                resource_type="image",
                format=file_extension,
                overwrite=True,
                responsive_breakpoints={
                    "create_derived": True,
                    "bytes_step": 20000,
                    "min_width": 200,
                    "max_width": 1000,
                    "max_images": 5
                }
            )
            
            # Check upload response
            if upload_response and 'secure_url' in upload_response:
                logger.info(f"Profile image uploaded successfully for user_id: {user_id}")
                return {
                    'success': True,
                    'url': upload_response['secure_url'],
                    'public_id': upload_response['public_id']
                }
            else:
                return {
                    'success': False,
                    'error': 'Upload failed - invalid response from Cloudinary'
                }
                
        except Exception as e:
            logger.error(f"Profile image upload error: {str(e)}")
            return {
                'success': False,
                'error': f'Upload failed: {str(e)}'
            }
    
    def upload_image(self, image_file, folder='profile_pictures'):
        """
        Upload an image to Cloudinary
        
        Args:
            image_file: File object or file path
            folder: Cloudinary folder name (default: 'profile_pictures')
            
        Returns:
            dict: Upload response containing url and public_id
        """
        try:
            if not self.is_initialized:
                return {
                    'success': False,
                    'error': 'Cloudinary not initialized',
                    'message': 'Failed to upload image'
                }
            
            # Upload to Cloudinary
            upload_info = cloudinary.uploader.upload(
                image_file,
                folder=folder,
                resource_type="image",
                overwrite=True
            )
            
            # Check if upload was successful
            if upload_info and 'secure_url' in upload_info:
                return {
                    'success': True,
                    'secure_url': upload_info['secure_url'],
                    'public_id': upload_info['public_id'],
                    'message': 'Image uploaded successfully'
                }
            else:
                return {
                    'success': False,
                    'error': 'Invalid response from Cloudinary',
                    'message': 'Failed to upload image'
                }
                
        except Exception as e:
            logger.error(f"Cloudinary upload error: {e}")
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
            if not self.is_initialized:
                return image_url
            
            # Create transformation parameters
            transformations = []
            if width:
                transformations.append(f"w_{width}")
            if height:
                transformations.append(f"h_{height}")
            transformations.append(f"q_{quality}")
            
            if transformations:
                transformation_string = ",".join(transformations)
                # Add transformations to URL
                if "?" in image_url:
                    return f"{image_url}&{transformation_string}"
                else:
                    return f"{image_url}?{transformation_string}"
            
            return image_url
            
        except Exception as e:
            logger.error(f"Error creating optimized URL: {e}")
            return image_url
    
    def delete_image(self, public_id):
        """
        Delete an image from Cloudinary
        
        Args:
            public_id: Cloudinary public ID
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            delete_response = cloudinary.api.delete_resources([public_id], resource_type="image")
            return delete_response and 'deleted' in delete_response and delete_response['deleted']
            
        except Exception as e:
            logger.error(f"Error deleting image: {e}")
            return False

# Create global instance
cloudinary_service = CloudinaryService()
