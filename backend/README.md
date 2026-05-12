# Khonology Backend API

FastAPI backend for KhonoBuzz (auth, users, modules) with PostgreSQL as the primary datastore.

## Docker build and run

Build the image from the `backend` directory:

```bash
cd backend
docker build -t khonobuzz-backend .
```

Run locally (port 5000, env from `.env`):

```bash
docker run -p 5000:5000 --env-file .env khonobuzz-backend
```

Run with a specific port (e.g. for deploy):

```bash
docker run -p 8080:8080 -e PORT=8080 --env-file .env khonobuzz-backend
```

For production, set `PORT` in your environment (e.g. Render sets it automatically); the Dockerfile uses `PORT` with a default of 5000.

## Local development (no Docker)

```bash
cd backend
python -m venv venv
venv\Scripts\activate   # Windows
# source venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
python app.py
```

If port 5000 is already in use (e.g. Windows `WSAEADDRINUSE`), the server will try the next available port (5001, 5002, …) and print which one it is using.

PostgreSQL setup (Render + local)

1) Required environment variables
- `DATABASE_URL`: PostgreSQL connection string (required for PostgreSQL mode)
- `USE_POSTGRES_PRIMARY=true`: forces the API to use PostgreSQL-backed storage

2) Render example
- `DATABASE_URL=postgresql://khonobuzz_user:YOUR_PASSWORD@dpg-xxxxx-a.oregon-postgres.render.com:5432/khonobuzz_db`
- `USE_POSTGRES_PRIMARY=true`

3) Local example
- `DATABASE_URL=postgresql://postgres:postgres@localhost:5432/khonobuzz`
- `USE_POSTGRES_PRIMARY=true`
