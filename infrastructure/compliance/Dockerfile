# Multi-Framework Compliance Validator
# Supports CMMC, SOC2, HIPAA, PCI-DSS, and NIST frameworks

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
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -r compliance && useradd -r -g compliance compliance

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/reports /app/data /app/logs \
    && chown -R compliance:compliance /app

# Copy compliance frameworks
COPY compliance/ /app/compliance/
COPY scripts/ /app/scripts/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Switch to app user
USER compliance

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose port
EXPOSE 8080

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["python", "-m", "compliance.server"]