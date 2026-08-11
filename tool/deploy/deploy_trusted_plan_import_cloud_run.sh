#!/usr/bin/env bash
set -euo pipefail

readonly PROJECT_ID='cohort-platform-production'
readonly PROJECT_NUMBER='809647670049'
readonly REGION='europe-west1'
readonly SERVICE='cohort-trusted-plan-import'
readonly REPOSITORY='cohort-trusted-runtime'
readonly IMAGE_NAME='trusted-plan-import'
readonly RUNTIME_SERVICE_ACCOUNT="cohort-trusted-plan-import@${PROJECT_ID}.iam.gserviceaccount.com"
readonly SUPABASE_URL='https://otnhhdxstdnwccehacku.supabase.co'
readonly SERVICE_ROLE_SECRET='cohort-trusted-plan-import-service-role'
readonly SERVICE_ROLE_SECRET_VERSION='1'
readonly FOUNDER_ALLOWLIST_SECRET='cohort-trusted-plan-import-founder-allowlist'
readonly FOUNDER_ALLOWLIST_SECRET_VERSION='1'

if command -v gcloud >/dev/null 2>&1; then
  GCLOUD="$(command -v gcloud)"
elif [[ -x /opt/homebrew/share/google-cloud-sdk/bin/gcloud ]]; then
  GCLOUD='/opt/homebrew/share/google-cloud-sdk/bin/gcloud'
else
  echo 'Google Cloud CLI is unavailable.' >&2
  exit 1
fi

if [[ "$("$GCLOUD" config get-value project)" != "$PROJECT_ID" ]]; then
  echo "Refusing unexpected Google Cloud project." >&2
  exit 1
fi

if [[ "$("$GCLOUD" projects describe "$PROJECT_ID" --format='value(projectId)')" != "$PROJECT_ID" ]]; then
  echo 'Google Cloud project identity verification failed.' >&2
  exit 1
fi

if [[ -n "$(git diff --cached --name-only)" ]]; then
  echo 'Refusing deployment with staged files.' >&2
  exit 1
fi

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  case "${line:3}" in
    supabase/.temp/gotrue-version|supabase/.temp/storage-version) ;;
    *)
      echo 'Refusing deployment with changes outside approved Supabase temp drift.' >&2
      exit 1
      ;;
  esac
done < <(git status --porcelain=v1 --untracked-files=all)

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo 'SUPABASE_ANON_KEY must be supplied through the deployment process environment.' >&2
  exit 1
fi

readonly SOURCE_COMMIT="$(git rev-parse HEAD)"
readonly IMAGE_TAG="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${SOURCE_COMMIT}"
readonly CONTEXT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cohort-trusted-import-build.XXXXXX")"
trap 'rm -rf "$CONTEXT_DIR"' EXIT

git archive "$SOURCE_COMMIT" | tar -x -C "$CONTEXT_DIR"

"$GCLOUD" builds submit "$CONTEXT_DIR" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --config="$CONTEXT_DIR/server/trusted_plan_package_import/cloudbuild.yaml" \
  --substitutions="_SOURCE_COMMIT=${SOURCE_COMMIT},_IMAGE_URI=${IMAGE_TAG}"

readonly IMAGE_DIGEST="$("$GCLOUD" artifacts docker images describe "$IMAGE_TAG" \
  --project="$PROJECT_ID" \
  --format='value(image_summary.digest)')"
if [[ ! "$IMAGE_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo 'Immutable image digest was not resolved.' >&2
  exit 1
fi
readonly IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}@${IMAGE_DIGEST}"

if "$GCLOUD" run services describe "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" >/dev/null 2>&1; then
  echo 'Refusing to create more than the authorised first Cloud Run revision.' >&2
  exit 1
fi

"$GCLOUD" run deploy "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --image="$IMAGE_URI" \
  --revision-suffix="${SOURCE_COMMIT:0:12}" \
  --service-account="$RUNTIME_SERVICE_ACCOUNT" \
  --allow-unauthenticated \
  --ingress=all \
  --execution-environment=gen2 \
  --port=8080 \
  --cpu=1 \
  --memory=256Mi \
  --concurrency=4 \
  --timeout=30s \
  --min=0 \
  --max=2 \
  --set-env-vars="SUPABASE_URL=${SUPABASE_URL},SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY},BIND_ADDRESS=0.0.0.0,MAX_PLAN_PACKAGE_YAML_BYTES=1048576" \
  --set-secrets="SUPABASE_SERVICE_ROLE_KEY=${SERVICE_ROLE_SECRET}:${SERVICE_ROLE_SECRET_VERSION},FOUNDER_EMAIL_ALLOWLIST=${FOUNDER_ALLOWLIST_SECRET}:${FOUNDER_ALLOWLIST_SECRET_VERSION}" \
  --startup-probe='httpGet.path=/healthz,httpGet.port=8080,initialDelaySeconds=0,timeoutSeconds=1,periodSeconds=5,failureThreshold=6' \
  --liveness-probe='httpGet.path=/healthz,httpGet.port=8080,initialDelaySeconds=0,timeoutSeconds=1,periodSeconds=30,failureThreshold=3' \
  --labels="component=trusted-plan-import,source-commit=${SOURCE_COMMIT}"

readonly REVISION="$("$GCLOUD" run services describe "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format='value(status.latestReadyRevisionName)')"
readonly SERVICE_URL="$("$GCLOUD" run services describe "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format='value(status.url)')"

printf 'SOURCE_COMMIT=%s\n' "$SOURCE_COMMIT"
printf 'IMAGE_TAG=%s\n' "$IMAGE_TAG"
printf 'IMAGE_DIGEST=%s\n' "$IMAGE_DIGEST"
printf 'IMAGE_URI=%s\n' "$IMAGE_URI"
printf 'CLOUD_RUN_REVISION=%s\n' "$REVISION"
printf 'CLOUD_RUN_SERVICE_URL=%s\n' "$SERVICE_URL"
printf 'RUNTIME_SERVICE_ACCOUNT=%s\n' "$RUNTIME_SERVICE_ACCOUNT"
printf 'FOUNDER_ALLOWLIST_SECRET_VERSION=projects/%s/secrets/%s/versions/%s\n' \
  "$PROJECT_NUMBER" "$FOUNDER_ALLOWLIST_SECRET" "$FOUNDER_ALLOWLIST_SECRET_VERSION"
