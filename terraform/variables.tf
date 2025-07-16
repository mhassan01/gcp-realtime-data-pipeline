variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "fabled-web-172810"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = "mohammedhasssan3390515@gmail.com"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "dataflow_machine_type" {
  description = "Machine type for Dataflow workers"
  type        = string
  default     = "n1-standard-2"
}

variable "dataflow_max_workers" {
  description = "Maximum number of Dataflow workers"
  type        = number
  default     = 10
}

variable "dataflow_num_workers" {
  description = "Initial number of Dataflow workers"
  type        = number
  default     = 2
}