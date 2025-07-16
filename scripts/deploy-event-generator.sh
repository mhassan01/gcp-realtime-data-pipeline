#!/bin/bash

# Deploy Event Generator Service to Cloud Run
# Usage: ./deploy-event-generator.sh [PROJECT_ID] [ENVIRONMENT] [REGION]

set -e

# Configuration
PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}
REGION=${3:-"us-central1"}

SERVICE_NAME="${ENVIRONMENT}-event-generator"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
SOURCE_DIR="cloud-functions/event-generator"

echo "🚀 Deploying Event Generator Service to Cloud Run"
echo "Project ID: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Service Name: $SERVICE_NAME"

# Ensure we're in the correct directory
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Error: $SOURCE_DIR directory not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Authenticate with gcloud if needed
echo "🔐 Checking authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "No active authentication found. Please run: gcloud auth login"
    exit 1
fi

# Set project
echo "📋 Setting project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    containerregistry.googleapis.com \
    --quiet

# Build and push Docker image
echo "🏗️ Building Docker image..."
cd $SOURCE_DIR

# Build the image using Cloud Build for better performance
gcloud builds submit --tag $IMAGE_NAME .

# Go back to root directory
cd ..

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --set-env-vars PROJECT_ID=$PROJECT_ID,ENVIRONMENT=$ENVIRONMENT \
    --memory 1Gi \
    --cpu 1 \
    --concurrency 100 \
    --timeout 900 \
    --max-instances 10 \
    --min-instances 0 \
    --port 8080 \
    --quiet

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)")

echo "✅ Event Generator Service deployed successfully!"
echo ""
echo "🔗 Service URL: $SERVICE_URL"
echo ""
echo "📖 API Documentation:"
echo "   Health Check: $SERVICE_URL/health"
echo "   API Docs: $SERVICE_URL/docs"
echo "   OpenAPI Schema: $SERVICE_URL/openapi.json"
echo ""
echo "🧪 Test Commands:"
echo "   # Get sample event"
echo "   curl $SERVICE_URL/sample/order"
echo ""
echo "   # Generate single event"
echo "   curl -X POST $SERVICE_URL/generate/single/order"
echo ""
echo "   # Start continuous generation"
echo "   curl -X POST $SERVICE_URL/generate/start \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"events_per_minute\": 30, \"duration_minutes\": 5}'"
echo ""
echo "🔍 Monitor logs:"
echo "   gcloud logs tail $SERVICE_NAME --region=$REGION"

# Update Terraform outputs (if terraform directory exists)
if [ -d "terraform" ]; then
    echo ""
    echo "📝 Next steps:"
    echo "1. Update terraform/outputs.tf to include the event generator service URL"
    echo "2. Run 'cd terraform && terraform apply' to update infrastructure"
fi 