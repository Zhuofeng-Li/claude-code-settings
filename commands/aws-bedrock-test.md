---
description: Test AWS Bedrock Claude connectivity by sending a quick test message
argument-hint: "[model_id]"
allowed-tools: Bash
---

测试 AWS Bedrock Claude 是否可正常调用。默认测试 `us.anthropic.claude-opus-4-7`，也可传入其他 model ID。

## 步骤

1. 用 Python 调用 Bedrock，发送一条简短测试消息
2. 打印响应内容和 token 用量
3. 若失败，打印错误信息并提示可能原因

```bash
python3 -c "
import boto3, json, sys

model = '$ARGUMENTS' if '$ARGUMENTS' else 'us.anthropic.claude-opus-4-7'
print(f'Testing model: {model}')

try:
    client = boto3.client('bedrock-runtime', region_name='us-east-1')
    response = client.invoke_model(
        modelId=model,
        body=json.dumps({
            'anthropic_version': 'bedrock-2023-05-31',
            'max_tokens': 100,
            'messages': [{'role': 'user', 'content': 'Say hello and tell me your model name.'}]
        })
    )
    result = json.loads(response['body'].read())
    text = result['content'][0]['text']
    usage = result['usage']
    print(f'Response : {text}')
    print(f'Tokens   : input={usage[\"input_tokens\"]}, output={usage[\"output_tokens\"]}')
    print('Status   : OK')
except Exception as e:
    print(f'Status   : FAILED')
    print(f'Error    : {e}')
    sys.exit(1)
"
```

若失败，常见原因：
- AWS credentials 过期 → 运行 `aws sts get-caller-identity` 检查
- 没有该模型的访问权限 → 检查 Bedrock model access 设置
- 网络问题 → 检查 VPC/proxy 配置
