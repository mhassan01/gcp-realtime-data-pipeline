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
echo "📋 Step 2: Enhanced Resource Cleanup (with existence checks)"
echo "-----------------------------------------------------"

# Function to check if a resource exists
check_and_delete() {
    local resource_type=$1
    local resource_name=$2
    local delete_command=$3
    
    echo "🔍 Checking $resource_type: $resource_name"
    
    case $resource_type in
        "dataflow_job")
            if gcloud dataflow jobs list --region=$REGION --filter="name:${resource_name} AND state=Running" --format="value(id)" | grep -q .; then
                echo "🔄 Found running Dataflow job, stopping..."
                eval "$delete_command"
            else
                echo "✅ No running Dataflow jobs found"
            fi
            ;;
        "cloud_run")
            if gcloud run services describe "$resource_name" --region=$REGION --platform=managed >/dev/null 2>&1; then
                echo "🏃 Deleting Cloud Run service..."
                eval "$delete_command"
            else
                echo "✅ Cloud Run service not found or already deleted"
            fi
            ;;
        "cloud_function")
            if gcloud functions describe "$resource_name" --region=$REGION >/dev/null 2>&1; then
                echo "⚡ Deleting Cloud Function..."
                eval "$delete_command"
            else
                echo "✅ Cloud Function not found or already deleted"
            fi
            ;;
        "pubsub_subscription")
            if gcloud pubsub subscriptions describe "$resource_name" >/dev/null 2>&1; then
                echo "📨 Deleting Pub/Sub subscription..."
                eval "$delete_command"
            else
                echo "✅ Pub/Sub subscription not found or already deleted"
            fi
            ;;
        "pubsub_topic")
            if gcloud pubsub topics describe "$resource_name" >/dev/null 2>&1; then
                echo "📨 Deleting Pub/Sub topic..."
                eval "$delete_command"
            else
                echo "✅ Pub/Sub topic not found or already deleted"
            fi
            ;;
        "storage_bucket")
            if gsutil ls -b "gs://$resource_name" >/dev/null 2>&1; then
                echo "🪣 Deleting Cloud Storage bucket..."
                eval "$delete_command"
            else
                echo "✅ Storage bucket not found or already deleted"
            fi
            ;;
        "bigquery_dataset")
            if bq ls -d "$PROJECT_ID:$resource_name" >/dev/null 2>&1; then
                echo "📊 Deleting BigQuery dataset..."
                eval "$delete_command"
            else
                echo "✅ BigQuery dataset not found or already deleted"
            fi
            ;;
        "container_image")
            if gcloud container images describe "$resource_name" >/dev/null 2>&1; then
                echo "🐳 Deleting Container Registry image..."
                eval "$delete_command"
            else
                echo "✅ Container image not found or already deleted"
            fi
            ;;
        "service_account")
            if gcloud iam service-accounts describe "$resource_name" >/dev/null 2>&1; then
                echo "👤 Attempting to delete service account..."
                eval "$delete_command" || echo "⚠️  Service account deletion failed (permission denied)"
            else
                echo "✅ Service account not found or already deleted"
            fi
            ;;
    esac
}

# Stop any running Dataflow jobs
check_and_delete "dataflow_job" "${ENVIRONMENT}-realtime-data-pipeline" \
    "gcloud dataflow jobs list --region=$REGION --filter='name:${ENVIRONMENT}-realtime-data-pipeline AND state=Running' --format='value(id)' | xargs -I {} gcloud dataflow jobs cancel {} --region=$REGION"

# Delete Cloud Run services
check_and_delete "cloud_run" "${ENVIRONMENT}-event-generator" \
    "gcloud run services delete ${ENVIRONMENT}-event-generator --region=$REGION --quiet --platform=managed"

# Delete Cloud Functions
check_and_delete "cloud_function" "${ENVIRONMENT}-table-manager" \
    "gcloud functions delete ${ENVIRONMENT}-table-manager --region=$REGION --quiet"

# Delete BigQuery dataset
check_and_delete "bigquery_dataset" "${ENVIRONMENT}_events_dataset" \
    "bq rm -r -f ${PROJECT_ID}:${ENVIRONMENT}_events_dataset"

# Delete Pub/Sub topics and subscriptions
check_and_delete "pubsub_subscription" "${ENVIRONMENT}-backend-events-subscription" \
    "gcloud pubsub subscriptions delete ${ENVIRONMENT}-backend-events-subscription --quiet"

check_and_delete "pubsub_topic" "${ENVIRONMENT}-backend-events-topic" \
    "gcloud pubsub topics delete ${ENVIRONMENT}-backend-events-topic --quiet"

check_and_delete "pubsub_topic" "${ENVIRONMENT}-backend-events-dead-letter" \
    "gcloud pubsub topics delete ${ENVIRONMENT}-backend-events-dead-letter --quiet"

# Delete Cloud Storage buckets
check_and_delete "storage_bucket" "${PROJECT_ID}-${ENVIRONMENT}-raw-events" \
    "gsutil -m rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-raw-events"

check_and_delete "storage_bucket" "${PROJECT_ID}-${ENVIRONMENT}-dataflow-temp" \
    "gsutil -m rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-dataflow-temp"

check_and_delete "storage_bucket" "${PROJECT_ID}-${ENVIRONMENT}-dataflow-templates" \
    "gsutil -m rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-dataflow-templates"

check_and_delete "storage_bucket" "${PROJECT_ID}-${ENVIRONMENT}-function-source" \
    "gsutil -m rm -r gs://${PROJECT_ID}-${ENVIRONMENT}-function-source"

check_and_delete "storage_bucket" "terraform-state-${PROJECT_ID}" \
    "gsutil -m rm -r gs://terraform-state-${PROJECT_ID}"

# Delete Container Registry images
check_and_delete "container_image" "gcr.io/${PROJECT_ID}/${ENVIRONMENT}-event-generator:latest" \
    "gcloud container images delete gcr.io/${PROJECT_ID}/${ENVIRONMENT}-event-generator:latest --force-delete-tags --quiet"

# Delete Service Accounts (may fail due to permissions)
echo ""
echo "👤 Attempting to delete service accounts (may require elevated permissions)..."
check_and_delete "service_account" "${ENVIRONMENT}-dataflow-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    "gcloud iam service-accounts delete ${ENVIRONMENT}-dataflow-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet"

check_and_delete "service_account" "${ENVIRONMENT}-table-manager-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    "gcloud iam service-accounts delete ${ENVIRONMENT}-table-manager-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet"

check_and_delete "service_account" "${ENVIRONMENT}-event-generator-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    "gcloud iam service-accounts delete ${ENVIRONMENT}-event-generator-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet"

echo ""
echo "📋 Step 3: Cleanup Local Files"
echo "-----------------------------------------------------"
echo "🧹 Cleaning up local Terraform files..."
rm -rf terraform/.terraform/
rm -f terraform/.terraform.lock.hcl
rm -f terraform/terraform.tfstate*
rm -f terraform/import.tf
# Keeping terraform.tfvars for future use, as it may contain secrets.

echo ""
echo "✅ Enhanced cleanup finished!"
echo "-----------------------------------------------------"
echo "🔍 Summary:"
echo "  ✅ Terraform destroy completed"
echo "  ✅ Resource existence checks performed"
echo "  ✅ Permissions handled gracefully"
echo "  ⚠️  Service accounts may require manual deletion with elevated permissions"
echo ""
echo "💡 Note: Some permission errors are expected in CI/CD environments"
echo "🔍 Recommended: Double-check the GCP Console to verify cleanup"
echo "💰 Cost: All billable resources should now be stopped"
echo "-----------------------------------------------------" 