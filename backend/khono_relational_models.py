"""
Normalized PostgreSQL tables for KhonoBuzz (users, emails, profiles, roles, org data).

Legacy `firestore_documents` JSONB rows remain supported via mirror writes until fully retired.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class KbAppUser(Base):
    """Core account row (replaces `users` collection JSON blob)."""

    __tablename__ = "kb_app_user"
    __table_args__ = (UniqueConstraint("email", name="uq_kb_app_user_email"),)

    id: Mapped[str] = mapped_column(String(255), primary_key=True)
    email: Mapped[str] = mapped_column(String(320), nullable=False, index=True)
    password: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    name: Mapped[str] = mapped_column(String(500), default="")
    role: Mapped[str] = mapped_column(String(100), default="Staff")
    status: Mapped[str] = mapped_column(String(50), default="Inactive")
    entity: Mapped[str] = mapped_column(String(255), default="")
    department: Mapped[str] = mapped_column(String(255), default="")
    designation: Mapped[str] = mapped_column(String(255), default="")
    manager: Mapped[str] = mapped_column(String(320), default="")
    module_access: Mapped[str] = mapped_column("module_access", Text, default="")
    module_role: Mapped[str] = mapped_column("module_role", Text, default="")
    module_access_role: Mapped[str] = mapped_column("module_access_role", Text, default="")
    theme_preference: Mapped[str] = mapped_column(String(32), default="dark")
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    last_sign_in_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    login_count: Mapped[int] = mapped_column(Integer, default=0)
    admin_json: Mapped[Optional[dict[str, Any]]] = mapped_column("admin_json", JSONB, nullable=True)


class KbUserEmail(Base):
    """Normalized email addresses (primary + optional alternates)."""

    __tablename__ = "kb_user_email"
    __table_args__ = (UniqueConstraint("email", name="uq_kb_user_email_address"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(255), ForeignKey("kb_app_user.id", ondelete="CASCADE"), nullable=False, index=True
    )
    email: Mapped[str] = mapped_column(String(320), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=True)


class KbUserProfile(Base):
    """Profile / onboarding fields (replaces `onboarding` collection JSON blob)."""

    __tablename__ = "kb_user_profile"

    user_id: Mapped[str] = mapped_column(
        String(255), ForeignKey("kb_app_user.id", ondelete="CASCADE"), primary_key=True
    )
    first_name: Mapped[str] = mapped_column(String(200), default="")
    last_name: Mapped[str] = mapped_column(String(200), default="")
    surname: Mapped[str] = mapped_column(String(200), default="")
    preferred_name: Mapped[str] = mapped_column(String(200), default="")
    full_name: Mapped[str] = mapped_column(String(500), default="")
    phone_number: Mapped[str] = mapped_column(String(64), default="")
    department: Mapped[str] = mapped_column(String(255), default="")
    designation: Mapped[str] = mapped_column(String(255), default="")
    entity: Mapped[str] = mapped_column(String(255), default="")
    manager: Mapped[str] = mapped_column(String(320), default="")
    managed_by: Mapped[str] = mapped_column(String(320), default="")
    module_access: Mapped[str] = mapped_column("module_access", Text, default="")
    module_role: Mapped[str] = mapped_column("module_role", Text, default="")
    module_access_role: Mapped[str] = mapped_column("module_access_role", Text, default="")
    profile_image_url: Mapped[str] = mapped_column(Text, default="")
    profile_image_public_id: Mapped[str] = mapped_column(Text, default="")
    theme_preference: Mapped[str] = mapped_column(String(32), default="dark")
    token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    token_updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    onboarding_role: Mapped[str] = mapped_column(String(100), default="")
    onboarding_status: Mapped[str] = mapped_column(String(50), default="")
    admin_json: Mapped[Optional[dict[str, Any]]] = mapped_column("admin_json", JSONB, nullable=True)
    last_sign_in_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    login_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    extra: Mapped[dict[str, Any]] = mapped_column(
        "extra", JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )


class KbRoleDefinition(Base):
    """Role documents from the `roles` collection."""

    __tablename__ = "kb_role_definition"

    id: Mapped[str] = mapped_column(String(255), primary_key=True)
    role_name: Mapped[str] = mapped_column(String(200), default="", index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    page_access: Mapped[Optional[dict[str, Any]]] = mapped_column("page_access", JSONB, nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)


class KbDepartment(Base):
    __tablename__ = "kb_department"

    id: Mapped[str] = mapped_column(String(255), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)


class KbDesignation(Base):
    __tablename__ = "kb_designation"

    id: Mapped[str] = mapped_column(String(255), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)


class KbEntity(Base):
    __tablename__ = "kb_entity"

    id: Mapped[str] = mapped_column(String(255), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), default="")
    assigned_user_ids: Mapped[Optional[list[Any]]] = mapped_column(JSONB, nullable=True)
    raw: Mapped[Optional[dict[str, Any]]] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)


class KbAdminNotification(Base):
    __tablename__ = "kb_admin_notification"

    id: Mapped[str] = mapped_column(String(255), primary_key=True)
    actor_email: Mapped[str] = mapped_column("actor_email", String(320), default="")
    title: Mapped[str] = mapped_column(String(500), default="")
    message: Mapped[str] = mapped_column(Text, default="")
    area: Mapped[str] = mapped_column(String(100), default="general")
    details: Mapped[Optional[dict[str, Any]]] = mapped_column(JSONB, nullable=True)
    target_roles: Mapped[Optional[list[Any]]] = mapped_column(JSONB, nullable=True)
    requires_ack: Mapped[bool] = mapped_column(Boolean, default=False)
    effective_date_iso: Mapped[str] = mapped_column(String(64), default="")
    acknowledged_by_emails: Mapped[Optional[list[Any]]] = mapped_column(JSONB, nullable=True)
    created_at_iso: Mapped[str] = mapped_column("created_at_iso", String(64), default="")
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=False), nullable=True)
    raw: Mapped[Optional[dict[str, Any]]] = mapped_column(JSONB, nullable=True)


class KbAdminNotificationState(Base):
    __tablename__ = "kb_admin_notification_state"

    user_email: Mapped[str] = mapped_column(String(320), primary_key=True)
    role: Mapped[str] = mapped_column(String(100), default="")
    cleared_at_iso: Mapped[str] = mapped_column(String(64), default="")
    updated_at_iso: Mapped[str] = mapped_column(String(64), default="")
    dismissed_ids: Mapped[Optional[list[Any]]] = mapped_column(JSONB, nullable=True)


def init_relational_tables(engine) -> None:
    Base.metadata.create_all(
        bind=engine,
        tables=[
            KbAppUser.__table__,
            KbUserEmail.__table__,
            KbUserProfile.__table__,
            KbRoleDefinition.__table__,
            KbDepartment.__table__,
            KbDesignation.__table__,
            KbEntity.__table__,
            KbAdminNotification.__table__,
            KbAdminNotificationState.__table__,
        ],
    )
