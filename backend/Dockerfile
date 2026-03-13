# Use Python 3.11 slim image for smaller size
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user for security
RUN adduser --disabled-password --gecos '' appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose port (platforms like Render set PORT; default 5000 for local runs)
EXPOSE 5000

# Health check uses same port as app (PORT env or 5000)
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD sh -c "curl -f http://localhost:${PORT:-5000}/health || exit 1"

# Bind to 0.0.0.0 so container accepts external connections; PORT default 5000
CMD ["sh", "-c", "gunicorn -w 4 -k uvicorn.workers.UvicornWorker fastapi_app:app --bind 0.0.0.0:${PORT:-5000}"]
