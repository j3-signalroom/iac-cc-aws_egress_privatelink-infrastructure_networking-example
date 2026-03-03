# =======================================================================================
# GATEWAY OUTPUTS
# =======================================================================================

output "egress_gateway_id" {
  description = "Confluent Egress PrivateLink Gateway ID — shared by all access points in this workspace."
  value       = confluent_gateway.non_prod_egress.id
}

output "egress_gateway_iam_principal" {
  description = "IAM Principal ARN Confluent uses to create VPC endpoints. Automatically set in aws_vpc_endpoint_service.allowed_principals for JDBC. Also visible in the Confluent Cloud Console under the gateway's Access Points tab."
  value       = confluent_gateway.non_prod_egress.aws_egress_private_link_gateway[0].principal_arn
}

# =======================================================================================
# S3 OUTPUTS
# =======================================================================================

output "egress_s3_access_point_id" {
  description = "Confluent access point ID for the S3 egress endpoint."
  value       = confluent_access_point.egress_s3.id
}

output "egress_s3_vpc_endpoint_id" {
  description = "AWS VPC endpoint ID for S3 egress. Add this to your S3 bucket policy as an aws:sourceVpce condition to restrict bucket access to Confluent's egress endpoint only."
  value       = confluent_access_point.egress_s3.aws_egress_private_link_endpoint[0].vpc_endpoint_id
}

# =======================================================================================
# JDBC OUTPUTS
# =======================================================================================

output "egress_jdbc_access_point_id" {
  description = "Confluent access point ID for the JDBC egress endpoint."
  value       = confluent_access_point.egress_jdbc.id
}

output "egress_jdbc_vpc_endpoint_id" {
  description = "AWS VPC endpoint ID for JDBC egress. Can be used in NLB or database security group ingress rules to further restrict access to traffic from Confluent's endpoint only."
  value       = confluent_access_point.egress_jdbc.aws_egress_private_link_endpoint[0].vpc_endpoint_id
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer fronting the database."
  value       = aws_lb.jdbc.arn
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer. Use for connectivity troubleshooting."
  value       = aws_lb.jdbc.dns_name
}

output "vpc_endpoint_service_name" {
  description = "AWS PrivateLink endpoint service name for JDBC — the service Confluent's access point connects to."
  value       = aws_vpc_endpoint_service.jdbc.service_name
}

output "vpc_endpoint_service_id" {
  description = "AWS VPC Endpoint Service ID for JDBC."
  value       = aws_vpc_endpoint_service.jdbc.id
}

# =======================================================================================
# CONNECTOR CONFIGURATION HINTS
# =======================================================================================

output "s3_connector_endpoint_hint" {
  description = "The S3 connector uses the standard AWS S3 endpoint. Confluent routes it over PrivateLink transparently via the DNS record."
  value       = "s3.${var.aws_region}.amazonaws.com"
}

output "jdbc_connector_connection_url_hint" {
  description = "Use this as the connection.url in the JDBC connector config. The hostname must exactly match the confluent_dns_record domain."
  value       = "jdbc:<engine>://${var.database_domain}:${var.database_port}/<database_name>"
}
