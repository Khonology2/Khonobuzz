"""
Shared Sentry initialization and error reporting for the KhonoBuzz backend.
"""
from __future__ import annotations

import logging
import os
from typing import Any, Callable, Dict, Optional

import sentry_sdk
from dotenv import load_dotenv
from fastapi import HTTPException
from fastapi.responses import JSONResponse
from sentry_sdk.integrations.logging import LoggingIntegration
from sentry_sdk.integrations.redis import RedisIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

try:
    from sentry_sdk.integrations.fastapi import FastApiIntegration
    from sentry_sdk.integrations.starlette import StarletteIntegration

    _HAS_FASTAPI_INTEGRATIONS = True
except ImportError:
    _HAS_FASTAPI_INTEGRATIONS = False

load_dotenv()

logger = logging.getLogger(__name__)
_INITIALIZED = False


def sentry_enabled() -> bool:
    return _INITIALIZED


def _load_settings():
    try:
        from .config import settings
    except ImportError:
        from config import settings
    return settings


def _debug_mode() -> bool:
    return os.environ.get("DEBUG", "True").lower() == "true"


def _resolve_environment() -> str:
    return (
        os.environ.get("SENTRY_ENVIRONMENT")
        or os.environ.get("SENTRY_SERVER_ENVIRONMENT")
        or ("development" if _debug_mode() else "production")
    )


def _before_send(event: Dict[str, Any], hint: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    exc_info = hint.get("exc_info")
    if exc_info and exc_info[1] is not None:
        exc = exc_info[1]
        if isinstance(exc, HTTPException) and exc.status_code < 500:
            return None
    return event


def init_sentry(script_name: Optional[str] = None) -> bool:
    global _INITIALIZED
    if _INITIALIZED:
        return True

    settings = _load_settings()
    dsn = (
        settings.SENTRY_DSN
        or os.environ.get("BACKEND_DSN")
        or os.environ.get("SENTRY_DSN")
        or os.environ.get("Sentry_DSN")
    )
    if not dsn:
        logger.info("Sentry DSN not configured; error monitoring disabled")
        return False

    traces_sample_rate = settings.SENTRY_TRACES_SAMPLE_RATE
    profiles_sample_rate = settings.SENTRY_PROFILES_SAMPLE_RATE
    environment = settings.SENTRY_ENVIRONMENT or _resolve_environment()
    server_name = os.environ.get("SENTRY_SERVER_NAME") or script_name
    release = settings.SENTRY_RELEASE or os.environ.get("SENTRY_SERVER_VERSION")

    integrations = [
        LoggingIntegration(level=logging.INFO, event_level=logging.ERROR),
        SqlalchemyIntegration(),
        RedisIntegration(),
    ]
    if _HAS_FASTAPI_INTEGRATIONS and script_name == "khonobuzz-backend":
        integrations.extend([
            StarletteIntegration(transaction_style="url"),
            FastApiIntegration(transaction_style="url"),
        ])

    init_kwargs: Dict[str, Any] = {
        "dsn": dsn,
        "send_default_pii": False,
        "enable_logs": True,
        "traces_sample_rate": traces_sample_rate,
        "profiles_sample_rate": profiles_sample_rate,
        "environment": environment,
        "before_send": _before_send,
        "integrations": integrations,
    }
    if server_name:
        init_kwargs["server_name"] = server_name
    if release:
        init_kwargs["release"] = release

    sentry_sdk.init(**init_kwargs)
    _INITIALIZED = True
    logger.info(
        "Sentry initialized (environment=%s, server_name=%s, release=%s)",
        environment,
        server_name or "default",
        release or "unset",
    )
    return True


def report_exception(
    exc: BaseException,
    context: Optional[Dict[str, Any]] = None,
    level: str = "error",
) -> None:
    if not _INITIALIZED:
        return
    with sentry_sdk.push_scope() as scope:
        if context:
            for key, value in context.items():
                scope.set_extra(key, value)
        scope.level = level
        sentry_sdk.capture_exception(exc)


def report_message(
    message: str,
    level: str = "info",
    context: Optional[Dict[str, Any]] = None,
) -> None:
    if not _INITIALIZED:
        return
    with sentry_sdk.push_scope() as scope:
        if context:
            for key, value in context.items():
                scope.set_extra(key, value)
        sentry_sdk.capture_message(message, level=level)


def api_error_response(
    exc: Exception,
    endpoint: str,
    status_code: int = 500,
) -> JSONResponse:
    report_exception(exc, context={"endpoint": endpoint}, level="error")
    logger.exception("%s failed: %s", endpoint, exc)
    return JSONResponse(status_code=status_code, content={"error": str(exc)})


def run_script(main_fn: Callable[[], None], script_name: str) -> None:
    init_sentry(script_name=script_name)
    try:
        main_fn()
    except Exception as exc:
        report_exception(exc, context={"script": script_name}, level="error")
        logger.exception("%s failed: %s", script_name, exc)
        raise
    finally:
        if _INITIALIZED:
            sentry_sdk.flush(timeout=5)
