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

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "pubsub.googleapis.com",
    "dataflow.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com"
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

# Eventarc Trigger for Table Manager Cloud Run Service
resource "google_eventarc_trigger" "table_manager_trigger" {
  name     = "${var.environment}-table-manager-trigger"
  location = var.region
  project  = var.project_id

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  destination {
    cloud_run_service {
      service = "${var.environment}-table-manager"
      region  = var.region
    }
  }

  transport {
    pubsub {
      topic = google_pubsub_topic.backend_events.id
    }
  }

  service_account = google_service_account.eventarc_trigger_sa.email

  depends_on = [
    google_project_service.apis,
    google_service_account.eventarc_trigger_sa
  ]
}

# Service Account for the Eventarc Trigger itself
resource "google_service_account" "eventarc_trigger_sa" {
  account_id   = "${var.environment}-eventarc-trigger-sa"
  display_name = "Eventarc Trigger Service Account (${var.environment})"
  project      = var.project_id
}

# Grant Eventarc SA permission to receive events from Pub/Sub
resource "google_project_iam_member" "eventarc_sa_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = format("serviceAccount:%s", google_service_account.eventarc_trigger_sa.email)
}

# Grant Eventarc SA permission to invoke the Cloud Run service
resource "google_project_iam_member" "eventarc_sa_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = format("serviceAccount:%s", google_service_account.eventarc_trigger_sa.email)
}