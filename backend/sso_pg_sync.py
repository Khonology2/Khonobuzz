from __future__ import annotations

import os
import traceback
import uuid
from datetime import datetime
from typing import Any, Dict, Optional

from sqlalchemy import MetaData, Table, create_engine, select
import bcrypt

_TARGETS: Dict[str, Dict[str, Any]] = {}
_SEED_PASSWORD_HASH = bcrypt.hashpw(
    os.urandom(24).hex().encode(),
    bcrypt.gensalt(rounds=10),
).decode()


def _get_conn_urls() -> Dict[str, str]:
    urls = {
        "skills_heatmap": (
            os.getenv("Skills_Heatmap", "").strip()
            or os.getenv("SKILLS_HEATMAP", "").strip()
        ),
        "sign_off_hub": (
            os.getenv("sign_off_hub", "").strip()
            or os.getenv("SIGN_OFF_HUB", "").strip()
            or os.getenv("Sign_Off_Hub", "").strip()
            or os.getenv("sign_off_heatmap", "").strip()
            or os.getenv("SIGN_OFF_HEATMAP", "").strip()
            or os.getenv("Sign_Off_Heatmap", "").strip()
        ),
    }
    return {name: url for name, url in urls.items() if url}


def _ensure_targets_loaded() -> Dict[str, Dict[str, Any]]:
    conn_urls = _get_conn_urls()
    if not conn_urls:
        return {}

    for target_name, conn_url in conn_urls.items():
        existing = _TARGETS.get(target_name)
        if existing and existing.get("url") == conn_url:
            continue

        engine = create_engine(conn_url, pool_pre_ping=True)
        metadata = MetaData()
        table_name = "sso_user_login"
        try:
            table = Table(table_name, metadata, autoload_with=engine)
        except Exception:
            table_name = "users"
            table = Table(table_name, metadata, autoload_with=engine)
        columns = {col.name for col in table.columns}
        _TARGETS[target_name] = {
            "url": conn_url,
            "engine": engine,
            "table": table,
            "table_name": table_name,
            "columns": columns,
        }

    return _TARGETS


def _pick_lookup_column(columns: set[str]) -> Optional[str]:
    for candidate in ("email", "user_id", "id", "uid"):
        if candidate in columns:
            return candidate
    return None


def _coalesce(*values: Any) -> Any:
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        return value
    return None


