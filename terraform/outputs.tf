# The IAM principal from the gateway
output "egress_gateway_iam_principal" {
  description = "IAM Principal ARN for Confluent Egress PrivateLink — add this to your S3 bucket policy"
  value       = confluent_gateway.non_prod_egress.aws_egress_private_link_gateway[0].principal_arn
}

output "egress_gateway_id" {
  description = "Confluent Egress PrivateLink Gateway ID"
  value       = confluent_gateway.non_prod_egress.id
}

output "egress_s3_access_point_id" {
  description = "Access point ID for the S3 egress endpoint"
  value       = confluent_access_point.egress_s3.id
}

output "egress_s3_vpc_endpoint_id" {
  description = "VPC endpoint ID — use in S3 bucket policy aws:sourceVpce condition"
  value       = confluent_access_point.egress_s3.aws_egress_private_link_endpoint[0].vpc_endpoint_id
}