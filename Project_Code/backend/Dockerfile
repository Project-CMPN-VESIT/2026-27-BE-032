FROM python:3.10-slim

# Install system libraries for OpenCV, PyTorch/TensorFlow, and Git LFS
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    curl \
    git \
    git-lfs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Ensure writable cache directories for Keras and Matplotlib in container
ENV KERAS_HOME=/tmp/.keras_cache
ENV MPLCONFIGDIR=/tmp/.mpl_cache
ENV PYTHONPATH=/app

# Copy requirements and install dependencies
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend application and training model weights
COPY backend /app/backend
COPY training /app/training

# Expose default HTTP port
EXPOSE 8000

# Start FastAPI production server with Uvicorn using Railway's dynamic $PORT
CMD ["sh", "-c", "uvicorn backend.app:app --host 0.0.0.0 --port ${PORT:-8000}"]
