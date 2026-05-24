# S3 Sync to/from Amazon Internal Buckets

Refresh AWS credentials via ADA and sync between local and S3 (shopqa or rufus bucket).

## Buckets

- `shopqa`: `s3://shopqa-users/zhuofeng/`
- `rufus`: `s3://rufus-post-training-users-272436634516-us-west-2-an/zhuofeng/`

## Steps

1. **Refresh credentials** using ADA conduit:
```bash
ada credentials update --provider=conduit --account=684288478426 --role=RufusScienceConduitRole --profile=default --once
```

2. **Ask the user** for the direction:
   - Upload (local → S3)
   - Download (S3 → local)

3. **Ask the user** for the local path and which bucket/path on S3.

4. **Run the sync**:

Upload (local → S3):
```bash
aws s3 cp --recursive <LOCAL_FOLDER> <S3_BUCKET_PATH>
```

Download (S3 → local):
```bash
aws s3 cp --recursive <S3_BUCKET_PATH> <LOCAL_FOLDER>
```

S3 path first = download, local path first = upload.

For a single file, omit `--recursive`.

If syncing to **both** buckets (upload only), run both commands sequentially.

5. After each transfer, run `aws s3 ls <S3_BUCKET_PATH>` to confirm.

## Notes
- Always refresh credentials first — conduit tokens expire quickly.
- If `ada` is not found, remind the user to run it themselves with `! ada credentials update ...` in the prompt.
- To preview what would be synced without transferring: `aws s3 cp --recursive --dryrun <SRC> <DST>`.
