"""
Token generation and encryption utilities for secure authentication.
"""
import jwt
from datetime import datetime, timedelta
from cryptography.fernet import Fernet
import os
from dotenv import load_dotenv
import base64

load_dotenv()

# JWT Configuration
JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY') or os.urandom(32).hex()
JWT_ALGORITHM = 'HS256'
JWT_EXPIRATION_HOURS = int(os.environ.get('JWT_EXPIRATION_HOURS', '24'))  # Default 24 hours

# Encryption Configuration
# Generate encryption key from environment or create a new one
ENCRYPTION_KEY = os.environ.get('ENCRYPTION_KEY')
if not ENCRYPTION_KEY:
    # Generate a new key if not set (for development only)
    # In production, this should be set via environment variable
    # Fernet.generate_key() returns a base64-encoded key as bytes
    key = Fernet.generate_key()
    ENCRYPTION_KEY = key.decode()  # Convert bytes to string
    print(f"[WARNING] ENCRYPTION_KEY not set. Generated new key for this session: {ENCRYPTION_KEY}")
    print("[WARNING] Set ENCRYPTION_KEY in environment variables for production!")
    fernet = Fernet(key)
else:
    # Ensure the encryption key is the right format (32 bytes base64-encoded)
    try:
        # Fernet keys are base64-encoded 32-byte keys
        # Try to create Fernet instance to validate the key
        fernet = Fernet(ENCRYPTION_KEY.encode())
    except Exception as e:
        print(f"[ERROR] Invalid ENCRYPTION_KEY: {e}")
        # Generate a new valid key
        key = Fernet.generate_key()
        ENCRYPTION_KEY = key.decode()
        fernet = Fernet(key)
        print(f"[WARNING] Generated new encryption key: {ENCRYPTION_KEY}")


def generate_jwt_token(user_id: str, email: str, module_role: str = "", expiration_hours: int = None) -> str:
    """
    Generate a JWT token containing user information.
    
    Args:
        user_id: The user's unique identifier
        email: The user's email address
        module_role: The user's module access role (e.g., "PDH - Employee", "PDH - Manager")
        expiration_hours: Token expiration time in hours (defaults to JWT_EXPIRATION_HOURS)
    
    Returns:
        A JWT token string
    """
    if expiration_hours is None:
        expiration_hours = JWT_EXPIRATION_HOURS
    
    expiration_time = datetime.utcnow() + timedelta(hours=expiration_hours)
    
    payload = {
        'user_id': user_id,
        'email': email,
        'module_role': module_role,
        'exp': expiration_time,
        'iat': datetime.utcnow(),
    }
    
    token = jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    return token


def encrypt_token(token: str) -> str:
    """
    Encrypt a JWT token using Fernet symmetric encryption.
    
    Args:
        token: The JWT token string to encrypt
    
    Returns:
        An encrypted token string (base64-encoded)
    """
    try:
        encrypted_token = fernet.encrypt(token.encode())
        return encrypted_token.decode()
    except Exception as e:
        print(f"[ERROR] Failed to encrypt token: {e}")
        raise


def decrypt_token(encrypted_token: str) -> str:
    """
    Decrypt an encrypted JWT token.
    
    Args:
        encrypted_token: The encrypted token string
    
    Returns:
        The decrypted JWT token string
    
    Raises:
        Exception: If decryption fails
    """
    try:
        decrypted_token = fernet.decrypt(encrypted_token.encode())
        return decrypted_token.decode()
    except Exception as e:
        print(f"[ERROR] Failed to decrypt token: {e}")
        raise


def verify_token(token: str) -> dict:
    """
    Verify and decode a JWT token.
    
    Args:
        token: The JWT token string (can be encrypted or plain)
    
    Returns:
        The decoded token payload as a dictionary
    
    Raises:
        jwt.ExpiredSignatureError: If the token has expired
        jwt.InvalidTokenError: If the token is invalid
    """
    try:
        # Try to decrypt first (in case it's encrypted)
        try:
            token = decrypt_token(token)
        except:
            # If decryption fails, assume it's already a plain JWT token
            pass
        
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise jwt.ExpiredSignatureError("Token has expired")
    except jwt.InvalidTokenError as e:
        raise jwt.InvalidTokenError(f"Invalid token: {e}")


def generate_and_encrypt_token(user_id: str, email: str, module_role: str = "", expiration_hours: int = None) -> str:
    """
    Convenience function to generate a JWT token and encrypt it in one step.
    
    Args:
        user_id: The user's unique identifier
        email: The user's email address
        module_role: The user's module access role
        expiration_hours: Token expiration time in hours
    
    Returns:
        An encrypted JWT token string ready for storage
    """
    token = generate_jwt_token(user_id, email, module_role, expiration_hours)
    encrypted_token = encrypt_token(token)
    return encrypted_token

