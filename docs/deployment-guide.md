# Data Engineering Technical Assessment - Deployment Guide

## 🎯 Overview

This guide provides step-by-step instructions for deploying the complete real-time data pipeline solution that meets all the technical assessment requirements.

## 📋 Assessment Requirements Mapping

### ✅ Task 1: Data Modeling and Architecture
- **Deliverable**: [Data Model Documentation](./task1-data-modeling.md)
- **BigQuery Tables**: Orders, Inventory, User Activity
- **Partitioning**: Daily by `event_date`
- **Clustering**: Optimized for common query patterns
- **DDL Statements**: Complete table creation scripts

### ✅ Task 2: Streaming Pipeline
- **Dataflow Pipeline**: Apache Beam with Python
- **Pub/Sub Integration**: Reads from specified topic/subscription
- **BigQuery Output**: Writes to partitioned/clustered tables
- **GCS Output**: Structured folder format as required
- **Processing**: Transforms and enriches event data

## 🏗️ Architecture Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub        │    │   Cloud Build    │    │   GCP Project   │
│   Repository    │───▶│   CI/CD         │───▶│   Infrastructure │
└─────────────────┘    └──────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Event         │    │   Pub/Sub       │    │   Dataflow       │    │   BigQuery      │
│   Generator     │───▶│   Topic         │───▶│   Pipeline       │───▶│   Tables        │
│   (Cloud Run)   │    │                 │    │                  │    │                 │
└─────────────────┘    └─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │                       │
                                                        ▼                       ▼
                                               ┌─────────────────┐    ┌─────────────────┐
                                               │   Cloud Storage │    │   Cloud Function│
                                               │   (Raw Files)   │    │   (Auto Tables) │
                                               └─────────────────┘    └─────────────────┘
```

### Key Components:

- **Event Generator (Cloud Run)**: FastAPI service that generates realistic sample events for demonstration
- **Pub/Sub Topic**: Ingests events from generator and external sources
- **Cloud Function**: Automatically creates BigQuery tables based on event types
- **Dataflow Pipeline**: Processes events in real-time, writing to BigQuery and GCS
- **BigQuery Tables**: Partitioned and clustered tables for optimal analytics performance
- **Cloud Storage**: Raw event files organized by date hierarchy

## 🚀 Quick Start Deployment

### Prerequisites

1. **GCP Project** with billing enabled
2. **GitHub Repository** forked/cloned
3. **Service Account** with required permissions
4. **Local Tools** (optional for manual deployment):
   - Terraform >= 1.5.7
   - Google Cloud SDK
   - Docker

### 1. Setup GitHub Secrets

Navigate to your GitHub repository → Settings → Secrets and Variables → Actions

Add these secrets:

```
GCP_PROJECT_ID: your-gcp-project-id
GCP_SA_KEY: <service-account-json-key-content>
```

**Service Account Permissions Required**:
- Editor or Owner on the project
- Service Account Admin
- Cloud Build Service Account
- Dataflow Admin

### 2. Configure Project Settings

Update `terraform/terraform.tfvars`:

```hcl
project_id    = "your-gcp-project-id"
region        = "us-central1"
zone          = "us-central1-a"
alert_email   = "your-email@example.com"
environment   = "dev"

# Dataflow configuration
dataflow_machine_type = "n1-standard-2"
dataflow_max_workers  = 10
dataflow_num_workers  = 2
```

### 3. Deploy via GitHub Actions

**Option A: Automatic Deployment**
- Push to `main` or `dev` branch
- GitHub Actions will automatically deploy

**Option B: Manual Deployment**
- Go to Actions tab in GitHub
- Select "Deploy Real-time Data Pipeline Infrastructure"
- Click "Run workflow"
- Choose environment (dev/staging/prod)

### 4. Monitor Deployment

Check deployment progress:
1. **GitHub Actions**: View workflow execution
2. **GCP Console**: Monitor resource creation
3. **Terraform State**: Verify infrastructure

## 📦 Manual Deployment (Alternative)

If you prefer manual deployment or need to troubleshoot:

### Step 1: Deploy Infrastructure

```bash
# Clone repository
git clone <your-repo-url>
cd gcp-realtime-data-pipeline

# Configure GCP credentials
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 2: Deploy Cloud Function

```bash
# From project root
./scripts/deploy-cloud-function.sh YOUR_PROJECT_ID dev
```

### Step 3: Deploy Dataflow Template

```bash
# Build and deploy Dataflow template
./scripts/deploy-dataflow-template.sh YOUR_PROJECT_ID dev us-central1

# Deploy Dataflow job
cd terraform
terraform apply
```

