# Deployment (Google Cloud)

| Component | Service |
|---|---|
| REST API (Node.js) | Cloud Run (`gamya-api`) – Docker image in Artifact Registry |
| Database | Cloud SQL for PostgreSQL 16 (`gamya-db`), connected over the Cloud SQL socket |
| File uploads (documents, selfies, vehicle photos) | Cloud Storage bucket (`*-gamya-uploads`) – `STORAGE_DRIVER=gcs` |
| Admin web (Flutter web) | Cloud Storage static bucket (`*-gamya-admin-web`) – or Cloud Run + nginx (`nginx.Dockerfile`) |
| Android app | `flutter build apk/appbundle` → Play Console |
| Secrets | Secret Manager (`gamya-database-url`, `gamya-jwt-secret`) |

## First time
```bash
PROJECT_ID=your-project REGION=asia-south1 ./infra/setup-gcp.sh
```
Creates APIs, Artifact Registry, Cloud SQL instance/db/user, buckets, secrets and an initial Cloud Run service.

## Every release
```bash
gcloud builds submit --config infra/cloudbuild.yaml \
  --substitutions=_REGION=asia-south1,_WEB_BUCKET=<web-bucket>,_CLOUDSQL_INSTANCE=<project:region:instance>,_API_URL=https://<cloud-run-url>/api/v1
```
The Cloud Run container runs `prisma migrate deploy` on start, then boots the API. The first boot creates the
super-admin from `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` — change the password immediately from
Admin Users → Change My Password.

Individual pieces: `infra/deploy-api.sh`, `infra/deploy-web.sh`, `infra/build-android.sh`.

## Custom domain
Put an HTTPS load balancer (or Firebase Hosting) in front of the web bucket and map `api.` to the Cloud Run
service with `gcloud run domain-mappings create`. Then set `CORS_ORIGINS` on the service to the web origin.

## Optional integrations
* Push notifications: set `FCM_ENABLED=true` and `FIREBASE_SERVICE_ACCOUNT_JSON` (Secret Manager) on Cloud Run,
  add `google-services.json` to `apps/mobile/android/app` and the `firebase_messaging` plugin.
* Face verification: `FACE_VERIFY_DRIVER=vision` uses Cloud Vision face detection (needs `@google-cloud/vision`
  and the Vision API enabled); default `mock` records a match score without an external call.
