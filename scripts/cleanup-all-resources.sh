#!/bin/bash

# Complete Resource Cleanup Script
# Usage: ./scripts/cleanup-all-resources.sh [PROJECT_ID] [ENVIRONMENT]

set -e

PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}

echo "🗑️ Starting complete resource cleanup for project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo ""

# Set project
gcloud config set project $PROJECT_ID

echo "📋 Step 1: Terraform Destroy"
cd terraform
echo "Reviewing resources to be destroyed..."
terraform plan -destroy

read -p "Do you want to proceed with Terraform destroy? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Destroying Terraform-managed resources..."
    terraform destroy -auto-approve
    echo "✅ Terraform destroy completed"
else
    echo "❌ Terraform destroy skipped"
fi

cd ..

echo ""
echo "📋 Step 2: Manual Resource Cleanup"

# Stop any running Dataflow jobs
echo "🔄 Stopping Dataflow jobs..."
DATAFLOW_JOBS=$(gcloud dataflow jobs list --region=us-central1 --filter="name:${ENVIRONMENT}-realtime-data-pipeline AND state:Running" --format="value(id)")
for job_id in $DATAFLOW_JOBS; do
    echo "Stopping Dataflow job: $job_id"
    gcloud dataflow jobs cancel $job_id --region=us-central1 || true
done

# Delete Cloud Run services
echo "🏃 Deleting Cloud Run services..."
gcloud run services delete ${ENVIRONMENT}-event-generator --region=us-central1 --quiet || true

# Delete Cloud Functions
echo "⚡ Deleting Cloud Functions..."
gcloud functions delete ${ENVIRONMENT}-bigquery-table-manager --region=us-central1 --quiet || true

# Delete BigQuery dataset (if it exists)
echo "📊 Deleting BigQuery dataset..."
bq rm -r -f ${ENVIRONMENT}_events_dataset || true

# Delete Pub/Sub topics and subscriptions
echo "📨 Deleting Pub/Sub resources..."
gcloud pubsub subscriptions delete ${ENVIRONMENT}-backend-events-subscription || true
gcloud pubsub topics delete ${ENVIRONMENT}-backend-events-topic || true
gcloud pubsub topics delete ${ENVIRONMENT}-backend-events-dead-letter || true

# Delete Cloud Storage buckets
echo "🪣 Deleting Cloud Storage buckets..."
gsutil rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-raw-events || true
gsutil rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-dataflow-temp || true
gsutil rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-dataflow-templates || true
gsutil rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-function-source || true
gsutil rm -r gs://terraform-state-${PROJECT_ID} || true

# Delete Container Registry images
echo "🐳 Deleting Container Registry images..."
gcloud container images delete gcr.io/${PROJECT_ID}/${ENVIRONMENT}-event-generator --force-delete-tags --quiet || true

# Delete Service Accounts
echo "👤 Deleting Service Accounts..."
gcloud iam service-accounts delete ${ENVIRONMENT}-dataflow-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet || true
gcloud iam service-accounts delete ${ENVIRONMENT}-table-manager-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet || true
gcloud iam service-accounts delete ${ENVIRONMENT}-event-generator-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet || true

# Delete Monitoring alerts
echo "📊 Deleting Monitoring alerts..."
gcloud alpha monitoring policies list --format="value(name)" --filter="displayName:${ENVIRONMENT}" | xargs -I {} gcloud alpha monitoring policies delete {} --quiet || true

# Delete Monitoring notification channels
echo "🔔 Deleting Notification channels..."
gcloud alpha monitoring channels list --format="value(name)" --filter="displayName:${ENVIRONMENT}" | xargs -I {} gcloud alpha monitoring channels delete {} --quiet || true

echo ""
echo "📋 Step 3: Cleanup Local Files"

# Clean up Terraform state
echo "🧹 Cleaning up local Terraform files..."
rm -rf terraform/.terraform/
rm -f terraform/.terraform.lock.hcl
rm -f terraform/terraform.tfstate*
rm -f terraform/terraform.tfvars

echo ""
echo "✅ Complete cleanup finished!"
echo ""
echo "📊 Summary of cleaned resources:"
echo "  • Terraform-managed infrastructure"
echo "  • Dataflow jobs"
echo "  • Cloud Run services"
echo "  • Cloud Functions"
echo "  • BigQuery datasets"
echo "  • Pub/Sub topics and subscriptions"
echo "  • Cloud Storage buckets"
echo "  • Container Registry images"
echo "  • Service Accounts"
echo "  • Monitoring alerts and channels"
echo "  • Local Terraform state files"
echo ""
echo "🔍 Recommended: Check GCP Console to verify all resources are deleted"
echo "💰 Cost: All billable resources should now be stopped" 