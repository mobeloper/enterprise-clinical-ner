# ==========================================
# Production-grade Python Runtime Environment
# ==========================================
FROM python:3.11-slim AS base

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

# Install system dependencies needed for compiling certain wheel extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY app.py .

# Create a non-privileged system user for absolute container runtime security
RUN useradd -u 10001 -m appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose web gateway port
EXPOSE ${PORT}

# Healthcheck to let ECS/EKS know the container is healthy and ready to accept traffic
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Execute FastAPI gateway via Uvicorn with optimized production workers
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
