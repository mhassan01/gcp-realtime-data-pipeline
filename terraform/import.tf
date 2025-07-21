# This file is used to import existing resources into the Terraform state.
# It is not meant to be committed to the repository, as it contains
# project-specific information.

import {
  to = google_storage_bucket.terraform_state
  id = "terraform-state-fabled-web-172810dev"
}

import {
  to = google_service_account.dataflow_sa
  id = "projects/fabled-web-172810dev/serviceAccounts/dev-dataflow-pipeline-sa@fabled-web-172810dev.iam.gserviceaccount.com"
}

import {
  to = google_service_account.table_manager_sa
  id = "projects/fabled-web-172810dev/serviceAccounts/dev-table-manager-sa@fabled-web-172810dev.iam.gserviceaccount.com"
}

import {
  to = google_service_account.event_generator_sa
  id = "projects/fabled-web-172810dev/serviceAccounts/dev-event-generator-sa@fabled-web-172810dev.iam.gserviceaccount.com"
}

import {
  to = google_pubsub_topic.dead_letter
  id = "projects/fabled-web-172810dev/topics/dev-backend-events-dead-letter"
}

import {
  to = google_pubsub_topic.backend_events
  id = "projects/fabled-web-172810dev/topics/dev-backend-events-topic"
}

import {
  to = google_storage_bucket.raw_events
  id = "fabled-web-172810dev-dev-raw-events"
}

import {
  to = google_storage_bucket.dataflow_temp
  id = "fabled-web-172810dev-dev-dataflow-temp"
}

import {
  to = google_storage_bucket.dataflow_templates
  id = "fabled-web-172810dev-dev-dataflow-templates"
}

import {
  to = google_storage_bucket.function_source
  id = "fabled-web-172810dev-dev-function-source"
}

import {
  to = google_bigquery_dataset.events_dataset
  id = "projects/fabled-web-172810dev/datasets/dev_events_dataset"
} 