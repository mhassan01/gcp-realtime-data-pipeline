#!/bin/bash

# Deploy Cloud Function (as a Cloud Run service) for BigQuery Table Management
# This script builds and deploys the function as a containerized service.

set -e

# Configuration
PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}
REGION="us-central1"
SERVICE_NAME="${ENVIRONMENT}-table-manager"
SOURCE_DIR="cloud-functions/table-manager"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "🚀 Deploying BigQuery Table Manager Cloud Function (as Cloud Run)"
echo "Project ID: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Service Name: $SERVICE_NAME"
echo "Image: $IMAGE_NAME"

# Check if required files exist
if [ ! -f "$SOURCE_DIR/main.py" ] || [ ! -f "$SOURCE_DIR/Dockerfile" ]; then
    echo "❌ Error: main.py or Dockerfile not found in $SOURCE_DIR"
    exit 1
fi

# Set project context
gcloud config set project $PROJECT_ID

# Build and push Docker image using Cloud Build
echo "🏗️ Building and pushing Docker image..."
gcloud builds submit "$SOURCE_DIR" --tag "$IMAGE_NAME"

# Deploy to Cloud Run, which backs the Gen 2 Cloud Function
echo "🚀 Deploying Cloud Function service to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
    --image="$IMAGE_NAME" \
    --platform=managed \
    --region="$REGION" \
    --allow-unauthenticated \
    --set-env-vars="PROJECT_ID=$PROJECT_ID,ENVIRONMENT=$ENVIRONMENT" \
    --service-account="${ENVIRONMENT}-table-manager-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --memory=512Mi \
    --cpu=1 \
    --concurrency=80 \
    --timeout=300 \
    --max-instances=5 \
    --min-instances=0 \
    --port=8080 \
    --execution-environment=gen2 \
    --cpu-boost \
    --startup-timeout=900 \
    --quiet

# The Pub/Sub trigger is now managed via Eventarc by Terraform.
# We no longer need to specify it here as Terraform handles the connection
# between the Pub/Sub topic and the Cloud Run service.

echo "✅ Cloud Function service deployed successfully!"
echo "📝 The service is now ready to receive events from the '${ENVIRONMENT}-backend-events-topic' Pub/Sub topic via its Eventarc trigger." 