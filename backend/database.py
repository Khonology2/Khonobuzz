import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

# Create SQLAlchemy engine and session factory only if DATABASE_URL is present
engine = create_engine(DATABASE_URL) if DATABASE_URL else None
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine) if engine else None

Base = declarative_base()


def get_db():
  if SessionLocal is None:
    raise RuntimeError("DATABASE_URL is not configured or engine not initialized")
  db = SessionLocal()
  try:
    yield db
  finally:
    db.close()
