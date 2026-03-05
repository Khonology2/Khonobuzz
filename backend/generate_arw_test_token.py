"""
Generate an ARW (Automated Recruitment Workflow) test token.
Run from the backend directory: python generate_arw_test_token.py

Uses JWT_SECRET_KEY and ENCRYPTION_KEY from .env (same as the API).
"""
import sys
import os
from datetime import datetime, timezone

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))

# Ensure backend directory is on path so token_utils can load .env
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from token_utils import generate_and_encrypt_token

# Test user: Sam Joe, Admin role for ARW
USER_ID = "test-arw-sasa-zul-001"
EMAIL = "leo.cheng@khonology.com"
FULL_NAME = "Leo Cheng"
ROLES = ["ARW - Hiring Manager"]

if __name__ == "__main__":
    exp_hours = int(os.environ.get("JWT_EXPIRATION_HOURS", "24"))
    now = int(datetime.now(timezone.utc).timestamp())
    iat = now
    exp = now + (exp_hours * 3600)

    token = generate_and_encrypt_token(
        user_id=USER_ID,
        email=EMAIL,
        full_name=FULL_NAME,
        roles=ROLES,
        expiration_hours=exp_hours,
    )
    print("ARW test token (use as ?token=... in the recruitment app URL):")
    print()
    print(token)
    print()
    print("Payload (in token):")
    print("  user_id:    %s" % USER_ID)
    print("  email:      %s" % EMAIL)
    print("  full_name: %s" % FULL_NAME)
    print("  roles:      %s" % ROLES)
    print("  iat:        %d  (issued at, Unix timestamp)" % iat)
    print("  exp:        %d  (expiration, Unix timestamp)" % exp)