def _is_valid_uuid(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        uuid.UUID(value)
        return True
    except Exception:
        return False


def _is_uuid_column(table: Table, column_name: str) -> bool:
    try:
        col = table.c[column_name]
    except Exception:
        return False
    return col.type.__class__.__name__.upper() == "UUID"


def _to_title_name(email: str) -> str:
    local = (email or "").split("@", 1)[0]
    parts = local.replace("-", ".").split(".")
    return " ".join(p.capitalize() for p in parts if p)


def _normalize_sign_off_role(role: Any) -> str:
    role_raw = str(role or "").strip().lower()
    if role_raw in {"admin", "system admin", "systemadmin"}:
        return "systemAdmin"
    if role_raw in {"manager", "delivery manager", "delivery lead"}:
        return "deliveryLead"
    if role_raw in {"client", "client reviewer", "clientreviewer"}:
        return "clientReviewer"
    return "teamMember"


def sync_sso_user_login(
    uid: str,
    user_data: Optional[Dict[str, Any]],
    onboarding_data: Optional[Dict[str, Any]],
) -> None:
    """Insert/update user in sso_user_login for all configured external apps."""
    try:
        targets = _ensure_targets_loaded()
        if not targets:
            return

        user_data = user_data or {}
        onboarding_data = onboarding_data or {}
        now = datetime.utcnow()

        first_name = _coalesce(
            onboarding_data.get("firstName"),
            onboarding_data.get("name"),
            user_data.get("firstName"),
        )
        last_name = _coalesce(
            onboarding_data.get("lastName"),
            onboarding_data.get("surname"),
            user_data.get("lastName"),
        )
        full_name = _coalesce(
            onboarding_data.get("fullName"),
            user_data.get("name"),
            f"{first_name or ''} {last_name or ''}".strip(),
        )

        base_payload = {
            "user_id": uid,
            "id": uid,
            "uid": uid,
            "email": _coalesce(user_data.get("email"), onboarding_data.get("email")),
            "name": full_name,
            "full_name": full_name,
            "first_name": first_name,
            "last_name": last_name,
            "surname": last_name,
            "role": user_data.get("role"),
            "status": _coalesce(user_data.get("status"), onboarding_data.get("status")),
            "entity": _coalesce(user_data.get("entity"), onboarding_data.get("entity")),
            "department": _coalesce(
                user_data.get("department"),
                onboarding_data.get("department"),
            ),
            "designation": _coalesce(
                user_data.get("designation"),
                onboarding_data.get("designation"),
            ),
            "module_access": _coalesce(
                user_data.get("moduleAccess"),
                onboarding_data.get("moduleAccess"),
            ),
            "module_role": _coalesce(
                user_data.get("moduleRole"),
                onboarding_data.get("moduleRole"),
            ),
            "module_access_role": _coalesce(
                user_data.get("moduleAccessRole"),
                onboarding_data.get("moduleAccessRole"),
            ),
            "created_at": _coalesce(
                user_data.get("created_at"), onboarding_data.get("created_at"), now
            ),
            "updated_at": now,
        }

        for target_name, target in targets.items():
            try:
                engine = target["engine"]
                table = target["table"]
                table_name = target.get("table_name", "")
                columns = target["columns"]

                if table_name == "users":
                    email = _coalesce(user_data.get("email"), onboarding_data.get("email"))
                    if not email:
                        continue
                    email = str(email).strip().lower()
                    first = _coalesce(first_name, _to_title_name(email).split(" ")[0])
                    last = _coalesce(
                        last_name,
                        " ".join(_to_title_name(email).split(" ")[1:]) or None,
                    )
                    display_name = _coalesce(full_name, _to_title_name(email))
                    role_value = _normalize_sign_off_role(
                        _coalesce(user_data.get("role"), onboarding_data.get("role"))
                    )

                    with engine.begin() as conn:
                        existing = conn.execute(
                            select(table.c["email"]).where(table.c["email"] == email).limit(1)
                        ).first()

                        if existing:
                            update_payload = {}
                            if "name" in columns:
                                update_payload["name"] = display_name
                            if "role" in columns:
                                update_payload["role"] = role_value
                            if "is_active" in columns:
                                update_payload["is_active"] = True
                            if "email_verified" in columns:
                                update_payload["email_verified"] = True
                            if "updated_at" in columns:
                                update_payload["updated_at"] = now
                            if "first_name" in columns:
                                update_payload["first_name"] = first
                            if "last_name" in columns:
                                update_payload["last_name"] = last
                            conn.execute(
                                table.update()
                                .where(table.c["email"] == email)
                                .values(**update_payload)
                            )
                        else:
                            insert_payload = {}
                            if "id" in columns:
                                raw_id = str(uid) if _is_valid_uuid(uid) else str(uuid.uuid4())
                                insert_payload["id"] = raw_id
                            if "email" in columns:
                                insert_payload["email"] = email
                            if "password_hash" in columns:
                                insert_payload["password_hash"] = _SEED_PASSWORD_HASH
                            if "name" in columns:
                                insert_payload["name"] = display_name
                            if "role" in columns:
                                insert_payload["role"] = role_value
                            if "is_active" in columns:
                                insert_payload["is_active"] = True
                            if "email_verified" in columns:
                                insert_payload["email_verified"] = True
                            if "created_at" in columns:
                                insert_payload["created_at"] = now
                            if "updated_at" in columns:
                                insert_payload["updated_at"] = now
                            if "first_name" in columns:
                                insert_payload["first_name"] = first
                            if "last_name" in columns:
                                insert_payload["last_name"] = last
                            conn.execute(table.insert().values(**insert_payload))
                    continue

                payload = {}
                for key, value in base_payload.items():
                    if key not in columns or value is None:
                        continue
                    if _is_uuid_column(table, key) and not _is_valid_uuid(value):
                        continue
                    payload[key] = value
                if not payload:
                    continue

                lookup_col = _pick_lookup_column(columns)
                if lookup_col is None:
                    with engine.begin() as conn:
                        conn.execute(table.insert().values(**payload))
                    continue

                lookup_value = payload.get(lookup_col)
                if (
                    lookup_value is not None
                    and _is_uuid_column(table, lookup_col)
                    and not _is_valid_uuid(lookup_value)
                ):
                    lookup_value = None
                if lookup_value is None:
                    lookup_value = (
                        uid
                        if lookup_col in {"user_id", "id", "uid"}
                        else payload.get("email")
                    )
                if (
                    lookup_value is not None
                    and _is_uuid_column(table, lookup_col)
                    and not _is_valid_uuid(lookup_value)
                ):
                    lookup_value = payload.get("email")
                    lookup_col = "email" if "email" in columns else lookup_col
                if lookup_value is None:
                    continue

                with engine.begin() as conn:
                    existing = conn.execute(
                        select(table.c[lookup_col])
                        .where(table.c[lookup_col] == lookup_value)
                        .limit(1)
                    ).first()
                    if existing:
                        conn.execute(
                            table.update()
                            .where(table.c[lookup_col] == lookup_value)
                            .values(**payload)
                        )
                    else:
                        conn.execute(table.insert().values(**payload))
            except Exception as target_error:
                print(
                    f"[WARNING] Failed syncing user {uid} to {target_name}: {target_error}\n"
                    f"{traceback.format_exc()}"
                )
    except Exception as e:
        print(
            f"[WARNING] Failed syncing user {uid} to sso targets: {e}\n{traceback.format_exc()}"
        )
