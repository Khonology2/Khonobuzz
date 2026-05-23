"""
Read/write helpers for normalized kb_* tables + optional mirror to legacy PG Firestore shim.
"""
from __future__ import annotations

import json
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import delete, func, select, text
from sqlalchemy.orm import Session

from database import SessionLocal
from khono_relational_models import (
    KbAdminNotification,
    KbAdminNotificationState,
    KbAppUser,
    KbDepartment,
    KbDesignation,
    KbEntity,
    KbRoleDefinition,
    KbUserEmail,
    KbUserProfile,
)


def _derive_module_access_from_role(
    module_access: Optional[str], module_access_role: Optional[str]
) -> Optional[str]:
    if module_access and str(module_access).strip():
        return str(module_access).strip()
    if not module_access_role or not str(module_access_role).strip():
        return None
    parts = str(module_access_role).split(",")
    module_names: list[str] = []
    for part in parts:
        trimmed = part.strip()
        if trimmed.startswith("PDH"):
            if "Personal Development Hub" not in module_names:
                module_names.append("Personal Development Hub")
    return ",".join(module_names) if module_names else None


def _coerce_dt(value: Any) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        normalized = raw.replace("Z", "+00:00") if raw.endswith("Z") else raw
        try:
            return datetime.fromisoformat(normalized)
        except Exception:
            return None
    return None


def _sortable_dt(dt: Optional[datetime]) -> datetime:
    if dt is None:
        return datetime.min
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


@contextmanager
def session_scope():
    session: Session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def relational_user_count(session: Session) -> int:
    return int(session.scalar(select(func.count()).select_from(KbAppUser)) or 0)


def user_to_legacy_dict(u: KbAppUser) -> Dict[str, Any]:
    d: Dict[str, Any] = {
        "email": u.email,
        "password": u.password,
        "name": u.name,
        "role": u.role,
        "status": u.status,
        "entity": u.entity,
        "department": u.department,
        "designation": u.designation,
        "manager": u.manager,
        "moduleAccess": u.module_access,
        "moduleRole": u.module_role,
        "moduleAccessRole": u.module_access_role,
        "themePreference": u.theme_preference,
        "created_at": u.created_at,
        "updated_at": u.updated_at,
        "lastSignInAt": u.last_sign_in_at,
        "loginCount": u.login_count,
    }
    if u.admin_json is not None:
        d["admin"] = u.admin_json
    return {k: v for k, v in d.items() if v is not None or k in ("email", "role", "status")}


def get_user_legacy_dict(session: Session, user_id: str) -> Optional[Dict[str, Any]]:
    u = session.get(KbAppUser, user_id)
    if u is None:
        return None
    return user_to_legacy_dict(u)


def profile_to_legacy_onboarding_dict(p: KbUserProfile, user_id: str) -> Dict[str, Any]:
    d: Dict[str, Any] = {
        "user_id": user_id,
        "email": "",
        "firstName": p.first_name or "",
        "lastName": p.last_name or "",
        "surname": p.surname or p.last_name or "",
        "preferredName": p.preferred_name or "",
        "fullName": p.full_name or "",
        "phoneNumber": p.phone_number or "",
        "department": p.department or "",
        "designation": p.designation or "",
        "entity": p.entity or "",
        "manager": p.manager or "",
        "managedBy": p.managed_by or "",
        "moduleAccess": p.module_access or "",
        "moduleRole": p.module_role or "",
        "moduleAccessRole": p.module_access_role or "",
        "profileImageUrl": p.profile_image_url or "",
        "profileImagePublicId": p.profile_image_public_id or "",
        "themePreference": p.theme_preference or "dark",
        "role": p.onboarding_role or "",
        "status": p.onboarding_status or "",
        "lastSignInAt": p.last_sign_in_at,
        "loginCount": p.login_count,
        "created_at": p.created_at,
        "updated_at": p.updated_at,
    }
    if p.token:
        d["token"] = p.token
    if p.token_updated_at:
        d["token_updated_at"] = p.token_updated_at
    if p.admin_json is not None:
        d["admin"] = p.admin_json
    if p.extra:
        for k, v in p.extra.items():
            if k not in d:
                d[k] = v
    return d


