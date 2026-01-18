from sqlalchemy import Column, String, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime

from database import Base


class PGUser(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    first_name = Column(String)
    last_name = Column(String)
    role = Column(String)
    status = Column(String)
    entity = Column(String)
    department = Column(String)
    designation = Column(String)
    manager = Column(String)
    module_access = Column(String)
    module_role = Column(String)
    module_access_role = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    onboarding = relationship("PGOnboarding", uselist=False, back_populates="user")


class PGOnboarding(Base):
    __tablename__ = "onboarding"

    user_id = Column(String, ForeignKey("users.id"), primary_key=True)
    email = Column(String)
    name = Column(String)
    surname = Column(String)
    full_name = Column(String)
    department = Column(String)
    designation = Column(String)

    first_valid = Column(DateTime)
    last_valid = Column(DateTime)

    onboarding_id = Column(String)
    status_id = Column(String)
    updated_by = Column(String)
    inserted_by = Column(String)
    entity = Column(String)

    module_access = Column(String)
    module_role = Column(String)
    module_access_role = Column(String)

    token = Column(Text)
    token_updated_at = Column(DateTime)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("PGUser", back_populates="onboarding")
