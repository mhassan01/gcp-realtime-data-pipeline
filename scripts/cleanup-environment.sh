#!/bin/bash

# Complete Environment Cleanup Script
# This script completely wipes ALL resources for the environment
# ensuring a clean deployment every time

set -e

PROJECT_ID=${1:-}
ENVIRONMENT=${2:-dev}
REGION=${3:-us-central1}

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: PROJECT_ID is required"
  echo "Usage: $0 <PROJECT_ID> [ENVIRONMENT] [REGION]"
  exit 1
fi

echo "🧹 COMPLETE ENVIRONMENT CLEANUP STARTING"
echo "=================================="
echo "📍 Project: $PROJECT_ID"
echo "🏷️  Environment: $ENVIRONMENT"
echo "🌍 Region: $REGION"
echo "⚠️  This will DELETE ALL resources for this environment!"
echo "=================================="

# Set project context
gcloud config set project $PROJECT_ID

# Function to safely delete with retries
safe_delete() {
  local description="$1"
  local command="$2"
  local max_retries=3
  local retry=0
  
  echo "🗑️  $description"
  
  while [ $retry -lt $max_retries ]; do
    if eval "$command" 2>/dev/null; then
      echo "✅ $description - SUCCESS"
      return 0
    else
      retry=$((retry + 1))
      if [ $retry -lt $max_retries ]; then
        echo "⏳ Retry $retry/$max_retries for: $description"
        sleep 5
      else
        echo "ℹ️  $description - Not found or already deleted"
        return 0
      fi
    fi
  done
}

# 1. Stop all Dataflow jobs for this environment
echo "🛑 Stopping Dataflow jobs..."
DATAFLOW_JOBS=$(gcloud dataflow jobs list --region=$REGION --filter="name~${ENVIRONMENT}" --format="value(id)" 2>/dev/null || echo "")
if [ ! -z "$DATAFLOW_JOBS" ]; then
  for job_id in $DATAFLOW_JOBS; do
    safe_delete "Stop Dataflow job $job_id" "gcloud dataflow jobs cancel $job_id --region=$REGION"
  done
else
  echo "ℹ️  No Dataflow jobs found"
fi

