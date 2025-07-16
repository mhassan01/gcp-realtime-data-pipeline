# Real-time Data Pipeline 

A comprehensive, production-ready real-time data pipeline solution built on Google Cloud Platform that demonstrates enterprise-grade event processing, dynamic table management, and scalable analytics capabilities.

## 🎯 Overview


- **Task 1**: Complete data modeling with BigQuery DDL statements and optimized partitioning/clustering strategies
- **Task 2**: Real-time streaming pipeline using Apache Beam/Dataflow with dual output to BigQuery and GCS
- **Bonus**: Event Generator service for comprehensive demonstration and testing

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Event         │    │   Pub/Sub       │    │   Dataflow       │    │   BigQuery      │
│   Generator     │───▶│   Topic         │───▶│   Pipeline       │───▶│   Tables        │
│   (Cloud Run)   │    │                 │    │   (Apache Beam)  │    │   (Partitioned) │
└─────────────────┘    └─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐      ┌─────────────────┐
                       │   Cloud         │      │   Cloud Storage │
                       │   Function      │      │   (Raw Events)  │
                       │   (Auto Tables) │      │   YYYY/MM/DD/HH │
                       └─────────────────┘      └─────────────────┘
```
### Core Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Event Generator** | Cloud Run + FastAPI | Generates realistic sample events for demonstration |
| **Event Ingestion** | Pub/Sub | Scalable event streaming and distribution |
| **Table Management** | Cloud Functions | Dynamic BigQuery table creation based on event types |
| **Stream Processing** | Dataflow (Apache Beam) | Real-time event processing and transformation |
| **Data Warehouse** | BigQuery | Partitioned/clustered tables for analytics |
| **Raw Storage** | Cloud Storage | Structured event files by date hierarchy |
| **Infrastructure** | Terraform | Infrastructure as Code for reproducible deployments |
| **CI/CD** | GitHub Actions | Automated testing and deployment pipeline |

## 🚀 Quick Start

### 1. Prerequisites
- **GCP Project** with billing enabled
- **GitHub Repository** (fork this repo)
- **Service Account** with Editor/Owner permissions
- **Terraform** >= 1.0
- **Google Cloud SDK** installed

### 2. Deploy via GitHub Actions (Recommended)
1. **Configure Secrets** in your GitHub repository:
   ```
   GCP_PROJECT_ID: your-project-id
   GCP_SA_KEY: <service-account-json-key>
   ```

2. **Update Configuration**:
   ```bash
   # Edit terraform/terraform.tfvars
   project_id  = "your-project-id"
   region      = "us-central1"
   alert_email = "your-email@example.com"
   environment = "dev"
   ```

3. **Deploy**:
   - Push to `main` branch for automatic deployment
   - Or manually trigger via GitHub Actions → "Deploy Infrastructure"

### 3. Alternative: Manual Deployment
```bash
# Clone and navigate
git clone <your-repo-url>
cd gcp-realtime-data-pipeline

# Configure GCP
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# Deploy components
../scripts/deploy-cloud-function.sh YOUR_PROJECT_ID dev
../scripts/deploy-event-generator.sh YOUR_PROJECT_ID dev
../scripts/deploy-dataflow-template.sh YOUR_PROJECT_ID dev us-central1
```

## 🎮 Event Generator Service

The **Event Generator** is a Cloud Run service that automatically creates realistic sample events for demonstrating the pipeline.

### Features
- ✅ **10 Predefined Scenarios** (quick demo to stress test)
- ✅ **Custom Rate Control** (events per minute, duration)
- ✅ **Multiple Event Types** (order, inventory, user_activity)
- ✅ **REST API** with OpenAPI documentation
- ✅ **Background Tasks** with progress monitoring
- ✅ **Schema Compliance** with exact BigQuery table schemas

### Quick Demo
```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe dev-event-generator --region=us-central1 --format="value(status.url)")

# Health check
curl $SERVICE_URL/health

# Start light demo (150 events in 5 minutes)
curl -X POST $SERVICE_URL/scenarios/light_demo/start

# Monitor progress
curl $SERVICE_URL/generate/status

