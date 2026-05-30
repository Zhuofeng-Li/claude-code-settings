# model-config

查询指定 LLM 模型的完整 API 调用配置，输出结构化表格。

## 触发条件

用户询问任何 LLM 模型的 API 配置、参数、怎么调用时触发：
- `/model-config kimi k2.6`
- `/model-config deepseek-r1`
- `/model-config gpt-4o`
- "kimi 的 temperature 怎么设？"
- "deepseek-r1 的 max_tokens 上限是多少？"
- "这个模型支持 thinking 吗？"

## 执行步骤

### 1. 识别目标模型

从用户输入解析：
- 模型名称（规范化，e.g. `kimi-k2.6` → `moonshotai/Kimi-K2.6`）
- Provider（OpenAI / Anthropic / DeepSeek / Moonshot-Kimi / Google / xAI / 本地 vLLM/SGLang 等）

### 2. 从本地项目提取已验证配置（优先）

依次搜索本地脚本，提取常量和调用参数：

```bash
# 查找所有生成脚本
grep -rn "DEFAULT_MODEL\|max_tokens\|temperature\|top_p\|extra_body\|thinking\|base_url\|reasoning_effort" \
  research/scripts/generate_solutions*.py \
  algorithmic/scripts/generate_solutions_*.py \
  src/frontier_cs/gen/llm_interface.py \
  src/frontier_cs/gen/llm.py \
  2>/dev/null | grep -i "<model_keyword>"
```

关注字段：
- `DEFAULT_MODEL` / `DEFAULT_BASE_URL`
- `max_tokens` 默认值
- `temperature` / `top_p` / `top_k`
- `extra_body` 中的 thinking/reasoning 配置
- `reasoning_effort`
- API key 环境变量名（`os.getenv(...)`）
- 重试逻辑（`max_retries`, `base_delay`）

### 3. 从官方文档补充（本地无覆盖时）

用 WebFetch 抓取：
- HuggingFace model card：`https://huggingface.co/<org>/<model>`
- 官方 API 文档

重点提取：thinking 启用方式、推荐参数、context length、max output tokens。

### 4. 输出完整配置表格

**必须**以如下 Markdown 表格形式输出，不得只用文字叙述：

---

## `<model_id>` 配置摘要

| 参数 | 值 | 备注 |
|------|-----|------|
| **Model ID** | `<model_id>` | 传给 API 的实际 model 字符串 |
| **Provider** | `<provider>` | |
| **Base URL** | `<base_url>` | |
| **API Key 变量** | `<ENV_VAR>` | |
| **Context Length** | `<value>` tokens | 最大输入长度 |
| **Max Output Tokens** | `<value>` | 单次响应上限 |
| **temperature** | `<value>` | thinking 模式推荐值 |
| **top_p** | `<value>` | |
| **top_k** | `<value>` | 如适用 |
| **Thinking / Reasoning** | 支持 / 不支持 | |
| **Thinking 启用方式** | `<extra_body snippet>` | 如适用 |
| **默认 max_tokens** | `<value>` | 本项目脚本中使用的默认值 |
| **Timeout** | `<value>` s | |
| **并发建议** | `<value>` | 本项目脚本默认值 |

**最小调用示例：**

```python
from openai import OpenAI

client = OpenAI(
    api_key="<API_KEY>",
    base_url="<BASE_URL>",
)

response = client.chat.completions.create(
    model="<model_id>",
    messages=[{"role": "user", "content": "..."}],
    max_tokens=<max_tokens>,
    temperature=<temperature>,
    top_p=<top_p>,
    # thinking 模式（如适用）：
    extra_body=<extra_body>,
)
print(response.choices[0].message.content)
```

---

若某字段无法确认，单元格填 `未知` 并在备注列说明如何查找。

## 注意事项

- **本地脚本优先**：`src/frontier_cs/gen/llm_interface.py` 和各 `generate_solutions_*.py` 中的参数已经过实际验证，比官方文档更可靠
- thinking 模式下 temperature 通常**必须为 1.0**，不可调低
- 若用户同时询问多个模型，每个模型输出一张独立表格
- 若用户只问某一具体参数（如"max_tokens 多少"），直接回答该参数，无需完整表格