### Step 4: Test the Pipeline

```bash
# Run integration tests
./scripts/test-table-creation.sh YOUR_PROJECT_ID dev
```

## 🎮 Event Generator Service

The Event Generator is a Cloud Run service that automatically generates realistic sample events for demonstrating the entire pipeline. It provides both REST API endpoints and predefined scenarios for different testing needs.

### Event Generator Features

- **Realistic Data**: Generates events that match exact BigQuery schemas
- **Rate Control**: Configurable events per minute and duration
- **Predefined Scenarios**: Ready-to-use demo configurations
- **Background Tasks**: Long-running generation with status tracking
- **Multiple Event Types**: Order, inventory, and user activity events

### Access the Event Generator

After deployment, the service is available at:
```bash
# Get service URL
gcloud run services describe dev-event-generator --region=us-central1 --format="value(status.url)"

# Or check Terraform outputs
cd terraform && terraform output event_generator_service_url
```

### API Endpoints

#### Health Check
```bash
curl https://YOUR_SERVICE_URL/health
```

#### Generate Single Events
```bash
# Generate a single order event
curl -X POST https://YOUR_SERVICE_URL/generate/single/order

# Generate inventory event
curl -X POST https://YOUR_SERVICE_URL/generate/single/inventory

# Generate user activity event  
curl -X POST https://YOUR_SERVICE_URL/generate/single/user_activity
```

#### Get Sample Events (No Publishing)
```bash
# Preview what an event looks like
curl https://YOUR_SERVICE_URL/sample/order
curl https://YOUR_SERVICE_URL/sample/inventory
curl https://YOUR_SERVICE_URL/sample/user_activity
```

#### Demo Scenarios

View all available scenarios:
```bash
curl https://YOUR_SERVICE_URL/scenarios
```

Start a predefined scenario:
```bash
# Quick demo (12 events in 1 minute)
curl -X POST https://YOUR_SERVICE_URL/scenarios/quick_sample/start

# Light demo (150 events in 5 minutes)
curl -X POST https://YOUR_SERVICE_URL/scenarios/light_demo/start

# Moderate load (600 events in 10 minutes)
curl -X POST https://YOUR_SERVICE_URL/scenarios/moderate_load/start

# Heavy load (1,800 events in 15 minutes)
curl -X POST https://YOUR_SERVICE_URL/scenarios/heavy_load/start

# Stress test (6,000 events in 10 minutes)
curl -X POST https://YOUR_SERVICE_URL/scenarios/stress_test/start
```

#### Monitor Running Tasks
```bash
# View all active generation tasks
curl https://YOUR_SERVICE_URL/generate/status

# Check specific task
curl https://YOUR_SERVICE_URL/generate/status/TASK_ID

# Stop specific task
curl -X DELETE https://YOUR_SERVICE_URL/generate/status/TASK_ID

# Stop all tasks
curl -X DELETE https://YOUR_SERVICE_URL/generate/stop
```

#### Custom Generation
```bash
# Generate custom batch
curl -X POST https://YOUR_SERVICE_URL/generate/batch \
  -H "Content-Type: application/json" \
  -d '{
    "events_per_minute": 60,
    "duration_minutes": 5,
    "event_types": ["order", "inventory", "user_activity"],
    "environment": "dev"
  }'

# Start custom continuous generation
curl -X POST https://YOUR_SERVICE_URL/generate/start \
  -H "Content-Type: application/json" \
  -d '{
    "events_per_minute": 120,
    "duration_minutes": 10,
    "event_types": ["order", "inventory"],
    "environment": "dev"
  }'
```

### Interactive API Documentation

The service provides interactive API documentation:
```bash
# OpenAPI/Swagger UI
https://YOUR_SERVICE_URL/docs

# OpenAPI JSON schema
https://YOUR_SERVICE_URL/openapi.json
```

### Recommended Demo Flow

1. **Start with health check**: Verify service is running
2. **Generate samples**: Preview event structures
3. **Run quick demo**: 1-minute test to verify pipeline
4. **Execute scenario**: Choose appropriate load for your demo
5. **Monitor progress**: Track events and processing
6. **Verify results**: Check BigQuery tables and GCS files

