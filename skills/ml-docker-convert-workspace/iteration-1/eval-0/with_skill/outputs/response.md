# Docker Setup for LLM Training (Llama-2-7b)

## Build

```bash
docker build -t llama-trainer:dev .
```

Build succeeded. All dependencies installed:
- `transformers-5.3.0`, `accelerate-1.13.0`, `datasets-4.8.3`, `peft-0.18.1`
- Base image: `pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime`

---

## docker run command

```bash
docker run --gpus all \
  -v /path/to/your/data:/data \
  -v /path/to/your/output:/output \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=$HF_TOKEN \
  llama-trainer:dev
```

Or with explicit args override:

```bash
docker run --gpus all \
  -v /path/to/your/data:/data \
  -v /path/to/your/output:/output \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=$HF_TOKEN \
  llama-trainer:dev \
  python train.py --model meta-llama/Llama-2-7b-hf --data /data/train.jsonl --output /output
```

---

## Notes

- **GPU required**: The script uses `torch.bfloat16` and `device_map='auto'`, so `--gpus all` is mandatory.
- **HF_TOKEN**: `meta-llama/Llama-2-7b-hf` is a gated model — you must have accepted the license on HuggingFace and pass your token via `-e HF_TOKEN=$HF_TOKEN`. The token is never baked into the image.
- **HuggingFace cache**: Mount `~/.cache/huggingface:/root/.cache/huggingface` to avoid re-downloading the ~13GB model on every run.
- **Data volume**: Your local data file should be mounted to `/data/train.jsonl` inside the container.
- **Output volume**: Training checkpoints are written to `/output` — mount a local directory there so they persist after the container exits.
- **No docker-compose**: Single training job; a plain `docker run` is cleaner.
