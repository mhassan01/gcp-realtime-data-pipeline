# Real-time Data Pipeline Infrastructure
# 
# This Terraform configuration creates the core infrastructure for a GCP real-time data pipeline.
# IAM roles and application deployments (Cloud Function, Cloud Run, Dataflow jobs) are handled
# by deployment scripts to avoid dependency issues with source code and Docker images.
#
# Deploy order: 1) terraform apply, 2) run IAM script, 3) deploy applications

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Terraform state bucket
resource "google_storage_bucket" "terraform_state" {
  name     = "terraform-state-${var.project_id}"
  location = var.region

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  public_access_prevention = "enforced"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "terraform-state"
  }
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "pubsub.googleapis.com",
    "dataflow.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com"
  ])
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Service Accounts
resource "google_service_account" "dataflow_sa" {
  account_id   = "${var.environment}-dataflow-pipeline-sa"
  display_name = "Dataflow Pipeline Service Account (${var.environment})"

  depends_on = [google_project_service.apis]
}

resource "google_service_account" "table_manager_sa" {
  account_id   = "${var.environment}-table-manager-sa"
  display_name = "BigQuery Table Manager Service Account (${var.environment})"

  depends_on = [google_project_service.apis]
}

resource "google_service_account" "event_generator_sa" {
  account_id   = "${var.environment}-event-generator-sa"
  display_name = "Event Generator Service Account (${var.environment})"

  depends_on = [google_project_service.apis]
}

# Pub/Sub Topics and Subscriptions
resource "google_pubsub_topic" "dead_letter" {
  name = "${var.environment}-backend-events-dead-letter"

  depends_on = [google_project_service.apis]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "dead-letter"
  }
}

resource "google_pubsub_topic" "backend_events" {
  name = "${var.environment}-backend-events-topic"

  depends_on = [google_project_service.apis]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "events"
  }
}

resource "google_pubsub_subscription" "backend_events_sub" {
  name  = "${var.environment}-backend-events-subscription"
  topic = google_pubsub_topic.backend_events.name

  ack_deadline_seconds = 600

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "dataflow-subscription"
  }
}

# Cloud Storage Buckets
resource "google_storage_bucket" "raw_events" {
  name     = "${var.project_id}-${var.environment}-raw-events"
  location = var.region

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.apis]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "raw-events"
  }
}

resource "google_storage_bucket" "dataflow_temp" {
  name     = "${var.project_id}-${var.environment}-dataflow-temp"
  location = var.region

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.apis]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "dataflow-temp"
  }
}

resource "google_storage_bucket" "dataflow_templates" {
  name     = "${var.project_id}-${var.environment}-dataflow-templates"
  location = var.region

  uniform_bucket_level_access = true

  depends_on = [google_project_service.apis]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "dataflow-templates"
  }
}

resource "google_storage_bucket" "function_source" {
  name     = "${var.project_id}-${var.environment}-function-source"
  location = var.region

  uniform_bucket_level_access = true

  depends_on = [google_project_service.apis]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "cloud-function-source"
  }
}

# BigQuery Dataset
resource "google_bigquery_dataset" "events_dataset" {
  dataset_id    = "${var.environment}_events_dataset"
  friendly_name = "Events Dataset (${var.environment})"
  description   = "Dataset for storing processed events"
  location      = var.region

  default_table_expiration_ms = 7776000000 # 90 days

  access {
    role          = "OWNER"
    user_by_email = google_service_account.dataflow_sa.email
  }

  depends_on = [google_project_service.apis, google_service_account.dataflow_sa]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "events-data"
  }
}

# Note: IAM roles are assigned via scripts/assign-iam-roles.sh
# Note: Applications (Cloud Function, Cloud Run, Dataflow) deployed via scripts