```bash
# Complete demo flow
SERVICE_URL="https://YOUR_SERVICE_URL"

# 1. Health check
curl $SERVICE_URL/health

# 2. Start light demo
TASK_RESPONSE=$(curl -X POST $SERVICE_URL/scenarios/light_demo/start)
TASK_ID=$(echo $TASK_RESPONSE | jq -r '.task_id')

# 3. Monitor progress
curl $SERVICE_URL/generate/status/$TASK_ID

# 4. Verify in BigQuery
bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM `YOUR_PROJECT.dev_events_dataset.orders`'
```

## 🧪 Testing the Solution

### Automated Testing

The solution includes comprehensive testing:

1. **Unit Tests**: Cloud Function logic
2. **Integration Tests**: End-to-end pipeline
3. **Performance Tests**: Load testing with 100+ events
4. **Monitoring Tests**: Verify all components are healthy

Run tests manually:

```bash
# Test table creation
./scripts/test-table-creation.sh YOUR_PROJECT_ID dev

# Or use GitHub Actions
# Go to Actions → "Test Data Pipeline" → Run workflow
```

### Manual Testing

#### 1. Publish Test Events

```bash
# Set topic name
TOPIC_NAME="dev-backend-events-topic"

# Order event
gcloud pubsub topics publish $TOPIC_NAME --message='{
  "event_type": "order",
  "order_id": "test-order-001",
  "customer_id": "customer-123",
  "order_date": "2024-01-15T10:30:00Z",
  "status": "pending",
  "items": [
    {
      "product_id": "prod-001",
      "product_name": "Test Product",
      "quantity": 2,
      "price": 29.99
    }
  ],
  "shipping_address": {
    "street": "123 Test St",
    "city": "Test City",
    "country": "US"
  },
  "total_amount": 59.98
}'

# Inventory event
gcloud pubsub topics publish $TOPIC_NAME --message='{
  "event_type": "inventory",
  "inventory_id": "inv-001",
  "product_id": "prod-001",
  "warehouse_id": "wh-us-central",
  "quantity_change": -2,
  "reason": "sale",
  "timestamp": "2024-01-15T10:35:00Z"
}'

# User activity event
gcloud pubsub topics publish $TOPIC_NAME --message='{
  "event_type": "user_activity",
  "user_id": "user-123",
  "activity_type": "view_product",
  "ip_address": "192.168.1.100",
  "user_agent": "Mozilla/5.0 Test Browser",
  "timestamp": "2024-01-15T10:40:00Z",
  "metadata": {
    "session_id": "sess-123",
    "platform": "web"
  }
}'
```

#### 2. Verify BigQuery Tables

```sql
-- Check created tables
SELECT table_name, creation_time, row_count
FROM `YOUR_PROJECT.dev_events_dataset.INFORMATION_SCHEMA.TABLES`
WHERE table_type = 'BASE_TABLE';

-- Query orders data
SELECT *
FROM `YOUR_PROJECT.dev_events_dataset.orders`
WHERE event_date = CURRENT_DATE()
ORDER BY order_date DESC
LIMIT 10;

-- Query inventory data
SELECT *
FROM `YOUR_PROJECT.dev_events_dataset.inventory`
WHERE event_date = CURRENT_DATE()
ORDER BY timestamp DESC
LIMIT 10;

-- Query user activity data
SELECT *
FROM `YOUR_PROJECT.dev_events_dataset.user_activity`
WHERE event_date = CURRENT_DATE()
ORDER BY timestamp DESC
LIMIT 10;
```

#### 3. Verify GCS Output

```bash
# Check GCS output structure
gsutil ls -r gs://YOUR_PROJECT-dev-raw-events/output/

# Example expected structure:
# gs://project-dev-raw-events/output/
# ├── order/2025/01/15/10/30/order_202501151030001.json
# ├── inventory/2025/01/15/10/35/inventory_202501151035001.json
# └── user_activity/2025/01/15/10/40/user_activity_202501151040001.json
```

#### 4. Monitor Dataflow Job

```bash
# Check job status
gcloud dataflow jobs list --region=us-central1

# View job details
JOB_ID=$(gcloud dataflow jobs list --region=us-central1 --filter="name:dev-realtime-data-pipeline" --format="value(id)" | head -1)
gcloud dataflow jobs show $JOB_ID --region=us-central1

# Monitor logs
gcloud dataflow jobs show $JOB_ID --region=us-central1 --format="table(currentState,currentStateTime)"
```

## 📊 Expected Results

After successful deployment and testing, you should see:

### 1. BigQuery Tables Created
- `dev_events_dataset.orders`
- `dev_events_dataset.inventory` 
- `dev_events_dataset.user_activity`

Each with:
- ✅ Daily partitioning by `event_date`
- ✅ Optimized clustering
- ✅ Proper schemas matching assessment requirements

