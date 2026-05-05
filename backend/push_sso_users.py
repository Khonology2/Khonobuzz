from __future__ import annotations

import os
from datetime import UTC, datetime

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

USERS = [
    "user.salman@khonology.com",
]


def _to_full_name(email: str) -> str:
    local = email.split("@", 1)[0]
    parts = local.replace("-", ".").split(".")
    return " ".join(p.capitalize() for p in parts if p)


def main() -> None:
    load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
    db_urls = {
        "skills_heatmap": (
            os.getenv("Skills_Heatmap") or os.getenv("SKILLS_HEATMAP") or ""
        ).strip(),
        "sign_off_hub": (
            os.getenv("sign_off_hub")
            or os.getenv("SIGN_OFF_HUB")
            or os.getenv("Sign_Off_Hub")
            or os.getenv("sign_off_heatmap")
            or os.getenv("SIGN_OFF_HEATMAP")
            or os.getenv("Sign_Off_Heatmap")
            or ""
        ).strip(),
    }
    db_urls = {name: url for name, url in db_urls.items() if url}
    if not db_urls:
        raise RuntimeError(
            "Missing DB URLs in backend/.env. Set Skills_Heatmap and sign_off_hub."
        )
    now = datetime.now(UTC)
    for target_name, db_url in db_urls.items():
        engine = create_engine(db_url, pool_pre_ping=True)
        inserted = 0
        updated = 0

        with engine.begin() as conn:
            for raw_email in USERS:
                email = raw_email.strip().lower()
                full_name = _to_full_name(email)
                role = "Staff"
                user_id = email

                existing = conn.execute(
                    text("SELECT 1 FROM sso_user_login WHERE email = :email LIMIT 1"),
                    {"email": email},
                ).first()

                conn.execute(
                    text(
                        """
                        INSERT INTO sso_user_login (email, role, full_name, user_id, updated_at)
                        VALUES (:email, :role, :full_name, :user_id, :updated_at)
                        ON CONFLICT (email) DO UPDATE
                        SET
                            role = EXCLUDED.role,
                            full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), sso_user_login.full_name),
                            user_id = COALESCE(NULLIF(EXCLUDED.user_id, ''), sso_user_login.user_id),
                            updated_at = EXCLUDED.updated_at
                        """
                    ),
                    {
                        "email": email,
                        "role": role,
                        "full_name": full_name,
                        "user_id": user_id,
                        "updated_at": now,
                    },
                )

                if existing:
                    updated += 1
                else:
                    inserted += 1

        print(
            f"{target_name}: inserted={inserted}, updated={updated}, total={len(USERS)}"
        )


if __name__ == "__main__":
    main()