def mirror_user_profile_to_firestore(db_compat: Any, user: KbAppUser, prof: Optional[KbUserProfile]) -> None:
    """Keep `firestore_documents` rows in sync for tooling still reading JSONB."""
    db_compat.collection("users").document(user.id).set(user_to_legacy_dict(user), merge=True)
    if prof is None:
        prof = KbUserProfile(user_id=user.id)
    ob = profile_to_legacy_onboarding_dict(prof, user.id)
    ob["email"] = user.email
    db_compat.collection("onboarding").document(user.id).set(ob, merge=True)


def find_user_by_email(session: Session, normalized_email: str) -> Tuple[Optional[str], Dict[str, Any]]:
    row = session.scalar(
        select(KbAppUser).where(func.lower(KbAppUser.email) == normalized_email.lower())
    )
    if row is None:
        return None, {}
    return row.id, user_to_legacy_dict(row)


def fetch_profile_row(session: Session, user_id: str) -> Optional[KbUserProfile]:
    return session.get(KbUserProfile, user_id)


def merged_onboarding_dict(session: Session, user_id: str, user_email: str) -> Dict[str, Any]:
    prof = fetch_profile_row(session, user_id)
    if prof is None:
        return {}
    d = profile_to_legacy_onboarding_dict(prof, user_id)
    d["email"] = d.get("email") or user_email
    return d


def list_users_payloads(session: Session) -> List[Dict[str, Any]]:
    """Same payload shape as /api/users when sourced from kb_* tables."""
    stmt = (
        select(KbAppUser, KbUserProfile)
        .outerjoin(KbUserProfile, KbUserProfile.user_id == KbAppUser.id)
        .order_by(
            func.coalesce(KbUserProfile.updated_at, KbAppUser.updated_at, KbAppUser.created_at).desc()
        )
    )
    rows = session.execute(stmt).all()
    out: List[Tuple[datetime, Dict[str, Any]]] = []
    for u, p in rows:
        user_info = user_to_legacy_dict(u)
        onboarding_info = merged_onboarding_dict(session, u.id, u.email) if p else {}
        if not p:
            onboarding_info = {}
        first_name = onboarding_info.get("firstName") or onboarding_info.get("name") or ""
        last_name = onboarding_info.get("lastName") or onboarding_info.get("surname") or ""
        created_at_dt = _coerce_dt(user_info.get("created_at"))
        updated_at_dt = _coerce_dt(user_info.get("updated_at"))
        last_sign_in_dt = _coerce_dt(
            user_info.get("lastSignInAt") or onboarding_info.get("lastSignInAt")
        )
        login_count = int(onboarding_info.get("loginCount") or user_info.get("loginCount") or 0)
        if created_at_dt is None:
            created_at_dt = u.created_at
        if updated_at_dt is None:
            updated_at_dt = u.updated_at or created_at_dt
        created_at_str = created_at_dt.isoformat() + "Z" if created_at_dt else None
        updated_at_str = updated_at_dt.isoformat() + "Z" if updated_at_dt else None
        last_sign_in_str = last_sign_in_dt.isoformat() + "Z" if last_sign_in_dt else None
        module_access_raw = user_info.get("moduleAccess") or onboarding_info.get("moduleAccess", "")
        module_access_role_raw = user_info.get("moduleAccessRole") or onboarding_info.get(
            "moduleAccessRole", ""
        )
        final_module_access = _derive_module_access_from_role(module_access_raw, module_access_role_raw)
        profile_image_url = onboarding_info.get("profileImageUrl") or user_info.get("profileImageUrl") or ""
        user_payload = {
            "id": u.id,
            "email": user_info.get("email", u.email),
            "role": user_info.get("role", "Staff"),
            "status": user_info.get("status", "Active"),
            "firstName": first_name,
            "lastName": last_name,
            "department": onboarding_info.get("department", ""),
            "designation": onboarding_info.get("designation", ""),
            "entity": user_info.get("entity") or onboarding_info.get("entity", ""),
            "manager": user_info.get("manager") or onboarding_info.get("manager", ""),
            "moduleAccess": final_module_access or "",
            "moduleRole": user_info.get("moduleRole") or onboarding_info.get("moduleRole", ""),
            "moduleAccessRole": module_access_role_raw or "",
            "profileImageUrl": profile_image_url,
            "createdAt": created_at_str,
            "updatedAt": updated_at_str,
            "lastSignInAt": last_sign_in_str,
            "loginCount": login_count,
        }
        sort_key = _sortable_dt(updated_at_dt or created_at_dt)
        out.append((sort_key, user_payload))
    out.sort(key=lambda item: item[0], reverse=True)
    return [p for _, p in out]


