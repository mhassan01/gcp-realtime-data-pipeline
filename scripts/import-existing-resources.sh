#!/bin/bash

# Import Existing Resources Script
# This script imports existing GCP resources into Terraform state
# Usage: ./scripts/import-existing-resources.sh [PROJECT_ID] [ENVIRONMENT] [REGION]

set -e

PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}
REGION=${3:-"us-central1"}

echo "🔄 Importing existing resources into Terraform state"
echo "Project ID: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "-----------------------------------------------------"

# Ensure we're in the terraform directory
cd terraform

# Function to import a resource if it exists
import_if_exists() {
    local resource_type=$1
    local terraform_resource=$2
    local gcp_resource_id=$3
    local check_command=$4
    
    echo "🔍 Checking $resource_type: $terraform_resource"
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo "✅ Found existing resource, importing..."
        terraform import -var="project_id=$PROJECT_ID" -var="environment=$ENVIRONMENT" -var="region=$REGION" \
            "$terraform_resource" "$gcp_resource_id" || echo "⚠️  Import failed (may already be in state)"
    else
        echo "📝 Resource doesn't exist, will be created"
    fi
    echo ""
}

# Import Storage Buckets
echo "🪣 Importing Storage Buckets..."
import_if_exists "Storage Bucket" "google_storage_bucket.terraform_state" \
    "terraform-state-$PROJECT_ID" \
    "gsutil ls -b gs://terraform-state-$PROJECT_ID"

import_if_exists "Storage Bucket" "google_storage_bucket.raw_events" \
    "$PROJECT_ID-$ENVIRONMENT-raw-events" \
    "gsutil ls -b gs://$PROJECT_ID-$ENVIRONMENT-raw-events"

import_if_exists "Storage Bucket" "google_storage_bucket.dataflow_temp" \
    "$PROJECT_ID-$ENVIRONMENT-dataflow-temp" \
    "gsutil ls -b gs://$PROJECT_ID-$ENVIRONMENT-dataflow-temp"

import_if_exists "Storage Bucket" "google_storage_bucket.dataflow_templates" \
    "$PROJECT_ID-$ENVIRONMENT-dataflow-templates" \
    "gsutil ls -b gs://$PROJECT_ID-$ENVIRONMENT-dataflow-templates"

import_if_exists "Storage Bucket" "google_storage_bucket.function_source" \
    "$PROJECT_ID-$ENVIRONMENT-function-source" \
    "gsutil ls -b gs://$PROJECT_ID-$ENVIRONMENT-function-source"

# Import Service Accounts
echo "👤 Importing Service Accounts..."
import_if_exists "Service Account" "google_service_account.dataflow_sa" \
    "projects/$PROJECT_ID/serviceAccounts/$ENVIRONMENT-dataflow-pipeline-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    "gcloud iam service-accounts describe $ENVIRONMENT-dataflow-pipeline-sa@$PROJECT_ID.iam.gserviceaccount.com"

import_if_exists "Service Account" "google_service_account.table_manager_sa" \
    "projects/$PROJECT_ID/serviceAccounts/$ENVIRONMENT-table-manager-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    "gcloud iam service-accounts describe $ENVIRONMENT-table-manager-sa@$PROJECT_ID.iam.gserviceaccount.com"

import_if_exists "Service Account" "google_service_account.event_generator_sa" \
    "projects/$PROJECT_ID/serviceAccounts/$ENVIRONMENT-event-generator-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    "gcloud iam service-accounts describe $ENVIRONMENT-event-generator-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Import Pub/Sub Topics
echo "📨 Importing Pub/Sub Topics..."
import_if_exists "Pub/Sub Topic" "google_pubsub_topic.dead_letter" \
    "projects/$PROJECT_ID/topics/$ENVIRONMENT-backend-events-dead-letter" \
    "gcloud pubsub topics describe $ENVIRONMENT-backend-events-dead-letter"

import_if_exists "Pub/Sub Topic" "google_pubsub_topic.backend_events" \
    "projects/$PROJECT_ID/topics/$ENVIRONMENT-backend-events-topic" \
    "gcloud pubsub topics describe $ENVIRONMENT-backend-events-topic"

# Import Pub/Sub Subscription
import_if_exists "Pub/Sub Subscription" "google_pubsub_subscription.backend_events_sub" \
    "projects/$PROJECT_ID/subscriptions/$ENVIRONMENT-backend-events-subscription" \
    "gcloud pubsub subscriptions describe $ENVIRONMENT-backend-events-subscription"

# Import BigQuery Dataset
echo "📊 Importing BigQuery Dataset..."
import_if_exists "BigQuery Dataset" "google_bigquery_dataset.events_dataset" \
    "projects/$PROJECT_ID/datasets/${ENVIRONMENT}_events_dataset" \
    "bq ls -d $PROJECT_ID:${ENVIRONMENT}_events_dataset"

# Import Project Services (these usually exist)
echo "🔧 Importing Project Services..."
services=("bigquery.googleapis.com" "cloudbuild.googleapis.com" "cloudfunctions.googleapis.com" "dataflow.googleapis.com" "pubsub.googleapis.com" "run.googleapis.com" "storage.googleapis.com")

for service in "${services[@]}"; do
    import_if_exists "Project Service" "google_project_service.apis[\"$service\"]" \
        "$PROJECT_ID/$service" \
        "gcloud services list --enabled --filter=name:$service --format='value(name)' | grep -q $service"
done

echo "✅ Import process completed!"
echo "-----------------------------------------------------"
echo "📋 Summary:"
echo "  • Checked and imported existing storage buckets"
echo "  • Checked and imported existing service accounts"
echo "  • Checked and imported existing Pub/Sub resources"
echo "  • Checked and imported existing BigQuery dataset"
echo "  • Checked and imported existing project services"
echo ""
echo "🚀 You can now run 'terraform plan' and 'terraform apply' safely"
echo "-----------------------------------------------------" 