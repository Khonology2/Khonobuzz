import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    DEBUG = os.environ.get('DEBUG', 'True').lower() == 'true'
    PORT = int(os.environ.get('PORT', 5000))
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY')
    if not JWT_SECRET_KEY:
        raise RuntimeError("JWT_SECRET_KEY environment variable is required for token signing and validation")
    JWT_EXPIRATION_HOURS = int(os.environ.get('JWT_EXPIRATION_HOURS', '24'))
    ENCRYPTION_KEY = os.environ.get('ENCRYPTION_KEY')
    if not ENCRYPTION_KEY:
        raise RuntimeError("ENCRYPTION_KEY environment variable is required for token encryption and decryption")

    # Sentry — backend error and performance tracking
    # BACKEND_DSN is the canonical name; SENTRY_DSN / Sentry_DSN kept for local .env compat.
    SENTRY_DSN: str = (
        os.getenv("BACKEND_DSN")
        or os.getenv("SENTRY_DSN")
        or os.getenv("Sentry_DSN")
        or ""
    ).strip()
    SENTRY_ENVIRONMENT: str = (
        os.getenv("SENTRY_ENVIRONMENT") or "production"
    ).strip()
    SENTRY_TRACES_SAMPLE_RATE: float = float(
        os.getenv("SENTRY_TRACES_SAMPLE_RATE") or "0.2"
    )
    SENTRY_PROFILES_SAMPLE_RATE: float = float(
        os.getenv("SENTRY_PROFILES_SAMPLE_RATE") or "0.1"
    )
    SENTRY_RELEASE: str = (
        os.getenv("SENTRY_RELEASE") or "khonobuzz-backend@1.0.0"
    ).strip()


settings = Config()
