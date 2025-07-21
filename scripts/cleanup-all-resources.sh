#!/bin/bash

# Comprehensive Resource Cleanup Script
# This script is designed to be run in a CI/CD environment.
# It is non-interactive and will not prompt for confirmation.
#
# Usage: ./scripts/cleanup-all-resources.sh [PROJECT_ID] [ENVIRONMENT] [REGION]

set -e

PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}
REGION=${3:-"us-central1"}

echo "🗑️  Starting comprehensive resource cleanup for project: $PROJECT_ID"
echo "✅ Environment: $ENVIRONMENT"
echo "✅ Region: $REGION"
echo "-----------------------------------------------------"

# Set project
gcloud config set project $PROJECT_ID

echo "📋 Step 1: Terraform Destroy"
echo "-----------------------------------------------------"
cd terraform
echo "Destroying Terraform-managed resources (non-interactive)..."
terraform destroy -auto-approve -var="project_id=$PROJECT_ID" -var="environment=$ENVIRONMENT" -var="region=$REGION"
echo "✅ Terraform destroy completed."
cd ..

echo ""
echo "📋 Step 2: Manual Resource Cleanup (with error handling)"
echo "-----------------------------------------------------"

# Stop any running Dataflow jobs
echo "🔄 Stopping Dataflow jobs..."
DATAFLOW_JOBS=$(gcloud dataflow jobs list --region=$REGION --filter="name:${ENVIRONMENT}-realtime-data-pipeline AND state=Running" --format="value(id)" || echo "")
if [ -n "$DATAFLOW_JOBS" ]; then
    for job_id in $DATAFLOW_JOBS; do
        echo "Stopping Dataflow job: $job_id"
        gcloud dataflow jobs cancel $job_id --region=$REGION || echo "Failed to stop job $job_id, it may have already been stopped."
    done
else
    echo "No running Dataflow jobs found to stop."
fi

# Delete Cloud Run services
echo "🏃 Deleting Cloud Run services..."
gcloud run services delete ${ENVIRONMENT}-event-generator --region=$REGION --quiet --platform=managed --async || echo "Cloud Run service not found or already deleted."

# Delete Cloud Functions
echo "⚡ Deleting Cloud Functions..."
gcloud functions delete ${ENVIRONMENT}-bigquery-table-manager --region=$REGION --quiet || echo "Cloud Function not found or already deleted."

# Delete BigQuery dataset
echo "📊 Deleting BigQuery dataset..."
bq rm -r -f ${PROJECT_ID}:${ENVIRONMENT}_events_dataset || echo "BigQuery dataset not found or already deleted."

# Delete Pub/Sub topics and subscriptions
echo "📨 Deleting Pub/Sub resources..."
gcloud pubsub subscriptions delete ${ENVIRONMENT}-backend-events-subscription --project=$PROJECT_ID --quiet || echo "Pub/Sub subscription not found or already deleted."
gcloud pubsub topics delete ${ENVIRONMENT}-backend-events-topic --project=$PROJECT_ID --quiet || echo "Pub/Sub topic not found or already deleted."
gcloud pubsub topics delete ${ENVIRONMENT}-backend-events-dead-letter --project=$PROJECT_ID --quiet || echo "Pub/Sub dead-letter topic not found or already deleted."

# Delete Cloud Storage buckets
echo "🪣 Deleting Cloud Storage buckets..."
gsutil -m rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-raw-events || echo "Storage bucket not found or already deleted."
gsutil -m rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-dataflow-temp || echo "Storage bucket not found or already deleted."
gsutil -m rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-dataflow-templates || echo "Storage bucket not found or already deleted."
gsutil -m rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-function-source || echo "Storage bucket not found or already deleted."
gsutil -m rm -r gs://terraform-state-${PROJECT_ID} || echo "Terraform state bucket not found or already deleted."

# Delete Container Registry images
echo "🐳 Deleting Container Registry images..."
gcloud container images delete gcr.io/${PROJECT_ID}/${ENVIRONMENT}-event-generator --force-delete-tags --quiet || echo "Container image not found or already deleted."

# Delete Service Accounts
echo "👤 Deleting Service Accounts..."
gcloud iam service-accounts delete ${ENVIRONMENT}-dataflow-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet || echo "Service account not found or already deleted."
gcloud iam service-accounts delete ${ENVIRONMENT}-table-manager-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet || echo "Service account not found or already deleted."
gcloud iam service-accounts delete ${ENVIRONMENT}-event-generator-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet || echo "Service account not found or already deleted."

echo ""
echo "📋 Step 3: Cleanup Local Files"
echo "-----------------------------------------------------"
echo "🧹 Cleaning up local Terraform files..."
rm -rf terraform/.terraform/
rm -f terraform/.terraform.lock.hcl
rm -f terraform/terraform.tfstate*
# Keeping terraform.tfvars for future use, as it may contain secrets.

echo ""
echo "✅ Comprehensive cleanup finished!"
echo "-----------------------------------------------------"
echo "🔍 Recommended: Double-check the GCP Console to verify all resources are deleted."
echo "💰 Cost: All billable resources created by this project should now be stopped."
echo "-----------------------------------------------------" 