# API documentation
open $SERVICE_URL/docs
```

### Available Scenarios
| Scenario | Events | Duration | Use Case |
|----------|--------|----------|----------|
| `quick_sample` | 12 | 1 min | Pipeline verification |
| `light_demo` | 150 | 5 min | Basic demonstration |
| `moderate_load` | 600 | 10 min | Standard demo |
| `heavy_load` | 1,800 | 15 min | High throughput test |
| `burst_test` | 900 | 3 min | Traffic spike simulation |
| `stress_test` | 6,000 | 10 min | Maximum load testing |

## 📊 Data Model & Analytics

### Event Types & Tables

| Event Type | BigQuery Table | Schema Fields | Clustering |
|------------|----------------|---------------|------------|
| **order** | `orders` | order_id, customer_id, items[], total_amount | customer_id, status |
| **inventory** | `inventory` | product_id, warehouse_id, quantity_change | product_id, warehouse_id |
| **user_activity** | `user_activity` | user_id, activity_type, metadata{} | user_id, activity_type |

### Performance Optimizations
- **Daily Partitioning** by `event_date` for cost efficiency
- **Strategic Clustering** for common query patterns
- **Nested Records** for related data (items, addresses, metadata)
- **Data Types** optimized for analytics and storage

### Sample Analytics Queries
```sql
-- Customer order analysis
SELECT 
  customer_id,
  COUNT(*) as order_count,
  SUM(total_amount) as total_value
FROM `PROJECT.dev_events_dataset.orders`
WHERE event_date >= CURRENT_DATE() - 30
GROUP BY customer_id
ORDER BY total_value DESC;

-- Inventory movement analysis
SELECT 
  warehouse_id,
  product_id,
  SUM(quantity_change) as net_change,
  COUNT(*) as transaction_count
FROM `PROJECT.dev_events_dataset.inventory`
WHERE event_date = CURRENT_DATE()
GROUP BY warehouse_id, product_id;

-- User activity funnel
SELECT 
  activity_type,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_id) as unique_users
FROM `PROJECT.dev_events_dataset.user_activity`
WHERE event_date >= CURRENT_DATE() - 7
GROUP BY activity_type
ORDER BY event_count DESC;
```

## 🔧 Development & Customization

### Adding New Event Types
1. **Update Cloud Function**:
   ```python
   # In cloud-functions/table-manager/main.py
   table_mapping = {
       'order': 'orders',
       'inventory': 'inventory',
       'user_activity': 'user_activity',
       'new_event': 'new_table'  # Add here
   }
   ```

2. **Define Schema**:
   ```python
   # In cloud-functions/table-manager/table_schemas.py
   def get_new_table_schema():
       return [
           bigquery.SchemaField("event_type", "STRING", mode="REQUIRED"),
           # Add your fields here
       ]
   ```

 3. **Update Event Generator**:
    ```python
    # In cloud-functions/event-generator/main.py
    def generate_new_event(self) -> Dict[str, Any]:
        # Implement event generation logic
    ```

4. **Redeploy**:
   ```bash
   ./scripts/deploy-cloud-function.sh PROJECT_ID dev
   ./scripts/deploy-event-generator.sh PROJECT_ID dev
   ```

### Local Development
```bash
# Test Cloud Function locally
cd cloud-functions/table-manager
pip install -r requirements.txt
functions-framework --target=create_table --debug

 # Test Event Generator locally
 cd cloud-functions/event-generator
 pip install -r requirements.txt
 uvicorn main:app --reload
```

## 🔍 Monitoring & Observability

### Built-in Monitoring
- **Email Alerts**: Pub/Sub backlogs, BigQuery job failures
- **Cloud Monitoring**: Dataflow metrics, Cloud Run performance
- **Logging**: Comprehensive logging across all components
- **Health Checks**: Automated service health verification

### Key Metrics to Monitor
- **Event Processing Rate**: Events per minute through pipeline
- **Pipeline Latency**: Time from Pub/Sub to BigQuery
- **Table Creation**: Automatic table creation success rate
- **Storage Costs**: BigQuery storage and query costs
- **Error Rates**: Failed events and processing errors

### Debugging Commands
```bash
# Cloud Function logs
gcloud functions logs read dev-bigquery-table-manager --region=us-central1

# Dataflow job status
gcloud dataflow jobs list --region=us-central1

# Event Generator logs
gcloud logs tail dev-event-generator --region=us-central1

