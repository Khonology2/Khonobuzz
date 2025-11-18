"""
Script to generate secure credentials for .env file.
Run this script to generate JWT_SECRET_KEY, ENCRYPTION_KEY, and SECRET_KEY.
"""
import secrets
from cryptography.fernet import Fernet

# Generate JWT Secret Key (32+ character random string)
jwt_secret_key = secrets.token_urlsafe(32)

# Generate Application Secret Key (different from JWT secret)
app_secret_key = secrets.token_urlsafe(32)

# Generate Fernet Encryption Key
encryption_key = Fernet.generate_key().decode()

# Default expiration hours
jwt_expiration_hours = 24

print("\n" + "="*70)
print("Generated Environment Variables for .env file:")
print("="*70)
print("\n# Critical Security Variables")
print(f"JWT_SECRET_KEY={jwt_secret_key}")
print(f"ENCRYPTION_KEY={encryption_key}")
print(f"SECRET_KEY={app_secret_key}")
print(f"\n# JWT Configuration")
print(f"JWT_EXPIRATION_HOURS={jwt_expiration_hours}")
print("\n" + "="*70)
print("\nCopy these values to your .env file in the backend directory.")
print("See ENV_VARIABLES_REQUIRED.md for complete .env template.")
print("="*70 + "\n")