def upsert_user_from_registration(
    session: Session,
    user_id: str,
    normalized_email: str,
    user_data: Dict[str, Any],
    onboarding_data: Dict[str, Any],
) -> Tuple[KbAppUser, KbUserProfile]:
    u = session.get(KbAppUser, user_id)
    if u is None:
        u = KbAppUser(id=user_id, email=normalized_email)
        session.add(u)
    u.email = normalized_email
    u.password = user_data.get("password")
    u.name = user_data.get("name") or ""
    u.role = user_data.get("role") or "Staff"
    u.status = user_data.get("status") or "Inactive"
    u.entity = user_data.get("entity") or ""
    u.department = user_data.get("department") or ""
    u.designation = user_data.get("designation") or ""
    u.manager = user_data.get("manager") or ""
    u.module_access = user_data.get("moduleAccess") or ""
    u.module_role = user_data.get("moduleRole") or ""
    u.module_access_role = user_data.get("moduleAccessRole") or ""
    u.theme_preference = user_data.get("themePreference") or "dark"
    u.created_at = _coerce_dt(user_data.get("created_at")) or datetime.utcnow()
    u.updated_at = _coerce_dt(user_data.get("updated_at")) or datetime.utcnow()
    u.admin_json = user_data.get("admin") if isinstance(user_data.get("admin"), dict) else None

    em = session.scalar(
        select(KbUserEmail).where(
            KbUserEmail.user_id == user_id, KbUserEmail.is_primary.is_(True)
        )
    )
    if em is None:
        session.add(KbUserEmail(user_id=user_id, email=normalized_email, is_primary=True))
    else:
        em.email = normalized_email

    p = session.get(KbUserProfile, user_id)
    if p is None:
        p = KbUserProfile(user_id=user_id)
        session.add(p)
    p.first_name = onboarding_data.get("firstName") or onboarding_data.get("name") or ""
    p.last_name = onboarding_data.get("lastName") or onboarding_data.get("surname") or ""
    p.surname = onboarding_data.get("surname") or p.last_name
    p.full_name = onboarding_data.get("fullName") or ""
    p.department = onboarding_data.get("department") or ""
    p.designation = onboarding_data.get("designation") or ""
    p.entity = onboarding_data.get("entity") or ""
    p.manager = onboarding_data.get("manager") or ""
    p.managed_by = onboarding_data.get("managedBy") or ""
    p.module_access = onboarding_data.get("moduleAccess") or ""
    p.module_role = onboarding_data.get("moduleRole") or ""
    p.module_access_role = onboarding_data.get("moduleAccessRole") or ""
    p.theme_preference = onboarding_data.get("themePreference") or "dark"
    p.token = onboarding_data.get("token")
    p.token_updated_at = _coerce_dt(onboarding_data.get("token_updated_at"))
    p.created_at = _coerce_dt(onboarding_data.get("created_at")) or datetime.utcnow()
    p.updated_at = _coerce_dt(onboarding_data.get("updated_at")) or datetime.utcnow()
    p.onboarding_role = onboarding_data.get("role") or ""
    p.onboarding_status = onboarding_data.get("status") or ""
    if isinstance(onboarding_data.get("admin"), dict):
        p.admin_json = onboarding_data.get("admin")
    known_ob = {
        "user_id",
        "firstName",
        "lastName",
        "name",
        "surname",
        "fullName",
        "department",
        "designation",
        "entity",
        "manager",
        "managedBy",
        "moduleAccess",
        "moduleRole",
        "moduleAccessRole",
        "profileImageUrl",
        "profileImagePublicId",
        "themePreference",
        "token",
        "token_updated_at",
        "role",
        "status",
        "admin",
        "lastSignInAt",
        "loginCount",
        "created_at",
        "updated_at",
        "email",
        "phoneNumber",
        "preferredName",
        "first_valid",
        "last_valid",
        "inserted_by",
        "onboarding_id",
        "status_id",
        "updated_by",
    }
    p.extra = {k: v for k, v in onboarding_data.items() if k not in known_ob}
    session.flush()
    return u, p


