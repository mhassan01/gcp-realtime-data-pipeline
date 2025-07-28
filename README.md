# GCP Real-Time Data Pipeline

A robust, cloud-native real-time data processing pipeline built on Google Cloud Platform that automatically creates BigQuery tables and processes streaming events with full automation via GitHub Actions.

## 🏗️ Architecture Overview

```
Event Generator (Cloud Run) → Pub/Sub Topic → Table Manager (Cloud Run) → BigQuery Tables
                                    ↓
                              Dataflow Job → Cloud Storage & BigQuery
```

### Core Components

- **Event Generator**: Cloud Run service that generates realistic test events
- **Pub/Sub Topic**: `backend-events-topic` - Single topic for all event types
- **Table Manager**: Cloud Run service that dynamically creates BigQuery tables
- **Dataflow Job**: Processes events and stores data in BigQuery and Cloud Storage
- **BigQuery Dataset**: `prod_events_dataset` with dynamically created tables
- **Cloud Storage**: Stores processed event data

## 🚀 Quick Start

### Prerequisites

1. **GCP Project**: Active Google Cloud Project with billing enabled
2. **GitHub Repository**: Fork this repository
3. **Service Account**: GitHub Actions service account with appropriate permissions

### Deployment

The entire pipeline deploys automatically via GitHub Actions:

```bash
# Trigger deployment by pushing to main branch
git push origin main
```

The deployment workflow will:
1. 🧹 **Complete Environment Cleanup** - Remove all existing resources
2. 🏗️ **Fresh Infrastructure Deployment** - Deploy via Terraform
3. 📦 **Application Deployment** - Deploy Cloud Run services
4. ✅ **Verification** - Test all components
5. 🧪 **Integration Testing** - End-to-end data flow verification

## 📋 Components Detail

### 1. Infrastructure (Terraform)

**Location**: `terraform/`

**Resources Created**:
- Service Accounts with proper IAM roles
- Pub/Sub topic: `backend-events-topic`
- Pub/Sub subscription: `backend-events-topic-sub`  
- BigQuery dataset: `prod_events_dataset`
- Cloud Storage bucket for Dataflow templates
- IAM permissions and role bindings

### 2. Event Generator

**Location**: `cloud-functions/event-generator/`

**Features**:
- FastAPI-based Cloud Run service
- Generates realistic events for testing
- Health checks: `/health`, `/readiness`, `/liveness`
- Lazy initialization for optimal startup
- Publishes to `backend-events-topic`

**Event Types Generated**:
- `order` - E-commerce order events
- `inventory` - Inventory management events  
- `user_activity` - User behavior tracking

### 3. Table Manager

**Location**: `cloud-functions/table-manager/`

**Features**:
- FastAPI-based Cloud Run service
- Triggered by Eventarc on Pub/Sub messages
- Dynamically creates BigQuery tables based on event schema
- Handles schema evolution automatically
- Creates tables: `orders`, `inventory`, `user_activity`

### 4. Dataflow Job

**Location**: `dataflow/`

**Capabilities**:
- Real-time stream processing
- Dual output to BigQuery and Cloud Storage
- Automatic scaling based on load
- Error handling and dead letter queues

## 🎯 Event Schema

### Order Events
```json
{
  "event_type": "order",
  "order_id": "order-123",
  "customer_id": "customer-456", 
  "order_date": "2024-01-15T10:30:00Z",
  "status": "pending",
  "items": [...],
  "total_amount": 99.99,
  "currency": "USD",
  "event_date": "2024-01-15"
}
```

### Inventory Events
```json
{
  "event_type": "inventory",
  "inventory_id": "inv-123",
  "product_id": "prod-456",
  "quantity_change": -5,
  "warehouse_id": "wh-us-central",
  "reason": "sale",
  "timestamp": "2024-01-15T10:35:00Z",
  "event_date": "2024-01-15"
}
```

### User Activity Events
```json
{
  "event_type": "user_activity",
  "user_id": "user-123",
  "session_id": "sess-456",
  "activity_type": "page_view",
  "page_url": "/products/prod-789",
  "timestamp": "2024-01-15T10:40:00Z",
  "event_date": "2024-01-15"
}
```

## 🧪 Testing

### Manual Testing

Test individual components:

