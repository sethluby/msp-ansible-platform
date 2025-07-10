# Graceful Disconnection Service
# Handles clean MSP disconnection and client independence

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
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -r disconnect && useradd -r -g disconnect disconnect

# Add user to docker group for container management
RUN usermod -aG docker disconnect

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/data /app/logs \
    && chown -R disconnect:disconnect /app

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Switch to app user
USER disconnect

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8085/health')" || exit 1

# Expose port
EXPOSE 8085

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["python", "-m", "disconnection.service"]