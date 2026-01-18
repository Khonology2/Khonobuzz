from __future__ import annotations
import traceback
from typing import Optional, Dict, Any
from datetime import datetime

from database import engine, SessionLocal, Base
from models_pg import PGUser, PGOnboarding


def ensure_pg_schema() -> None:
    """Create PostgreSQL schema if DATABASE_URL is configured."""
    if engine is None:
        return
    try:
        Base.metadata.create_all(bind=engine)
    except Exception as e:
        print(f"[ERROR] Failed to create PostgreSQL schema: {e}\n{traceback.format_exc()}")


def _safe_get(d: Optional[Dict[str, Any]], key: str, default=None):
    if not d:
        return default
    return d.get(key, default)


def sync_user_to_postgres(uid: str, user_data: Optional[Dict[str, Any]], onboarding_data: Optional[Dict[str, Any]]) -> None:
    """
    Upsert user and onboarding data into PostgreSQL.
    Accepts partial payloads; missing fields won't overwrite existing values.
    """
    if SessionLocal is None:
        # PG not configured
        return

    db = SessionLocal()
    try:
        # Upsert user
        user = db.get(PGUser, uid)
        if user is None:
            user = PGUser(id=uid)
            db.add(user)

        # Map fields with preference: provided value if not None/'' else keep existing
        def set_if_present(obj, attr, value):
            if value is not None:
                setattr(obj, attr, value)

        set_if_present(user, 'email', _safe_get(user_data, 'email'))
        # Prefer explicit full name when present
        name_val = _safe_get(user_data, 'name')
        set_if_present(user, 'name', name_val)
        set_if_present(user, 'first_name', _safe_get(onboarding_data, 'firstName') or _safe_get(onboarding_data, 'name'))
        set_if_present(user, 'last_name', _safe_get(onboarding_data, 'lastName') or _safe_get(onboarding_data, 'surname'))
        set_if_present(user, 'role', _safe_get(user_data, 'role'))
        set_if_present(user, 'status', _safe_get(user_data, 'status'))
        set_if_present(user, 'entity', _safe_get(user_data, 'entity') or _safe_get(onboarding_data, 'entity'))
        set_if_present(user, 'department', _safe_get(user_data, 'department') or _safe_get(onboarding_data, 'department'))
        set_if_present(user, 'designation', _safe_get(user_data, 'designation') or _safe_get(onboarding_data, 'designation'))
        set_if_present(user, 'manager', _safe_get(user_data, 'manager') or _safe_get(onboarding_data, 'manager'))
        set_if_present(user, 'module_access', _safe_get(user_data, 'moduleAccess') or _safe_get(onboarding_data, 'moduleAccess'))
        set_if_present(user, 'module_role', _safe_get(user_data, 'moduleRole') or _safe_get(onboarding_data, 'moduleRole'))
        set_if_present(user, 'module_access_role', _safe_get(user_data, 'moduleAccessRole') or _safe_get(onboarding_data, 'moduleAccessRole'))
        user.updated_at = datetime.utcnow()

        # Upsert onboarding
        ob = db.get(PGOnboarding, uid)
        if ob is None:
            ob = PGOnboarding(user_id=uid)
            db.add(ob)

        set_if_present(ob, 'email', _safe_get(onboarding_data, 'email') or _safe_get(user_data, 'email'))
        set_if_present(ob, 'name', _safe_get(onboarding_data, 'firstName') or _safe_get(onboarding_data, 'name'))
        set_if_present(ob, 'surname', _safe_get(onboarding_data, 'lastName') or _safe_get(onboarding_data, 'surname'))
        set_if_present(ob, 'full_name', _safe_get(onboarding_data, 'fullName'))
        set_if_present(ob, 'department', _safe_get(onboarding_data, 'department') or _safe_get(user_data, 'department'))
        set_if_present(ob, 'designation', _safe_get(onboarding_data, 'designation') or _safe_get(user_data, 'designation'))
        set_if_present(ob, 'first_valid', _safe_get(onboarding_data, 'first_valid'))
        set_if_present(ob, 'last_valid', _safe_get(onboarding_data, 'last_valid'))
        set_if_present(ob, 'onboarding_id', _safe_get(onboarding_data, 'onboarding_id'))
        set_if_present(ob, 'status_id', _safe_get(onboarding_data, 'status_id'))
        set_if_present(ob, 'updated_by', _safe_get(onboarding_data, 'updated_by'))
        set_if_present(ob, 'inserted_by', _safe_get(onboarding_data, 'inserted_by'))
        set_if_present(ob, 'entity', _safe_get(onboarding_data, 'entity') or _safe_get(user_data, 'entity'))
        set_if_present(ob, 'module_access', _safe_get(onboarding_data, 'moduleAccess') or _safe_get(user_data, 'moduleAccess'))
        set_if_present(ob, 'module_role', _safe_get(onboarding_data, 'moduleRole') or _safe_get(user_data, 'moduleRole'))
        set_if_present(ob, 'module_access_role', _safe_get(onboarding_data, 'moduleAccessRole') or _safe_get(user_data, 'moduleAccessRole'))
        set_if_present(ob, 'token', _safe_get(onboarding_data, 'token'))
        set_if_present(ob, 'token_updated_at', _safe_get(onboarding_data, 'token_updated_at'))
        ob.updated_at = datetime.utcnow()

        db.commit()
    except Exception as e:
        db.rollback()
        print(f"[ERROR] Failed to sync user {uid} to PostgreSQL: {e}\n{traceback.format_exc()}")
    finally:
        db.close()


def delete_user_from_postgres(uid: str) -> None:
    if SessionLocal is None:
        return
    db = SessionLocal()
    try:
        ob = db.get(PGOnboarding, uid)
        if ob:
            db.delete(ob)
        user = db.get(PGUser, uid)
        if user:
            db.delete(user)
        db.commit()
    except Exception as e:
        db.rollback()
        print(f"[WARNING] Failed to delete user {uid} from PostgreSQL: {e}")
    finally:
        db.close()
