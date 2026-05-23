# S3 Sync to Amazon Internal Buckets

Refresh AWS credentials via ADA and sync a local folder to S3 (shopqa or rufus bucket).

## Steps

1. **Refresh credentials** using ADA conduit:
```bash
ada credentials update --provider=conduit --account=684288478426 --role=RufusScienceConduitRole --profile=default --once
```

2. **Ask the user** which bucket to sync to:
   - `shopqa`: `s3://shopqa-users/zhuofeng/`
   - `rufus`: `s3://rufus-post-training-users-272436634516-us-west-2-an/zhuofeng/`
   - Or both

3. **Ask the user** for the local folder path (e.g. `./algorithmic/qwen3_solutions`). Use `$PWD` if they say "current directory".

4. **Run the sync**:
```bash
aws s3 cp --recursive <LOCAL_FOLDER> <S3_BUCKET_PATH>
```

Replace `<LOCAL_FOLDER>` and `<S3_BUCKET_PATH>` with the actual values.

If syncing to **both** buckets, run both commands sequentially.

5. After each upload, run `aws s3 ls <S3_BUCKET_PATH>` to confirm the files landed.

## Notes
- Always refresh credentials first — conduit tokens expire quickly.
- If `ada` is not found, remind the user to run it themselves with `! ada credentials update ...` in the prompt.
- Use `--recursive` for directories; for a single file use `aws s3 cp <file> <s3-path>` without `--recursive`.
