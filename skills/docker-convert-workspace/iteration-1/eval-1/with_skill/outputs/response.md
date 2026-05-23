# vLLM Inference Server — Dockerfile for Qwen/Qwen2.5-7B-Instruct

## Dockerfile

已生成的 `Dockerfile` 基于官方 `vllm/vllm-openai:latest` 镜像，这是跑 vLLM 推理服务最直接的方式——CUDA、PyTorch、vLLM 全部预装好了，无需额外安装依赖。

## 构建结果

构建成功：

```
docker build -t qwen2-vllm:dev .
```

镜像 `qwen2-vllm:dev` 已成功构建（约 20.7 GB，主要是 vLLM 基础镜像本身的大小）。

## 运行命令

```bash
docker run --gpus all \
  -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=$HF_TOKEN \
  qwen2-vllm:dev
```

启动后，OpenAI 兼容的 API 会监听在 `http://localhost:8000`，可以直接用 OpenAI SDK 或 curl 访问：

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [{"role": "user", "content": "你好"}]
  }'
```

## 重要说明

1. **挂载 HuggingFace 缓存目录**：`-v ~/.cache/huggingface:/root/.cache/huggingface`
   第一次运行时 vLLM 会自动从 HuggingFace 下载 Qwen2.5-7B-Instruct（约 15 GB）。挂载本地缓存目录后，下次启动就不用重新下载了。

2. **HF_TOKEN**：如果你的网络需要登录 HuggingFace 才能下载模型，需要通过 `-e HF_TOKEN=$HF_TOKEN` 传入 token。Qwen2.5-7B-Instruct 是公开模型，通常不需要，但保险起见建议加上。

3. **GPU 要求**：7B 模型在 FP16 下大约需要 14 GB 显存，建议单张 A100/H100/RTX 4090 及以上。如果显存不够，可以加 `--dtype float8` 或换更小的模型。

4. **自定义启动参数**：如果需要修改 tensor parallel、max model len 等参数，可以直接修改 Dockerfile 中的 CMD，或在 `docker run` 时覆盖：

   ```bash
   docker run --gpus all \
     -p 8000:8000 \
     -v ~/.cache/huggingface:/root/.cache/huggingface \
     -e HF_TOKEN=$HF_TOKEN \
     qwen2-vllm:dev \
     python -m vllm.entrypoints.openai.api_server \
       --model Qwen/Qwen2.5-7B-Instruct \
       --host 0.0.0.0 \
       --port 8000 \
       --tensor-parallel-size 2
   ```
