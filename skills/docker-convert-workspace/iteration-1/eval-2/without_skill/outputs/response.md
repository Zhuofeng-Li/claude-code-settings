# Dockerizing the evaluate.py Project

## Dependency Analysis

From `evaluate.py`, the external dependencies are:

- **openai**: Used for `openai.OpenAI()` client and `client.chat.completions.create()`
- **tqdm**: Used for the `tqdm()` progress bar wrapper

The following are Python standard library modules (no installation needed):
- `json`
- `pathlib`
- `sys`

## Generated Files

### requirements.txt

```
openai
tqdm
```

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY evaluate.py .

ENTRYPOINT ["python", "evaluate.py"]
```

## Usage

Build the image:

```bash
docker build -t evaluate .
```

Run the container (pass your OpenAI API key and mount a volume for input/output files):

```bash
docker run --rm \
  -e OPENAI_API_KEY=your_api_key_here \
  -v $(pwd)/data:/data \
  evaluate /data/input.json /data/output.json
```

- `input.json` should be a JSON array of objects with a `prompt` field, e.g.:
  ```json
  [{"prompt": "Hello, world!"}]
  ```
- The results will be written to `output.json` inside the mounted `/data` directory.
