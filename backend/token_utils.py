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


def generate_jwt_token(user_id: str, email: str, full_name: str = "", roles: list = None, expiration_hours: int = None) -> str:
    """
    Generate a JWT token containing user information for PDH auto-login.
    
    Args:
        user_id: The user's unique identifier
        email: The user's email address
        full_name: The user's full name (first + last)
        roles: List of user roles (e.g., ["PDH - Employee", "PDH - Manager"])
        expiration_hours: Token expiration time in hours (defaults to JWT_EXPIRATION_HOURS)
    
    Returns:
        A JWT token string
    """
    if expiration_hours is None:
        expiration_hours = JWT_EXPIRATION_HOURS
    
    if roles is None:
        roles = []
    
    # Use Unix timestamp (integer) for iat and exp
    now = int(datetime.utcnow().timestamp())
    iat = now
    exp = now + (expiration_hours * 3600)  # Convert hours to seconds
    
    # JWT payload structure for PDH compatibility
    payload = {
        'user_id': user_id,
        'email': email,
        'full_name': full_name,
        'roles': roles,  # Array of roles
        'iat': iat,      # Issued at timestamp
        'exp': exp,      # Expiration timestamp
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
    Returns payload with standard field names.
    Supports both old and new token formats for backward compatibility.
    
    Args:
        token: The JWT token string (plain JWT, no encryption)
    
    Returns:
        The decoded token payload as a dictionary
    
    Raises:
        jwt.ExpiredSignatureError: If the token has expired
        jwt.InvalidTokenError: If the token is invalid
    """
    try:
        # Try to decrypt first (for backward compatibility with old encrypted tokens)
        try:
            token = decrypt_token(token)
        except:
            # If decryption fails, assume it's already a plain JWT token
            pass
        
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        
        # Support both old (shortened) and new (full) formats
        # Old format: uid, e, r
        # New format: user_id, email, full_name, roles, iat, exp
        if 'user_id' in payload or 'uid' in payload:
            # New format or old format - normalize to new format
            expanded_payload = {
                'user_id': payload.get('user_id') or payload.get('uid', ''),
                'email': payload.get('email') or payload.get('e', ''),
                'full_name': payload.get('full_name', ''),
                'roles': payload.get('roles', []),
                'exp': payload.get('exp'),
                'iat': payload.get('iat', payload.get('exp', 0) - 86400),
            }
            
            # If old format with module_role, convert to roles array
            if 'r' in payload or 'module_role' in payload:
                module_role = payload.get('r') or payload.get('module_role', '')
                if module_role and not expanded_payload['roles']:
                    # Parse comma-separated roles into array
                    expanded_payload['roles'] = [r.strip() for r in module_role.split(',') if r.strip()]
        else:
            # Fallback for any other format
            expanded_payload = payload
        
        return expanded_payload
    except jwt.ExpiredSignatureError:
        raise jwt.ExpiredSignatureError("Token has expired")
    except jwt.InvalidTokenError as e:
        raise jwt.InvalidTokenError(f"Invalid token: {e}")


def parse_module_access_role_to_roles(module_access_role: str) -> list:
    """
    Parse moduleAccessRole string into a list of roles.
    
    Args:
        module_access_role: Comma-separated string like "PDH - Employee, Skills Heatmap - Manager"
    
    Returns:
        List of role strings, e.g., ["PDH - Employee", "Skills Heatmap - Manager"]
    """
    if not module_access_role or not isinstance(module_access_role, str):
        return []
    
    # Split by comma and clean up each role
    roles = [role.strip() for role in module_access_role.split(',') if role.strip()]
    return roles


def generate_and_encrypt_token(user_id: str, email: str, full_name: str = "", roles: list = None, expiration_hours: int = None) -> str:
    """
    Generate a plain JWT token (no encryption).
    This function is kept for backward compatibility but now returns plain JWT.
    
    Args:
        user_id: The user's unique identifier
        email: The user's email address
        full_name: The user's full name (first + last)
        roles: List of user roles (e.g., ["PDH - Employee", "PDH - Manager"])
        expiration_hours: Token expiration time in hours
    
    Returns:
        A plain JWT token string ready for storage
    """
    # Return plain JWT token without encryption for PDH compatibility
    return generate_jwt_token(user_id, email, full_name, roles, expiration_hours)

