# Use the official vLLM image with CUDA support
FROM vllm/vllm-openai:latest

# Set environment variables
ENV HF_HOME=/root/.cache/huggingface
ENV TRANSFORMERS_CACHE=/root/.cache/huggingface/hub

# Expose the port for OpenAI-compatible API
EXPOSE 8000

# Run vLLM server with Qwen2.5-7B-Instruct model
# The model will be downloaded from HuggingFace on first run
ENTRYPOINT ["python", "-m", "vllm.entrypoints.openai.api_server", \
    "--model", "Qwen/Qwen2.5-7B-Instruct", \
    "--host", "0.0.0.0", \
    "--port", "8000"]
