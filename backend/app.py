import uvicorn
import os
import errno
from dotenv import load_dotenv
from fastapi_app import app

load_dotenv()

# Windows WSAEADDRINUSE = 10048; Unix EADDRINUSE = 98
_PORT_IN_USE_ERRNOS = (errno.EADDRINUSE, getattr(errno, "WSAEADDRINUSE", 10048))


def _find_available_port(host: str, start_port: int, max_tries: int = 10) -> int:
    import socket
    for i in range(max_tries):
        port = start_port + i
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind((host, port))
                return port
        except OSError as e:
            if e.errno in _PORT_IN_USE_ERRNOS and i < max_tries - 1:
                continue
            raise
    return start_port + max_tries - 1


if __name__ == "__main__":
    host = os.environ.get("HOST", "0.0.0.0")
    requested_port = int(os.environ.get("PORT", 5000))
    port = _find_available_port(host, requested_port)
    if port != requested_port:
        print(f"[INFO] Port {requested_port} in use; using {port}")
    debug = os.environ.get("DEBUG", "True").lower() == "true"
    print("=" * 70)
    print("Starting Khonology Backend API")
    print("=" * 70)
    print(f"Host: {host}")
    print(f"Port: {port}")
    print(f"Debug Mode: {debug}")
    print(f"Accessible at: http://localhost:{port}")
    print(f"API Documentation: http://localhost:{port}/docs")
    print("=" * 70)
    uvicorn.run(
        "fastapi_app:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info",
        # Your FastAPI middleware already logs requests. Disable Uvicorn's access log
        # to avoid double-spam (especially for /api/version).
        access_log=False,
    )
