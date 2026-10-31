FROM python:3.10-slim

# Install system libraries for OpenCV and PyTorch/TensorFlow
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install dependencies
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend application and training model weights
COPY backend /app/backend
COPY training /app/training

# Set Python path environment variable
ENV PYTHONPATH=/app

# Expose HTTP port 8000
EXPOSE 8000

# Start FastAPI production server with Uvicorn
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]
