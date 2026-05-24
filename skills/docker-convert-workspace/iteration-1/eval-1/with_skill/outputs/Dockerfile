FROM vllm/vllm-openai:latest

# Environment variables
# PYTHONUNBUFFERED ensures Python output appears in docker logs immediately
ENV PYTHONUNBUFFERED=1
# HF_HOME sets a consistent cache location for HuggingFace models
# Mount this as a volume to avoid re-downloading the model on each run
ENV HF_HOME=/root/.cache/huggingface

WORKDIR /app

# Expose the OpenAI-compatible API port
EXPOSE 8000

# Launch the vLLM OpenAI-compatible API server with Qwen2.5-7B-Instruct
# The model will be downloaded from HuggingFace at startup if not cached
CMD ["python", "-m", "vllm.entrypoints.openai.api_server", \
     "--model", "Qwen/Qwen2.5-7B-Instruct", \
     "--host", "0.0.0.0", \
     "--port", "8000"]
