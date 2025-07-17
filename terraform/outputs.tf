output "pubsub_topic_name" {
  description = "Name of the Pub/Sub topic"
  value       = google_pubsub_topic.backend_events.name
}

output "pubsub_subscription_name" {
  description = "Name of the Pub/Sub subscription"
  value       = google_pubsub_subscription.backend_events_sub.name
}

output "bigquery_dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.events_dataset.dataset_id
}

output "storage_bucket_raw_events" {
  description = "Name of the raw events storage bucket"
  value       = google_storage_bucket.raw_events.name
}

output "storage_bucket_dataflow_temp" {
  description = "Name of the Dataflow temp storage bucket"
  value       = google_storage_bucket.dataflow_temp.name
}

output "storage_bucket_function_source" {
  description = "Name of the Cloud Function source storage bucket"
  value       = google_storage_bucket.function_source.name
}

output "dataflow_service_account_email" {
  description = "Email of the Dataflow service account"
  value       = google_service_account.dataflow_sa.email
}

output "table_manager_service_account_email" {
  description = "Email of the Table Manager service account"
  value       = google_service_account.table_manager_sa.email
}

# Cloud Function outputs commented out - deployed via script
# output "table_manager_function_name" {
#   description = "Name of the BigQuery Table Manager Cloud Function"
#   value       = google_cloudfunctions2_function.table_manager.name
# }

# output "table_manager_function_url" {
#   description = "URL of the BigQuery Table Manager Cloud Function"
#   value       = google_cloudfunctions2_function.table_manager.service_config[0].uri
# }

output "storage_bucket_dataflow_templates" {
  description = "Name of the Dataflow templates storage bucket"
  value       = google_storage_bucket.dataflow_templates.name
}

# Dataflow job outputs commented out - deployed via script
# output "dataflow_job_name" {
#   description = "Name of the Dataflow streaming pipeline job"
#   value       = google_dataflow_job.streaming_pipeline.name
# }

# output "dataflow_job_id" {
#   description = "ID of the Dataflow streaming pipeline job"
#   value       = google_dataflow_job.streaming_pipeline.job_id
# }

output "event_generator_service_account_email" {
  description = "Email of the Event Generator service account"
  value       = google_service_account.event_generator_sa.email
}

# Event Generator outputs commented out - service deployed via script
# output "event_generator_service_name" {
#   description = "Name of the Event Generator Cloud Run service"
#   value       = google_cloud_run_v2_service.event_generator.name
# }

# output "event_generator_service_url" {
#   description = "URL of the Event Generator Cloud Run service"
#   value       = google_cloud_run_v2_service.event_generator.uri
# } 