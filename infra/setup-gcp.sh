#!/usr/bin/env bash
# One-time Google Cloud project bootstrap for Gamya Mobility.
# Usage: PROJECT_ID=my-project REGION=asia-south1 ./infra/setup-gcp.sh
set -euo pipefail
PROJECT_ID=${PROJECT_ID:?set PROJECT_ID}
REGION=${REGION:-asia-south1}
REPO=${REPO:-gamya}
DB_INSTANCE=${DB_INSTANCE:-gamya-db}
DB_NAME=${DB_NAME:-gamya_mobility}
DB_USER=${DB_USER:-gamya}
DB_PASSWORD=${DB_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/')}
WEB_BUCKET=${WEB_BUCKET:-${PROJECT_ID}-gamya-admin-web}
UPLOAD_BUCKET=${UPLOAD_BUCKET:-${PROJECT_ID}-gamya-uploads}
JWT_SECRET=${JWT_SECRET:-$(openssl rand -hex 32)}

gcloud config set project "$PROJECT_ID"
echo "▶ Enabling APIs"
gcloud services enable run.googleapis.com sqladmin.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com storage.googleapis.com

echo "▶ Artifact Registry"
gcloud artifacts repositories describe "$REPO" --location "$REGION" >/dev/null 2>&1 || gcloud artifacts repositories create "$REPO" --repository-format docker --location "$REGION"

echo "▶ Cloud SQL (PostgreSQL 16)"
if ! gcloud sql instances describe "$DB_INSTANCE" >/dev/null 2>&1; then
  gcloud sql instances create "$DB_INSTANCE" --database-version POSTGRES_16 --tier db-g1-small --region "$REGION" --storage-auto-increase
fi
gcloud sql databases describe "$DB_NAME" --instance "$DB_INSTANCE" >/dev/null 2>&1 || gcloud sql databases create "$DB_NAME" --instance "$DB_INSTANCE"
gcloud sql users describe "$DB_USER" --instance "$DB_INSTANCE" >/dev/null 2>&1 || gcloud sql users create "$DB_USER" --instance "$DB_INSTANCE" --password "$DB_PASSWORD"
CONN=$(gcloud sql instances describe "$DB_INSTANCE" --format 'value(connectionName)')

echo "▶ Buckets"
gsutil ls -b "gs://$WEB_BUCKET" >/dev/null 2>&1 || gsutil mb -l "$REGION" "gs://$WEB_BUCKET"
gsutil iam ch allUsers:objectViewer "gs://$WEB_BUCKET"
gsutil web set -m index.html -e index.html "gs://$WEB_BUCKET"
gsutil ls -b "gs://$UPLOAD_BUCKET" >/dev/null 2>&1 || gsutil mb -l "$REGION" "gs://$UPLOAD_BUCKET"
gsutil iam ch allUsers:objectViewer "gs://$UPLOAD_BUCKET"

echo "▶ Secrets"
printf '%s' "postgresql://$DB_USER:$DB_PASSWORD@localhost/$DB_NAME?host=/cloudsql/$CONN&schema=public" | gcloud secrets create gamya-database-url --data-file=- 2>/dev/null || printf '%s' "postgresql://$DB_USER:$DB_PASSWORD@localhost/$DB_NAME?host=/cloudsql/$CONN&schema=public" | gcloud secrets versions add gamya-database-url --data-file=-
printf '%s' "$JWT_SECRET" | gcloud secrets create gamya-jwt-secret --data-file=- 2>/dev/null || true

echo "▶ Initial Cloud Run service (placeholder image; Cloud Build will deploy the real one)"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format 'value(projectNumber)')
SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"
gcloud secrets add-iam-policy-binding gamya-database-url --member "serviceAccount:$SA" --role roles/secretmanager.secretAccessor >/dev/null
gcloud secrets add-iam-policy-binding gamya-jwt-secret --member "serviceAccount:$SA" --role roles/secretmanager.secretAccessor >/dev/null
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member "serviceAccount:$SA" --role roles/cloudsql.client >/dev/null
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member "serviceAccount:$SA" --role roles/storage.objectAdmin >/dev/null
gcloud run deploy gamya-api --image gcr.io/cloudrun/hello --region "$REGION" --allow-unauthenticated --add-cloudsql-instances "$CONN" \
  --set-secrets DATABASE_URL=gamya-database-url:latest,JWT_SECRET=gamya-jwt-secret:latest \
  --set-env-vars "NODE_ENV=production,STORAGE_DRIVER=gcs,GCS_BUCKET=$UPLOAD_BUCKET,GCS_PROJECT_ID=$PROJECT_ID,CORS_ORIGINS=*,ADMIN_BOOTSTRAP_EMAIL=admin@gamya.com,ADMIN_BOOTSTRAP_PASSWORD=ChangeMe@123" >/dev/null

echo
echo "✔ Done. Next:"
echo "  gcloud builds submit --config infra/cloudbuild.yaml --substitutions=_REGION=$REGION,_WEB_BUCKET=$WEB_BUCKET,_CLOUDSQL_INSTANCE=$CONN,_API_URL=\$(gcloud run services describe gamya-api --region $REGION --format 'value(status.url)')/api/v1"
echo "  Admin web: https://storage.googleapis.com/$WEB_BUCKET/index.html  (put a load balancer + custom domain in front for production)"
echo "  DB password: $DB_PASSWORD  (stored inside the gamya-database-url secret)"
