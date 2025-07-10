# MSP Backup Service
# Handles backup collection, encryption, and storage

FROM python:3.11-slim-bullseye

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    ca-certificates \
    openssh-client \
    rsync \
    git \
    cron \
    postgresql-client \
    redis-tools \
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -r backup && useradd -r -g backup backup

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/backups /app/data /app/logs /app/temp \
    && chown -R backup:backup /app

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Setup cron for scheduled backups
COPY crontab /etc/cron.d/backup-service
RUN chmod 0644 /etc/cron.d/backup-service \
    && crontab /etc/cron.d/backup-service

# Switch to app user
USER backup

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8082/health')" || exit 1

# Expose port
EXPOSE 8082

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["python", "-m", "backup.service"]