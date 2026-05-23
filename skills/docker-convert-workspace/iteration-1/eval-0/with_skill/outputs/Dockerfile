FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

# System dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Environment variables
ENV PYTHONUNBUFFERED=1
# Mount your HuggingFace cache here to avoid re-downloading models on each run:
#   -v ~/.cache/huggingface:/root/.cache/huggingface
ENV HF_HOME=/root/.cache/huggingface

# Default entry point — override args via docker run
CMD ["python", "train.py", \
     "--model", "meta-llama/Llama-2-7b-hf", \
     "--data", "/data/train.jsonl", \
     "--output", "/output"]
