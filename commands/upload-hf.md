# Upload Model to HuggingFace

Upload a local model folder to HuggingFace Hub. Reads `HF_TOKEN` from environment (set in `~/.zshrc`).

## Steps

1. **Parse arguments** from the user: `<local_folder_path>` and `<repo_id>` (e.g. `ZhuofengLi/my-model`). If either is missing, ask the user.

2. **Check HF_TOKEN** is available:
```bash
echo $HF_TOKEN | grep -q "^hf_" && echo "Token found" || echo "ERROR: HF_TOKEN not set in environment"
```

3. **Check `huggingface_hub` is installed** in the target environment (local or K8s pod). If uploading from a K8s pod, write a temp script and run via `kubectl exec`. If local, run directly.

4. **Generate the upload script** at `/tmp/upload_hf_<repo_slug>.py`:

```python
import os
os.environ['HF_XET_HIGH_PERFORMANCE'] = '1'
from huggingface_hub import HfApi, login

TOKEN = os.environ.get('HF_TOKEN', '')
login(token=TOKEN)
api = HfApi()

FOLDER = '<local_folder_path>'
REPO_ID = '<repo_id>'

try:
    api.create_repo(repo_id=REPO_ID, repo_type='model', private=False)
    print(f'Repo {REPO_ID} created')
except Exception as e:
    print(f'Repo exists or error: {e}')

api.upload_large_folder(
    folder_path=FOLDER,
    repo_id=REPO_ID,
    repo_type='model',
    num_workers=16,
)
print('Upload complete!')
```

5. **Write a README.md** into the model folder before uploading **if the user requests it or if no README.md exists**. Ask the user for:
   - Model description / what it is
   - Base model
   - Training data source
   - Training framework and config (hyperparams, hardware, duration)
   
   Use the template in the **README Template** section below.

6. **Run the upload** in the background with nohup and log to a file:

For K8s:
```bash
kubectl exec <pod> -n application-nonprod -- bash -c "
  HF_TOKEN=<token> nohup python3 /tmp/upload_hf_<slug>.py \
    > /path/to/logs/hf_upload_<slug>.log 2>&1 &
  echo PID: \$!
"
```

For local:
```bash
HF_TOKEN=$HF_TOKEN nohup python3 /tmp/upload_hf_<slug>.py \
  > /tmp/hf_upload_<slug>.log 2>&1 &
echo "PID: $!"
```

7. **Monitor progress**:
```bash
# K8s
kubectl exec <pod> -n application-nonprod -- bash -c "tail -5 /path/to/logs/hf_upload_<slug>.log"

# Local
tail -5 /tmp/hf_upload_<slug>.log
```

8. **Report** the final HuggingFace URL: `https://huggingface.co/<repo_id>`

---

## README Template

When writing README.md for a trained model, use this structure:

```markdown
---
license: apache-2.0
base_model: <base_model_hf_id>
datasets:
  - <dataset_hf_id>
tags:
  - sft
  - <domain>
---

# <Model Name>

## Model Description

<One paragraph: what this model is, what it's trained to do, and the key result.>

## Training Data

- **Dataset**: [<dataset name>](<hf_dataset_url>)
- **Description**: <What the dataset contains and why it was chosen.>

## Training Details

### Framework

- **Training Framework**: [veRL](https://github.com/volcengine/verl)
- **Backend**: FSDP2

### Hyperparameters

| Parameter | Value |
|---|---|
| Learning Rate | <lr> |
| Weight Decay | <wd> |
| Epochs | <epochs> |
| Global Batch Size | <gbs> |
| Micro-batch Size per GPU | <mbs> |
| Max Sequence Length | <seq_len> tokens |
| Optimizer | AdamW (β₁=<b1>, β₂=<b2>) |
| LR Scheduler | <scheduler> with <warmup>% warmup |
| Gradient Clipping | <clip> |
| Sequence Parallelism | <sp> |

### Hardware

| Item | Value |
|---|---|
| GPU | <gpu_type> |
| Nodes | <num_nodes> |
| GPUs per Node | <gpus_per_node> |
| Total GPUs | <total_gpus> |
| Approx. Training Time | <duration> |

## Results

<Benchmark table or description of eval results.>

## Usage

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained("<repo_id>", torch_dtype="auto")
tokenizer = AutoTokenizer.from_pretrained("<repo_id>")
```
```

---

## Notes

- `HF_XET_HIGH_PERFORMANCE=1` replaces the deprecated `HF_HUB_ENABLE_HF_TRANSFER=1` (huggingface_hub >= 1.16)
- `upload_large_folder` with `num_workers=16` gives best parallel throughput for large models
- HF commit rate limit: 128 commits/hour — for large file counts, batching is handled automatically by `upload_large_folder`
- The token is read from `$HF_TOKEN` env var set in `~/.zshrc` — never hardcode it in scripts