# BigQuery job history
bq ls -j --max_results=10
```

## 📁 Project Structure

```
gcp-realtime-data-pipeline/
├── 📁 terraform/                    # Infrastructure as Code
│   ├── main.tf                     # Core infrastructure resources
│   ├── variables.tf                # Variable definitions
│   ├── outputs.tf                  # Output values and URLs
│   └── terraform.tfvars            # Configuration values
├── 📁 cloud-functions/             # Serverless functions
│   ├── table-manager/              # BigQuery table management
│   │   ├── main.py                 # Event-driven table creation
│   │   ├── table_schemas.py        # BigQuery schema definitions
│   │   └── requirements.txt        # Python dependencies
│   └── event-generator/            # Demo event generation service
│       ├── main.py                 # FastAPI service
│       ├── demo_scenarios.py       # Predefined demo scenarios
│       ├── Dockerfile              # Container configuration
│       └── requirements.txt        # Python dependencies
├── 📁 dataflow-pipeline/           # Apache Beam streaming pipeline
│   ├── streaming_pipeline.py       # Main pipeline logic
│   ├── Dockerfile                  # Dataflow template container
│   └── requirements.txt            # Pipeline dependencies
├── 📁 scripts/                     # Deployment automation
│   ├── deploy-cloud-function.sh    # Cloud Function deployment
│   ├── deploy-event-generator.sh   # Event Generator deployment
│   ├── deploy-dataflow-template.sh # Dataflow template build
│   └── test-table-creation.sh      # Integration testing
├── 📁 .github/workflows/           # CI/CD automation
│   ├── deploy-infrastructure.yml   # Main deployment pipeline
│   └── test-pipeline.yml          # Comprehensive testing
├── 📁 docs/                        # Comprehensive documentation
│   ├── deployment-guide.md         # Detailed deployment instructions
│   └── task1-data-modeling.md      # Data architecture documentation
└── README.md                       # This file
```

## 🔒 Security & Best Practices

### Security Features
- **Least Privilege IAM**: Minimal required permissions for each service account
- **Encryption**: All data encrypted at rest and in transit
- **Network Security**: Private service communication within GCP
- **Secret Management**: Secure handling of credentials and API keys
- **Resource Isolation**: Environment-based resource separation

### Cost Optimization
- **Partitioned Tables**: Query only necessary date ranges
- **Clustered Storage**: Optimized data layout for common queries
- **Lifecycle Policies**: Automatic cleanup of old data (90 days)
- **Serverless Architecture**: Pay-per-use scaling with Cloud Run and Functions
- **Resource Tagging**: Complete labeling for cost tracking and management

### Scalability Considerations
- **Auto-scaling**: All services scale automatically based on load
- **Streaming Architecture**: Real-time processing without batch limitations
- **Distributed Processing**: Dataflow handles large-scale parallel processing
- **Multi-region Support**: Can be deployed across multiple GCP regions
- **Schema Evolution**: Backward-compatible schema changes supported

## 📖 Documentation

| Document | Description |
|----------|-------------|
| **[Deployment Guide](docs/deployment-guide.md)** | Comprehensive deployment instructions with Event Generator API |
| **[Data Modeling](docs/task1-data-modeling.md)** | Complete data architecture and DDL statements |
| **[API Documentation](https://YOUR_SERVICE_URL/docs)** | Interactive Event Generator API documentation |

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/new-feature`
3. **Test** locally and ensure all tests pass
4. **Commit** changes: `git commit -am 'Add new feature'`
5. **Push** to branch: `git push origin feature/new-feature`
6. **Submit** a Pull Request

## 📊 Assessment Deliverables

### ✅ Task 1: Data Modeling
- **Complete DDL statements** for all table types
- **Partitioning strategy** (daily by event_date)
- **Clustering optimization** for query performance
- **Data architecture documentation** with rationale

### ✅ Task 2: Streaming Pipeline
- **Apache Beam/Dataflow** real-time processing
- **Dual output** to BigQuery (analytics) and GCS (raw files)
- **Exact GCS structure**: `output/event_type/YYYY/MM/DD/HH/MM/filename.json`
- **Error handling** and monitoring

### ✅ Bonus Features
- **Event Generator service** for comprehensive demonstration
- **CI/CD pipeline** with automated testing
- **Infrastructure as Code** with Terraform
- **Production-ready monitoring** and alerting
- **Comprehensive documentation** and examples

## 🆘 Support & Troubleshooting

### Common Issues
1. **Permission Errors**: Ensure service account has required IAM roles
2. **API Enablement**: Check that all required GCP APIs are enabled
3. **Resource Quotas**: Verify GCP quotas for compute and storage resources
4. **Network Issues**: Ensure proper VPC and firewall configurations

### Getting Help
- **GitHub Issues**: Report bugs or request features
- **Documentation**: Check the comprehensive deployment guide
- **GCP Console**: Monitor resources and view detailed error logs
- **Cloud Monitoring**: Set up custom dashboards for operational insights

---

**Built for Data Engineering Excellence** 🚀  
*Demonstrating enterprise-grade real-time data processing capabilities on Google Cloud Platform*
