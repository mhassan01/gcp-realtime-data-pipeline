# Infrastructure Outputs

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "environment" {
  description = "Environment"
  value       = var.environment
}

# Service Account Outputs
output "dataflow_service_account_email" {
  description = "Email of the Dataflow service account"
  value       = google_service_account.dataflow_sa.email
}

output "table_manager_service_account_email" {
  description = "Email of the Table Manager service account"
  value       = google_service_account.table_manager_sa.email
}

output "event_generator_service_account_email" {
  description = "Email of the Event Generator service account"
  value       = google_service_account.event_generator_sa.email
}

# Storage Outputs
output "raw_events_bucket_name" {
  description = "Name of the raw events storage bucket"
  value       = google_storage_bucket.raw_events.name
}

output "dataflow_temp_bucket_name" {
  description = "Name of the Dataflow temp storage bucket"
  value       = google_storage_bucket.dataflow_temp.name
}

output "dataflow_templates_bucket_name" {
  description = "Name of the Dataflow templates storage bucket"
  value       = google_storage_bucket.dataflow_templates.name
}

output "function_source_bucket_name" {
  description = "Name of the Cloud Function source storage bucket"
  value       = google_storage_bucket.function_source.name
}

# Pub/Sub Outputs
output "pubsub_topic_name" {
  description = "Name of the Pub/Sub topic for backend events"
  value       = google_pubsub_topic.backend_events.name
}

output "pubsub_subscription_name" {
  description = "Name of the Pub/Sub subscription for Dataflow"
  value       = google_pubsub_subscription.backend_events_sub.name
}

output "dead_letter_topic_name" {
  description = "Name of the dead letter topic"
  value       = google_pubsub_topic.dead_letter.name
}

# BigQuery Outputs
output "bigquery_dataset_id" {
  description = "ID of the BigQuery dataset for events"
  value       = google_bigquery_dataset.events_dataset.dataset_id
}

output "bigquery_dataset_location" {
  description = "Location of the BigQuery dataset"
  value       = google_bigquery_dataset.events_dataset.location
}

# Application Resources Deployed via Scripts:
# - Cloud Function: deploy-cloud-function.sh
# - Event Generator: deploy-event-generator.sh  
# - Dataflow Job: deploy-dataflow-template.sh 