# Confluent environment — ID sourced from the ingress workspace output
data "confluent_environment" "non_prod" {
  id = var.confluent_environment_id
}

# Used to scope the NLB security group ingress rule to the database VPC CIDR
data "aws_vpc" "database" {
  id = var.database_vpc_id
}

locals {
  database_subnet_ids = length(var.database_subnet_ids) > 0 ? split(",", var.database_subnet_ids) : []
}