```bash
# Test Event Generator health
curl https://prod-event-generator-[hash]-uc.a.run.app/health

# Test Table Manager health  
curl https://prod-table-manager-[hash]-uc.a.run.app/health

# Generate test events
curl -X POST https://prod-event-generator-[hash]-uc.a.run.app/generate/order
```

### Integration Testing

Run the comprehensive integration test:

```bash
./scripts/test-table-creation.sh [PROJECT_ID] [ENVIRONMENT]
```

This test:
- Publishes sample events to `backend-events-topic`
- Verifies table creation in BigQuery
- Tests end-to-end data flow

### Verify BigQuery Tables

```bash
# List created tables
bq ls prod_events_dataset

# Query table data
bq query --use_legacy_sql=false 'SELECT * FROM `PROJECT_ID.prod_events_dataset.orders` LIMIT 5'
```

## 📊 Monitoring & Observability

### Cloud Run Services
- **Event Generator**: `prod-event-generator`
- **Table Manager**: `prod-table-manager`

### Key Metrics to Monitor
- Pub/Sub message throughput
- Cloud Run request latency and error rates
- BigQuery job execution times
- Dataflow job lag and throughput

### Logs
```bash
# Event Generator logs
gcloud run services logs read prod-event-generator --region=us-central1

# Table Manager logs  
gcloud run services logs read prod-table-manager --region=us-central1

# Dataflow job logs
gcloud dataflow jobs list --region=us-central1
```

## 🔧 Configuration

### Environment Variables

**GitHub Actions Secrets Required**:
- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Service account key JSON

**Key Configuration**:
- **Region**: `us-central1`
- **Topic**: `backend-events-topic`
- **Subscription**: `backend-events-topic-sub`
- **Dataset**: `prod_events_dataset`

## 🛠️ Development

### Local Development

1. **Set up environment**:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account.json"
export GCP_PROJECT_ID="your-project-id"
```

2. **Install dependencies**:
```bash
cd cloud-functions/event-generator
pip install -r requirements.txt

cd ../table-manager  
pip install -r requirements.txt
```

3. **Run locally**:
```bash
# Event Generator
uvicorn main:app --reload --port 8080

# Table Manager
uvicorn main:app --reload --port 8081
```

### Deployment Scripts

- `scripts/cleanup-environment.sh` - Complete environment cleanup
- `scripts/deploy-cloud-function.sh` - Deploy Table Manager
- `scripts/deploy-event-generator.sh` - Deploy Event Generator
- `scripts/test-table-creation.sh` - Integration testing

## 🚨 Troubleshooting

### Common Issues

1. **Topic Not Found Error**
   - Verify topic name is `backend-events-topic` (no environment prefix)
   - Check Terraform deployment completed successfully

2. **Cloud Run Startup Failures**  
   - Check container health endpoints
   - Verify environment variables and IAM permissions
   - Review Cloud Run logs for detailed errors

3. **BigQuery Table Creation Issues**
   - Verify Table Manager has BigQuery permissions
   - Check Eventarc trigger is properly configured
   - Ensure events have correct `event_type` field

4. **Dataflow Job Failures**
   - Check template exists in Cloud Storage
   - Verify IAM permissions for Dataflow service account
   - Review job logs for specific error messages

### Debug Commands

```bash
# Check Pub/Sub topic
gcloud pubsub topics describe backend-events-topic

# Verify Cloud Run services
gcloud run services list --region=us-central1

# Check Eventarc triggers
gcloud eventarc triggers list --location=us-central1

# Test Pub/Sub publishing
gcloud pubsub topics publish backend-events-topic --message='{"event_type":"order","test":true}'
```

## 🔒 Security

- All services use dedicated service accounts with minimal required permissions
- Cloud Run services are not publicly accessible except via proper authentication
- Secrets are managed via GitHub Actions secrets and GCP Secret Manager
- Network security follows GCP best practices

## 📈 Scaling

The pipeline automatically scales based on:
- **Pub/Sub**: Automatically scales subscription processing
- **Cloud Run**: Auto-scales based on request volume (0-1000 instances)
- **Dataflow**: Auto-scales workers based on message backlog
- **BigQuery**: Serverless, scales automatically

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request

All changes trigger automatic deployment and testing via GitHub Actions.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**🎉 Ready to process real-time events at scale!**

For questions or support, please open an issue in the GitHub repository.
