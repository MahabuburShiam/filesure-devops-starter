# Worker Service Dockerfile
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY worker/downloader.py .

# Create non-root user for security
RUN useradd -r -u 1001 appuser && chown -R appuser:appuser /app
USER appuser

# Expose metrics port
EXPOSE 9100

# Health check for metrics endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:9100/metrics || exit 1

# Default command - will be overridden by KEDA with JOB_ID
CMD ["python", "downloader.py"]