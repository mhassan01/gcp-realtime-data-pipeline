#!/bin/bash

# Test script for BigQuery Table Creation via Cloud Function
# This script sends test events to trigger table creation

set -e

# Configuration
PROJECT_ID=${1:-"fabled-web-172810"}
ENVIRONMENT=${2:-"dev"}
TOPIC_NAME="backend-events-topic"

echo "🧪 Testing BigQuery Table Creation via Cloud Function"
echo "Project ID: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Topic: $TOPIC_NAME"

# Function to publish a message and wait
publish_and_wait() {
    local message="$1"
    local description="$2"
    
    echo "📤 Publishing $description..."
    gcloud pubsub topics publish "$TOPIC_NAME" --message="$message"
    echo "⏳ Waiting 10 seconds for processing..."
    sleep 10
}

# Test 1: Order event (should create orders table)
ORDER_EVENT='{
    "event_type": "order",
    "order_id": "test-order-001",
    "customer_id": "test-customer-123",
    "order_date": "2024-01-15T10:30:00Z",
    "status": "pending",
    "items": [
        {
            "product_id": "prod-001",
            "product_name": "Test Product",
            "quantity": 2,
            "price": 29.99,
            "category": "electronics"
        }
    ],
    "shipping_address": {
        "street": "123 Test St",
        "city": "Test City",
        "country": "US",
        "postal_code": "12345"
    },
    "total_amount": 59.98,
    "currency": "USD",
    "payment_method": "credit_card",
    "event_date": "2024-01-15"
}'

publish_and_wait "$ORDER_EVENT" "order event"

# Test 2: Inventory event (should create inventory table)
INVENTORY_EVENT='{
    "event_type": "inventory",
    "inventory_id": "inv-test-001",
    "product_id": "prod-001",
    "warehouse_id": "wh-us-central",
    "quantity_change": -2,
    "quantity_before": 100,
    "quantity_after": 98,
    "reason": "sale",
    "reason_details": "Customer order fulfillment",
    "adjusted_by_user": "system",
    "timestamp": "2024-01-15T10:35:00Z",
    "event_date": "2024-01-15"
}'

publish_and_wait "$INVENTORY_EVENT" "inventory event"

# Test 3: User activity event (should create user_activity table)
USER_ACTIVITY_EVENT='{
    "event_type": "user_activity",
    "user_id": "user-test-123",
    "session_id": "sess-abc-123",
    "activity_type": "product_page",
    "page_url": "/products/prod-001",
    "page_title": "Test Product - Our Store",
    "ip_address": "192.168.1.100",
    "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
    "device_type": "desktop",
    "browser": "Chrome",
    "country": "US",
    "timestamp": "2024-01-15T10:40:00Z",
    "metadata": {
        "platform": "web",
        "app_version": "1.0.0",
        "language": "en-US"
    },
    "event_date": "2024-01-15"
}'

publish_and_wait "$USER_ACTIVITY_EVENT" "user activity event"

echo "✅ All test events published!"
echo ""
echo "🔍 Verification Steps:"
echo "1. Check Cloud Function logs:"
echo "   gcloud functions logs read ${ENVIRONMENT}-bigquery-table-manager --region=us-central1"
echo ""
echo "2. Check created tables in BigQuery:"
echo "   bq ls ${ENVIRONMENT}_events_dataset"
echo ""
echo "3. Query table data:"
echo "   bq query --use_legacy_sql=false 'SELECT table_name, creation_time FROM \`${PROJECT_ID}.${ENVIRONMENT}_events_dataset.INFORMATION_SCHEMA.TABLES\`'"
echo ""
echo "4. Check table contents:"
echo "   bq query --use_legacy_sql=false 'SELECT * FROM \`${PROJECT_ID}.${ENVIRONMENT}_events_dataset.orders\` LIMIT 5'"
echo "   bq query --use_legacy_sql=false 'SELECT * FROM \`${PROJECT_ID}.${ENVIRONMENT}_events_dataset.inventory\` LIMIT 5'"
echo "   bq query --use_legacy_sql=false 'SELECT * FROM \`${PROJECT_ID}.${ENVIRONMENT}_events_dataset.user_activity\` LIMIT 5'" 