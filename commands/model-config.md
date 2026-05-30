# model-config

查询指定 LLM 模型的完整 API 调用配置，输出结构化表格。

## 触发条件

用户询问任何 LLM 模型的 API 配置、参数、怎么调用时触发：
- `/model-config kimi k2.6`
- `/model-config deepseek-r1`
- "kimi 的 temperature 怎么设？"
- "这个模型支持 thinking 吗？"

## 执行步骤

### 1. 识别目标模型

从用户输入解析模型名称和 provider（OpenAI / Anthropic / DeepSeek / Moonshot-Kimi / Google / xAI / 本地 vLLM/SGLang 等）。

### 2. 追踪完整调用链（必须读代码，不能只看默认值）

**必须**沿完整调用链逐层读取代码，而非只看 `__init__` 的默认参数。调用链通常为：

```
CLI 入口 (generate_solutions.py)
  → generate_code()          ← 在这里看 timeout、base_url 是否被硬编码
    → instantiate_llm_client()  (llm.py)   ← 看 provider 分支，actual_model 如何传入
      → LLMClient.__init__()  (llm_interface.py)  ← 看构造参数
        → client.chat.completions.create()  ← 看实际 API 请求的所有字段
```

每一层都要读，重点关注：
- 哪些参数被**硬编码**（不可通过 CLI 覆盖）
- 哪些参数有**运行时覆盖**（如 `base_url=None` 传入后被替换）
- `messages` 结构：system prompt 和 user prompt 是分开还是合并为单条 user 消息
- `stream` 是否启用
- 重试逻辑：`MAX_RETRIES`、`RETRY_DELAY`、重试条件（空响应 / error 开头 / 线性还是指数退避）
- `is_reasoning_model` 标志对该模型是否生效

搜索命令：
```bash
grep -n "<model_keyword>\|max_tokens\|temperature\|top_p\|extra_body\|thinking\|base_url\|reasoning_effort\|MAX_RETRIES\|RETRY_DELAY\|stream\|messages" \
  research/scripts/generate_solutions*.py \
  algorithmic/scripts/generate_solutions_*.py \
  src/frontier_cs/gen/llm_interface.py \
  src/frontier_cs/gen/llm.py \
  2>/dev/null
```

### 3. 从官方文档补充（本地无覆盖时）

用 WebFetch 抓取 HuggingFace model card 或官方 API 文档，补充 context length、max output tokens 上限。

### 4. 输出两张表格

#### 表格一：实际 API 请求参数

列出 `client.chat.completions.create()` 调用时**实际传入**的每个字段及其值和代码来源（文件:行号）：

| 参数 | 实际值 | 来源（文件:行号） |
|------|--------|-----------------|
| `model` | `<实际传入的 model 字符串>` | `llm.py:XX infer_provider_and_model()` |
| `messages` | `[{"role": "user", "content": system+user 合并}]` 或分离 | `generate_solutions.py:XX` |
| `max_tokens` | `<value>` | `llm_interface.py:XX` |
| `temperature` | `<value>`（硬编码 / 可配置） | `llm_interface.py:XX` |
| `top_p` | `<value>` | `llm_interface.py:XX` |
| `top_k` | `<value>` 或 不传 | |
| `stream` | `True` / `False` | `llm_interface.py:XX` |
| `extra_body` | `<完整 dict>` 或 不传 | `llm_interface.py:XX` |
| `reasoning_effort` | `<value>` 或 不传 | |
| `timeout` | `<value>` s | `generate_solutions.py:XX` |
| `base_url` | `<实际值>`（是否可被 CLI 覆盖） | `llm.py:XX` |
| `api_key` 来源 | `KIMI_API_KEY` / `MOONSHOT_API_KEY` 等 | `llm_interface.py:XX` |

#### 表格二：重试与运行时参数

| 参数 | 值 | 备注 |
|------|----|------|
| `MAX_RETRIES` | `<value>` | |
| `RETRY_DELAY` | `<value>` s | 线性 `n×delay` 还是指数退避 |
| 重试条件 | `<描述>` | 空响应 / error 开头 / 异常类型 |
| `concurrency` 默认值 | `<value>` | CLI `--concurrency` 默认 |
| `is_reasoning_model` | `True/False` | 对该模型是否有实际影响 |
| Context Length | `<value>` tokens | 官方上限 |
| Max Output Tokens | `<value>` | 官方上限 |

---

若某字段无法确认，填 `未知` 并注明如何查找。

## 注意事项

- **必须读实际调用代码**，不能只看 `__init__` 默认值——很多参数在调用层被硬编码覆盖
- 标注每个参数的代码来源（文件:行号），方便快速定位
- 硬编码的参数要明确标注"硬编码，不可通过 CLI 覆盖"
- thinking 模式下 temperature 通常**必须为 1.0**，不可调低
- 若用户同时询问多个模型，每个模型输出一组独立表格
- 若用户只问某一具体参数，直接回答，无需完整表格
