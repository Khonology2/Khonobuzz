from __future__ import annotations

import os
import traceback
import uuid
from datetime import datetime
from typing import Any, Dict, Optional

from sqlalchemy import MetaData, Table, create_engine, select

_engine = None
_table = None
_table_columns = set()


def _get_conn_url() -> str:
    return (
        os.getenv("Skills_Heatmap", "").strip()
        or os.getenv("SKILLS_HEATMAP", "").strip()
    )


def _ensure_table_loaded() -> bool:
    global _engine, _table, _table_columns

    if _table is not None:
        return True

    conn_url = _get_conn_url()
    if not conn_url:
        return False

    if _engine is None:
        _engine = create_engine(conn_url, pool_pre_ping=True)

    metadata = MetaData()
    _table = Table("sso_user_login", metadata, autoload_with=_engine)
    _table_columns = {col.name for col in _table.columns}
    return True


def _pick_lookup_column() -> Optional[str]:
    for candidate in ("email", "user_id", "id", "uid"):
        if candidate in _table_columns:
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


def _is_uuid_column(column_name: str) -> bool:
    try:
        col = _table.c[column_name]
    except Exception:
        return False
    return col.type.__class__.__name__.upper() == "UUID"


def sync_sso_user_login(
    uid: str,
    user_data: Optional[Dict[str, Any]],
    onboarding_data: Optional[Dict[str, Any]],
) -> None:
    """Insert/update a user row in external sso_user_login table."""
    try:
        if not _ensure_table_loaded():
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
            "created_at": _coalesce(user_data.get("created_at"), onboarding_data.get("created_at"), now),
            "updated_at": now,
        }

        payload = {}
        for key, value in base_payload.items():
            if key not in _table_columns or value is None:
                continue
            if _is_uuid_column(key) and not _is_valid_uuid(value):
                continue
            payload[key] = value
        if not payload:
            return

        lookup_col = _pick_lookup_column()
        if lookup_col is None:
            with _engine.begin() as conn:
                conn.execute(_table.insert().values(**payload))
            return

        lookup_value = payload.get(lookup_col)
        if lookup_value is not None and _is_uuid_column(lookup_col) and not _is_valid_uuid(lookup_value):
            lookup_value = None
        if lookup_value is None:
            lookup_value = uid if lookup_col in {"user_id", "id", "uid"} else payload.get("email")
        if lookup_value is not None and _is_uuid_column(lookup_col) and not _is_valid_uuid(lookup_value):
            lookup_value = payload.get("email")
            lookup_col = "email" if "email" in _table_columns else lookup_col
        if lookup_value is None:
            return

        with _engine.begin() as conn:
            existing = conn.execute(
                select(_table.c[lookup_col]).where(_table.c[lookup_col] == lookup_value).limit(1)
            ).first()
            if existing:
                conn.execute(
                    _table.update()
                    .where(_table.c[lookup_col] == lookup_value)
                    .values(**payload)
                )
            else:
                conn.execute(_table.insert().values(**payload))
    except Exception as e:
        print(f"[WARNING] Failed syncing user {uid} to sso_user_login: {e}\n{traceback.format_exc()}")
