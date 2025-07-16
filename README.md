# Real-time Data Pipeline 

A comprehensive, production-ready real-time data pipeline solution built on Google Cloud Platform that demonstrates enterprise-grade event processing, dynamic table management, and scalable analytics capabilities.

## 🎯 Overview

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