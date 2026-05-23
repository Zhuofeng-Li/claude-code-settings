# Docker Setup for LLM Training

## Files Generated

- `Dockerfile` — container definition based on the official PyTorch CUDA image

## Build the Image

```bash
docker build -t llm-train .
```

## Run Command

```bash
docker run --gpus all \
  -v /path/to/your/data:/data \
  -v /path/to/your/output:/output \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  llm-train \
  --model meta-llama/Llama-2-7b-hf \
  --data /data/train.jsonl \
  --output /output
```

## Notes

### Base Image
Uses `pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime` which provides:
- PyTorch 2.1.0 pre-installed with CUDA 12.1 support
- Matches the `torch>=2.1` requirement

### GPU Access
- `--gpus all` is required to pass NVIDIA GPUs into the container.
- Requires [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed on the host.

### HuggingFace Model Cache
- The `-v ~/.cache/huggingface:/root/.cache/huggingface` mount re-uses any locally cached model weights, avoiding repeated large downloads.
- If you need to download `meta-llama/Llama-2-7b-hf` at runtime, make sure you have accepted the model license on HuggingFace and set your token:

```bash
docker run --gpus all \
  -e HUGGING_FACE_HUB_TOKEN=<your_token> \
  -v /path/to/your/data:/data \
  -v /path/to/your/output:/output \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  llm-train \
  --model meta-llama/Llama-2-7b-hf \
  --data /data/train.jsonl \
  --output /output
```

### Data Format
- `/data/train.jsonl` should be a newline-delimited JSON file. Each line is one training example.

### Output
- Checkpoints and final model weights are written to `/output` inside the container, which maps to the host directory you mount.

### bf16 Training
- The script uses `bf16=True` and `torch_dtype=torch.bfloat16`. This requires an Ampere-class GPU (A100, A30, RTX 30xx/40xx) or newer. On older GPUs you will need to change these to `fp16`.
