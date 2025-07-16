#!/bin/bash

# Deploy Cloud Function for BigQuery Table Management
# This script packages and uploads the Cloud Function source code

set -e

# Configuration
PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}
FUNCTION_DIR="cloud-functions/table-manager"
BUCKET_NAME="${PROJECT_ID}-${ENVIRONMENT}-function-source"
SOURCE_ARCHIVE="table-manager-source.zip"

echo "🚀 Deploying Cloud Function for BigQuery Table Management"
echo "Project ID: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Bucket: $BUCKET_NAME"

# Check if required files exist
if [ ! -f "$FUNCTION_DIR/main.py" ]; then
    echo "❌ Error: main.py not found in $FUNCTION_DIR"
    exit 1
fi

if [ ! -f "$FUNCTION_DIR/requirements.txt" ]; then
    echo "❌ Error: requirements.txt not found in $FUNCTION_DIR"
    exit 1
fi

if [ ! -f "$FUNCTION_DIR/table_schemas.py" ]; then
    echo "❌ Error: table_schemas.py not found in $FUNCTION_DIR"
    exit 1
fi

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
echo "📦 Creating package in $TEMP_DIR"

# Copy source files
cp "$FUNCTION_DIR/main.py" "$TEMP_DIR/"
cp "$FUNCTION_DIR/requirements.txt" "$TEMP_DIR/"
cp "$FUNCTION_DIR/table_schemas.py" "$TEMP_DIR/"

# Create archive
cd "$TEMP_DIR"
zip -r "$SOURCE_ARCHIVE" .
cd - > /dev/null

echo "✅ Created source archive: $TEMP_DIR/$SOURCE_ARCHIVE"

# Check if bucket exists, create if not
if ! gsutil ls -b "gs://$BUCKET_NAME" > /dev/null 2>&1; then
    echo "⚠️  Bucket $BUCKET_NAME does not exist. Please run terraform apply first."
    exit 1
fi

# Upload to Cloud Storage
echo "📤 Uploading to Cloud Storage..."
gsutil cp "$TEMP_DIR/$SOURCE_ARCHIVE" "gs://$BUCKET_NAME/$SOURCE_ARCHIVE"

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ Cloud Function source code deployed successfully!"
echo "📝 Next steps:"
echo "   1. Run 'terraform apply' to deploy/update the Cloud Function"
echo "   2. Test by sending events to the Pub/Sub topic"
echo "   3. Check Cloud Function logs in GCP Console" 