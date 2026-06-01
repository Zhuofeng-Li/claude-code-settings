# S3 Sync to Amazon Internal Buckets

Refresh AWS credentials via ADA and sync between local and S3 (shopqa or rufus bucket).
**Default tool: s5cmd** (parallel, much faster than aws cli).

## Buckets

- `shopqa`: `s3://shopqa-users/zhuofeng/`
- `rufus`: `s3://rufus-post-training-users-272436634516-us-west-2-an/zhuofeng/`

## Steps

1. **Refresh credentials** using ADA conduit:
```bash
ada credentials update --provider=conduit --account=684288478426 --role=RufusScienceConduitRole --profile=default --once
```

2. **Install s5cmd if not present**:
```bash
which s5cmd || (curl -fsSL https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_Linux-64bit.tar.gz | tar xz -C /tmp && mv /tmp/s5cmd ~/.local/bin/)
```

3. **Ask the user** which bucket to sync to:
   - `shopqa`: `s3://shopqa-users/zhuofeng/`
   - `rufus`: `s3://rufus-post-training-users-272436634516-us-west-2-an/zhuofeng/`
   - Or both

4. **Ask the user** for the local folder path. Use `$PWD` if they say "current directory".

5. **Run the sync with s5cmd**:

Upload (local → S3):
```bash
s5cmd sync \
  --exclude "*.pyc" \
  --exclude "*/__pycache__/*" \
  --exclude "*/.venv/*" \
  --exclude "*/.git/*" \
  <LOCAL_FOLDER>/ \
  <S3_BUCKET_PATH>/
```

Download (S3 → local):
```bash
s5cmd sync \
  <S3_BUCKET_PATH>/ \
  <LOCAL_FOLDER>/
```

For a single file:
```bash
s5cmd cp <SRC> <DST>
```

If syncing to **both** buckets (upload only), run both commands sequentially.

6. After each transfer, verify with:
```bash
s5cmd ls <S3_BUCKET_PATH>/
```

## Notes
- Always refresh credentials first — conduit tokens expire quickly.
- If `ada` is not found, remind the user to run it themselves with `! ada credentials update ...` in the prompt.
- `s5cmd sync` is incremental — only uploads changed/new files (like `rsync`).
- To preview without transferring: `s5cmd sync --dry-run <SRC>/ <DST>/`.
- s5cmd uses parallel workers by default; no extra flags needed for speed.
- Trailing `/` on local path is required for `sync` to work correctly.
