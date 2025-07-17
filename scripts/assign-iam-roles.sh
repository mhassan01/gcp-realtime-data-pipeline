#!/bin/bash

# Script to assign IAM roles after terraform apply
# This is needed because the terraform service account may not have IAM admin permissions

set -e

# Get project ID from command line or use default
PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}

echo "🔐 Assigning IAM roles for demo project..."
echo "Project ID: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo ""

# Function to assign role with error handling
assign_role() {
    local sa_email=$1
    local role=$2
    local description=$3
    
    echo "👤 Assigning $role to $description..."
    if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$sa_email" \
        --role="$role" \
        --quiet > /dev/null 2>&1; then
        echo "✅ Successfully assigned $role to $description"
    else
        echo "❌ Failed to assign $role to $description"
        echo "   Manual command: gcloud projects add-iam-policy-binding $PROJECT_ID --member=\"serviceAccount:$sa_email\" --role=\"$role\""
    fi
}

echo "📋 Assigning roles for Dataflow service account..."
assign_role "${ENVIRONMENT}-dataflow-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/dataflow.worker" "Dataflow Service Account"
assign_role "${ENVIRONMENT}-dataflow-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/bigquery.dataEditor" "Dataflow Service Account"
assign_role "${ENVIRONMENT}-dataflow-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/storage.objectAdmin" "Dataflow Service Account"
assign_role "${ENVIRONMENT}-dataflow-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/pubsub.subscriber" "Dataflow Service Account"

echo ""
echo "📋 Assigning roles for Table Manager service account..."
assign_role "${ENVIRONMENT}-table-manager-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/bigquery.admin" "Table Manager Service Account"
assign_role "${ENVIRONMENT}-table-manager-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/logging.logWriter" "Table Manager Service Account"
assign_role "${ENVIRONMENT}-table-manager-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/cloudsql.client" "Table Manager Service Account"

echo ""
echo "📋 Assigning roles for Event Generator service account..."
assign_role "${ENVIRONMENT}-event-generator-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/pubsub.publisher" "Event Generator Service Account"
assign_role "${ENVIRONMENT}-event-generator-sa@${PROJECT_ID}.iam.gserviceaccount.com" "roles/logging.logWriter" "Event Generator Service Account"

echo ""
echo "🎉 IAM role assignment completed!"
echo ""
echo "📋 Next steps:"
echo "1. Wait a few minutes for IAM propagation"
echo "2. Continue with Cloud Function and Cloud Run deployments"
echo "3. Test the pipeline with: ./scripts/test-table-creation.sh $PROJECT_ID $ENVIRONMENT"
echo ""
echo "💡 To verify assigned roles:"
echo "   gcloud projects get-iam-policy $PROJECT_ID --flatten=\"bindings[].members\" --format='table(bindings.role)' --filter=\"bindings.members:*$PROJECT_ID*\"" 