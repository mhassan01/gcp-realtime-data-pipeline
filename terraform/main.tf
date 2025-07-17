terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  # backend "gcs" {
  #   bucket = "terraform-state-fabled-web-172810"
  #   prefix = "data-pipeline/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Create terraform state bucket first
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

# Service Account for Dataflow
resource "google_service_account" "dataflow_sa" {
  account_id   = "${var.environment}-dataflow-pipeline-sa"
  display_name = "Dataflow Pipeline Service Account (${var.environment})"

  depends_on = [google_project_service.apis]
}

# IAM roles for Dataflow service account
# NOTE: Commented out due to IAM permission requirements for demo
# Run these commands manually after terraform apply:
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-dataflow-pipeline-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/dataflow.worker"
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-dataflow-pipeline-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/bigquery.dataEditor"
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-dataflow-pipeline-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/storage.objectAdmin"
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-dataflow-pipeline-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/pubsub.subscriber"

# resource "google_project_iam_member" "dataflow_permissions" {
#   for_each = toset([
#     "roles/dataflow.worker",
#     "roles/bigquery.dataEditor",
#     "roles/storage.objectAdmin",
#     "roles/pubsub.subscriber"
#   ])
#
#   project = var.project_id
#   role    = each.value
#   member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
#
#   depends_on = [google_service_account.dataflow_sa]
# }

# Dead Letter Topic (created first as it's referenced by subscription)
resource "google_pubsub_topic" "dead_letter" {
  name = "${var.environment}-backend-events-dead-letter"

  depends_on = [google_project_service.apis]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "dead-letter"
  }
}

# Pub/Sub Topic
resource "google_pubsub_topic" "backend_events" {
  name = "${var.environment}-backend-events-topic"

  depends_on = [google_project_service.apis]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "events"
  }
}

# Pub/Sub Subscription for Dataflow
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

# Cloud Storage bucket for raw events
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

# Cloud Storage bucket for Dataflow temp files
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

# BigQuery dataset
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

# BigQuery tables will be created dynamically by Cloud Function

# Cloud Storage bucket for Dataflow templates
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

# Service Account for Cloud Function
resource "google_service_account" "table_manager_sa" {
  account_id   = "${var.environment}-table-manager-sa"
  display_name = "BigQuery Table Manager Service Account (${var.environment})"

  depends_on = [google_project_service.apis]
}

# IAM roles for Table Manager service account
# NOTE: Commented out due to IAM permission requirements for demo
# Run these commands manually after terraform apply:
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-table-manager-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/bigquery.admin"
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-table-manager-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/logging.logWriter"
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-table-manager-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/cloudsql.client"

# resource "google_project_iam_member" "table_manager_permissions" {
#   for_each = toset([
#     "roles/bigquery.admin",
#     "roles/logging.logWriter",
#     "roles/cloudsql.client"
#   ])
#
#   project = var.project_id
#   role    = each.value
#   member  = "serviceAccount:${google_service_account.table_manager_sa.email}"
#
#   depends_on = [google_service_account.table_manager_sa]
# }

# Cloud Storage bucket for Cloud Function source code
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

# Cloud Function for table management
resource "google_cloudfunctions2_function" "table_manager" {
  name     = "${var.environment}-bigquery-table-manager"
  location = var.region

  build_config {
    runtime     = "python311"
    entry_point = "create_table"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "table-manager-source.zip"
      }
    }
  }

  service_config {
    max_instance_count    = 10
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.table_manager_sa.email

    environment_variables = {
      PROJECT_ID  = var.project_id
      DATASET_ID  = google_bigquery_dataset.events_dataset.dataset_id
      ENVIRONMENT = var.environment
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.backend_events.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }

  depends_on = [
    google_project_service.apis,
    google_service_account.table_manager_sa,
    google_storage_bucket.function_source
  ]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "table-management"
  }
}

# Dataflow job for streaming pipeline
resource "google_dataflow_job" "streaming_pipeline" {
  name              = "${var.environment}-realtime-data-pipeline"
  template_gcs_path = "gs://${google_storage_bucket.dataflow_templates.name}/templates/streaming-pipeline.json"
  temp_gcs_location = "gs://${google_storage_bucket.dataflow_temp.name}/temp"
  region            = var.region
  zone              = var.zone

  parameters = {
    inputSubscription = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.backend_events_sub.name}"
    outputDataset     = google_bigquery_dataset.events_dataset.dataset_id
    outputGcsPrefix   = "gs://${google_storage_bucket.raw_events.name}/output"
    project           = var.project_id
    region            = var.region
    environment       = var.environment
  }

  # Dataflow job configuration
  machine_type            = var.dataflow_machine_type
  max_workers             = var.dataflow_max_workers
  service_account_email   = google_service_account.dataflow_sa.email
  network                 = "default"
  subnetwork              = "regions/${var.region}/subnetworks/default"
  ip_configuration        = "WORKER_IP_PUBLIC"
  enable_streaming_engine = true
  on_delete               = "cancel"

  depends_on = [
    google_project_service.apis,
    google_service_account.dataflow_sa,
    google_pubsub_subscription.backend_events_sub,
    google_bigquery_dataset.events_dataset,
    google_storage_bucket.raw_events,
    google_storage_bucket.dataflow_temp,
    google_storage_bucket.dataflow_templates
  ]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "streaming-pipeline"
    assessment  = "data-engineering"
  }
}

# Service Account for Event Generator Cloud Run
resource "google_service_account" "event_generator_sa" {
  account_id   = "${var.environment}-event-generator-sa"
  display_name = "Event Generator Service Account (${var.environment})"

  depends_on = [google_project_service.apis]
}

# IAM roles for Event Generator service account
# NOTE: Commented out due to IAM permission requirements for demo
# Run these commands manually after terraform apply:
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-event-generator-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/pubsub.publisher"
#   gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:dev-event-generator-sa@PROJECT_ID.iam.gserviceaccount.com" --role="roles/logging.logWriter"

# resource "google_project_iam_member" "event_generator_permissions" {
#   for_each = toset([
#     "roles/pubsub.publisher",
#     "roles/logging.logWriter"
#   ])
#
#   project = var.project_id
#   role    = each.value
#   member  = "serviceAccount:${google_service_account.event_generator_sa.email}"
#
#   depends_on = [google_service_account.event_generator_sa]
# }

# Cloud Run service for event generator
resource "google_cloud_run_v2_service" "event_generator" {
  name     = "${var.environment}-event-generator"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.event_generator_sa.email

    containers {
      image = "gcr.io/${var.project_id}/${var.environment}-event-generator:latest"

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

      ports {
        container_port = 8080
      }

      startup_probe {
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
        http_get {
          path = "/health"
          port = 8080
        }
      }

      liveness_probe {
        timeout_seconds   = 3
        period_seconds    = 30
        failure_threshold = 3
        http_get {
          path = "/health"
          port = 8080
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    timeout = "900s"
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.apis,
    google_service_account.event_generator_sa
  ]

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "event-generator"
  }
}

# Allow unauthenticated invocations to Cloud Run service
resource "google_cloud_run_service_iam_member" "event_generator_noauth" {
  location = google_cloud_run_v2_service.event_generator.location
  service  = google_cloud_run_v2_service.event_generator.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Note: Monitoring and alerting removed for demo simplicity
# Can be added back when proper IAM permissions are configured