def apply_user_patch_to_relational(session: Session, user_id: str, patch: Dict[str, Any]) -> Optional[KbAppUser]:
    u = session.get(KbAppUser, user_id)
    if u is None:
        return None
    key_map = {
        "role": "role",
        "status": "status",
        "entity": "entity",
        "department": "department",
        "designation": "designation",
        "manager": "manager",
        "moduleAccess": "module_access",
        "moduleRole": "module_role",
        "moduleAccessRole": "module_access_role",
        "admin": "admin_json",
    }
    for src, dst in key_map.items():
        if src in patch:
            val = patch[src]
            if dst == "admin_json" and val is not None and not isinstance(val, dict):
                continue
            setattr(u, dst, val)
    if "updated_at" in patch:
        u.updated_at = _coerce_dt(patch.get("updated_at")) or datetime.utcnow()
    else:
        u.updated_at = datetime.utcnow()
    session.flush()
    return u


def apply_onboarding_patch_to_relational(session: Session, user_id: str, patch: Dict[str, Any]) -> KbUserProfile:
    p = session.get(KbUserProfile, user_id)
    if p is None:
        p = KbUserProfile(user_id=user_id)
        session.add(p)
    if "firstName" in patch:
        p.first_name = patch.get("firstName") or ""
    if "lastName" in patch:
        p.last_name = patch.get("lastName") or ""
    if "surname" in patch:
        p.surname = patch.get("surname") or ""
    if "fullName" in patch:
        p.full_name = patch.get("fullName") or ""
    if "department" in patch:
        p.department = patch.get("department") or ""
    if "designation" in patch:
        p.designation = patch.get("designation") or ""
    if "entity" in patch:
        p.entity = patch.get("entity") or ""
    if "manager" in patch:
        p.manager = patch.get("manager") or ""
    if "managedBy" in patch:
        p.managed_by = patch.get("managedBy") or ""
    if "moduleAccess" in patch:
        p.module_access = patch.get("moduleAccess") or ""
    if "moduleRole" in patch:
        p.module_role = patch.get("moduleRole") or ""
    if "moduleAccessRole" in patch:
        p.module_access_role = patch.get("moduleAccessRole") or ""
    if "token" in patch:
        p.token = patch.get("token")
    if "token_updated_at" in patch:
        p.token_updated_at = _coerce_dt(patch.get("token_updated_at"))
    if "role" in patch:
        p.onboarding_role = patch.get("role") or ""
    if "status" in patch:
        p.onboarding_status = patch.get("status") or ""
    if "admin" in patch and isinstance(patch.get("admin"), dict):
        p.admin_json = patch.get("admin")
    if "profileImageUrl" in patch:
        p.profile_image_url = patch.get("profileImageUrl") or ""
    if "profileImagePublicId" in patch:
        p.profile_image_public_id = patch.get("profileImagePublicId") or ""
    if "themePreference" in patch:
        p.theme_preference = patch.get("themePreference") or "dark"
    if "email" in patch:
        pass
    if "lastSignInAt" in patch:
        p.last_sign_in_at = _coerce_dt(patch.get("lastSignInAt"))
    if "loginCount" in patch:
        try:
            p.login_count = int(patch.get("loginCount") or 0)
        except Exception:
            pass
    p.updated_at = _coerce_dt(patch.get("updated_at")) or datetime.utcnow()
    if p.created_at is None:
        p.created_at = _coerce_dt(patch.get("created_at")) or datetime.utcnow()
    session.flush()
    return p


def delete_user_relational(session: Session, user_id: str) -> bool:
    u = session.get(KbAppUser, user_id)
    if u is None:
        return False
    session.execute(delete(KbUserEmail).where(KbUserEmail.user_id == user_id))
    session.execute(delete(KbUserProfile).where(KbUserProfile.user_id == user_id))
    session.delete(u)
    session.flush()
    return True


