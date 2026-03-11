"""
Generate a Personal Development Hub (PDH) token by role.
Run from the backend directory: python generate_pdh_token.py [options]

Uses JWT_SECRET_KEY and ENCRYPTION_KEY from .env (same as the API).
PDH roles: Employee, Manager, Admin (stored in token as "PDH - <Role>").
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import jwt
from token_utils import (
    generate_jwt_token,
    generate_and_encrypt_token,
    JWT_SECRET_KEY,
    JWT_ALGORITHM,
    JWT_EXPIRATION_HOURS,
)

PDH_ROLES = ("Employee", "Manager", "Admin")


def role_to_pdh_roles(role: str) -> list:
    """Map a single PDH role name to the list used in token payload."""
    r = role.strip()
    if not r:
        return []
    if r.startswith("PDH - Admin "):
        return [r]
    return [f"PDH - {r}"]


def main():
    parser = argparse.ArgumentParser(
        description="Generate a PDH JWT token by role and print full payload details."
    )
    parser.add_argument(
        "--user-id",
        default="pdh-test-user-001",
        help="User ID (default: pdh-test-user-001)",
    )
    parser.add_argument(
        "--email",
        default="test@khonology.com",
        help="User email",
    )
    parser.add_argument(
        "--full-name",
        default="Test User",
        help="User full name",
    )
    parser.add_argument(
        "--role",
        choices=PDH_ROLES,
        default="Employee",
        help="PDH role: Employee, Manager, or Admin (default: Employee)",
    )
    parser.add_argument(
        "--expiration-hours",
        type=int,
        default=None,
        help=f"Token validity in hours (default: JWT_EXPIRATION_HOURS from .env or {JWT_EXPIRATION_HOURS})",
    )
    parser.add_argument(
        "--plain",
        action="store_true",
        help="Also print the plain JWT (before encryption)",
    )
    args = parser.parse_args()

    exp_hours = args.expiration_hours if args.expiration_hours is not None else JWT_EXPIRATION_HOURS
    roles = role_to_pdh_roles(args.role)

    plain_token = generate_jwt_token(
        user_id=args.user_id,
        email=args.email,
        full_name=args.full_name,
        roles=roles,
        expiration_hours=exp_hours,
    )
    encrypted_token = generate_and_encrypt_token(
        user_id=args.user_id,
        email=args.email,
        full_name=args.full_name,
        roles=roles,
        expiration_hours=exp_hours,
    )

    payload = jwt.decode(plain_token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
    iat = payload.get("iat")
    exp = payload.get("exp")

    print("=" * 60)
    print("PDH token – payload details")
    print("=" * 60)
    print()
    print("Payload (all fields in the token):")
    print("-" * 40)
    print("  user_id    : %s" % payload.get("user_id", ""))
    print("  email      : %s" % payload.get("email", ""))
    print("  full_name  : %s" % payload.get("full_name", ""))
    print("  roles      : %s" % (payload.get("roles") or []))
    print("  iat        : %s  (issued at, Unix timestamp)" % iat)
    if iat is not None:
        print("             %s  (UTC)" % datetime.fromtimestamp(iat, tz=timezone.utc).isoformat())
    print("  exp        : %s  (expires at, Unix timestamp)" % exp)
    if exp is not None:
        print("             %s  (UTC)" % datetime.fromtimestamp(exp, tz=timezone.utc).isoformat())
    print()
    print("Payload (raw JSON):")
    print(json.dumps({k: v for k, v in payload.items()}, indent=2))
    print()
    print("Encrypted token (use as ?token=... for auto-login):")
    print("-" * 40)
    print(encrypted_token)
    print()
    if args.plain:
        print("Plain JWT (before encryption):")
        print("-" * 40)
        print(plain_token)
        print()
    print("=" * 60)


if __name__ == "__main__":
    main()
