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
JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY')
if not JWT_SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY environment variable is required for token signing and validation")
JWT_ALGORITHM = 'HS256'
JWT_EXPIRATION_HOURS = int(os.environ.get('JWT_EXPIRATION_HOURS', '24'))
ENCRYPTION_KEY = os.environ.get('ENCRYPTION_KEY')
if not ENCRYPTION_KEY:
    raise RuntimeError("ENCRYPTION_KEY environment variable is required for token encryption and decryption")
try:
    fernet = Fernet(ENCRYPTION_KEY.encode())
except Exception as e:
    raise RuntimeError(f"Invalid ENCRYPTION_KEY: {e}")
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
    now = int(datetime.utcnow().timestamp())
    iat = now
    exp = now + (expiration_hours * 3600)
    payload = {
        'user_id': user_id,
        'email': email,
        'full_name': full_name,
        'roles': roles,
        'iat': iat,
        'exp': exp,
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
        token: The JWT token string, possibly Fernet-encrypted
    Returns:
        The decoded token payload as a dictionary
    Raises:
        jwt.ExpiredSignatureError: If the token has expired
        jwt.InvalidTokenError: If the token is invalid or cannot be decrypted
    """
    original_token = token
    try:
        is_probably_encrypted = original_token.startswith('gAAAA') or '.' not in original_token
        try:
            token = decrypt_token(original_token)
        except Exception as decrypt_error:
            if is_probably_encrypted:
                raise jwt.InvalidTokenError(
                    f"Failed to decrypt encrypted token: {decrypt_error}"
                )
            token = original_token
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        if 'user_id' in payload or 'uid' in payload:
            expanded_payload = {
                'user_id': payload.get('user_id') or payload.get('uid', ''),
                'email': payload.get('email') or payload.get('e', ''),
                'full_name': payload.get('full_name', ''),
                'roles': payload.get('roles', []),
                'exp': payload.get('exp'),
                'iat': payload.get('iat', payload.get('exp', 0) - 86400),
            }
            if 'r' in payload or 'module_role' in payload:
                module_role = payload.get('r') or payload.get('module_role', '')
                if module_role and not expanded_payload['roles']:
                    expanded_payload['roles'] = [r.strip() for r in module_role.split(',') if r.strip()]
        else:
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
        module_access_role: Comma-separated string like "PDH - Employee, PDH - Manager"
    Returns:
        List of role strings, e.g., ["PDH - Employee", "PDH - Manager"]
    """
    if not module_access_role or not isinstance(module_access_role, str):
        return []
    roles = [role.strip() for role in module_access_role.split(',') if role.strip()]
    return roles


def parse_module_access_role_to_arw_roles(module_access_role: str) -> list:
    """
    Extract Automated Recruitment Workflow roles from moduleAccessRole and map to ARW - X format.
    Used when issuing a token for the ARW (Automated Recruitment Workflow) app.
    Args:
        module_access_role: Comma-separated string, e.g. "PDH - Employee, Automated Recruitment Workflow - Admin"
    Returns:
        List like ["ARW - Admin", "ARW - Hiring Manager"] for use in the ARW token payload.
    """
    if not module_access_role or not isinstance(module_access_role, str):
        return []
    prefix = "Automated Recruitment Workflow - "
    result = []
    for part in module_access_role.split(','):
        part = part.strip()
        if part.startswith(prefix):
            role_suffix = part[len(prefix):].strip()
            if role_suffix:
                result.append(f"ARW - {role_suffix}")
    return result
def generate_and_encrypt_token(
    user_id: str,
    email: str,
    full_name: str = "",
    roles: list = None,
    expiration_hours: int = None,
) -> str:
    """
    Generate a JWT token and encrypt it for secure storage/transport.
    Args:
        user_id: The user's unique identifier
        email: The user's email address
        full_name: The user's full name (first + last)
        roles: List of user roles (e.g., ["PDH - Employee", "PDH - Manager"])
        expiration_hours: Token expiration time in hours
    Returns:
        An encrypted token string
    """
    plain_token = generate_jwt_token(user_id, email, full_name, roles, expiration_hours)
    try:
        return encrypt_token(plain_token)
    except Exception as e:
        print(f"[ERROR] Failed to encrypt token in generate_and_encrypt_token: {e}")
        raise
