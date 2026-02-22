---
auto_invoke:
  description: "Setting up S3 storage, file uploads, photo uploads, or presigned URLs"
---

# Set Up Storage (AWS S3 + Presigned URLs)

Add S3-backed file/photo storage with presigned URL uploads and optional auth gating.

## Steps

1. Copy all files from `/Users/scottzockoll/projects/workshop/services/storage/files/` into the project root, preserving directory structure:
   - `src/lib/storage.ts` — S3 client + presigned URL helpers
   - `src/app/api/upload/route.ts` — POST endpoint to get a presigned PUT URL
   - `src/app/api/storage/[...key]/route.ts` — GET proxy that serves files (with optional auth gate)
   - `scripts/provision-storage.sh` — Bucket provisioning script

2. Install dependencies:
   ```bash
   npm install @aws-sdk/client-s3 @aws-sdk/s3-request-presigner jose
   ```
   (`jose` is needed by the storage route for optional auth gating)

3. Add env vars to `.env.local` (create if it doesn't exist):
   ```
   S3_BUCKET_NAME=scottzockoll-<project-slug>
   S3_REGION=us-east-1
   AWS_ACCESS_KEY_ID=<from secrets.env or AWS console>
   AWS_SECRET_ACCESS_KEY=<from secrets.env or AWS console>
   STORAGE_REQUIRE_AUTH=false
   ```

4. Update `services.json` to include `"storage"` in the services array.

5. Tell the user:
   - **Upload flow**: POST `/api/upload` with `{ filename, contentType }` → get `{ uploadUrl, key }` → PUT file directly to S3 from the browser
   - **Display files**: Always use `<img src="/api/storage/${key}">` — never use direct S3 URLs (bucket is private)
   - **Auth gating**: Set `STORAGE_REQUIRE_AUTH=true` (and ensure `JWT_SECRET` is set from the auth service) to gate all file access behind a valid session cookie
   - Run `scripts/provision-storage.sh` (with AWS credentials set) to create the S3 bucket and push env vars to Vercel
