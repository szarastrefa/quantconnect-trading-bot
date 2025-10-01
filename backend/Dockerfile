FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    python3-dev \
    build-essential \
    curl \
    wget \
    git \
    pkg-config \
    libhdf5-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/models/trained_models \
    /app/models/model_configs \
    /app/data \
    /app/logs \
    /app/lean/algorithms \
    /app/lean/data

# Set permissions
RUN chmod +x /app/entrypoint.sh 2>/dev/null || true

# Create non-root user
RUN useradd -m -u 1000 tradingbot && \
    chown -R tradingbot:tradingbot /app

USER tradingbot

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# Start application
CMD ["python", "app.py"]