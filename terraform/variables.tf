# ===================================================
# CONFLUENT CLOUD CONFIGURATION
# ===================================================
variable "confluent_api_key" {
  description = "Confluent API Key (also referred as Cloud API ID)."
  type        = string
}

variable "confluent_api_secret" {
  description = "Confluent API Secret."
  type        = string
  sensitive   = true
}

variable "confluent_environment_id" {
  description = "The Confluent Cloud Environment ID where the resources will be created."
  type        = string
}

# ===================================================
# AWS PROVIDER CONFIGURATION
# ===================================================
variable "aws_region" {
    description = "The AWS Region."
    type        = string
}

variable "aws_access_key_id" {
    description = "The AWS Access Key ID."
    type        = string
    default     = ""
}

variable "aws_secret_access_key" {
    description = "The AWS Secret Access Key."
    type        = string
    default     = ""
}

variable "aws_session_token" {
    description = "The AWS Session Token."
    type        = string
    default     = ""
}