def migrate_from_firestore_documents(_engine: Any = None) -> Dict[str, int]:
    """Import rows from `firestore_documents` into kb_* tables (raw SQL; works across SQLAlchemy bases)."""
    counts: Dict[str, int] = {}

    def _as_dict(raw: Any) -> Dict[str, Any]:
        if raw is None:
            return {}
        if isinstance(raw, dict):
            return dict(raw)
        if isinstance(raw, str):
            try:
                return dict(json.loads(raw))
            except Exception:
                return {}
        return {}

    with SessionLocal() as session:
        stream = session.execute(text("SELECT collection_name, document_id, data FROM firestore_documents"))
        for collection_name, document_id, data_raw in stream:
            coll = (collection_name or "").strip()
            data = _as_dict(data_raw)
            if coll == "users":
                uid = (document_id or "").strip()
                email = (data.get("email") or "").strip().lower()
                if not uid or not email:
                    continue
                u = session.get(KbAppUser, uid)
                if u is None:
                    u = KbAppUser(id=uid, email=email)
                    session.add(u)
                u.email = email
                u.password = data.get("password")
                u.name = data.get("name") or ""
                u.role = data.get("role") or "Staff"
                u.status = data.get("status") or "Inactive"
                u.entity = data.get("entity") or ""
                u.department = data.get("department") or ""
                u.designation = data.get("designation") or ""
                u.manager = data.get("manager") or ""
                u.module_access = data.get("moduleAccess") or ""
                u.module_role = data.get("moduleRole") or ""
                u.module_access_role = data.get("moduleAccessRole") or ""
                u.theme_preference = data.get("themePreference") or "dark"
                u.created_at = _coerce_dt(data.get("created_at"))
                u.updated_at = _coerce_dt(data.get("updated_at"))
                u.last_sign_in_at = _coerce_dt(data.get("lastSignInAt"))
                u.login_count = int(data.get("loginCount") or 0)
                if isinstance(data.get("admin"), dict):
                    u.admin_json = data.get("admin")
                em = session.scalar(select(KbUserEmail).where(KbUserEmail.email == email))
                if em is None:
                    session.add(KbUserEmail(user_id=uid, email=email, is_primary=True))
                counts["users"] = counts.get("users", 0) + 1
            elif coll == "onboarding":
                uid = (data.get("user_id") or document_id or "").strip()
                if not uid:
                    continue
                p = session.get(KbUserProfile, uid)
                if p is None:
                    p = KbUserProfile(user_id=uid)
                    session.add(p)
                p.first_name = data.get("firstName") or data.get("name") or ""
                p.last_name = data.get("lastName") or ""
                p.surname = data.get("surname") or p.last_name
                p.preferred_name = data.get("preferredName") or ""
                p.full_name = data.get("fullName") or ""
                p.phone_number = data.get("phoneNumber") or ""
                p.department = data.get("department") or ""
                p.designation = data.get("designation") or ""
                p.entity = data.get("entity") or ""
                p.manager = data.get("manager") or ""
                p.managed_by = data.get("managedBy") or ""
                p.module_access = data.get("moduleAccess") or ""
                p.module_role = data.get("moduleRole") or ""
                p.module_access_role = data.get("moduleAccessRole") or ""
                p.profile_image_url = data.get("profileImageUrl") or ""
                p.profile_image_public_id = data.get("profileImagePublicId") or ""
                p.theme_preference = data.get("themePreference") or "dark"
                p.token = data.get("token")
                p.token_updated_at = _coerce_dt(data.get("token_updated_at"))
                p.onboarding_role = data.get("role") or ""
                p.onboarding_status = data.get("status") or ""
                if isinstance(data.get("admin"), dict):
                    p.admin_json = data.get("admin")
                p.last_sign_in_at = _coerce_dt(data.get("lastSignInAt"))
                p.login_count = int(data.get("loginCount") or 0)
                p.created_at = _coerce_dt(data.get("created_at"))
                p.updated_at = _coerce_dt(data.get("updated_at"))
                known = {
                    "user_id",
                    "firstName",
                    "lastName",
                    "name",
                    "surname",
                    "fullName",
                    "department",
                    "designation",
                    "entity",
                    "manager",
                    "managedBy",
                    "moduleAccess",
                    "moduleRole",
                    "moduleAccessRole",
                    "profileImageUrl",
                    "profileImagePublicId",
                    "themePreference",
                    "token",
                    "token_updated_at",
                    "role",
                    "status",
                    "admin",
                    "lastSignInAt",
                    "loginCount",
                    "created_at",
                    "updated_at",
                    "email",
                    "phoneNumber",
                    "preferredName",
                }
                p.extra = {k: v for k, v in data.items() if k not in known}
                counts["onboarding"] = counts.get("onboarding", 0) + 1
            elif coll == "roles":
                did = (document_id or "").strip()
                if not did:
                    continue
                r = session.get(KbRoleDefinition, did)
                if r is None:
                    r = KbRoleDefinition(id=did)
                    session.add(r)
                r.role_name = (data.get("roleName") or data.get("role_name") or "")[:200]
                r.description = data.get("description") or ""
                r.page_access = data.get("pageAccess") if isinstance(data.get("pageAccess"), dict) else None
                r.created_at = _coerce_dt(data.get("created_at"))
                r.updated_at = _coerce_dt(data.get("updated_at"))
                counts["roles"] = counts.get("roles", 0) + 1
            elif coll in ("departments", "department"):
                did = (document_id or "").strip()
                name = (data.get("name") or "").strip()
                if not did or not name:
                    continue
                d = session.get(KbDepartment, did)
                if d is None:
                    d = KbDepartment(id=did, name=name)
                    session.add(d)
                d.name = name
                d.created_at = _coerce_dt(data.get("created_at"))
                counts["departments"] = counts.get("departments", 0) + 1
            elif coll in ("designations", "designation"):
                did = (document_id or "").strip()
                name = (data.get("name") or "").strip()
                if not did or not name:
                    continue
                d = session.get(KbDesignation, did)
                if d is None:
                    d = KbDesignation(id=did, name=name)
                    session.add(d)
                d.name = name
                d.created_at = _coerce_dt(data.get("created_at"))
                counts["designations"] = counts.get("designations", 0) + 1
            elif coll == "entities":
                did = (document_id or "").strip()
                if not did:
                    continue
                e = session.get(KbEntity, did)
                if e is None:
                    e = KbEntity(id=did)
                    session.add(e)
                e.name = data.get("name") or ""
                e.assigned_user_ids = data.get("assignedUsers") or data.get("assigned_user_ids")
                e.raw = data
                e.created_at = _coerce_dt(data.get("created_at"))
                counts["entities"] = counts.get("entities", 0) + 1
            elif coll == "admin_notifications":
                nid = (document_id or "").strip()
                if not nid:
                    continue
                n = session.get(KbAdminNotification, nid)
                if n is None:
                    n = KbAdminNotification(id=nid)
                    session.add(n)
                n.actor_email = data.get("actorEmail") or ""
                n.title = data.get("title") or ""
                n.message = data.get("message") or ""
                n.area = data.get("area") or "general"
                n.details = data.get("details") if isinstance(data.get("details"), dict) else None
                n.target_roles = data.get("targetRoles")
                n.requires_ack = bool(data.get("requiresAck", False))
                n.effective_date_iso = (data.get("effectiveDateIso") or "").strip()
                n.acknowledged_by_emails = data.get("acknowledgedByEmails")
                n.created_at_iso = data.get("createdAtIso") or ""
                n.created_at = _coerce_dt(data.get("createdAt"))
                n.raw = data
                counts["admin_notifications"] = counts.get("admin_notifications", 0) + 1
            elif coll == "admin_notification_state":
                em = (document_id or "").strip()
                if not em:
                    continue
                st = session.get(KbAdminNotificationState, em)
                if st is None:
                    st = KbAdminNotificationState(user_email=em)
                    session.add(st)
                st.role = data.get("role") or ""
                st.cleared_at_iso = data.get("clearedAtIso") or ""
                st.updated_at_iso = data.get("updatedAtIso") or ""
                st.dismissed_ids = data.get("dismissedIds")
                counts["admin_notification_state"] = counts.get("admin_notification_state", 0) + 1

        session.commit()
    return counts