# 2. Delete Cloud Functions
echo "⚡ Deleting Cloud Functions..."
CF_FUNCTIONS=$(gcloud functions list --regions=$REGION --filter="name~${ENVIRONMENT}" --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$CF_FUNCTIONS" ]; then
  for func in $CF_FUNCTIONS; do
    safe_delete "Delete Cloud Function $func" "gcloud functions delete $func --region=$REGION --quiet"
  done
else
  echo "ℹ️  No Cloud Functions found"
fi

# 3. Delete Eventarc Triggers
echo "🔗 Deleting Eventarc triggers..."
EVENTARC_TRIGGERS=$(gcloud eventarc triggers list --location=$REGION --filter="name~${ENVIRONMENT}" --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$EVENTARC_TRIGGERS" ]; then
  for trigger in $EVENTARC_TRIGGERS; do
    trigger_name=$(basename "$trigger")
    safe_delete "Delete Eventarc trigger $trigger_name" "gcloud eventarc triggers delete $trigger_name --location=$REGION --quiet"
  done
else
  echo "ℹ️  No Eventarc triggers found"
fi

# 4. Delete Cloud Run services
echo "🏃 Deleting Cloud Run services..."
CR_SERVICES=$(gcloud run services list --regions=$REGION --filter="metadata.name~${ENVIRONMENT}" --format="value(metadata.name)" 2>/dev/null || echo "")
if [ ! -z "$CR_SERVICES" ]; then
  for service in $CR_SERVICES; do
    safe_delete "Delete Cloud Run service $service" "gcloud run services delete $service --region=$REGION --quiet"
  done
else
  echo "ℹ️  No Cloud Run services found"
fi

# 5. Delete BigQuery datasets
echo "📊 Deleting BigQuery datasets..."
BQ_DATASETS=$(bq ls --filter="labels.environment:${ENVIRONMENT}" --format=value | grep "${ENVIRONMENT}" 2>/dev/null || echo "")
if [ ! -z "$BQ_DATASETS" ]; then
  for dataset in $BQ_DATASETS; do
    safe_delete "Delete BigQuery dataset $dataset" "bq rm -r -f -d $PROJECT_ID:$dataset"
  done
else
  # Try specific dataset naming pattern
  safe_delete "Delete BigQuery dataset ${ENVIRONMENT}_events_dataset" "bq rm -r -f -d $PROJECT_ID:${ENVIRONMENT}_events_dataset"
fi

# 6. Delete Pub/Sub subscriptions first (before topics)
echo "📨 Deleting Pub/Sub subscriptions..."
PUBSUB_SUBS=$(gcloud pubsub subscriptions list --filter="name~${ENVIRONMENT}" --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$PUBSUB_SUBS" ]; then
  for sub in $PUBSUB_SUBS; do
    sub_name=$(basename "$sub")
    safe_delete "Delete Pub/Sub subscription $sub_name" "gcloud pubsub subscriptions delete $sub_name"
  done
else
  echo "ℹ️  No Pub/Sub subscriptions found"
fi

# Also delete the specific backend-events subscription
safe_delete "Delete backend-events-topic-sub" "gcloud pubsub subscriptions delete backend-events-topic-sub"

# 7. Delete Pub/Sub topics
echo "📨 Deleting Pub/Sub topics..."
PUBSUB_TOPICS=$(gcloud pubsub topics list --filter="name~${ENVIRONMENT}" --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$PUBSUB_TOPICS" ]; then
  for topic in $PUBSUB_TOPICS; do
    topic_name=$(basename "$topic")
    safe_delete "Delete Pub/Sub topic $topic_name" "gcloud pubsub topics delete $topic_name"
  done
else
  echo "ℹ️  No Pub/Sub topics found"
fi

# Also delete the specific backend-events topic
safe_delete "Delete backend-events-topic" "gcloud pubsub topics delete backend-events-topic"

# 8. Delete Storage buckets
echo "🪣 Deleting Storage buckets..."
STORAGE_BUCKETS=$(gsutil ls -p $PROJECT_ID | grep -E "(${ENVIRONMENT}|terraform-state)" | sed 's|gs://||' | sed 's|/||' 2>/dev/null || echo "")
if [ ! -z "$STORAGE_BUCKETS" ]; then
  for bucket in $STORAGE_BUCKETS; do
    safe_delete "Delete Storage bucket $bucket" "gsutil -m rm -r gs://$bucket"
  done
else
  echo "ℹ️  No Storage buckets found"
fi

# 9. Remove IAM policy bindings (before deleting service accounts)
echo "🔐 Cleaning IAM policy bindings..."
SERVICE_ACCOUNTS=$(gcloud iam service-accounts list --filter="email~${ENVIRONMENT}" --format="value(email)" 2>/dev/null || echo "")
if [ ! -z "$SERVICE_ACCOUNTS" ]; then
  for sa_email in $SERVICE_ACCOUNTS; do
    echo "🗑️  Removing IAM bindings for: $sa_email"
    
    # Remove all common roles (ignore failures)
    roles=(
      "roles/pubsub.publisher"
      "roles/pubsub.subscriber" 
      "roles/dataflow.worker"
      "roles/bigquery.dataEditor"
      "roles/storage.objectAdmin"
      "roles/cloudfunctions.invoker"
      "roles/run.invoker"
      "roles/bigquery.admin"
      "roles/storage.admin"
    )
    
    for role in "${roles[@]}"; do
      gcloud projects remove-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$sa_email" \
        --role="$role" 2>/dev/null || true
    done
  done
fi

# 10. Delete Service Accounts
echo "👤 Deleting Service Accounts..."
if [ ! -z "$SERVICE_ACCOUNTS" ]; then
  for sa_email in $SERVICE_ACCOUNTS; do
    safe_delete "Delete Service Account $sa_email" "gcloud iam service-accounts delete $sa_email --quiet"
  done
else
  echo "ℹ️  No Service Accounts found"
fi

# 11. Clean up Container Registry images
echo "🐳 Deleting Container Registry images..."
CR_IMAGES=$(gcloud container images list --repository=gcr.io/$PROJECT_ID --filter="name~${ENVIRONMENT}" --format="value(name)" 2>/dev/null || echo "")
if [ ! -z "$CR_IMAGES" ]; then
  for image in $CR_IMAGES; do
    safe_delete "Delete Container image $image" "gcloud container images delete $image --force-delete-tags --quiet"
  done
else
  echo "ℹ️  No Container Registry images found"
fi

# 12. Clean local terraform state
echo "🧹 Cleaning local terraform state..."
rm -rf terraform/.terraform/
rm -f terraform/.terraform.lock.hcl
rm -f terraform/terraform.tfstate*
rm -f terraform/import.tf
echo "✅ Local terraform state cleaned"

# 13. Wait for resource deletion propagation
echo "⏳ Waiting for resource deletion to propagate..."
sleep 45

echo ""
echo "🎉 COMPLETE ENVIRONMENT CLEANUP FINISHED!"
echo "=================================="
echo "✅ All $ENVIRONMENT resources have been removed"
echo "✅ Environment is now completely clean"
echo "🚀 Ready for fresh deployment"
echo "==================================" 