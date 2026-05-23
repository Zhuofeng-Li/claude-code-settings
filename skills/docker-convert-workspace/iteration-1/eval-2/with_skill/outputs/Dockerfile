FROM python:3.11-slim

# System dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Ensure Python output is not buffered (important for docker logs)
ENV PYTHONUNBUFFERED=1

# OPENAI_API_KEY must be passed at runtime via -e OPENAI_API_KEY=...
# Never hardcode secrets in the Dockerfile

# Example usage:
#   docker run -e OPENAI_API_KEY=$OPENAI_API_KEY \
#     -v $(pwd)/data:/app/data \
#     evaluate:dev python evaluate.py input.json output.json

CMD ["python", "evaluate.py"]
