"""
Generate a Deliverables & Sprint Sign-Off Hub token by role.
Run from the backend directory: python generate_deliverables_token.py [options]

Uses JWT_SECRET_KEY and ENCRYPTION_KEY from .env (same as the API).
Deliverables roles are stored in token as:
"Deliverables & Sprint Sign-Off Hub - <Role>".
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

DELIVERABLES_ROLES = (
    "System Admin",
    "Delivery Manager",
    "Client Reviewer",
    "Team member",
)

# ---------------------------------------------
# USER DETAILS INPUT SECTION (quick edit fields)
# ---------------------------------------------
# Option 1: fill these fields and run script without args.
# Option 2: use CLI args to override these defaults.
DEFAULT_USER_DETAILS = {
    "user_id": "amanda-test-user-001",
    "email": "amanda.test@khonology.com",
    "full_name": "Amanda Test User",
    "role": "Delivery Manager",
    "expiration_hours": 24,
}


def role_to_deliverables_roles(role: str) -> list:
    """Map one deliverables role to the token payload role format."""
    r = role.strip()
    if not r:
        return []
    prefix = "Deliverables & Sprint Sign-Off Hub - "
    if r.startswith(prefix):
        return [r]
    return [f"{prefix}{r}"]


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Generate an encrypted Deliverables & Sprint Sign-Off Hub token "
            "using user email and selected role."
        )
    )
    parser.add_argument(
        "--user-id",
        default=DEFAULT_USER_DETAILS["user_id"],
        help="User ID (default: deliverables-test-user-001)",
    )
    parser.add_argument(
        "--email",
        default=DEFAULT_USER_DETAILS["email"],
        help="User email to include in token payload",
    )
    parser.add_argument(
        "--full-name",
        default=DEFAULT_USER_DETAILS["full_name"],
        help="User full name",
    )
    parser.add_argument(
        "--role",
        choices=DELIVERABLES_ROLES,
        default=DEFAULT_USER_DETAILS["role"],
        help="Deliverables role",
    )
    parser.add_argument(
        "--expiration-hours",
        type=int,
        default=None,
        help=(
            "Token validity in hours "
            f"(default: JWT_EXPIRATION_HOURS from .env or {JWT_EXPIRATION_HOURS})"
        ),
    )
    parser.add_argument(
        "--plain",
        action="store_true",
        help="Also print the plain JWT (before encryption)",
    )
    parser.add_argument(
        "--prompt",
        action="store_true",
        help="Prompt for user details interactively before generating token",
    )
    args = parser.parse_args()

    if args.prompt:
        print("\nEnter user details for token generation:")
        user_id_input = input(f"User ID [{args.user_id}]: ").strip()
        if user_id_input:
            args.user_id = user_id_input

        email_input = input("Email (required): ").strip()
        if email_input:
            args.email = email_input

        full_name_input = input(f"Full name [{args.full_name}]: ").strip()
        if full_name_input:
            args.full_name = full_name_input

        print("\nSelect role:")
        for idx, role_name in enumerate(DELIVERABLES_ROLES, start=1):
            print(f"  {idx}. {role_name}")
        role_choice = input(f"Role number [default {args.role}]: ").strip()
        if role_choice.isdigit():
            role_index = int(role_choice) - 1
            if 0 <= role_index < len(DELIVERABLES_ROLES):
                args.role = DELIVERABLES_ROLES[role_index]

        exp_choice = input(
            "Expiration hours (blank = .env default): "
        ).strip()
        if exp_choice.isdigit():
            args.expiration_hours = int(exp_choice)

    if not args.email:
        raise ValueError(
            "Email is required. Provide --email, set DEFAULT_USER_DETAILS['email'], or use --prompt."
        )

    exp_hours = (
        args.expiration_hours
        if args.expiration_hours is not None
        else JWT_EXPIRATION_HOURS
    )
    roles = role_to_deliverables_roles(args.role)

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
    print("Deliverables token - payload details")
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
        print(
            "             %s  (UTC)"
            % datetime.fromtimestamp(iat, tz=timezone.utc).isoformat()
        )
    print("  exp        : %s  (expires at, Unix timestamp)" % exp)
    if exp is not None:
        print(
            "             %s  (UTC)"
            % datetime.fromtimestamp(exp, tz=timezone.utc).isoformat()
        )
    print()
    print("Payload (raw JSON):")
    print(json.dumps({k: v for k, v in payload.items()}, indent=2))
    print()
    print("Encrypted token (use as ?token=...):")
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
