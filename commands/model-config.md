# model-config

查询指定 LLM 模型的关键推理参数配置（temperature、top_p、thinking/reasoning 模式、max_tokens、base_url 等）。

## 使用方式

用户提问示例：
- `/model-config kimi k2.6`
- `/model-config deepseek-r1`
- `/model-config gpt-4o`
- `/model-config claude sonnet 4.5`

## 执行步骤

### 1. 识别模型

从用户输入识别目标模型名称，解析 provider（OpenAI / Anthropic / DeepSeek / Moonshot / Google / xAI / 本地等）。

### 2. 从本地脚本提取已知配置

优先从项目中现有的生成脚本提取参数（最可靠，已经过验证）：

```bash
ls algorithmic/scripts/generate_solutions_*.py research/scripts/generate_solutions*.py 2>/dev/null
```

搜索匹配的脚本文件，读取其中的常量（`DEFAULT_MODEL`、`THINKING_TEMPERATURE`、`THINKING_TOP_P`、`max_tokens` 默认值、`extra_body` 配置等）。

### 3. 从官方文档补充

如果本地脚本没有覆盖目标模型，使用 WebFetch 获取官方文档：
- HuggingFace model card：`https://huggingface.co/<org>/<model>`
- 官方 API 文档页面

重点抓取：
- thinking/reasoning 模式是否支持及如何启用
- 官方推荐的 temperature / top_p
- max_tokens 上限
- base_url
- API key 环境变量名

### 4. 输出配置摘要

以清晰的表格或代码块形式输出：

```
模型          : <model_id>
Provider      : <provider>
Base URL      : <base_url>
API Key 变量  : <ENV_VAR_NAME>

── 推理参数 ──────────────────────────────
Thinking 模式 : <支持/不支持> | 启用方式: <extra_body snippet>
temperature   : <value>  (thinking 模式) / <value>  (普通模式)
top_p         : <value>
max_tokens    : <default> (上限: <max>)
context length: <value>

── 调用示例 ──────────────────────────────
<minimal Python code snippet>
```

如果某参数不确定，注明"未知，需查官方文档"。

## 注意事项

- 优先使用本地已验证脚本中的参数，而非网络文档（网络文档可能过时）
- thinking 模式下 temperature 通常固定为 1.0，不可随意调低
- 如果用户问的是"我应该用什么参数"，结合问题类型（竞赛/对话/代码生成）给出推荐值
