# vLLM + Qwen2.5-7B-Instruct Dockerfile

## Dockerfile 说明

生成的 `Dockerfile` 基于官方 `vllm/vllm-openai:latest` 镜像，直接使用 vLLM 内置的 OpenAI 兼容 API 服务器启动 `Qwen/Qwen2.5-7B-Instruct` 模型，监听 8000 端口。

---

## 构建镜像

```bash
docker build -t vllm-qwen2.5-7b .
```

---

## 运行容器

### 基本运行命令（需要 NVIDIA GPU）

```bash
docker run --gpus all \
  -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm-qwen2.5-7b
```

### 参数说明

- `--gpus all`：将所有 GPU 挂载进容器（vLLM 必须有 GPU）
- `-p 8000:8000`：将容器的 8000 端口映射到宿主机 8000 端口
- `-v ~/.cache/huggingface:/root/.cache/huggingface`：挂载 HuggingFace 缓存目录，避免每次重启都重新下载模型

---

## 使用 HuggingFace Token（如需访问受限模型）

如果模型需要身份验证，可以通过环境变量传入 HF Token：

```bash
docker run --gpus all \
  -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN=your_huggingface_token \
  vllm-qwen2.5-7b
```

---

## 验证服务是否启动

服务启动后，可以用以下命令测试：

```bash
curl http://localhost:8000/v1/models
```

发送推理请求：

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [
      {"role": "user", "content": "你好，介绍一下你自己。"}
    ]
  }'
```

---

## 注意事项

1. **GPU 要求**：Qwen2.5-7B-Instruct 需要至少 16GB 显存（如 A100 40GB、RTX 3090/4090 等），建议 24GB+。
2. **首次启动**：第一次运行时会从 HuggingFace 下载模型文件（约 15GB），请确保网络畅通或提前下载好并挂载到缓存目录。
3. **NVIDIA Container Toolkit**：宿主机需要安装 [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) 才能在 Docker 中使用 GPU。
4. **镜像大小**：`vllm/vllm-openai:latest` 本身较大（约 10GB+），构建时请确保磁盘空间充足。

---

## 可选：自定义启动参数

如需修改并发数、最大序列长度等参数，可以在 Dockerfile 的 `ENTRYPOINT` 中追加，或在 `docker run` 时覆盖：

```bash
docker run --gpus all \
  -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm-qwen2.5-7b \
  --max-model-len 8192 \
  --tensor-parallel-size 2
```

常用参数：
- `--max-model-len`：最大上下文长度
- `--tensor-parallel-size`：张量并行数（多 GPU 时使用）
- `--dtype`：数据类型（如 `bfloat16`、`float16`）
- `--gpu-memory-utilization`：GPU 显存利用率（默认 0.9）
