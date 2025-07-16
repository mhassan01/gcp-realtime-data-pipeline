#!/bin/bash

# Deploy Dataflow Flex Template
# This script builds and uploads the Dataflow template

set -e

# Configuration
PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}
REGION=${3:-"us-central1"}

TEMPLATE_IMAGE="gcr.io/${PROJECT_ID}/${ENVIRONMENT}-streaming-pipeline:latest"
TEMPLATE_BUCKET="${PROJECT_ID}-${ENVIRONMENT}-dataflow-templates"
TEMPLATE_PATH="gs://${TEMPLATE_BUCKET}/templates/streaming-pipeline.json"

echo "🚀 Deploying Dataflow Flex Template"
echo "Project ID: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Template Image: $TEMPLATE_IMAGE"
echo "Template Path: $TEMPLATE_PATH"

# Check if running from correct directory
if [ ! -f "dataflow-pipeline/Dockerfile" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Build and push Docker image
echo "📦 Building Docker image..."
cd dataflow-pipeline

# Configure Docker for GCR
gcloud auth configure-docker

# Build the image
docker build -t "$TEMPLATE_IMAGE" .

# Push the image
echo "📤 Pushing Docker image to GCR..."
docker push "$TEMPLATE_IMAGE"

cd ..

# Create template specification
echo "📋 Creating template specification..."
TEMPLATE_SPEC='{
  "image": "'$TEMPLATE_IMAGE'",
  "metadata": {
    "name": "Real-time Data Pipeline",
    "description": "Streaming pipeline that processes events from Pub/Sub and writes to BigQuery and GCS",
    "parameters": [
      {
        "name": "input_subscription",
        "label": "Pub/Sub subscription",
        "helpText": "The Pub/Sub subscription to read from",
        "isOptional": false,
        "regexes": ["^projects\\/[^\\n\\r\\/]+\\/subscriptions\\/[^\\n\\r\\/]+$"]
      },
      {
        "name": "output_dataset",
        "label": "BigQuery dataset",
        "helpText": "The BigQuery dataset to write events to",
        "isOptional": false
      },
      {
        "name": "output_gcs_prefix",
        "label": "GCS output prefix", 
        "helpText": "The GCS prefix for output files",
        "isOptional": false,
        "regexes": ["^gs:\\/\\/[^\\n\\r\\/]+.*$"]
      },
      {
        "name": "project",
        "label": "GCP Project ID",
        "helpText": "The GCP project ID",
        "isOptional": false
      },
      {
        "name": "region",
        "label": "GCP Region",
        "helpText": "The GCP region to run in",
        "isOptional": true
      },
      {
        "name": "environment",
        "label": "Environment",
        "helpText": "Environment (dev, staging, prod)",
        "isOptional": true
      }
    ]
  }
}'

# Upload template to Cloud Storage
echo "📤 Uploading template specification..."
echo "$TEMPLATE_SPEC" | gsutil cp - "$TEMPLATE_PATH"

echo "✅ Dataflow template deployed successfully!"
echo ""
echo "📝 Template Details:"
echo "   Image: $TEMPLATE_IMAGE"
echo "   Template: $TEMPLATE_PATH"
echo ""
echo "🚀 Next steps:"
echo "   1. Run 'terraform apply' to deploy the Dataflow job"
echo "   2. Monitor job status: gcloud dataflow jobs list --region=$REGION"
echo "   3. View job logs: gcloud dataflow jobs show JOB_ID --region=$REGION" 