### 2. GCS Folder Structure
```
gs://PROJECT-dev-raw-events/output/
├── order/
│   └── 2025/01/15/10/30/
│       └── order_202501151030001.json
├── inventory/
│   └── 2025/01/15/10/35/
│       └── inventory_202501151035001.json
└── user_activity/
    └── 2025/01/15/10/40/
        └── user_activity_202501151040001.json
```

### 3. Running Dataflow Job
- Status: `JOB_STATE_RUNNING`
- Processing events in real-time
- Writing to both BigQuery and GCS

### 4. Cloud Function Logs
- Tables created automatically based on event types
- Successful event processing logs
- Error handling for malformed events

## 🔍 Monitoring and Observability

### 1. Cloud Monitoring Dashboards

Access via GCP Console:
- **Dataflow**: Monitor job performance, throughput
- **Pub/Sub**: Message rates, subscription lag
- **BigQuery**: Query performance, storage usage
- **Cloud Functions**: Execution metrics, errors

### 2. Alerting

Automated alerts configured for:
- Pub/Sub undelivered messages (>100)
- BigQuery job failures
- Dataflow job state changes
- Cloud Function errors

### 3. Logging

Centralized logging:
```bash
# View Cloud Function logs
gcloud functions logs read dev-bigquery-table-manager --region=us-central1

# View Dataflow logs
gcloud dataflow jobs show JOB_ID --region=us-central1

# View Pub/Sub metrics
gcloud logging read "resource.type=pubsub_topic" --limit=50
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Permission Errors
```bash
# Grant required permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SERVICE_ACCOUNT_EMAIL" \
  --role="roles/editor"
```

#### 2. Dataflow Job Not Starting
- Check template exists in GCS
- Verify service account permissions
- Check quotas and billing

#### 3. Tables Not Created
- Check Cloud Function logs
- Verify Pub/Sub message format
- Check BigQuery permissions

#### 4. GCS Output Missing
- Check Dataflow job logs
- Verify bucket permissions
- Check pipeline windowing configuration

### Debug Commands

```bash
# Check infrastructure status
terraform show

# Verify Pub/Sub setup
gcloud pubsub topics list
gcloud pubsub subscriptions list

# Check BigQuery datasets
bq ls --project_id=PROJECT_ID

# Verify Cloud Function deployment
gcloud functions list

# Check Dataflow templates
gsutil ls gs://PROJECT-ENVIRONMENT-dataflow-templates/templates/
```

## 🚀 Production Deployment

For production deployment:

1. **Update Environment**: Change `environment = "prod"` in terraform.tfvars
2. **Resource Scaling**: Increase Dataflow workers and machine types
3. **Security**: Implement VPC, private IPs, encryption keys
4. **Monitoring**: Set up comprehensive alerting and dashboards
5. **Backup**: Configure cross-region backups
6. **Access Control**: Implement fine-grained IAM policies

### Production Configuration Example

```hcl
# terraform/terraform.tfvars (production)
project_id    = "your-prod-project-id"
region        = "us-central1"
zone          = "us-central1-a"
alert_email   = "alerts@yourcompany.com"
environment   = "prod"

# Production scaling
dataflow_machine_type = "n1-standard-4"
dataflow_max_workers  = 50
dataflow_num_workers  = 10
```

## 📝 Assessment Submission

For assessment submission, provide:

1. **GitHub Repository**: With complete codebase
2. **Live Demo**: Running infrastructure in GCP
3. **Documentation**: This deployment guide + data modeling doc
4. **Screenshots**: 
   - BigQuery tables with data
   - Dataflow job running
   - GCS folder structure
   - Cloud Function logs
5. **Test Results**: GitHub Actions test reports

### Demo Script

1. Show GitHub repository with CI/CD workflows
2. Demonstrate event publishing via gcloud
3. Show BigQuery tables with real data
4. Display GCS folder structure
5. Show Dataflow job monitoring
6. Run integration tests live

## 🎉 Success Criteria

Your deployment is successful when:

- ✅ All infrastructure deployed via Terraform
- ✅ Dataflow job running and processing events
- ✅ BigQuery tables auto-created with correct schemas
- ✅ GCS files organized in required folder structure
- ✅ Cloud Function creating tables dynamically
- ✅ End-to-end event processing working
- ✅ Monitoring and alerting configured
- ✅ GitHub Actions CI/CD pipeline operational
- ✅ Integration tests passing

This completes the Data Engineering Technical Assessment with a production-ready, scalable real-time data pipeline! 🚀 