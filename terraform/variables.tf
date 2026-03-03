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
  description = "The Confluent Cloud Environment ID where the resources will be created. Sourced from the ingress workspace output: non_prod_environment_id."
  type        = string
}

# ===================================================
# AWS PROVIDER CONFIGURATION
# ===================================================
variable "aws_region" {
  description = "The AWS region for the egress gateway and all AWS resources."
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
  sensitive   = true
  default     = ""
}

variable "aws_session_token" {
  description = "The AWS Session Token."
  type        = string
  sensitive   = true
  default     = ""
}

# ===================================================
# JDBC / DATABASE CONFIGURATION
# ===================================================
variable "database_vpc_id" {
  description = "ID of the VPC where the database instance resides. The NLB will be deployed here."
  type        = string
}

variable "database_subnet_ids" {
  description = "List of private subnet IDs within the database VPC to deploy the NLB into. Should span multiple AZs."
  type        = list(string)
}

variable "database_private_ip" {
  description = "Private IP address of the database instance (EC2, RDS, etc.) to register in the NLB target group."
  type        = string
}

variable "database_port" {
  description = "TCP port the database listens on (e.g. 5432 for PostgreSQL, 3306 for MySQL, 1433 for SQL Server, 1521 for Oracle)."
  type        = number
}

variable "database_domain" {
  description = "FQDN used by the JDBC connector to reach the database (e.g. mydb.cluster-xxxx.us-east-1.rds.amazonaws.com). Must exactly match the confluent_dns_record domain."
  type        = string
}

variable "nlb_name" {
  description = "Name for the Network Load Balancer fronting the database."
  type        = string
  default     = "jdbc-privatelink-nlb"
}

variable "endpoint_service_name" {
  description = "Friendly name for the VPC Endpoint Service backing the NLB."
  type        = string
  default     = "jdbc-privatelink-endpoint-service"
}
